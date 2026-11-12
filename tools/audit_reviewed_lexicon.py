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


def vocalized_key(word):
    """Compare fully diacritized Arabic after canonical mark-order sorting.

    Unlike normalize(), this intentionally preserves vowel choice and hamza.
    """
    return re.sub(r"[\u064b-\u065f\u0670]+",
                  lambda m: "".join(sorted(m.group(0))), word)


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
                norm_counts[vocalized_key(headword)] += 1
                original[headword] = entry

    # Scan-derived article references are checked against the corresponding
    # independently authored corpus entries; the 244 MB scan stays outside Git.
    source_chunk_name = "assets/data/entries_bayna_scan_verified_20261112.json"
    assert source_chunk_name in manifest["files"]
    source_chunk = json.loads((ROOT / source_chunk_name).read_text(encoding="utf-8"))
    source_words = source_chunk["entries"]
    assert len(source_words) >= 20
    assert len({e["id"] for e in source_words}) == len(source_words)
    assert len({e["arabic"] for e in source_words}) == len(source_words)
    expected_scan = "a2d98cbf6cd309bac2ac072e09679260b1fa20dec0af4cfa7ddf82d7fae2f995"
    indexed_articles = {e["arabic"]: e for e in reviewed["entries"]
                        if e.get("source_review") == "visual_check_of_user_supplied_scan_12383_pdf"}
    for entry in source_words:
        prov = entry["source_provenance"]
        article = indexed_articles.get(entry["arabic"])
        assert article is not None, f"Missing source-backed article: {entry['arabic']}"
        assert article["source_pdf_page"] == prov["pdf_page"]
        assert article["source_printed_page"] == prov["printed_page"]
        assert article["definition"][0]["ar"] == entry["meaning_ar"]
        assert entry["arabic"] in original
        assert prov["scan_sha256"] == expected_scan
        assert isinstance(prov["pdf_page"], int) and 1 <= prov["pdf_page"] <= 404
        assert isinstance(prov["printed_page"], int) and prov["printed_page"] >= 1
        assert entry["sources"]
        assert not re.search(r"[\u0400-\u04ff]", str(entry)), (
            f"Cyrillic in Arabic corpus entry: {entry['arabic']}")
    coverage = Counter()
    for entry in original.values():
        for field in ("grammar", "synonyms", "antonyms", "collocations", "examples_ar"):
            if entry.get(field):
                coverage[field] += 1
        if entry.get("usage_note_ar"):
            coverage["usage_note_ar"] += 1

    seen = set()
    effective = 0
    visually_checked = 0
    for article in reviewed["entries"]:
        word = article["arabic"]
        key = vocalized_key(word)
        assert key and key not in seen, f"Duplicate reviewed headword: {word}"
        seen.add(key)
        assert "translation_ru" not in article, f"Russian translation field present: {word}"
        if "source_review" in article:
            assert article["source_review"] == "visual_check_of_user_supplied_scan_12383_pdf", (
                f"Unrecognized scan review marker: {word}")
            assert type(article.get("source_pdf_page")) is int and (
                1 <= article["source_pdf_page"] <= 404), f"Bad PDF page: {word}"
            assert type(article.get("source_printed_page")) is int and (
                article["source_printed_page"] >= 1), f"Bad printed page: {word}"
            visually_checked += 1
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
            print(f"NOT ATTACHED: {word}: {norm_counts[key]} exactly vocalized headwords")

    relations = json.loads((DATA / "lexical_relations_v1.json").read_text(encoding="utf-8"))
    assert relations["schema_version"] == 1
    assert "translation_ru" not in relations
    assert all(not re.search(r"[\u0400-\u04ff]", str(pair))
               for pair in relations["pairs"]), "Cyrillic relation found"
    relation_seen = set()
    relation_added = {"synonym": set(), "antonym": set()}
    verified_files = {}
    for pair in relations["pairs"]:
        kind = pair["kind"]
        left, right = pair["left"], pair["right"]
        assert kind in relation_added, f"Unsupported relation kind: {kind}"
        assert left != right and normalize(left) != normalize(right)
        assert left in headwords and right in headwords, (
            f"Unmatched word: {left} / {right}")
        for headword in (left, right):
            assert ARABIC.search(headword) and TASHKEEL.search(headword), (
                f"Missing Arabic vocalization: {headword}")
        key = (kind, *sorted((left, right)))
        assert key not in relation_seen, f"Duplicate relation: {key}"
        relation_seen.add(key)
        file = pair["evidence_file"]
        assert file in manifest["files"], f"Unlisted evidence file: {file}"
        if file not in verified_files:
            verified_files[file] = {
                entry["arabic"] for entry in
                json.loads((ROOT / file).read_text(encoding="utf-8"))["entries"]
            }
        assert left in verified_files[file] and right in verified_files[file], (
            f"Pair lacks corpus evidence: {left} / {right}")
        relation_added[kind].update((left, right))

    synonyms_after = sum(
        bool(entry.get("synonyms")) or word in relation_added["synonym"]
        for word, entry in original.items())
    antonyms_after = sum(
        bool(entry.get("antonyms")) or word in relation_added["antonym"]
        for word, entry in original.items())
    print(f"Lexical relationships: {len(relation_seen)} pairs")
    print(f"Synonym coverage with overlay: {synonyms_after} / {len(headwords)}")
    print(f"Antonym coverage with overlay: {antonyms_after} / {len(headwords)}")
    print(f"Distinct relationship endpoints: {len(relation_added['synonym'] | relation_added['antonym'])}")
    print("CAUTION: Pair evidence is existing original corpus definitions, not verified verbatim against the published dictionary.")

    print(f"Independently authored Arabic entries checked against scan: {len(source_words)}")
    print(f"Corpus: {len(headwords)} unique exact vocalized headwords")
    for field in ("grammar", "synonyms", "antonyms", "collocations", "examples_ar", "usage_note_ar"):
        print(f"Legacy section {field}: {coverage[field]} / {len(headwords)} non-empty")
    print(f"Reviewed articles: {len(reviewed['entries'])}; unambiguously attached: {effective}")
    print(f"Visually checked articles from user-provided scanned dictionary: {visually_checked}")
    print(f"Remaining without reviewed article: {len(headwords) - effective}")
    print("NOTE: This script validates structure/vocalization presence, NOT linguistic correctness.")


if __name__ == "__main__":
    main()
