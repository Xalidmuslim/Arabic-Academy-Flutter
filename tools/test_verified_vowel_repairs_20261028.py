"""Regression protection for verified Arabic spelling and harakat repairs.

Source entries are checked by stable IDs: a broken source form must not
be hidden by the merge logic. Do not coalesce separate grammatical homographs.
"""
import json
import unicodedata
import unittest
from collections import defaultdict

from validate_dictionary import ROOT


def nfc(text):
    return unicodedata.normalize("NFC", text)


class ReviewedVowelRepairs(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.spec = json.loads(
            (ROOT / "tools/verified_vowel_repairs_20261028.json").read_text(encoding="utf-8")
        )
        cls.by_file = {}
        for repair in cls.spec["repairs"]:
            path = repair["filename"]
            if path not in cls.by_file:
                doc = json.loads((ROOT / "assets/data" / path).read_text(encoding="utf-8"))
                cls.by_file[path] = {item["id"]: item for item in doc["entries"]}

    def test_all_approved_headwords_are_repaired(self):
        self.assertGreaterEqual(len(self.spec["repairs"]), 19)
        for record in self.spec["repairs"]:
            with self.subTest(id=record["id"], file=record["filename"]):
                item = self.by_file[record["filename"]][record["id"]]
                self.assertEqual(nfc(item["arabic"]), nfc(record["new_headword"]))
                self.assertTrue(item["meaning_ar"])
                self.assertTrue(item["examples_ar"])

    def test_preserve_grammar_and_approved_lesson_order(self):
        for record in self.spec["repairs"]:
            item = self.by_file[record["filename"]][record["id"]]
            with self.subTest(id=record["id"]):
                self.assertTrue(item["grammar"])
                self.assertTrue(item["collocations"])
                if record["filename"].startswith("entries_level"):
                    self.assertTrue(item["book_references"])

    def test_no_unreviewed_homograph_deletions(self):
        # These forms share unvocalized spelling but have different senses.
        from audit_dictionary_variants import iter_corpus_chunks
        present = {nfc(e["arabic"]) for _, e in iter_corpus_chunks()}
        for a, b in (
            ("كُلِّيَّةٌ", "كُلْيَةٌ"),  # academic college / kidney
            ("سَلَطَةٌ", "سُلْطَةٌ"),  # salad / authority
            ("حَلَّ", "حَلٌّ"),         # verb / noun
            ("فِقْرَةٌ", "فَقْرَةٌ"),  # paragraph / vertebra
        ):
            with self.subTest(a=a, b=b):
                self.assertIn(nfc(a), present)
                self.assertIn(nfc(b), present)


if __name__ == "__main__":
    unittest.main()
