"""Regression checks for the moon-letter definite article before hamza.

Only a clearly missing sukun before the pronounced hamza is corrected.
Wasl-alif sequences and lexical variants are intentionally excluded.
"""
import unittest
from audit_dictionary_variants import iter_corpus_chunks
from audit_dictionary_deep_editorial import find_missing_moon_lam_sukun, inspect_deep_quality


class MoonArticleHamzaTests(unittest.TestCase):
    def test_detects_missing_lam_sukun_before_hamza(self):
        self.assertEqual(find_missing_moon_lam_sukun("الأَرْضِ"), ["الأَ"])
        self.assertEqual(find_missing_moon_lam_sukun("وَالأَشْيَاءِ"), ["الأَ"])
        self.assertEqual(find_missing_moon_lam_sukun("بِالإِضَاءَةِ"), ["الإِ"])
        self.assertEqual(find_missing_moon_lam_sukun("الآفَاتِ"), ["الآ"])

    def test_ignores_correct_moon_and_solar_definite_articles(self):
        for text in ("الْأَرْضِ", "وَالْإِحْسَانِ", "الْآخِرِ",
                     "التَّعْلِيمُ", "الْكِتَابُ", "الانْتِظَارُ"):
            self.assertEqual(find_missing_moon_lam_sukun(text), [], text)

    def test_detects_in_arabic_definition_and_example(self):
        card = {"id": "test", "arabic": "عِلْمٌ",
                "meaning_ar": "دِرَاسَةُ الأَرْضِ.",
                "usage_note_ar": "", "grammar": ["اِسْمٌ"],
                "collocations": ["عِلْمُ الأَحْيَاءِ"],
                "examples_ar": ["دَرَسَ الأَرْضَ."]}
        result = inspect_deep_quality([("sample.json", card)])
        self.assertEqual(len(result["missing_moon_article_lam_sukun"]), 3)

    def test_all_source_cards_have_correct_moon_article_before_hamza(self):
        report = inspect_deep_quality(iter_corpus_chunks())
        errors = report["missing_moon_article_lam_sukun"]
        self.assertEqual([], errors[:15], f"{len(errors)} occurrences need sukun correction")


if __name__ == "__main__":
    unittest.main()
