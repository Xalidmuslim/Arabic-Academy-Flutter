"""Evidence-based contextual regression tests for four technical Arabic cards.

Tests inspect source entries before the merged dictionary view. Do not assume
that an unvowelled spelling uniquely identifies an Arabic lemma.
"""
import json
import unittest
import unicodedata

from validate_dictionary import ROOT

FILES = {
    "energy": "assets/data/entries_editorial_energy_utilities_20261027.json",
    "maritime": "assets/data/entries_editorial_maritime_navigation_20261027.json",
}


def entry(subject: str, identifier: str) -> dict:
    doc = json.loads((ROOT / FILES[subject]).read_text(encoding="utf-8"))
    matches = [card for card in doc["entries"] if card["id"] == identifier]
    assert len(matches) == 1, f"Expected one card with ID {identifier}"
    return matches[0]


class ScientificWaterAndTechnicalVocabularyTests(unittest.TestCase):
    def test_uv_water_treatment_does_not_promise_sterilization(self):
        card = entry("energy", "editorial_energy_utilities_20261027_092")
        self.assertEqual(card["arabic"], unicodedata.normalize("NFC", "تَطْهِيرٌ بِالْأَشِعَّةِ فَوْقَ الْبَنَفْسَجِيَّةِ"))
        self.assertIn("لِلْمَاءِ", card["meaning_ar"])
        self.assertIn("الْكَائِنَاتِ الدَّقِيقَةِ", card["meaning_ar"])
        self.assertIn("لَا تَتْرُكُ", card["usage_note_ar"])
        self.assertIn("الْمَاءِ", card["usage_note_ar"])
        self.assertFalse(card["book_references"])
        self.assertFalse(card["sources"])

    def test_chlorination_notes_distinguish_chemical_residual_from_uv(self):
        card = entry("energy", "editorial_energy_utilities_20261027_091")
        self.assertIn("الْكُلُورِ الْمُتَبَقِّي", card["usage_note_ar"])
        self.assertIn("الْمَعَايِيرِ", card["usage_note_ar"])

    def test_variable_speed_motor_is_defined_as_speed_adaptation_not_attribution(self):
        card = entry("energy", "editorial_energy_utilities_20261027_116")
        self.assertIn("سُرْعَةَ مُحَرِّكٍ", card["meaning_ar"])
        self.assertIn("الْحِمْلِ", card["meaning_ar"])
        self.assertNotIn("تَنْسِيبِ", card["meaning_ar"])

    def test_anchor_describes_holding_position_not_preventing_all_motion(self):
        card = entry("maritime", "editorial_maritime_navigation_20261027_019")
        self.assertIn("مَوْقِعَ السَّفِينَةِ", card["meaning_ar"])
        self.assertIn("قَاعِ", card["meaning_ar"])
        self.assertIn("تَدُورَ", card["usage_note_ar"])


if __name__ == "__main__":
    unittest.main()
