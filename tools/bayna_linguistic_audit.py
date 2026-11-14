#!/usr/bin/env python3
"""Read-only QA for Bayna dictionary data, with three optional Arabic NLP engines.

Run from repository root: python3 tools/bayna_linguistic_audit.py --output audit.json
No source files or Android/Flutter assets are ever modified.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import subprocess
import unicodedata
from datetime import datetime, timezone
from pathlib import Path

ARABIC = re.compile(r"[\u0621-\u064a\u0671]")
MARKS = re.compile(r"[\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06ed]")
HARAKAT = re.compile(r"[\u064b-\u065f\u0670]")
FOREIGN = re.compile(r"[A-Za-z\u0400-\u052f]")
LOCATION = re.compile(r"^\(\d+:\d+:\d+:\d+\)$")
BUCKWALTER = {
    "'": "ء", "|": "آ", ">": "أ", "<": "إ", "&": "ؤ", "}": "ئ",
    "A": "ا", "b": "ب", "p": "ة", "t": "ت", "v": "ث", "j": "ج", "H": "ح",
    "x": "خ", "d": "د", "*": "ذ", "r": "ر", "z": "ز", "s": "س", "$": "ش",
    "S": "ص", "D": "ض", "T": "ط", "Z": "ظ", "E": "ع", "g": "غ", "f": "ف",
    "q": "ق", "k": "ك", "l": "ل", "m": "م", "n": "ن", "h": "ه", "w": "و",
    "Y": "ى", "y": "ي", "F": "ً", "N": "ٌ", "K": "ٍ", "a": "َ", "u": "ُ",
    "i": "ِ", "~": "ّ", "o": "ْ", "^": "ٓ", "#": "ٔ", "`": "ٰ", "{": "ٱ",
}


def to_arabic(s: str) -> str:
    if ARABIC.search(s):
        return s
    return "".join(BUCKWALTER.get(c, c) for c in s)


def bare(s: str) -> str:
    return MARKS.sub("", unicodedata.normalize("NFC", s)).replace("ـ", "").strip()


def root_key(s: str) -> str:
    return re.sub(r"[^\u0621-\u064a\u0671]", "", bare(to_arabic(s)))


def comparable_diac(s: str) -> str:
    """Ignore optional fatHa before bare alif for candidate comparison only.

    The original form and all its diacritics remain unchanged in the corpus.
    Other vowel distinctions (including case endings) are preserved.
    """
    normalized = unicodedata.normalize("NFC", s)
    return re.sub("\u064e(?=\u0627)", "", normalized)


def root_from_grammar(parts: list[str]) -> str:
    for text in parts:
        match = re.search(r"جَذْرُهُ\s*[:：]\s*([^\.،\n]+)", text)
        if match:
            root = root_key(match.group(1))
            if len(root) in (3, 4):
                return root
    return ""


def ar_facts(items) -> list[str]:
    if not isinstance(items, list):
        return []
    return [str(item.get("ar", "")) if isinstance(item, dict) else str(item) for item in items]


def normalize_entry(entry: dict, origin: str, reviewed: bool) -> dict:
    grammar = ar_facts(entry.get("grammar"))
    return {
        "id": ("reviewed:" + str(entry.get("arabic", ""))) if reviewed else str(entry.get("id", "")),
        "word": str(entry.get("arabic", "")),
        "root": root_from_grammar(grammar),
        "meaning": ar_facts(entry.get("definition")) if reviewed else [str(entry.get("meaning_ar") or "")] + ar_facts(entry.get("additional_meanings_ar")),
        "grammar": grammar,
        "examples": ar_facts(entry.get("examples" if reviewed else "examples_ar")),
        "synonyms": ar_facts(entry.get("synonyms")),
        "antonyms": ar_facts(entry.get("contrasts" if reviewed else "antonyms")),
        "important": ar_facts(entry.get("important")) if reviewed else [str(entry.get("usage_note_ar") or "")],
        "source_file": origin,
    }


def iter_entries(repo: Path):
    repo = repo.resolve()
    manifest = json.loads((repo / "assets/data/corpus_manifest.json").read_text(encoding="utf-8"))
    files = manifest.get("files")
    if not isinstance(files, list) or not files:
        raise ValueError("Invalid corpus_manifest.json")
    for name in files:
        if not isinstance(name, str):
            raise ValueError("Non-string corpus path")
        p = (repo / name).resolve()
        if not p.is_relative_to(repo) or not p.is_file():
            raise ValueError(f"Invalid or missing corpus path: {name}")
        for entry in json.loads(p.read_text(encoding="utf-8"))["entries"]:
            yield normalize_entry(entry, name, False)
    reviewed = repo / "assets/data/reviewed_articles_v1.json"
    if reviewed.is_file():
        for entry in json.loads(reviewed.read_text(encoding="utf-8"))["entries"]:
            yield normalize_entry(entry, "assets/data/reviewed_articles_v1.json", True)


def finding(code: str, message: str, severity: str = "review", source: str = "local") -> dict:
    return {"code": code, "message": message, "severity": severity, "source": source}


def valid_arabic(entry: dict) -> list[dict]:
    findings = []
    word = entry.get("word", "")
    if not ARABIC.search(word):
        return [finding("missing_arabic_headword", "Нет арабского заголовочного слова")]
    if not HARAKAT.search(word):
        findings.append(finding("missing_word_diacritics", "Огласовки заголовочного слова нужно сверить"))
    for field in ("meaning", "grammar", "examples", "important", "synonyms", "antonyms"):
        parts = entry.get(field, [])
        if field in ("meaning", "grammar", "examples", "important") and not any(s.strip() for s in parts):
            findings.append(finding("missing_" + field, "Отсутствует обязательный материал"))
        # Empty synonyms / antonyms are legitimate; never invent relations.
        for index, item in enumerate(parts):
            if FOREIGN.search(item):
                findings.append(finding("non_arabic_" + field, f"Поле {field}[{index}] содержит латиницу/кириллицу"))
            if ARABIC.search(item) and not HARAKAT.search(item):
                findings.append(finding("unvowelled_" + field, f"Поле {field}[{index}] требует проверки огласовок"))
    return findings


class QuranIndex:
    """Parse official corpus once; matching roots are reference hints only."""
    def __init__(self, path: Path):
        self.roots: dict[str, list[dict]] = {}
        self.segments: dict[str, list[dict]] = {}
        with Path(path).open(encoding="utf-8-sig", newline="") as source:
            for row in csv.reader(source, delimiter="\t"):
                if len(row) < 4 or not LOCATION.fullmatch(row[0]):
                    continue
                location, form, tag, attrs = row[:4]
                root_raw = next((v[5:] for v in attrs.split("|") if v.startswith("ROOT:")), "")
                ar_root = root_key(root_raw)
                rec = {"location": location, "root_arabic": ar_root, "form_buckwalter": form, "tag": tag}
                if ar_root:
                    self.roots.setdefault(ar_root, []).append(rec)
                self.segments.setdefault(bare(to_arabic(form)), []).append(rec)

    def lookup(self, word: str, root: str, limit: int = 5) -> list[dict]:
        """Return only source locations; never republish corpus annotation rows."""
        root = root_key(root)
        if root and root in self.roots:
            return [{"location": r["location"], "match_type": "root_reference"}
                    for r in self.roots[root][:limit]]
        return [{"location": r["location"], "match_type": "segment_reference"}
                for r in self.segments.get(bare(word), [])[:limit]]


def quran_lookup(path: Path, word: str, root: str, limit: int = 5) -> list[dict]:
    """Convenience one-shot lookup for interactive checks; bulk audit uses QuranIndex."""
    return QuranIndex(path).lookup(word, root, limit)


def get_morph():
    try:
        from camel_tools.morphology.analyzer import Analyzer
        from camel_tools.morphology.database import MorphologyDB
        return Analyzer(MorphologyDB.builtin_db())
    except Exception as exc:
        raise RuntimeError(f"CAMeL Tools or model unavailable: {exc}") from exc


def parse_sentence(text: str, repo: Path, python: str) -> dict:
    exe = Path(repo) / "text_to_conll_cli.py"
    if not exe.is_file():
        return {"status": "unavailable", "message": "text_to_conll_cli.py not installed"}
    try:
        process = subprocess.run(
            [python, str(exe), "-f", "text", "-d", "mle", "-m", "catib", "-s", text],
            cwd=str(repo), encoding="utf-8", errors="replace", capture_output=True, timeout=120, check=False)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {"status": "unavailable", "message": str(exc)[:300]}
    if process.returncode:
        return {"status": "error", "message": (process.stderr or process.stdout)[:600]}
    return {"status": "ok" if process.stdout.strip() else "review", "output": process.stdout[:3500]}


def audit(entries: list[dict], morph=None, corpus: QuranIndex | None = None, parser_repo: Path | None = None, parser_python: str | None = None, parser_max_entries: int = 20) -> dict:
    results = []
    for idx, entry in enumerate(entries):
        issues = valid_arabic(entry)
        word = entry.get("word", "")
        morph_candidates, corpus_refs, syntax = [], [], []
        if morph and ARABIC.search(word):
            try:
                analyses = morph.analyze(bare(word))
                morph_candidates = [{k: str(a.get(k, "")) for k in ("diac", "root", "pos", "lex") if k in a} for a in analyses[:8]]
                roots = {root_key(a.get("root", "")) for a in analyses}
                if entry.get("root") and root_key(entry["root"]) not in roots:
                    issues.append(finding("root_candidate_disagreement", "Корень отсутствует среди вариантов модели; нужна ручная сверка", source="camel_tools"))
                if analyses and all(comparable_diac(to_arabic(str(a.get("diac", "")))) != comparable_diac(word) for a in analyses):
                    issues.append(finding("diac_candidate_disagreement", "Нет точного совпадения огласовок среди вариантов модели; не исправлять автоматически", source="camel_tools"))
            except Exception as exc:
                issues.append(finding("camel_runtime_error", str(exc)[:300], source="camel_tools"))
        if corpus and ARABIC.search(word):
            corpus_refs = corpus.lookup(word, entry.get("root", ""), limit=3)
        if parser_repo and parser_python and idx < parser_max_entries and entry.get("examples"):
            syntax = [parse_sentence(entry["examples"][0], parser_repo, parser_python)]
        results.append({"id": entry.get("id"), "word": word, "source_file": entry.get("source_file"), "findings": issues, "morphology_candidates": morph_candidates, "quran_references": corpus_refs, "syntax": syntax})
    return {
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "mode": "READ_ONLY_NO_AUTOCORRECTION",
        "engines": {"camel_tools": "enabled" if morph else "not_run", "quranic_arabic_corpus": "enabled" if corpus else "not_run", "camel_parser": f"enabled_sampled_first_{min(parser_max_entries, len(entries))}" if parser_repo and parser_python else "not_run"},
        "summary": {"entries": len(results), "flagged_entries": sum(bool(r["findings"]) for r in results), "findings": sum(len(r["findings"]) for r in results)},
        "results": results,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Bayna Arabic audit, read-only")
    parser.add_argument("--repo", default=".")
    parser.add_argument("--output", required=True)
    parser.add_argument("--limit", type=int, default=0, help="0 = all entries; positive number = initial sample")
    parser.add_argument("--camel", action="store_true")
    parser.add_argument("--quran-corpus", type=Path)
    parser.add_argument("--parser-repo", type=Path)
    parser.add_argument("--parser-python")
    parser.add_argument("--parser-max-entries", type=int, default=20, help="Max entries to parse with CamelParser, to avoid unbounded costly subprocesses")
    args = parser.parse_args()
    if args.limit < 0 or args.parser_max_entries < 0 or bool(args.parser_repo) != bool(args.parser_python):
        parser.error("Limit must be >= 0; both --parser-repo and --parser-python are required")
    try:
        rows = iter_entries(Path(args.repo))
        if args.limit:
            from itertools import islice
            rows = islice(rows, args.limit)
        result = audit(list(rows), morph=get_morph() if args.camel else None, corpus=QuranIndex(args.quran_corpus) if args.quran_corpus else None, parser_repo=args.parser_repo, parser_python=args.parser_python, parser_max_entries=args.parser_max_entries)
        out = Path(args.output)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"Read-only: {result['summary']['entries']} entries; {result['summary']['flagged_entries']} flagged; {out}")
    except (OSError, ValueError, KeyError, TypeError, RuntimeError) as exc:
        parser.exit(2, f"Cannot audit: {exc}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
