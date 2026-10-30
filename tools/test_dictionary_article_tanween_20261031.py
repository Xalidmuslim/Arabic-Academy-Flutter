"""Check raw Arabic headwords for a definite-article/tanween typo.

Some Form VIII verbal nouns begin with the root-alif and a sukun on lam,
e.g. اِسْتِ... is different, but اِِلْتِهَامٌ must NOT be spelled
الْتِهَامٌ. The latter falsely puts sukun on the article lam and is
ungrammatical with the ending tanween.
"""
import json
import re
import unittest
import unicodedata

from audit_dictionary_variants import iter_corpus_chunks
from validate_dictionary import ROOT

AL_TANWEEN = re.compile(r"(?:^|\s)الْ[\u0621-\u064a\u064b-\u065f]*[ًٌٍ](?=\s|$)")


class DefiniteArticleTanweenTests(unittest.TestCase):
    def test_no_ungrammatical_article_with_tanween_in_any_source_headword(self):
        defects = []
        for filename, card in iter_corpus_chunks():
            word = card.get("arabic", "")
            if AL_TANWEEN.search(word):
                defects.append(f"{card.get('id')} {word} [{filename}]")
        self.assertFalse(defects, "Invalid harakat: " + "; ".join(defects[:50]))

    def test_six_corrected_headwords_retain_original_ids_and_indefinite_forms(self):
        cases = {
            "assets/data/entries_nouns_community_20261025.json": {
                "ind_noun_community_20261026_122": "اِلْتِمَاسٌ",
            },
            "assets/data/entries_editorial_health_anatomy_20261027.json": {
                "editorial_health_anatomy_20261027_124": "اسْتِجَابَةٌ اِلْتِهَابِيَّةٌ",
            },
            "assets/data/entries_editorial_finance_accounting_20261027.json": {
                "editorial_finance_accounting_20261027_009": "اِلْتِزَامٌ مُتَدَاوَلٌ",
                "editorial_finance_accounting_20261027_010": "اِلْتِزَامٌ طَوِيلُ الْأَجَلِ",
                "editorial_finance_accounting_20261027_149": "اِلْتِزَامٌ مُحْتَمَلٌ",
            },
            "assets/data/entries_editorial_genetics_microbiology_20261027.json": {
                "editorial_genetics_microbiology_20261027_154": "اِلْتِهَامٌ ذَاتِيٌّ خَلَوِيٌّ",
            },
        }
        checked = 0
        for filename, expected in cases.items():
            entries = json.loads((ROOT / filename).read_text(encoding="utf-8"))["entries"]
            by_id = {entry["id"]: entry for entry in entries}
            for stable_id, form in expected.items():
                self.assertIn(stable_id, by_id)
                self.assertEqual(by_id[stable_id]["arabic"], unicodedata.normalize("NFC", form))
                self.assertEqual(by_id[stable_id]["book_references"], [])
                self.assertEqual(by_id[stable_id]["sources"], [])
                checked += 1
        self.assertEqual(checked, 6)

    def test_iltimas_inflections_have_correct_initial_harakat(self):
        entries = json.loads((ROOT / "assets/data/entries_nouns_community_20261025.json")
                             .read_text(encoding="utf-8"))["entries"]
        card = next(e for e in entries if e["id"] == "ind_noun_community_20261026_122")
        self.assertIn("اِلْتِمَاسَاتٌ", card["grammar"][0])
        self.assertIn("اِلْتِمَاسُ", card["collocations"][0])
        self.assertIn("اِلْتِمَاسًا", card["examples_ar"][0])

    def test_long_term_obligation_collocation_does_not_start_as_article(self):
        entries = json.loads((ROOT / "assets/data/entries_editorial_finance_accounting_20261027.json")
                             .read_text(encoding="utf-8"))["entries"]
        card = next(e for e in entries if e["id"] == "editorial_finance_accounting_20261027_010")
        self.assertTrue(card["collocations"][0].startswith("اِلْتِزَامَاتٌ"))

    def test_autophagy_uses_indefinite_masdar_not_definite_article(self):
        filename = ROOT / "assets/data/entries_editorial_genetics_microbiology_20261027.json"
        cards = json.loads(filename.read_text(encoding="utf-8"))["entries"]
        card = next(c for c in cards if c["id"] == "editorial_genetics_microbiology_20261027_154")
        self.assertEqual(
            card["arabic"],
            unicodedata.normalize("NFC", "اِلْتِهَامٌ ذَاتِيٌّ خَلَوِيٌّ"),
        )
        self.assertIn("الْخَلِيَّةُ", card["meaning_ar"])
        self.assertEqual(card["book_references"], [])


if __name__ == "__main__":
    unittest.main()
