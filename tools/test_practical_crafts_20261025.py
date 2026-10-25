"""Structural guard for original craft, repair and safety vocabulary."""
import json
import re
import unittest

from validate_dictionary import ROOT, load_corpus

CHUNK = "assets/data/entries_practical_crafts_20261025.json"


class PracticalCraftCorpusTests(unittest.TestCase):
    def test_practical_cards_remain_original_and_complete(self):
        manifest = json.loads((ROOT / "assets/data/corpus_manifest.json").read_text(encoding="utf-8"))
        self.assertIn(CHUNK, manifest["files"])
        data = json.loads((ROOT / CHUNK).read_text(encoding="utf-8"))
        self.assertEqual(data["source_status"], "independent_practical_lexicon_not_book_collated")
        entries = data["entries"]
        self.assertGreaterEqual(len(entries), 75)
        self.assertEqual(len({item["id"] for item in entries}), len(entries))
        self.assertEqual(len({item["arabic"] for item in entries}), len(entries))
        extra = 0
        verbs = 0
        for item in entries:
            self.assertTrue(re.search(r"[\u064b-\u0652]", item["arabic"]), item["arabic"])
            self.assertGreater(len(item["meaning_ar"]), 39, item["arabic"])
            self.assertGreater(len(item["usage_note_ar"]), 19, item["arabic"])
            self.assertTrue(item["grammar"], item["arabic"])
            self.assertTrue(item["collocations"], item["arabic"])
            self.assertTrue(item["examples_ar"], item["arabic"])
            self.assertEqual(item["book_references"], [], item["arabic"])
            self.assertEqual(item["sources"], [], item["arabic"])
            self.assertEqual(item["editorial_level_hint"], 4)
            for key in ("synonyms", "antonyms", "additional_meanings_ar"):
                self.assertIsInstance(item[key], list)
            self.assertFalse(re.search(r"[A-Za-zА-Яа-яЁё]", str(item)), item["arabic"])
            extra += bool(item["additional_meanings_ar"])
            verbs += any(v.startswith("فِعْلٌ") for v in item["grammar"])
        self.assertGreaterEqual(extra, 15)
        self.assertGreaterEqual(verbs, 10)
        indexed = {entry["arabic"] for entry in load_corpus()["entries"]}
        self.assertTrue({entry["arabic"] for entry in entries}.issubset(indexed))

if __name__ == "__main__":
    unittest.main()
