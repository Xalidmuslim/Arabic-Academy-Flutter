#!/usr/bin/env python3
"""Audit source-backed enrichments without modifying or fabricating lexicon data.

Run from repository root:
    python3 tools/audit_reviewed_lexicon.py
"""
import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "assets/data"
TASHKEEL = re.compile(r"[\u064b-\u065f\u0670\u06d6-\u06ed\u0640]")
ARABIC = re.compile(r"[\u0621-\u064a]")


def normalize(word):
    word = TASHKEEL.sub("", word)
    word = re.sub(r"[إأٱآ]", "ا", word).replace("ى", "ي")
    return word.strip().lower()


def main():
    manifest = json.loads((DATA / "corpus_manifest.json").read_text(encoding="utf-8"))
    reviewed = json.loads((DATA / "reviewed_articles_v1.json").read_text(encoding="utf-8"))
    assert reviewed["schema_version"] == 2
    headwords = set()
    norm_counts = Counter()
    original = {}
    for file in manifest["files"]:
        path = ROOT / file
        items = json.loads(path.read_text(encoding="utf-8"))["entries"]
        for entry in items:
            headword = entry["arabic"]
            if headword not in headwords:
                headwords.add(headword)
                norm_counts[normalize(headword)] += 1
                original[headword] = entry

    coverage = Counter()
    for entry in original.values():
        for field in ("grammar", "synonyms", "antonyms", "collocations", "examples_ar"):
            if entry.get(field):
                coverage[field] += 1
        if entry.get("usage_note_ar"):
            coverage["usage_note_ar"] += 1

    seen = set()
    effective = 0
    for article in reviewed["entries"]:
        word = article["arabic"]
        key = normalize(word)
        assert key and key not in seen, f"Duplicate reviewed headword: {word}"
        seen.add(key)
        assert "translation_ru" not in article, f"Russian translation field present: {word}"
        assert article.get("source_urls"), f"No sources: {word}"
        assert all(s.startswith("https://") for s in article["source_urls"])
        for field in ("definition", "grammar", "examples", "important"):
            assert article.get(field), f"Missing mandatory {field}: {word}"
        for field in ("definition", "grammar", "examples", "important", "synonyms", "contrasts"):
            for fact in article.get(field, []):
                arabic = fact.get("ar", "")
                assert "ru" not in fact, f"Russian note field present in {word}: {field}"
                assert ARABIC.search(arabic) and TASHKEEL.search(arabic), (
                    f"Missing Arabic or vocalization in {word}: {field}: {arabic}")
                assert not re.search(r"[\u0400-\u04ff]", arabic), (
                    f"Cyrillic in Arabic fact: {word}: {field}")
        if norm_counts[key] == 1:
            effective += 1
        else:
            print(f"NOT ATTACHED: {word}: {norm_counts[key]} matching headwords")

    print(f"Corpus: {len(headwords)} unique exact vocalized headwords")
    for field in ("grammar", "synonyms", "antonyms", "collocations", "examples_ar", "usage_note_ar"):
        print(f"Legacy section {field}: {coverage[field]} / {len(headwords)} non-empty")
    print(f"Reviewed articles: {len(reviewed['entries'])}; unambiguously attached: {effective}")
    print(f"Remaining without reviewed article: {len(headwords) - effective}")
    print("NOTE: This script validates structure/vocalization presence, NOT linguistic correctness.")


if __name__ == "__main__":
    main()
