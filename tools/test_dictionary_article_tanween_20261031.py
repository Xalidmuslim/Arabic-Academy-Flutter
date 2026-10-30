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
