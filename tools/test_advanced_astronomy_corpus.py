"""Quality gate for original advanced astronomy and space-science articles."""
import json
import re
import unittest
from validate_dictionary import ROOT, load_corpus

CHUNK = "assets/data/entries_advanced_astronomy_20261025.json"

class AdvancedAstronomyCorpusTests(unittest.TestCase):
    def test_provenance_and_full_arabic_cards(self):
        manifest = json.loads((ROOT / "assets/data/corpus_manifest.json").read_text(encoding="utf8"))
        self.assertIn(CHUNK, manifest["files"])
        data = json.loads((ROOT / CHUNK).read_text(encoding="utf8"))
        self.assertEqual(data["source_status"], "independent_advanced_explanations_not_collated")
        entries = data["entries"]
        self.assertGreaterEqual(len(entries), 45)
        self.assertEqual(len({e["id"] for e in entries}), len(entries))
        self.assertEqual(len({e["arabic"] for e in entries}), len(entries))
        multi = 0
        for e in entries:
            self.assertEqual(e["book_references"], [], e["arabic"])
            self.assertEqual(e["sources"], [], e["arabic"])
            self.assertEqual(e["editorial_level_hint"], 4)
            self.assertGreater(len(e["meaning_ar"]), 37, e["arabic"])
            self.assertGreaterEqual(len(e["meaning_ar"].split()), 7, e["arabic"])
            self.assertTrue(e["grammar"], e["arabic"])
            self.assertTrue(e["collocations"], e["arabic"])
            self.assertTrue(e["examples_ar"], e["arabic"])
            self.assertGreater(len(e["usage_note_ar"]), 20, e["arabic"])
            self.assertFalse(re.search(r"[A-Za-zА-Яа-яЁё]", str(e["meaning_ar"])), e["arabic"])
            self.assertTrue(re.search(r"[\u064b-\u0652]", e["arabic"]), e["arabic"])
            for key in ("synonyms", "antonyms", "additional_meanings_ar"):
                self.assertIsInstance(e[key], list)
            multi += bool(e["additional_meanings_ar"])
        self.assertGreaterEqual(multi, 7)
        indexed = {e["arabic"] for e in load_corpus()["entries"]}
        self.assertTrue({e["arabic"] for e in entries}.issubset(indexed))

if __name__ == "__main__":
    unittest.main()
