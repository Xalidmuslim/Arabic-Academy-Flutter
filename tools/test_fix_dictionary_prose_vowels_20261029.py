"""Regression tests for context-preserving Arabic prose correction."""
import unittest
from fix_dictionary_confirmed_prose_vowels_20261029 import correct_prose, correct_entry, REPLACEMENTS, PROSE_FIELDS


class ProseCorrectionTests(unittest.TestCase):
    def test_all_confirmed_patterns_corrected(self):
        for wrong, right in REPLACEMENTS:
            with self.subTest(pattern=wrong):
                fixed, counts = correct_prose(wrong + " فِي جُمْلَةٍ.")
                self.assertIn(right, fixed)
                self.assertNotIn(wrong, fixed)
                self.assertEqual(sum(counts.values()), 1)

    def test_preserves_headword_and_nonprose_fields(self):
        entry = {
            "id": "sample",
            "arabic": "كَلامٌ",
            "grammar": ["اِسْمٌ"],
            "book_references": ["unmodified"],
            "meaning_ar": "كَلامٌ مُفِيدٌ.",
            "collocations": ["كَلامٌ وَاضِحٌ"],
            "examples_ar": ["يَنْمو الْعِلْمُ."],
            "usage_note_ar": "فِي عَلاقَةٍ مَعَ الْعِلْمِ.",
            "additional_meanings_ar": [],
        }
        changed, counts = correct_entry(entry)
        self.assertEqual(changed["arabic"], "كَلامٌ")
        self.assertEqual(changed["book_references"], ["unmodified"])
        self.assertIn("كَلَامٌ", changed["meaning_ar"])
        self.assertIn("يَنْمُو", changed["examples_ar"][0])
        self.assertIn("عَلَاقَةٍ", changed["usage_note_ar"])
        self.assertEqual(sum(counts.values()), 4)
        self.assertEqual(entry["meaning_ar"], "كَلامٌ مُفِيدٌ.")

    def test_idempotent(self):
        source = {"id": "x", "arabic": "عَلَامَةٌ", "meaning_ar": "كَلامٌ فِي عَلاقَةٍ."}
        first, count1 = correct_entry(source)
        second, count2 = correct_entry(first)
        self.assertEqual(second, first)
        self.assertEqual(sum(count1.values()), 2)
        self.assertEqual(sum(count2.values()), 0)

    def test_only_expected_fields_are_corrected(self):
        source = {"arabic": "كَلامٌ", "grammar": ["كَلامٌ"], "examples_ar": ["كَلامٌ"]}
        changed, _ = correct_entry(source)
        self.assertEqual(changed["arabic"], "كَلامٌ")
        self.assertEqual(changed["grammar"], ["كَلامٌ"])
        self.assertEqual(changed["examples_ar"], ["كَلَامٌ"])


if __name__ == "__main__":
    unittest.main()
