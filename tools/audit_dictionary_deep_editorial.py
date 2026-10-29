#!/usr/bin/env python3
"""Read-only deeper Arabic source-card quality audit across the entire corpus.

These findings are editorial REVIEW candidates; similarity or vowel coverage
does not itself prove an Arabic error and NEVER triggers an automatic merge.
"""
from __future__ import annotations

import argparse
import json
import re
import unicodedata
from collections import defaultdict
from pathlib import Path
from typing import Any, Iterable

from audit_dictionary_variants import iter_corpus_chunks, strip_diacritics

ARABIC_LETTER = re.compile(r"[\u0621-\u064A]")
DIACRITIC = re.compile(r"[\u064B-\u065F\u0670\u06D6-\u06ED]")
TOKEN = re.compile(r"[\u0621-\u064A\u0671][\u0621-\u064A\u0671\u064B-\u065F\u0670\u06D6-\u06ED]*")
IGNORE_LETTERS = set("اويىءآٱ")
NO_MARK = re.compile(r"[\u064B-\u065F\u0670\u06D6-\u06ED]")
NORMALIZE_SPACE = re.compile(r"\s+")
# In assimilated Arabic definite articles, ل must NOT carry sukun before a
# sun letter with shadda (e.g., السَّ not الْسَّ). Retain valid moon-letter sukun.
WRONG_SOLAR_LAM = re.compile(r"الْ[تثدذرزسشصضطظلن][\u064b-\u065f]*ّ")



def find_missing_moon_lam_sukun(text: str) -> list[str]:
    """Only pronounced hamza (أ / إ / آ) is checked, not wasl-alif."""
    if not isinstance(text, str):
        return []
    return [m.group(0) for m in re.finditer(
        r"ال[أإآ][\u064b-\u065f]?", unicodedata.normalize("NFC", text))]


def find_wrong_solar_lam(text: str) -> list[str]:
    """Return offending orthographic fragments (never rewrite source implicitly)."""
    if not isinstance(text, str):
        return []
    return [m.group(0) for m in WRONG_SOLAR_LAM.finditer(unicodedata.normalize("NFC", text))]



def vowel_coverage(text: str) -> dict[str, Any]:
    """Estimate explicitly marked consonants, with conservative exceptions.

    Alif/long vowels and sun-letter assimilation in the definite article may
    legitimately carry no mark. This metric deliberately cannot certify full
    linguistic vowelization. It is a review prioritizer, never a CI hard gate.
    """
    missing = []
    covered = 0
    eligible = 0
    if not isinstance(text, str):
        return {"missing": missing, "coverage": 1.0}
    for token in TOKEN.findall(unicodedata.normalize("NFC", text)):
        bases = []
        for char in token:
            if ARABIC_LETTER.fullmatch(char) or char == "ٱ":
                bases.append([char, ""])
            elif DIACRITIC.fullmatch(char) and bases:
                bases[-1][1] += char
        if not bases:
            continue
        # In الشَّمْسِيَّة the written lam is silent and legitimately has
        # no sukun: التَّ...; the same is true following بِـ or لِـ:
        # بِالتَّ... / لِلتَّ... / لِلصُّ... / بِالرَّ...
        chars = [part[0] for part in bases]
        silent_lam = None
        if len(bases) > 2 and chars[:2] in (["ا", "ل"], ["ل", "ل"]) and "ّ" in bases[2][1]:
            silent_lam = 1
        elif (len(bases) > 3 and chars[0] in "بكوف"
              and chars[1:3] == ["ا", "ل"] and "ّ" in bases[3][1]):
            silent_lam = 2
        for index, (char, marks) in enumerate(bases):
            if char in IGNORE_LETTERS:
                continue
            if index == silent_lam:
                continue
            eligible += 1
            if marks:
                covered += 1
            else:
                missing.append(char)
    return {"missing": missing, "coverage": round(covered / eligible, 4) if eligible else 1.0}


def _grammar_kind(card: dict[str, Any]) -> set[str]:
    # Match categorical POS labels, not examples or morphological annotations.
    out: set[str] = set()
    for raw in card.get("grammar") or []:
        if not isinstance(raw, str):
            continue
        s = strip_diacritics(raw).strip()
        if s.startswith(("فعل", "الفعل")):
            out.add("verb")
        elif s.startswith(("اسم", "الاسم", "صفة", "الصفة", "مصدر", "المصدر", "تركيب اسمي")):
            out.add("nominal")
        elif s.startswith(("حرف", "الحرف")):
            out.add("particle")
    return out


def detect_conflicting_metadata(cards: Iterable[tuple[str, dict[str, Any]]]) -> list[dict[str, Any]]:
    groups = defaultdict(list)
    for filename, card in cards:
        word = card.get("arabic")
        if isinstance(word, str) and word.strip():
            groups[word].append((filename, card))
    issues = []
    for word, entries in groups.items():
        kinds = set().union(*(_grammar_kind(c) for _, c in entries))
        if "nominal" in kinds and "verb" in kinds:
            issues.append({"arabic": word, "kind": "nominal_and_verb", "files": sorted({f for f, _ in entries}),
                           "entries": [{"id": c.get("id"), "grammar": c.get("grammar", [])} for _, c in entries]})
    return sorted(issues, key=lambda x: x["arabic"])


