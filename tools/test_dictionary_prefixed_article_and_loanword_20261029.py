"""Targeted checks after the 68-case Arabic prose review.

Known valid solar lam assimilations after compound prefixes should NOT be
flagged as missing vowels.  Two remaining lexical examples are fully marked.
"""
import json
import unicodedata
import unittest
from validate_dictionary import ROOT
from audit_dictionary_prose_diacritics import partially_vocalized_tokens, unvocalized_tokens
from audit_dictionary_deep_editorial import vowel_coverage


class CompoundArabicPrefixAndLoanwordTests(unittest.TestCase):
    def test_valid_solar_lam_with_waw_and_preposition_is_not_flagged(self):
        for text in (
            "وَبِالتَّقْوِيمِ", "وَلِلصُّعُودِ",
            "وَلِلشَّخْصِ", "وَلِلرُّسُومِ",
            "وَالدِّيزَلَ",
        ):
            with self.subTest(text=text):
                self.assertEqual(partially_vocalized_tokens(text), [])

    def test_tatweel_in_single_letter_prefix_is_not_a_missing_vowel(self):
        self.assertEqual(partially_vocalized_tokens("يَأْتِي غَالِبًا مَعَ «بِـ»."), [])
        self.assertEqual(unvocalized_tokens("تَرِدُ مَعَ «بـ»."), [])
        self.assertEqual(vowel_coverage("بِـ")["missing"], [])

    def test_confirmed_vocalization_of_agricultural_pests(self):
        path = ROOT / "assets/data/entries_editorial_agriculture_20261026.json"
        cards = json.loads(path.read_text(encoding="utf-8"))["entries"]
        entry = next(e for e in cards if e["id"] == "editorial_agriculture_20261026_129")
        self.assertIn("آفَاتٍ", entry["meaning_ar"])
        self.assertNotIn("آفاتٍ", entry["meaning_ar"])

    def test_diesel_loanword_is_marked_without_removing_lexical_variant(self):
        path = ROOT / "assets/data/entries_nouns_transport_20261025.json"
        cards = json.loads(path.read_text(encoding="utf-8"))["entries"]
        entry = next(e for e in cards if e["id"] == "ind_noun_transport_20261026_075")
        text = unicodedata.normalize("NFC", entry["usage_note_ar"])
        self.assertIn(unicodedata.normalize("NFC", "وَالدِّيزَلَ"), text)
        self.assertNotIn(unicodedata.normalize("NFC", "وَالدِّيزلَ"), text)


if __name__ == "__main__":
    unittest.main()
