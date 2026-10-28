"""Regressions: distinguish close Arabic meanings without deleting synonyms."""
import json
import unittest

from validate_dictionary import ROOT


def card(filename, key):
    data = json.loads((ROOT / "assets/data" / filename).read_text(encoding="utf-8"))
    return next(item for item in data["entries"] if item["id"] == key)


class DistinctLexicalSensesTests(unittest.TestCase):
    def test_dialogue_is_not_the_same_definition_as_conversation(self):
        dialogue = card("entries_level3_07_08.json", "l3u08_021")
        conversation = card("entries_level2_07_08.json", "l2u07_030")
        self.assertNotEqual(dialogue["meaning_ar"], conversation["meaning_ar"])
        self.assertIn("الْآرَاءِ", dialogue["meaning_ar"])

    def test_plural_winds_are_not_marked_as_collective_noun(self):
        winds = card("entries_level2_15_16.json", "l2u16_008")
        self.assertTrue(winds["grammar"][0].startswith("جَمْعُ تَكْسِيرٍ"))
        self.assertIn("جَمْعُ رِيحٍ", winds["meaning_ar"])

    def test_tidal_term_has_specific_context_and_usable_example(self):
        tide = card("entries_editorial_geology_climate_20261027.json", "editorial_geology_climate_20261027_136")
        generic = card("entries_nouns_environment_20261025.json", "ind_noun_environment_20261026_049")
        self.assertNotEqual(tide["meaning_ar"], generic["meaning_ar"])
        self.assertIn("الْمَدِّ", tide["meaning_ar"])
        self.assertIn("الْجَزْرِ", tide["examples_ar"][0])

    def test_specific_legal_article_not_a_duplicate_definition(self):
        legal = card("entries_level4_draft_11_12.json", "l4u12_004")
        general = card("entries_level4_draft_05_06.json", "l4draft06_003")
        self.assertNotEqual(legal["meaning_ar"], general["meaning_ar"])
        self.assertIn("تَشْرِيعٍ", legal["meaning_ar"])


if __name__ == "__main__":
    unittest.main()
