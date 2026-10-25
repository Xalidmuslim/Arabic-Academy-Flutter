"""Verify independently authored advanced batches before publication."""
import json
import unittest
from validate_dictionary import ROOT, load_corpus

FILES = [
    "assets/data/entries_advanced_reasoning_20261025.json",
    "assets/data/entries_advanced_expression_20261025.json",
]

class AdvancedSemanticExpansionTests(unittest.TestCase):
    def test_advanced_semantics_are_explanatory_and_unattributed(self):
        manifest = json.loads((ROOT / "assets/data/corpus_manifest.json").read_text(encoding="utf-8"))
        names = []
        ids = []
        meaningful_additional = 0
        for path in FILES:
            self.assertIn(path, manifest["files"])
            data = json.loads((ROOT / path).read_text(encoding="utf-8"))
            self.assertEqual(data["source_status"], "original_editorial_not_book_collated")
            self.assertGreaterEqual(len(data["entries"]), 30)
            for e in data["entries"]:
                names.append(e["arabic"])
                ids.append(e["id"])
                self.assertEqual(e.get("book_references"), [])
                self.assertEqual(e.get("sources"), [])
                self.assertGreaterEqual(len(e["meaning_ar"]), 35, e["arabic"])
                self.assertTrue(e["grammar"])
                self.assertTrue(e["collocations"])
                self.assertTrue(e["examples_ar"])
                self.assertGreater(len(e["usage_note_ar"]), 20, e["arabic"])
                for field in ("synonyms","antonyms","additional_meanings_ar"):
                    self.assertIsInstance(e[field], list)
                meaningful_additional += bool(e["additional_meanings_ar"])
        self.assertEqual(len(ids), len(set(ids)))
        self.assertEqual(len(names), len(set(names)))
        self.assertGreaterEqual(meaningful_additional, 7)
        self.assertGreaterEqual(len(load_corpus()["entries"]), 1979)

if __name__ == "__main__":
    unittest.main()
