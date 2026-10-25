"""Editorial advanced Arabic lexicon: quality and provenance safeguards."""
import json
import re
import unittest
from pathlib import Path
from validate_dictionary import ROOT, load_corpus

FILES = [
    "assets/data/entries_advanced_ecology_20261025_b.json",
    "assets/data/entries_advanced_institutions_20261025_b.json",
]

class EditorialSupplementTests(unittest.TestCase):
    def test_complete_original_cards_and_no_unsupported_book_references(self):
        for name in FILES:
            p = ROOT / name
            self.assertTrue(p.exists(), name)
            obj = json.loads(p.read_text(encoding="utf-8"))
            self.assertEqual(obj["source_status"], "independent_advanced_explanations_not_collated")
            cards = obj["entries"]
            self.assertGreaterEqual(len(cards), 25, name)
            ids = set()
            for e in cards:
                self.assertNotIn(e["id"], ids)
                ids.add(e["id"])
                self.assertEqual(e["book_references"], [])
                self.assertEqual(e["editorial_level_hint"], 4)
                self.assertGreater(len(e["meaning_ar"]), 20, e["arabic"])
                for key in ("grammar", "collocations", "examples_ar"):
                    self.assertTrue(e[key], f"{name}:{e['arabic']} {key}")
                self.assertIn("usage_note_ar", e)
                self.assertNotRegex(e["arabic"], r"[A-Za-zА-Яа-яЁё]")
                self.assertTrue(re.search(r"[\u064b-\u0652]", e["arabic"]), e["arabic"])
    def test_both_new_chunks_are_activated(self):
        loaded = load_corpus()
        for p in FILES:
            self.assertIn(p, loaded["files"])

if __name__ == "__main__":
    unittest.main()
