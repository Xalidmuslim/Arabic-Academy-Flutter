"""Editorial regression checks for explicitly source-verified Arabic senses.

Sources: Cairo Arabic Academy (الوسيط), and Birzeit Qabas:
- https://www.arabicacademy.gov.eg/ar/search_engine/roots/حمم
- https://www.arabicacademy.gov.eg/ar/search_engine/roots/صحف
- https://www.arabicacademy.gov.eg/ar/search_engine/roots/عبو
- https://sina.birzeit.edu/qabas/lemma/2022755900

This does NOT justify merging distinct unvocalized homographs.
"""
import json
import unicodedata
import unittest

from validate_dictionary import ROOT, load_corpus
from audit_dictionary_variants import strip_diacritics


def nfc(text):
    return unicodedata.normalize("NFC", text)


def article(filename, stable_id):
    data = json.loads((ROOT / "assets/data" / filename).read_text(encoding="utf-8"))
    return next(x for x in data["entries"] if x["id"] == stable_id)


class EditorialRecheckMediaNatureTests(unittest.TestCase):
    def test_volcanic_lava_is_humam_not_himam(self):
        e = article("entries_nouns_environment_20261025.json", "ind_noun_environment_20261026_074")
        self.assertEqual(nfc(e["arabic"]), nfc("حُمَمٌ"))
        self.assertIn("الْحُمَمِ", nfc(" ".join(e["collocations"] + e["examples_ar"])))
        self.assertNotIn("الْحِمَمِ", nfc(" ".join(e["collocations"] + e["examples_ar"])))

    def test_press_interview_uses_sahafi_not_suhufi_throughout_card(self):
        e = article("entries_nouns_arts_media_20261026.json", "editorial_arts_20261026_152")
        self.assertEqual(nfc(e["arabic"]), nfc("مُقَابَلَةٌ صَحَفِيَّةٌ"))
        source = nfc(" ".join([e["meaning_ar"], *e["grammar"], *e["collocations"], *e["examples_ar"]]))
        self.assertNotIn("صُحُفِي", source)
        self.assertIn("صَحَفِي", source)

    def test_press_investigation_uses_sahafi_not_suhufi_throughout_card(self):
        e = article("entries_nouns_arts_media_20261026.json", "editorial_arts_20261026_156")
        self.assertEqual(nfc(e["arabic"]), nfc("تَحْقِيقٌ صَحَفِيٌّ"))
        source = nfc(" ".join([e["meaning_ar"], *e["grammar"], *e["collocations"], *e["examples_ar"]]))
        self.assertNotIn("صُحُفِي", source)
        self.assertIn(nfc("الصَّحَفِيُّ"), source)

    def test_packaging_uses_attested_abwa_not_ub_wa(self):
        e = article("entries_nouns_commerce_20261025.json", "ind_noun_commerce_20261026_113")
        self.assertEqual(nfc(e["arabic"]), nfc("عَبْوَةٌ"))
        self.assertIn("عَبْوَةُ مَاءٍ", e["collocations"])
        self.assertIn("عَبْوَاتٌ", e["grammar"][0])
        self.assertNotIn("عُبْوَة", nfc(" ".join([e["arabic"], *e["collocations"], *e["examples_ar"]])))

    def test_tech_latent_response_uses_kumun_not_kamun(self):
        e = article("entries_level4_draft_03_04.json", "l4draft03_025")
        self.assertEqual(nfc(e["arabic"]), nfc("كُمُونٌ"))
        self.assertIn("زَمَنُ الْكُمُونِ", e["collocations"])
        self.assertTrue(e["book_references"]) # preserve original provenance (unverified)

    def test_cumin_is_not_merged_with_network_latency(self):
        e = article("entries_editorial_culinary_20261026.json", "editorial_culinary_20261026_087")
        self.assertEqual(nfc(e["arabic"]), nfc("كَمُّونٌ"))
        merged = {nfc(item["arabic"]) for item in load_corpus()["entries"]}
        self.assertIn(nfc("كَمُّونٌ"), merged)
        self.assertIn(nfc("كُمُونٌ"), merged)
        self.assertEqual(strip_diacritics("كَمُّونٌ"), strip_diacritics("كُمُونٌ"))

    def test_source_provenance_remains_independent(self):
        for filename, stable_id in (
            ("entries_nouns_environment_20261025.json", "ind_noun_environment_20261026_074"),
            ("entries_nouns_arts_media_20261026.json", "editorial_arts_20261026_152"),
            ("entries_nouns_arts_media_20261026.json", "editorial_arts_20261026_156"),
            ("entries_nouns_commerce_20261025.json", "ind_noun_commerce_20261026_113"),
        ):
            e = article(filename, stable_id)
            self.assertEqual(e["book_references"], [])
            self.assertEqual(e["sources"], [])


if __name__ == "__main__":
    unittest.main()
