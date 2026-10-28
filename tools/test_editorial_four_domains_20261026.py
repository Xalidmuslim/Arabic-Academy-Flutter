"""Acceptance checks for the 2026-10-26 independent Arabic dictionary batches.

Content is editorial and does not assert any textbook unit provenance.
"""
import json
import re
import unittest
import unicodedata

from validate_dictionary import ROOT, load_corpus

DOMAINS = ("architecture", "culinary", "agriculture", "astronomy")
CHUNKS = [f"assets/data/entries_editorial_{name}_20261026.json" for name in DOMAINS]
DIACRITICS = re.compile(r"[\u064b-\u0652]")
BAD_SCRIPTS = re.compile(r"[A-Za-zА-Яа-яЁё]")


class ExpandedDictionary20261026Tests(unittest.TestCase):
    def test_large_new_batches_registered_with_full_editorial_fields(self):
        manifest = json.loads((ROOT / "assets/data/corpus_manifest.json").read_text("utf-8"))
        all_entries = []
        for path in CHUNKS:
            self.assertIn(path, manifest["files"])
            doc = json.loads((ROOT / path).read_text("utf-8"))
            self.assertEqual(doc["schema_version"], 3)
            self.assertEqual(doc["source_status"], "original_independent_arabic_lexicon_not_textbook_collated")
            self.assertEqual(len(doc["entries"]), {"architecture": 166, "culinary": 182, "agriculture": 187, "astronomy": 225}[path.split("_editorial_")[1].removesuffix("_20261026.json")], path)
            all_entries.extend(doc["entries"])
        self.assertEqual(len(all_entries), 760)
        self.assertEqual(len(all_entries), len({e["id"] for e in all_entries}))
        self.assertEqual(len(all_entries), len({e["arabic"] for e in all_entries}))
        headwords = {unicodedata.normalize("NFC", e["arabic"]) for e in all_entries}
        for expected in ("كُسُوفٌ حَلَقِيٌّ", "مَرْكَبَةٌ جَوَّالَةٌ", "مَخْبُوزَاتٌ", "جَرَانِيتٌ"):
            self.assertIn(unicodedata.normalize("NFC", expected), headwords)
        merged = {e["arabic"] for e in load_corpus()["entries"]}
        for entry in all_entries:
            word = entry["arabic"]
            self.assertIn(word, merged)
            self.assertTrue(DIACRITICS.search(word), word)
            self.assertGreaterEqual(len(entry["meaning_ar"]), 25, word)
            self.assertGreaterEqual(len(entry["usage_note_ar"]), 18, word)
            self.assertTrue(entry["grammar"], word)
            self.assertTrue(entry["collocations"], word)
            self.assertTrue(entry["examples_ar"], word)
            self.assertEqual(entry["book_references"], [], word)
            self.assertEqual(entry["sources"], [], word)
            for field in ("additional_meanings_ar", "grammar", "collocations", "examples_ar", "synonyms", "antonyms"):
                self.assertIsInstance(entry[field], list, (word, field))
            prose = [word, entry["meaning_ar"], entry["usage_note_ar"]]
            prose.extend(s for field in ("additional_meanings_ar", "grammar", "collocations", "examples_ar", "synonyms", "antonyms") for s in entry[field])
            self.assertFalse(BAD_SCRIPTS.search(" ".join(prose)), word)


if __name__ == "__main__":
    unittest.main()
