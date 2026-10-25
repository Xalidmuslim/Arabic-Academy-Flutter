"""Check the large independent Arabic-only daily life vocabulary batch."""
import json
import re
import unittest

from validate_dictionary import ROOT, load_corpus

CHUNKS = [
    "assets/data/entries_daily_education_20261025.json",
    "assets/data/entries_daily_travel_20261025.json",
    "assets/data/entries_daily_food_20261025.json",
    "assets/data/entries_daily_society_20261025.json",
]


class ExpandedDailyLexiconTests(unittest.TestCase):
    def test_large_batch_content_and_merge(self):
        manifest = json.loads((ROOT / "assets/data/corpus_manifest.json").read_text(encoding="utf-8"))
        for chunk in CHUNKS:
            self.assertIn(chunk, manifest["files"])
        all_entries = []
        for chunk in CHUNKS:
            doc = json.loads((ROOT / chunk).read_text(encoding="utf-8"))
            self.assertEqual(doc["schema_version"], 3)
            self.assertEqual(doc["source_status"], "original_editorial_not_textbook_collated")
            self.assertGreaterEqual(len(doc["entries"]), 40)
            all_entries += doc["entries"]
        self.assertGreaterEqual(len(all_entries), 225)
        words = [entry["arabic"] for entry in all_entries]
        self.assertEqual(len(words), len(set(words)), "Duplicate fully-vocalized lemma in the large batch")
        self.assertEqual(len({entry["id"] for entry in all_entries}), len(all_entries))
        for entry in all_entries:
            lemma = entry["arabic"]
            self.assertRegex(lemma, r"[\u064b-\u0652]")
            self.assertGreaterEqual(len(entry["meaning_ar"]), 28, lemma)
            self.assertGreaterEqual(len(entry["usage_note_ar"]), 20, lemma)
            self.assertTrue(entry["grammar"], lemma)
            self.assertTrue(entry["examples_ar"], lemma)
            self.assertTrue(entry["collocations"], lemma)
            for key in ("grammar", "examples_ar", "collocations", "additional_meanings_ar", "synonyms", "antonyms"):
                self.assertIsInstance(entry[key], list)
            text_fields = [lemma, entry["meaning_ar"], entry["usage_note_ar"]]
            for key in ("grammar", "examples_ar", "collocations", "additional_meanings_ar"):
                text_fields.extend(entry[key])
            self.assertIsNone(re.search(r"[A-Za-zА-Яа-яЁё]", " ".join(text_fields)), lemma)
            self.assertEqual(entry["book_references"], [], lemma)
            self.assertEqual(entry["sources"], [], lemma)
        indexed = {entry["arabic"] for entry in load_corpus()["entries"]}
        self.assertTrue(set(words).issubset(indexed))


if __name__ == "__main__":
    unittest.main()