def inspect_deep_quality(cards: Iterable[tuple[str, dict[str, Any]]]) -> dict[str, Any]:
    """Analyze every pre-merge card (including those hidden by duplicate heads)."""
    all_cards = list(cards)
    missing = []
    self_synonym = []
    overlap = []
    solar_lam = []
    moon_lam = []
    definition_index = defaultdict(lambda: {"headwords": set(), "files": set(), "count": 0})
    for filename, card in all_cards:
        word = card.get("arabic") or ""
        if not isinstance(word, str) or not word:
            continue
        for field in ("arabic", "meaning_ar", "usage_note_ar", "grammar",
                      "collocations", "examples_ar", "additional_meanings_ar",
                      "synonyms", "antonyms"):
            value = card.get(field)
            texts = [value] if isinstance(value, str) else (value if isinstance(value, list) else [])
            for idx, part in enumerate(texts):
                missing_moon = find_missing_moon_lam_sukun(part)
                if missing_moon:
                    moon_lam.append({"file": filename, "id": card.get("id"),
                                     "arabic": word, "field": field, "index": idx,
                                     "fragments": missing_moon, "text": part[:240]})
                wrong = find_wrong_solar_lam(part)
                if wrong:
                    solar_lam.append({"file": filename, "id": card.get("id"),
                                      "arabic": word, "field": field, "index": idx,
                                      "fragments": wrong, "text": part[:240]})
        coverage = vowel_coverage(word)
        if coverage["missing"]:
            missing.append({"file": filename, "id": card.get("id"), "arabic": word,
                            "coverage": coverage["coverage"], "unmarked": coverage["missing"][:12]})
        synonyms = {strip_diacritics(x) for x in (card.get("synonyms") or []) if isinstance(x, str)}
        antonyms = {strip_diacritics(x) for x in (card.get("antonyms") or []) if isinstance(x, str)}
        lemma = strip_diacritics(word)
        if lemma in synonyms:
            self_synonym.append({"file": filename, "id": card.get("id"), "arabic": word})
        shared = sorted(synonyms & antonyms)
        if shared:
            overlap.append({"file": filename, "id": card.get("id"), "arabic": word, "overlap": shared})
        definition = card.get("meaning_ar") or ""
        if isinstance(definition, str):
            norm_def = NORMALIZE_SPACE.sub(" ", unicodedata.normalize("NFC", definition)).strip()
            if len(norm_def) > 14:
                bucket = definition_index[norm_def]
                bucket["headwords"].add(word)
                bucket["files"].add(filename)
                bucket["count"] += 1

    repeats = [
        {"meaning": key[:180], "headwords": sorted(bucket["headwords"]),
         "files": sorted(bucket["files"]), "raw_count": bucket["count"]}
        for key, bucket in definition_index.items() if len(bucket["headwords"]) > 1
    ]
    repeats.sort(key=lambda x: (-len(x["headwords"]), x["headwords"]))
    return {
        "source_cards": len(all_cards),
        "wrong_solar_article_lam_sukun": solar_lam,
        "missing_moon_article_lam_sukun": moon_lam,
        "headwords_with_incomplete_harakat": missing,
        "self_synonym": self_synonym,
        "synonym_antonym_overlap": overlap,
        "repeated_meaning_across_distinct_headwords": repeats,
        "metadata_conflicts": detect_conflicting_metadata(all_cards),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json-out", type=Path, default=None)
    parser.add_argument("--max-examples", type=int, default=90)
    args = parser.parse_args()
    report = inspect_deep_quality(iter_corpus_chunks())
    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("DEEP_DICTIONARY_QA_BEGIN")
    print(json.dumps({
        "source_cards": report["source_cards"],
        "wrong_solar_article_lam_sukun": len(report["wrong_solar_article_lam_sukun"]),
        "missing_moon_article_lam_sukun": len(report["missing_moon_article_lam_sukun"]),
        "headwords_with_incomplete_harakat": len(report["headwords_with_incomplete_harakat"]),
        "self_synonym": len(report["self_synonym"]),
        "synonym_antonym_overlap": len(report["synonym_antonym_overlap"]),
        "repeated_meaning_across_distinct_headwords": len(report["repeated_meaning_across_distinct_headwords"]),
        "metadata_conflicts": len(report["metadata_conflicts"]),
        "examples": {k: v[:args.max_examples] for k, v in report.items() if isinstance(v, list)},
    }, indent=2, ensure_ascii=False))
    print("DEEP_DICTIONARY_QA_END")


if __name__ == "__main__":
    main()
