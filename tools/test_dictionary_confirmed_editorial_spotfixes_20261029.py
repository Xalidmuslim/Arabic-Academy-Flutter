"""Regression checks for human-confirmed, tightly scoped Arabic prose corrections.

No headword, meaning, book reference, or grammatical category is merged.
"""
import json
import unittest
from pathlib import Path
from validate_dictionary import ROOT

CORRECTIONS = [
  [
    "entries_adjectives_context_20261025.json",
    "ind_adjective_context_20261025_011",
    "grammar",
    "تِلقَائِيَّةٌ",
    "تِلْقَائِيَّةٌ"
  ],
  [
    "entries_adjectives_context_20261025.json",
    "ind_adjective_context_20261025_011",
    "collocations",
    "تِلقَائِيٌّ",
    "تِلْقَائِيٌّ"
  ],
  [
    "entries_adjectives_context_20261025.json",
    "ind_adjective_context_20261025_011",
    "examples_ar",
    "تِلقَائِيٍّ",
    "تِلْقَائِيٍّ"
  ],
  [
    "entries_adjectives_context_20261025.json",
    "ind_adjective_context_20261025_036",
    "usage_note_ar",
    "وَالجَدَاوِلِ",
    "وَالْجَدَاوِلِ"
  ],
  [
    "entries_adjectives_context_20261025.json",
    "ind_adjective_context_20261025_071",
    "usage_note_ar",
    "الْكَميَّةِ",
    "الْكَمِّيَّةِ"
  ],
  [
    "entries_adjectives_context_20261025.json",
    "ind_adjective_context_20261025_130",
    "meaning_ar",
    "الْمُلوِّثَاتِ",
    "الْمُلَوِّثَاتِ"
  ],
  [
    "entries_adjectives_material_20261025.json",
    "ind_adjective_material_20261025_077",
    "usage_note_ar",
    "الْكَريهَةِ",
    "الْكَرِيهَةِ"
  ],
  [
    "entries_nouns_education_20261025.json",
    "ind_noun_education_20261025_070",
    "meaning_ar",
    "تُمنَحُ",
    "تُمْنَحُ"
  ],
  [
    "entries_editorial_astronomy_20261026.json",
    "editorial_astronomy_20261026_222",
    "meaning_ar",
    "التِقَاطُ",
    "اِلْتِقَاطُ"
  ],
  [
    "entries_editorial_geology_climate_20261027.json",
    "editorial_geology_climate_20261027_094",
    "examples_ar",
    "السْتْرَاتُوسْفِيرِ",
    "السِّتْرَاتُوسْفِيرِ"
  ],
  [
    "entries_editorial_geology_climate_20261027.json",
    "editorial_geology_climate_20261027_095",
    "meaning_ar",
    "السْتْرَاتُوسْفِيرِ",
    "السِّتْرَاتُوسْفِيرِ"
  ],
  [
    "entries_editorial_mathematics_science_20261027.json",
    "editorial_mathematics_science_20261027_198",
    "meaning_ar",
    "مُتَزامِنٍ",
    "مُتَزَامِنٍ"
  ],
  [
    "entries_editorial_software_networks_20261027.json",
    "editorial_software_networks_20261027_022",
    "meaning_ar",
    "كوَحْدَةٍ",
    "كَوَحْدَةٍ"
  ],
  [
    "entries_editorial_software_networks_20261027.json",
    "editorial_software_networks_20261027_022",
    "usage_note_ar",
    "تَسَاعَدُ",
    "تُسَاعِدُ"
  ],
  [
    "entries_editorial_manufacturing_20261027.json",
    "editorial_manufacturing_20261027_146",
    "usage_note_ar",
    "لِلأَنْابِيبِ",
    "لِلْأَنَابِيبِ"
  ],
  [
    "entries_editorial_health_anatomy_20261027.json",
    "editorial_health_anatomy_20261027_135",
    "meaning_ar",
    "لِمُلاحَظَةِ",
    "لِمُلَاحَظَةِ"
  ],
  [
    "entries_nouns_environment_20261025.json",
    "ind_noun_environment_20261026_060",
    "usage_note_ar",
    "لأَعْلَى",
    "لِأَعْلَى"
  ],
  [
    "entries_nouns_sports_recreation_20261026.json",
    "editorial_sports_20261026_180",
    "meaning_ar",
    "لِلحَرَكَةِ",
    "لِلْحَرَكَةِ"
  ],
  [
    "entries_nouns_time_planning_20261026.json",
    "editorial_time_20261026_038",
    "usage_note_ar",
    "لِلوَقْتِ",
    "لِلْوَقْتِ"
  ],
  [
    "entries_practical_textiles_20261025.json",
    "editorial_textiles_20261025_005",
    "additional_meanings_ar",
    "العَضَلَاتِ",
    "الْعَضَلَاتِ"
  ],
  [
    "entries_level3_15_16.json",
    "l3u15_030",
    "meaning_ar",
    "وَالتَزَمَ",
    "وَالْتَزَمَ"
  ]
]

class ConfirmedEditorialSpotfixTests(unittest.TestCase):
    def test_confirmed_arabic_forms_in_original_source_cards(self):
        cache = {}
        for filename, card_id, field, incorrect, corrected in CORRECTIONS:
            with self.subTest(file=filename, card_id=card_id, field=field, old=incorrect):
                if filename not in cache:
                    data = json.loads((ROOT / "assets" / "data" / filename).read_text(encoding="utf-8"))
                    cache[filename] = {entry["id"]: entry for entry in data["entries"]}
                self.assertIn(card_id, cache[filename])
                value = cache[filename][card_id][field]
                flattened = value if isinstance(value, str) else "\n".join(value)
                self.assertNotIn(incorrect, flattened, f"Uncorrected Arabic prose: {filename} / {card_id}")
                self.assertIn(corrected, flattened, f"Expected edited vowelization missing: {filename} / {card_id}")

if __name__ == "__main__":
    unittest.main()
