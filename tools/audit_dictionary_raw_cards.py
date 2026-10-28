#!/usr/bin/env python3
"""Non-destructive editorial audit of every raw source card before merge.

The normal validator inspects a merged headword view. A second source file
can have invalid data which is hidden when its headword is folded into an
earlier entry. This audit reports such defects separately. Missing grammatical
enrichment is a review cue, not an automatic reason to delete a lemma.
"""
from __future__ import annotations

import argparse
import json
import re
import unicodedata
from collections import Counter
from pathlib import Path
from typing import Any, Iterable

from audit_dictionary_variants import iter_corpus_chunks

ARABIC = re.compile(r"[\u0621-\u064a]")
FOREIGN = re.compile(r"[A-Za-zА-Яа-яЁё]")
HARAKAT = re.compile(r"[\u064b-\u065f\u0670]")
LISTS = ("grammar", "collocations", "examples_ar", "synonyms", "antonyms",
         "additional_meanings_ar", "book_references", "sources")


def inspect_raw_cards(cards: Iterable[tuple[str, dict[str, Any]]]) -> dict[str, Any]:
    totals = Counter()
    first_by_id = {}
    issues = []
    files = set()
    for filename, card in cards:
        totals["source_cards"] += 1
        files.add(filename)
        flags = []
        word = card.get("arabic")
        stable_id = card.get("id")
        if not isinstance(stable_id, str) or not stable_id.strip():
            flags.append("missing_id")
            totals["missing_id"] += 1
        elif stable_id in first_by_id:
            flags.append("repeated_card_id")
            totals["repeated_card_ids"] += 1
        else:
            first_by_id[stable_id] = filename

        if not isinstance(word, str) or not ARABIC.search(word):
            flags.append("invalid_headword")
            totals["invalid_headword_cards"] += 1
        elif not HARAKAT.search(word):
            flags.append("unvocalized_headword")
            totals["unvocalized_headword_cards"] += 1
        if isinstance(word, str) and unicodedata.normalize("NFC", word) != word:
            flags.append("non_nfc_headword")
            totals["non_nfc_headword_cards"] += 1

        meaning = card.get("meaning_ar")
        if not isinstance(meaning, str) or len(meaning) < 14 or not ARABIC.search(meaning):
            flags.append("invalid_definition")
            totals["invalid_definition_cards"] += 1

        if not isinstance(card.get("usage_note_ar"), str):
            flags.append("missing_usage_note")
            totals["missing_usage_note_field"] += 1

        for field in LISTS:
            value = card.get(field)
            if field in card and (not isinstance(value, list) or not all(
                isinstance(v, dict) if field in ("book_references", "sources") else isinstance(v, str) for v in value
            )):
                flags.append("invalid_" + field)
                totals["invalid_" + field + "_fields"] += 1

        for field in ("grammar", "collocations", "examples_ar"):
            if not card.get(field):
                flags.append("missing_" + field)
                totals["missing_" + field] += 1

        lexical = [word, meaning, card.get("usage_note_ar")]
        for field in ("grammar", "collocations", "examples_ar", "synonyms",
                      "antonyms", "additional_meanings_ar"):
            lexical.extend(v for v in (card.get(field) or []) if isinstance(v, str))
        if any(FOREIGN.search(v) for v in lexical if isinstance(v, str)):
            flags.append("invalid_script")
            totals["invalid_script_cards"] += 1

        references = card.get("book_references", [])
        if isinstance(references, list) and any(
            isinstance(v, dict) and v.get("official_end_glossary_checked") is True
            for v in references
        ):
            flags.append("unverified_official_glossary_claim")
            totals["official_claim_cards"] += 1

        if flags:
            totals["flagged_card_count"] += 1
            issues.append({
                "file": filename,
                "id": stable_id,
                "word": word,
                "flags": flags,
            })

    return {
        "source_cards": totals["source_cards"],
        "source_files": len(files),
        "flagged_card_count": totals["flagged_card_count"],
        "repeated_card_ids": totals["repeated_card_ids"],
        "missing_id": totals["missing_id"],
        "invalid_headword_cards": totals["invalid_headword_cards"],
        "unvocalized_headword_cards": totals["unvocalized_headword_cards"],
        "non_nfc_headword_cards": totals["non_nfc_headword_cards"],
        "invalid_definition_cards": totals["invalid_definition_cards"],
        "missing_usage_note_field": totals["missing_usage_note_field"],
        "missing_grammar": totals["missing_grammar"],
        "missing_collocations": totals["missing_collocations"],
        "missing_examples": totals["missing_examples_ar"],
        "invalid_script_cards": totals["invalid_script_cards"],
        "official_claim_cards": totals["official_claim_cards"],
        "invalid_list_fields": {
            f: totals["invalid_" + f + "_fields"] for f in LISTS
        },
        "issues": issues,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json-out", type=Path)
    parser.add_argument("--max-examples", type=int, default=45)
    args = parser.parse_args()
    result = inspect_raw_cards(iter_corpus_chunks())
    if args.json_out is not None:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    summary = {k: v for k, v in result.items() if k != "issues"}
    summary["issue_examples"] = result["issues"][:max(0, args.max_examples)]
    summary["examples_truncated"] = len(result["issues"]) > args.max_examples
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
