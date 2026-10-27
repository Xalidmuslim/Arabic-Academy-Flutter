"""Verify carefully reviewed spelling/harakat corrections across the corpus.

Only targeted article headings are modified; lesson indices, article IDs and
separate dictionary/book applications remain unchanged.
"""
import json
import unittest

from validate_dictionary import ROOT

# filepath relative to assets/data/, ID, corrected headword
CORRECTIONS = (
    ("entries_editorial_maritime_navigation_20261027.json", "editorial_maritime_navigation_20261027_077", "مَدٌّ بَحْرِيٌّ"),
    ("entries_editorial_genetics_microbiology_20261027.json", "editorial_genetics_microbiology_20261027_023", "طَفْرَةٌ وِرَاثِيَّةٌ"),
    ("entries_editorial_communication_media_20261027.json", "editorial_communication_media_20261027_126", "عَلَامَةٌ تِجَارِيَّةٌ"),
    ("entries_editorial_law_civics_20261027.json", "editorial_law_civics_20261027_058", "اِسْتِئْنَافٌ"),
    ("entries_editorial_mathematics_science_20261027.json", "editorial_mathematics_science_20261027_086", "اِنْحِرَافٌ مِعْيَارِيٌّ"),
    ("entries_editorial_health_anatomy_20261027.json", "editorial_health_anatomy_20261027_071", "هُرْمُونٌ"),
    ("entries_editorial_health_anatomy_20261027.json", "editorial_health_anatomy_20261027_146", "مَوْجَاتٌ فَوْقَ صَوْتِيَّةٍ"),
    ("entries_editorial_manufacturing_20261027.json", "editorial_manufacturing_20261027_054", "مَتَانَةٌ"),
    ("entries_nouns_community_20261025.json", "ind_noun_community_20261026_082", "مَتْحَفٌ"),
    ("entries_nouns_community_20261025.json", "ind_noun_community_20261026_173", "اِسْتِئْنَافٌ"),
    ("entries_daily_education_20261025.json", "editorial_daily_education_20261025_028", "مُصْطَلَحٌ"),
    ("entries_advanced_ecology_20261025_b.json", "editorial_earth_20261025_b_034", "مَسَامِيَّةٌ"),
    ("entries_semantic_disambiguation_20261025.json", "semantic_polysemy_20261025_062", "دُسْتُورٌ"),
    ("entries_semantic_disambiguation_20261025.json", "semantic_polysemy_20261025_010", "دَرَجَةٌ"),
    ("entries_level4_draft_07_08.json", "l4draft07_034", "مُعْجَمٌ"),
    ("entries_level4_draft_11_12.json", "l4u11_001", "تَغَيُّرٌ مُنَاخِيٌّ"),
)


class LinguisticHeadwordCorrections(unittest.TestCase):
    def test_corrected_headword_per_stable_article_id(self):
        by_file = {}
        for filename, entry_id, correct in CORRECTIONS:
            if filename not in by_file:
                data = json.loads((ROOT / "assets" / "data" / filename).read_text(encoding="utf-8"))
                by_file[filename] = {entry["id"]: entry for entry in data["entries"]}
            with self.subTest(filename=filename, entry_id=entry_id):
                self.assertIn(entry_id, by_file[filename])
                entry = by_file[filename][entry_id]
                self.assertEqual(entry["arabic"], correct)
                self.assertTrue(entry["meaning_ar"])
                self.assertTrue(entry["examples_ar"])
                self.assertTrue(entry["grammar"])

    def test_book_chapter_references_survive_spelling_edits(self):
        for filename, entry_id in (
            ("entries_level4_draft_07_08.json", "l4draft07_034"),
            ("entries_level4_draft_11_12.json", "l4u11_001"),
        ):
            data = json.loads((ROOT / "assets" / "data" / filename).read_text(encoding="utf-8"))
            entry = next(e for e in data["entries"] if e["id"] == entry_id)
            self.assertTrue(entry["book_references"])


if __name__ == "__main__":
    unittest.main()
