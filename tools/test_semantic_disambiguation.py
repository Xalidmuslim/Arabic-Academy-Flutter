"""Structural regression tests for newly written multi-sense Arabic explanatory cards."""
import json
from pathlib import Path
import unittest
from validate_dictionary import ROOT, load_corpus, ARABIC_LETTER, INVALID_SCRIPT

NAME = "assets/data/entries_semantic_disambiguation_20261025.json"

class SemanticDisambiguationTests(unittest.TestCase):
    def test_each_new_sense_is_distinct_and_supplied_with_context(self):
        part = json.loads((ROOT / NAME).read_text(encoding="utf-8"))
        self.assertEqual(part["source_status"], "original_lexicography_not_publisher_collated")
        records = part["entries"]
        self.assertGreaterEqual(len(records), 55)
        self.assertEqual(len({e["arabic"] for e in records}), len(records))
        for e in records:
            self.assertGreaterEqual(len(e["additional_meanings_ar"]), 1, e["arabic"])
            self.assertTrue(e["grammar"], e["arabic"])
            self.assertTrue(e["collocations"], e["arabic"])
            self.assertTrue(e["examples_ar"], e["arabic"])
            self.assertGreaterEqual(len(e["usage_note_ar"]), 25, e["arabic"])
            self.assertFalse(e["book_references"], e["arabic"])
            for item in [e["meaning_ar"], e["usage_note_ar"], *e["additional_meanings_ar"]]:
                self.assertIsNotNone(ARABIC_LETTER.search(item))
                self.assertIsNone(INVALID_SCRIPT.search(item))
            self.assertNotEqual(e["meaning_ar"], e["additional_meanings_ar"][0])
    def test_chunk_registered_and_canonical_ids_unique(self):
        corpus = load_corpus()
        self.assertIn(NAME, corpus["files"])
        self.assertEqual(len({e["id"] for e in corpus["entries"]}), len(corpus["entries"]))
        self.assertEqual(len({e["arabic"] for e in corpus["entries"]}), len(corpus["entries"]))

if __name__ == "__main__":
    unittest.main()
