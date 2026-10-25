"""Independent fourth-level lexicography must never impersonate publisher data."""
import json
import unittest
from pathlib import Path
from validate_dictionary import ROOT, load_corpus

FILES = [
    "assets/data/entries_advanced_methodology_20261025.json",
    "assets/data/entries_advanced_communication_20261025.json",
]

class AdvancedEditorialBatchTests(unittest.TestCase):
    def test_original_full_cards_with_no_fabricated_lesson_references(self):
        corpus = load_corpus()
        manifest = json.loads((ROOT / "assets/data/corpus_manifest.json").read_text(encoding="utf-8"))
        all_new = []
        for filename in FILES:
            self.assertIn(filename, manifest["files"])
            raw = json.loads((ROOT / filename).read_text(encoding="utf-8"))
            self.assertEqual(raw["source_status"], "original_editorial_not_book_collated")
            self.assertGreaterEqual(len(raw["entries"]), 25)
            for e in raw["entries"]:
                self.assertFalse(e["book_references"], e["arabic"])
                self.assertFalse(e["sources"], e["arabic"])
                self.assertGreater(len(e["meaning_ar"]), 30)
                self.assertTrue(e["grammar"], e["arabic"])
                self.assertTrue(e["collocations"], e["arabic"])
                self.assertTrue(e["examples_ar"], e["arabic"])
                self.assertGreater(len(e["usage_note_ar"]), 15, e["arabic"])
                self.assertIsInstance(e["synonyms"], list)
                self.assertIsInstance(e["antonyms"], list)
                self.assertIsInstance(e["additional_meanings_ar"], list)
            all_new.extend(raw["entries"])
        self.assertEqual(len({e["arabic"] for e in all_new}), len(all_new))
        self.assertTrue(any(e["additional_meanings_ar"] for e in all_new))
        self.assertTrue(any(e["antonyms"] for e in all_new))
        self.assertTrue(any(e["synonyms"] for e in all_new))
        self.assertGreaterEqual(len(corpus["entries"]), 1931)

if __name__ == "__main__":
    unittest.main()
