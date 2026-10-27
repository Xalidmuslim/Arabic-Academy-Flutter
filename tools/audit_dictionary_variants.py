#!/usr/bin/env python3
"""Read-only, conservative audit of Arabic headword spellings across all chunks.

IMPORTANT: A shared consonantal spelling does not prove a duplicate!
Arabic homographs (e.g. عَلَمٌ and عِلْمٌ) must remain independent articles
unless explicitly collated by an Arabic-language editor.
"""
from __future__ import annotations

import argparse
import json
import re
import unicodedata
from collections import defaultdict
from pathlib import Path
from typing import Iterable, Any

from validate_dictionary import ROOT

DIACRITICS = re.compile(r"[\u064b-\u065f\u0670\u06d6-\u06ed]")
TATWEEL = "\u0640"
ENDINGS = re.compile(r"[\u064b-\u0652]+$")
WHITESPACE = re.compile(r"\s+")


def strip_diacritics(word: str) -> str:
    """For review candidates only; does not equate distinct Arabic letters."""
    word = unicodedata.normalize("NFC", word).replace(TATWEEL, "")
    return WHITESPACE.sub(" ", DIACRITICS.sub("", word)).strip()


def remove_final_marks(word: str) -> str:
    """Drop word-final marks (may reflect DIFFERENT parts of speech, not just case)."""
    word = unicodedata.normalize("NFC", word).replace(TATWEEL, "").strip()
    return ENDINGS.sub("", word)


def classify_pair(a: str, b: str) -> str | None:
    if not a or not b or a == b or strip_diacritics(a) != strip_diacritics(b):
        return None
    # NFC catches visually identical letters with differently ordered vowel marks.
    if (unicodedata.normalize("NFC", a.replace(TATWEEL, ""))
            == unicodedata.normalize("NFC", b.replace(TATWEEL, ""))):
        return "unicode_equivalent"
    if remove_final_marks(a) == remove_final_marks(b):
        return "final_mark_only"
    return "vocalization_diff"


def audit_entries(entries: Iterable[tuple[str, dict[str, Any]]]) -> dict[str, Any]:
    exact = set()
    groups = defaultdict(lambda: {"variants": {}, "sources": set(), "total": 0})
    raw = 0
    for filename, item in entries:
        raw += 1
        word = item.get("arabic")
        if not isinstance(word, str) or not word.strip():
            continue
        exact.add(word)
        skeleton = strip_diacritics(word)
        if not skeleton:
            continue
        group = groups[skeleton]
        group["total"] += 1
        group["sources"].add(filename)
        bucket = group["variants"].setdefault(word, {
            "count": 0, "files": set(), "meanings": [],
        })
        bucket["count"] += 1
        bucket["files"].add(filename)
        meaning = item.get("meaning_ar")
        if isinstance(meaning, str) and meaning and meaning not in bucket["meanings"]:
            # Preserve enough examples for human review, not every sense.
            if len(bucket["meanings"]) < 2:
                bucket["meanings"].append(meaning[:160])

    review = []
    for skeleton, group in groups.items():
        forms = list(group["variants"])
        if len(forms) < 2:
            continue
        kinds = [classify_pair(forms[0], form) for form in forms[1:]]
        if all(k == "unicode_equivalent" for k in kinds):
            kind = "unicode_equivalent"
        elif all(k in ("unicode_equivalent", "final_mark_only") for k in kinds):
            kind = "final_mark_only"
        else:
            kind = "vocalization_diff"
        review.append({
            "unvocalized": skeleton,
            "kind": kind,
            "forms": forms,
            "source_files": sorted(group["sources"]),
            "total_raw_cards": group["total"],
            "details": [
                {"form": form, "count": group["variants"][form]["count"],
                 "files": sorted(group["variants"][form]["files"]),
                 "meanings": group["variants"][form]["meanings"]}
                for form in forms
            ],
        })

    # Put recent editorial candidates and strictly formatting-only variants first.
    review.sort(key=lambda g: (
        not any("20261027" in f for f in g["source_files"]),
        {"unicode_equivalent": 0, "final_mark_only": 1, "vocalization_diff": 2}[g["kind"]],
        -g["total_raw_cards"],
        g["unvocalized"],
    ))
    return {
        "raw_entries": raw,
        "exact_unique": len(exact),
        "exact_repeated": raw - len(exact),
        "unvocalized_variant_groups": len(review),
        "unicode_equivalent_groups": sum(g["kind"] == "unicode_equivalent" for g in review),
        "final_mark_only_groups": sum(g["kind"] == "final_mark_only" for g in review),
        "vocalization_diff_groups": sum(g["kind"] == "vocalization_diff" for g in review),
        "affected_recent_groups": sum(any("20261027" in f for f in g["source_files"]) for g in review),
        "groups": review,
    }


def iter_corpus_chunks(root: Path = ROOT):
    manifest = json.loads((root / "assets/data/corpus_manifest.json").read_text(encoding="utf-8"))
    for filename in manifest["files"]:
        path = root / filename
        data = json.loads(path.read_text(encoding="utf-8"))
        for item in data["entries"]:
            yield filename, item


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--max-groups", type=int, default=75)
    parser.add_argument("--json-out", type=Path, default=None,
                        help="Optional complete machine-readable audit output (never overwrites source)")
    args = parser.parse_args()
    result = audit_entries(iter_corpus_chunks())
    if args.json_out is not None:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    output = {k: v for k, v in result.items() if k != "groups"}
    output["review_groups"] = [{
        "unvocalized": g["unvocalized"],
        "kind": g["kind"],
        "forms": g["forms"],
        "source_files": [Path(p).name for p in g["source_files"]],
        "meanings": [d["meanings"][0][:115] if d["meanings"] else "" for d in g["details"]],
    } for g in result["groups"][:max(0, args.max_groups)]]
    output["review_output_limited"] = len(result["groups"]) > args.max_groups
    print(json.dumps(output, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
