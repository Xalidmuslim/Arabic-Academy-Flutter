#!/usr/bin/env python3
"""Apply narrowly confirmed diacritic corrections in Arabic *prose* only.

This does not change headwords, merge homographs, invent references, or
automatically infer vowels. All replacements are explicitly editorially
reviewed, and the operation is idempotent. The CI job validates the outcome
before committing changed JSON source files.
"""
from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from audit_dictionary_variants import iter_corpus_chunks
from validate_dictionary import ROOT

PROSE_FIELDS = ("meaning_ar", "usage_note_ar", "examples_ar",
                "collocations", "additional_meanings_ar")

# Exact, confirmed misspellings from the 2026-10-29 failing regression test.
# Do NOT expand this list by guessing diacritics from a skeleton.
REPLACEMENTS = (
    ("كَلام", "كَلَام"),
    ("عَلاق", "عَلَاق"),
    ("عَلام", "عَلَام"),
    ("آلي", "آلِي"),
    ("اكتَشَف", "اِكْتَشَف"),
    ("أَنْماط", "أَنْمَاط"),
    ("الْهِلال", "الْهِلَال"),
    ("يَنْمو", "يَنْمُو"),
    ("تَنْمو", "تَنْمُو"),
    ("خِلاف", "خِلَاف"),
    ("لِلوُصُولِ", "لِلْوُصُولِ"),
)


def correct_prose(value: str) -> tuple[str, Counter[str]]:
    changes: Counter[str] = Counter()
    for wrong, right in REPLACEMENTS:
        count = value.count(wrong)
        if count:
            value = value.replace(wrong, right)
            changes[wrong] += count
    return value, changes


def correct_entry(entry: dict[str, Any]) -> tuple[dict[str, Any], Counter[str]]:
    """Only five prose fields may change; do not touch identifiers or lemmas."""
    clone = dict(entry)
    changes: Counter[str] = Counter()
    for field in PROSE_FIELDS:
        value = entry.get(field)
        if isinstance(value, str):
            clone[field], delta = correct_prose(value)
            changes.update(delta)
        elif isinstance(value, list):
            corrected = []
            for item in value:
                if isinstance(item, str):
                    item, delta = correct_prose(item)
                    changes.update(delta)
                corrected.append(item)
            clone[field] = corrected
    return clone, changes


def apply_corrections(root: Path, write: bool) -> dict[str, Any]:
    manifest = json.loads((root / "assets/data/corpus_manifest.json").read_text(encoding="utf-8"))
    total: Counter[str] = Counter()
    updated_files: list[str] = []
    updated_cards = 0
    for filename in manifest["files"]:
        path = root / filename
        original = path.read_text(encoding="utf-8")
        document = json.loads(original)
        changed = False
        corrected_entries = []
        for entry in document["entries"]:
            corrected, differences = correct_entry(entry)
            if differences:
                changed = True
                updated_cards += 1
                total.update(differences)
            corrected_entries.append(corrected)
        if changed:
            document["entries"] = corrected_entries
            updated_files.append(filename)
            if write:
                path.write_text(json.dumps(document, ensure_ascii=False, indent=2) + "\n",
                                encoding="utf-8")
    return {
        "write": write,
        "changed_files": len(updated_files),
        "changed_cards": updated_cards,
        "corrected_occurrences": sum(total.values()),
        "replacement_counts": dict(total),
        "files": updated_files,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true",
                        help="Write only the confirmed corrections; default is dry run")
    args = parser.parse_args()
    result = apply_corrections(ROOT, write=args.apply)
    print("CONFIRMED_PROSE_CORRECTIONS_BEGIN")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    print("CONFIRMED_PROSE_CORRECTIONS_END")


if __name__ == "__main__":
    main()
