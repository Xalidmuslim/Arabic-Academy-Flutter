"""Regression tests for verified specialist Arabic lexicon corrections."""
import json
import unittest

from validate_dictionary import ROOT


class SpecialistArabicEditorialRepairs(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.entries = {}
        for name in ("maritime_navigation", "genetics_microbiology", "energy_utilities"):
            p = ROOT / f"assets/data/entries_editorial_{name}_20261027.json"
            for entry in json.loads(p.read_text(encoding="utf-8"))["entries"]:
                cls.entries[entry["id"]] = entry

    def test_ship_engine_uses_correct_active_participle(self):
        e = self.entries["editorial_maritime_navigation_20261027_029"]
        self.assertEqual(e["arabic"], "مُحَرِّكُ السَّفِينَةِ")
        self.assertTrue(all("الْمِحْرَكِ" not in x for x in e["collocations"] + e["examples_ar"]))
        self.assertTrue(any("الْمُحَرِّكِ" in x for x in e["collocations"]))

    def test_biological_treatment_headword_modifies_treatment_not_water(self):
        e = self.entries["editorial_genetics_microbiology_20261027_140"]
        self.assertEqual(e["arabic"], "مُعَالَجَةٌ حَيَوِيَّةٌ لِلْمِيَاهِ")
        self.assertIn("الْمُعَالَجَةِ الْحَيَوِيَّةِ", e["collocations"][0])

    def test_enzyme_note_agrees_with_masculine_shakl(self):
        e = self.entries["editorial_genetics_microbiology_20261027_116"]
        self.assertEqual(e["usage_note_ar"], "يُؤَثِّرُ شَكْلُ الْبِنْيَةِ فِي اخْتِصَاصِ الْإِنْزِيمِ.")

    def test_fungal_spore_definition_uses_intransitive_verb(self):
        e = self.entries["editorial_genetics_microbiology_20261027_071"]
        self.assertIn("وَتَنْتَشِرُ فِي الْبِيئَةِ", e["meaning_ar"])
        self.assertNotIn("تُنْتَشَرُ", e["meaning_ar"])

    def test_electrical_resistance_definition_is_not_circular(self):
        e = next(x for x in self.entries.values() if x["id"] == "editorial_energy_utilities_20261027_019")
        self.assertIn("مُعَاكَسَةِ", e["meaning_ar"])
        self.assertNotIn("تُحَدِّدُ مُقَاوَمَةَ", e["meaning_ar"])


if __name__ == "__main__":
    unittest.main()
