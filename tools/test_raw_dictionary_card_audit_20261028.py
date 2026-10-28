"""Regression tests for scanning ALL source cards before headword merge."""
import unittest

from audit_dictionary_raw_cards import inspect_raw_cards


class RawDictionaryCardAuditTests(unittest.TestCase):
    def test_later_duplicate_id_is_not_hidden_by_merged_corpus(self):
        items = [
            ("one.json", {"id": "same", "arabic": "كِتَابٌ", "meaning_ar": "مَجْمُوعَةٌ مِنَ الْأَوْرَاقِ الْمَكْتُوبَةِ.",
                          "grammar": ["اِسْمٌ"], "collocations": ["كِتَابٌ جَدِيدٌ"], "examples_ar": ["قَرَأَ كِتَابًا."], "usage_note_ar": "", "book_references": []}),
            ("two.json", {"id": "same", "arabic": "مَدْرَسَةٌ", "meaning_ar": "مَكَانٌ يَذْهَبُ إِلَيْهِ التَّلَامِيذُ.",
                          "grammar": [], "collocations": [], "examples_ar": [], "usage_note_ar": "", "book_references": []}),
        ]
        report = inspect_raw_cards(items)
        self.assertEqual(report["source_cards"], 2)
        self.assertEqual(report["repeated_card_ids"], 1)
        self.assertEqual(report["missing_grammar"], 1)
        self.assertEqual(report["missing_collocations"], 1)
        self.assertEqual(report["missing_examples"], 1)
        self.assertEqual(report["flagged_card_count"], 1)
        self.assertIn("same", report["issues"][0]["id"])

    def test_all_fields_are_checked_even_when_same_headword_merges(self):
        entries = [
            ("good.json", {"id": "one", "arabic": "بَابٌ", "meaning_ar": "جُزْءٌ مِنَ الْبَيْتِ يُفْتَحُ لِلدُّخُولِ.",
                           "grammar": ["اِسْمٌ"], "collocations": ["بَابُ الْبَيْتِ"], "examples_ar": ["أَغْلَقَ الْبَابَ."], "usage_note_ar": "", "book_references": []}),
            ("bad.json", {"id": "two", "arabic": "بَابٌ", "meaning_ar": "A broken definition", "grammar": [],
                          "collocations": ["Latin"], "examples_ar": [], "usage_note_ar": None, "book_references": []}),
        ]
        report = inspect_raw_cards(entries)
        self.assertEqual(report["source_cards"], 2)
        self.assertEqual(report["invalid_script_cards"], 1)
        self.assertEqual(report["missing_usage_note_field"], 1)
        self.assertEqual(report["missing_grammar"], 1)
        self.assertEqual(report["missing_examples"], 1)
        self.assertEqual(report["invalid_definition_cards"], 1)
        self.assertEqual(report["flagged_card_count"], 1)

    def test_different_lexemes_are_not_flagged_as_duplicates(self):
        entries = [
            ("x", {"id": "a", "arabic": "سَلَطَةٌ", "meaning_ar": "طَعَامٌ مِنَ الْخُضْرَوَاتِ.",
                    "grammar": ["اِسْمٌ"], "collocations": ["سَلَطَةٌ خَضْرَاءُ"], "examples_ar": ["أَكَلَ السَّلَطَةَ."],
                    "usage_note_ar": "", "book_references": []}),
            ("y", {"id": "b", "arabic": "سُلْطَةٌ", "meaning_ar": "قُدْرَةٌ عَلَى اتِّخَاذِ الْقَرَارِ.",
                    "grammar": ["اِسْمٌ"], "collocations": ["سُلْطَةُ الْقَانُونِ"], "examples_ar": ["لَهُ سُلْطَةٌ."],
                    "usage_note_ar": "", "book_references": []}),
        ]
        report = inspect_raw_cards(entries)
        self.assertEqual(report["repeated_card_ids"], 0)
        self.assertEqual(report["flagged_card_count"], 0)


if __name__ == "__main__":
    unittest.main()
