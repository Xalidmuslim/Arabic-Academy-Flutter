#!/usr/bin/env python3
"""Read-only coverage report for Arabic prose in *every* raw dictionary card.

A bare Arabic token is a review candidate, not proof of a misspelling.
Do not bulk auto-vowelize: Arabic words with the same bare spelling can
represent different inflections or entirely different lexemes.
"""
from __future__ import annotations

import argparse
import json
import re
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable

from audit_dictionary_variants import iter_corpus_chunks
from audit_dictionary_deep_editorial import vowel_coverage

ARABIC_WORD = re.compile(r"[\u0621-\u064A\u0671][\u0621-\u064A\u0671\u064b-\u065f\u0670\u06d6-\u06ed\u0640]*")
VOWEL = re.compile(r"[\u064b-\u065f\u0670\u06d6-\u06ed]")
ARABIC_CHAR = re.compile(r"[\u0621-\u063A\u0641-\u064A\u0671]")
PROSE_FIELDS = ("meaning_ar", "usage_note_ar", "examples_ar", "collocations", "additional_meanings_ar")


def unvocalized_tokens(text: str) -> list[str]:
    """Find fully *unmarked* Arabic words with >=2 base letters."""
    if not isinstance(text, str):
        return []
    words = []
    for token in ARABIC_WORD.findall(unicodedata.normalize("NFC", text)):
        if len(ARABIC_CHAR.findall(token)) >= 2 and not VOWEL.search(token):
            words.append(token.replace("\u0640", ""))
    return words

def partially_vocalized_tokens(text: str) -> list[str]:
    """Partly marked Arabic words are review candidates, NOT proven errors."""
    if not isinstance(text, str):
        return []
    result = []
    for token in ARABIC_WORD.findall(unicodedata.normalize("NFC", text)):
        if (len(ARABIC_CHAR.findall(token)) >= 2 and VOWEL.search(token)
                and vowel_coverage(token)["missing"]):
            result.append(token.replace("\u0640", ""))
    return result


def audit_prose_diacritics(cards: Iterable[tuple[str, dict[str, Any]]],
                           example_limit: int = 300) -> dict[str, Any]:
    all_cards = 0
    affected_cards = set()
    affected_files = set()
    tokens = Counter()
    places = defaultdict(set)
    examples = []
    partial_tokens = Counter()
    partial_places = defaultdict(set)
    partial_cards = set()
    partial_files = set()
    partial_examples = []
    for file_name, item in cards:
        all_cards += 1
        cid = item.get("id", f"unknown-{all_cards}")
        for field in PROSE_FIELDS:
            raw = item.get(field)
            texts = [raw] if isinstance(raw, str) else (raw if isinstance(raw, list) else [])
            for index, text in enumerate(texts):
                if not isinstance(text, str):
                    continue
                for token in unvocalized_tokens(text):
                    tokens[token] += 1
                    places[token].add(file_name)
                    affected_cards.add((file_name, str(cid)))
                    affected_files.add(file_name)
                    if len(examples) < example_limit:
                        examples.append({"file": file_name, "id": cid,
                                         "arabic": item.get("arabic"), "field": field,
                                         "index": index, "token": token, "text": text[:220]})
                for token in partially_vocalized_tokens(text):
                    partial_tokens[token] += 1
                    partial_places[token].add(file_name)
                    partial_cards.add((file_name, str(cid)))
                    partial_files.add(file_name)
                    if len(partial_examples) < example_limit:
                        partial_examples.append({"file": file_name, "id": cid,
                                                 "arabic": item.get("arabic"),
                                                 "field": field, "index": index,
                                                 "token": token, "text": text[:220]})

    return {
        "source_cards": all_cards,
        "affected_cards": len(affected_cards),
        "affected_files": len(affected_files),
        "unvocalized_token_occurrences": sum(tokens.values()),
        "unique_unvocalized_tokens": len(tokens),
        "tokens": [
            {"token": w, "count": n, "source_files": sorted(places[w])}
            for w, n in sorted(tokens.items(), key=lambda x: (-x[1], x[0]))
        ],
        "examples": examples,
        "examples_truncated": sum(tokens.values()) > len(examples),
        "partially_vocalized_cards": len(partial_cards),
        "partially_vocalized_files": len(partial_files),
        "partially_vocalized_token_occurrences": sum(partial_tokens.values()),
        "unique_partially_vocalized_tokens": len(partial_tokens),
        "partially_vocalized_tokens": [
            {"token": w, "count": n, "source_files": sorted(partial_places[w])}
            for w, n in sorted(partial_tokens.items(), key=lambda x: (-x[1], x[0]))
        ],
        "partial_examples": partial_examples,
        "partial_examples_truncated": sum(partial_tokens.values()) > len(partial_examples),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--max-examples", type=int, default=40)
    parser.add_argument("--max-tokens", type=int, default=100)
    parser.add_argument("--json-out", type=Path)
    opts = parser.parse_args()
    report = audit_prose_diacritics(iter_corpus_chunks(), example_limit=500)
    if opts.json_out is not None:
        opts.json_out.parent.mkdir(parents=True, exist_ok=True)
        opts.json_out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n",
                                 encoding="utf-8")
    summary = {k: v for k, v in report.items() if k not in ("tokens", "examples", "partially_vocalized_tokens", "partial_examples")}
    summary["top_tokens"] = report["tokens"][:max(0, opts.max_tokens)]
    summary["top_partial_tokens"] = report["partially_vocalized_tokens"][:max(0, opts.max_tokens)]
    summary["examples"] = report["examples"][:max(0, opts.max_examples)]
    summary["partial_examples"] = report["partial_examples"][:max(0, opts.max_examples)]
    print("PROSE_DIACRITICS_AUDIT_BEGIN")
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    print("PROSE_DIACRITICS_AUDIT_END")


if __name__ == "__main__":
    main()
