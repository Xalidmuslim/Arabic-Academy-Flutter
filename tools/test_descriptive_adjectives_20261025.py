"""Validate independent fully vocalized Arabic descriptive lexicon chunks.

This is a structural/integration gate, not linguistic proof or textbook collation.
"""
import json
import re
import unittest

from validate_dictionary import ROOT, load_corpus

CHUNKS = [
    "assets/data/entries_adjectives_character_20261025.json",
    "assets/data/entries_adjectives_cognition_20261025.json",
    "assets/data/entries_adjectives_material_20261025.json",
    "assets/data/entries_adjectives_context_20261025.json",
]
DIACRITIC = re.compile(r"[\u064b-\u0652]")
INVALID = re.compile(r"[A-Za-zА-Яа-яЁё]")


class DescriptiveAdjectiveBatchTest(unittest.TestCase):
    def test_large_batch_merges_into_corpus(self):
        manifest = json.loads((ROOT / "assets/data/corpus_manifest.json").read_text(encoding="utf-8"))
        all_cards = []
        for name in CHUNKS:
            self.assertIn(name, manifest["files"])
            chunk = json.loads((ROOT / name).read_text(encoding="utf-8"))
            self.assertEqual(chunk["schema_version"], 3)
            self.assertEqual(chunk["source_status"], "independent_adjective_lexicon_not_textbook_collated")
            self.assertGreaterEqual(len(chunk["entries"]), 90, name)
            all_cards.extend(chunk["entries"])

        self.assertGreaterEqual(len(all_cards), 470)
        self.assertEqual(len(all_cards), len({e["id"] for e in all_cards}))
        self.assertEqual(len(all_cards), len({e["arabic"] for e in all_cards}))

        for entry in all_cards:
            word = entry["arabic"]
            self.assertRegex(word, DIACRITIC)
            self.assertGreaterEqual(len(entry["meaning_ar"]), 32, word)
            self.assertGreaterEqual(len(entry["usage_note_ar"]), 20, word)
            self.assertTrue(entry["examples_ar"], word)
            self.assertTrue(entry["collocations"], word)
            self.assertTrue(entry["grammar"], word)
            self.assertIn("صِفَةٌ", " ".join(entry["grammar"]), word)
            self.assertIn("الْمُؤَنَّثُ", " ".join(entry["grammar"]), word)
            feminine = " ".join(entry["grammar"]).split("الْمُؤَنَّثُ", 1)[1].strip()
            self.assertRegex(feminine, DIACRITIC)
            self.assertNotEqual(feminine, word)
            for name in ("grammar", "collocations", "examples_ar", "additional_meanings_ar", "synonyms", "antonyms"):
                self.assertIsInstance(entry[name], list, word)
            self.assertEqual(entry["book_references"], [], word)
            self.assertEqual(entry["sources"], [], word)
            arabic_content = [word, entry["meaning_ar"], entry["usage_note_ar"]]
            for name in ("grammar", "collocations", "examples_ar", "additional_meanings_ar", "synonyms", "antonyms"):
                arabic_content += entry[name]
            self.assertIsNone(INVALID.search(" ".join(arabic_content)), word)

        merged = {e["arabic"] for e in load_corpus()["entries"]}
        self.assertTrue({e["arabic"] for e in all_cards}.issubset(merged))


if __name__ == "__main__":
    unittest.main()
