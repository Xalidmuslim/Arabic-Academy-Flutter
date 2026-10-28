"""Verified Arabic lexical repairs, checked against Cairo Arabic Academy.

Sources:
- https://www.arabicacademy.gov.eg/ar/محرك-البحث/معجم/dic-19/الفقرة
- https://www.arabicacademy.gov.eg/ar/search_engine/roots/غسل

No automatic merging of legitimate homographs is permitted.
"""
import json
import unittest
from validate_dictionary import ROOT, load_corpus


def entry_in(filename, entry_id):
    data = json.loads((ROOT / filename).read_text(encoding="utf-8"))
    return next(e for e in data["entries"] if e["id"] == entry_id)


class EditorialFaqraMaghsalTests(unittest.TestCase):
    def test_paragraph_has_standard_fiqra_vowels_and_grammar(self):
        e = entry_in("assets/data/entries_nouns_education_20261025.json",
                     "ind_noun_education_20261025_042")
        self.assertEqual(e["arabic"], "فِقْرَةٌ")
        self.assertIn("الْجَمْعُ فِقَرَاتٌ", e["grammar"][0])
        self.assertIn("فِقْرَةٌ قَصِيرَةٌ", e["collocations"])

    def test_vertebra_has_anatomical_faqara_not_paragraph_lemma(self):
        e = entry_in("assets/data/entries_editorial_health_anatomy_20261027.json",
                     "editorial_health_anatomy_20261027_095")
        self.assertEqual(e["arabic"], "فَقَرَةٌ")
        self.assertIn("الْجَمْعُ فَقَرَاتٌ", e["grammar"][0])
        self.assertIn("فَقَرَةٌ قَطَنِيَّةٌ", e["collocations"])

    def test_two_distinct_lemmas_do_not_mix_meanings(self):
        merged = {e["arabic"]: e for e in load_corpus()["entries"]}
        self.assertNotIn("فَقْرَةٌ", merged)
        self.assertIn("فِقْرَةٌ", merged)
        self.assertIn("فَقَرَةٌ", merged)
        self.assertNotIn("الْعَمُودِ الْفَقَرِيِّ", merged["فِقْرَةٌ"]["meaning_ar"])
        self.assertIn("الْعَمُودِ الْفَقَرِيِّ", merged["فَقَرَةٌ"]["meaning_ar"])

    def test_mighsala_washing_machine_is_not_a_sink_headword(self):
        e = entry_in("assets/data/entries_practical_home_20261025.json",
                     "editorial_home_20261025_016")
        self.assertEqual(e["arabic"], "مَغْسَلٌ")
        self.assertEqual(e["collocations"], ["مَغْسَلُ الْمَطْبَخِ"])
        self.assertIn("الْمَغْسَلِ", e["examples_ar"][0])
        self.assertIn("حَوْضٌ", e["meaning_ar"])


if __name__ == "__main__":
    unittest.main()
