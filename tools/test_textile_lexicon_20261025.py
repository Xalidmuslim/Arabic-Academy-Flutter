"""Guard independent fully Arabic textile and sewing cards."""
import json
import re
import unittest

from validate_dictionary import ROOT, load_corpus

CHUNK = "assets/data/entries_practical_textiles_20261025.json"


class PracticalTextilesCorpusTests(unittest.TestCase):
    def test_full_original_cards_and_manifest_integration(self):
        manifest = json.loads((ROOT / "assets/data/corpus_manifest.json").read_text(encoding="utf-8"))
        self.assertIn(CHUNK, manifest["files"])
        data = json.loads((ROOT / CHUNK).read_text(encoding="utf-8"))
        self.assertEqual(data["source_status"], "original_textile_lexicon_not_collated_with_textbook")
        entries = data["entries"]
        self.assertGreaterEqual(len(entries), 75)
        self.assertEqual(len({e["id"] for e in entries}), len(entries))
        self.assertEqual(len({e["arabic"] for e in entries}), len(entries))
        polysemy = 0
        for e in entries:
            self.assertTrue(re.search(r"[\u064b-\u0652]", e["arabic"]), e["arabic"])
            self.assertGreaterEqual(len(e["meaning_ar"]), 35, e["arabic"])
            self.assertGreaterEqual(len(e["usage_note_ar"]), 20, e["arabic"])
            for key in ("grammar", "collocations", "examples_ar"):
                self.assertTrue(e[key], e["arabic"])
            for key in ("synonyms", "antonyms", "additional_meanings_ar"):
                self.assertIsInstance(e[key], list, e["arabic"])
            self.assertEqual(e["book_references"], [])
            self.assertEqual(e["sources"], [])
            self.assertEqual(e["editorial_level_hint"], 2)
            text_fields = [e["arabic"], e["meaning_ar"], e["usage_note_ar"]]
            for key in ("grammar", "collocations", "examples_ar", "additional_meanings_ar"):
                text_fields.extend(e[key])
            self.assertIsNone(re.search(r"[A-Za-zА-Яа-яЁё]", " ".join(text_fields)), e["arabic"])
            polysemy += bool(e["additional_meanings_ar"])
        self.assertGreaterEqual(polysemy, 8)
        indexed = {e["arabic"] for e in load_corpus()["entries"]}
        self.assertTrue({e["arabic"] for e in entries}.issubset(indexed))

if __name__ == "__main__":
    unittest.main()
