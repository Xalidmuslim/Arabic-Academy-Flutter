"""Regression gate for two independently authored, completed Arabic noun batches.

The unfinished seven-batch experiment remains untouched on its source branch.
These checks do not establish textbook provenance or Arabic editorial accuracy.
"""
import json
import re
import unittest

from validate_dictionary import ROOT, load_corpus

CHUNKS = (
    "assets/data/entries_nouns_health_20261025.json",
    "assets/data/entries_nouns_education_20261025.json",
)
ARABIC_DIACRITIC = re.compile(r"[\u064b-\u0652]")
UNEXPECTED_SCRIPT = re.compile(r"[A-Za-zА-Яа-яЁё]")


class CompletedIndependentNounBatchesTest(unittest.TestCase):
    def test_both_complete_batches_are_included_without_data_loss(self):
        manifest = json.loads(
            (ROOT / "assets/data/corpus_manifest.json").read_text(encoding="utf-8")
        )
        cards = []
        for name in CHUNKS:
            self.assertEqual(manifest["files"].count(name), 1, name)
            chunk = json.loads((ROOT / name).read_text(encoding="utf-8"))
            self.assertEqual(chunk["schema_version"], 3, name)
            self.assertEqual(
                chunk["source_status"],
                "independent_editorial_nouns_not_book_collated",
                name,
            )
            self.assertGreaterEqual(len(chunk["entries"]), 140, name)
            cards.extend(chunk["entries"])

        self.assertEqual(len(cards), 318)
        self.assertEqual(len(cards), len({entry["id"] for entry in cards}))
        self.assertEqual(len(cards), len({entry["arabic"] for entry in cards}))

        for entry in cards:
            word = entry["arabic"]
            self.assertRegex(word, ARABIC_DIACRITIC)
            self.assertGreaterEqual(len(entry["meaning_ar"]), 25, word)
            self.assertGreaterEqual(len(entry["usage_note_ar"]), 15, word)
            for field in (
                "grammar", "collocations", "examples_ar",
                "synonyms", "antonyms", "additional_meanings_ar",
            ):
                self.assertIsInstance(entry[field], list, word)
            self.assertTrue(entry["grammar"], word)
            self.assertTrue(entry["collocations"], word)
            self.assertTrue(entry["examples_ar"], word)
            self.assertEqual(entry["book_references"], [], word)
            self.assertEqual(entry["sources"], [], word)
            lexical = [word, entry["meaning_ar"], entry["usage_note_ar"]]
            for field in (
                "grammar", "collocations", "examples_ar",
                "synonyms", "antonyms", "additional_meanings_ar",
            ):
                lexical.extend(entry[field])
            self.assertIsNone(UNEXPECTED_SCRIPT.search(" ".join(lexical)), word)

        merged = {entry["arabic"] for entry in load_corpus()["entries"]}
        self.assertTrue({entry["arabic"] for entry in cards}.issubset(merged))


if __name__ == "__main__":
    unittest.main()
