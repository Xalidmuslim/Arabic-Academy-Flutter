#!/usr/bin/env python3
"""Fast, offline validation. Does not build Android or install Flutter."""
from __future__ import annotations

import json
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "assets/data/corpus_manifest.json"
LEXICAL_ARRAYS = (
    "synonyms", "antonyms", "grammar", "collocations",
    "examples_ar", "additional_meanings_ar",
)
INVALID_SCRIPT = re.compile(r"[A-Za-zА-Яа-яЁё]")
ARABIC_LETTER = re.compile(r"[\u0621-\u064A]")
CASE_ENDINGS = re.compile(r"[\u064B-\u065F\u0670\u06D6-\u06ED]+$")


def load_corpus() -> dict:
    """Read the manifest in a stable order, preserving the first headword ID."""
    doc = json.loads(MANIFEST.read_text(encoding="utf-8"))
    chunks = doc.get("files")
    assert isinstance(chunks, list) and chunks, "Empty corpus manifest"
    entries = []
    by_headword = {}

    def references(entry):
        refs = entry.get("book_references")
        if refs is not None:
            return [dict(ref) for ref in refs]
        return [dict(entry["book_reference"])] if entry.get("book_reference") else []

    for filename in chunks:
        assert isinstance(filename, str) and filename, "Invalid corpus chunk path"
        path = Path(filename)
        if not path.is_absolute():
            path = ROOT / path
        assert path.is_file(), f"Missing corpus chunk: {filename}"
        part = json.loads(path.read_text(encoding="utf-8"))
        for raw in part.get("entries", []):
            entry = dict(raw)
            word = entry["arabic"]
            existing = by_headword.get(word)
            if existing is None:
                by_headword[word] = entry
                entries.append(entry)
            else:
                refs = references(existing)
                for ref in references(entry):
                    if not any(r["book"] == ref["book"] and
                               r["chapter"] == ref["chapter"] for r in refs):
                        refs.append(ref)
                existing["book_references"] = refs
                # Each chunk may define an independent contextual meaning of
                # the same headword. Keep the first definition primary, but
                # retain later distinct primary definitions as secondary senses.
                incoming_meaning = entry.get("meaning_ar")
                if (isinstance(incoming_meaning, str)
                        and incoming_meaning
                        and incoming_meaning != existing.get("meaning_ar")):
                    senses = list(existing.get("additional_meanings_ar") or [])
                    if incoming_meaning not in senses:
                        senses.append(incoming_meaning)
                    existing["additional_meanings_ar"] = senses
                for field in LEXICAL_ARRAYS:
                    previous = list(existing.get(field) or [])
                    for value in entry.get(field) or []:
                        if value not in previous:
                            previous.append(value)
                    if previous:
                        existing[field] = previous
                if not existing.get("usage_note_ar") and entry.get("usage_note_ar"):
                    existing["usage_note_ar"] = entry["usage_note_ar"]

    return {"entries": entries, "files": chunks}


def validate() -> dict:
    root = load_corpus()
    entries = root.get("entries")
    assert isinstance(entries, list) and entries, "Missing entries"
    ids: set[str] = set()
    exact_words: set[str] = set()
    positions: dict[tuple[int, int], dict[int, str]] = defaultdict(dict)
    referenced = set()

    for item in entries:
        wid = item.get("id")
        word = item.get("arabic")
        meaning = item.get("meaning_ar")
        assert isinstance(wid, str) and wid, "Missing ID"
        assert wid not in ids, f"Duplicate ID: {wid}"
        ids.add(wid)
        assert isinstance(word, str) and ARABIC_LETTER.search(word), wid
        assert word not in exact_words, f"Duplicate headword: {word}"
        exact_words.add(word)
        assert isinstance(meaning, str) and len(meaning) >= 14, f"Unexplained word: {word}"
        assert ARABIC_LETTER.search(meaning), f"No Arabic definition: {word}"
        assert isinstance(item.get("usage_note_ar"), str), f"Missing usage note: {word}"
        lexical = [word, meaning, item["usage_note_ar"]]
        for field in LEXICAL_ARRAYS:
            values = item.get(field)
            assert isinstance(values, list), f"{field} missing for {word}"
            assert all(isinstance(v, str) for v in values), f"Bad {field} for {word}"
            lexical.extend(values)
        for text in lexical:
            assert not INVALID_SCRIPT.search(text), f"Unexpected Latin/Cyrillic in {word}: {text}"
        # Newly authored complete lesson cards must have practical examples.
        if str(wid).startswith(("l1u", "l2u")):
            assert item["grammar"], f"No grammar: {word}"
            assert item["collocations"], f"No collocation: {word}"
            assert item["examples_ar"], f"No example: {word}"

        refs = item.get("book_references")
        if refs is None:
            refs = [item["book_reference"]] if item.get("book_reference") else []
        assert isinstance(refs, list), f"Bad chapter refs for {word}"
        for ref in refs:
            assert isinstance(ref, dict), f"Bad ref for {word}"
            book, chapter, index = ref.get("book"), ref.get("chapter"), ref.get("index")
            assert isinstance(book, int) and 1 <= book <= 4 and isinstance(chapter, int) and 1 <= chapter <= 16, f"Bad level/chapter for {word}"
            assert isinstance(index, int) and index >= 1, f"Bad index for {word}"
            key = (book, chapter)
            assert index not in positions[key], (
                f"Position {index} duplicated in chapter {chapter}: "
                f"{word}, {positions[key].get(index)}")
            positions[key][index] = word
            referenced.add(wid)
            assert not ref.get("official_end_glossary_checked", False), (
                f"Unverified chapter marked official: {word}")

    for (book, chapter), values in sorted(positions.items()):
        assert sorted(values) == list(range(1, len(values) + 1)), (
            f"Non-contiguous indices in book {book} chapter {chapter}")
    assert {(1, c) for c in range(1, 17)}.issubset(set(positions)), (
        "Not all 16 level-one unit lists are represented")
    return {
        "entries": len(entries),
        "referenced_entries": len(referenced),
        "chapters": {
            f"{b}.{c}": len(v) for (b, c), v in sorted(positions.items())
        },
        "status": "structurally valid; NOT proofread against official book",
    }


if __name__ == "__main__":
    print(json.dumps(validate(), indent=2, ensure_ascii=False))
