#!/usr/bin/env python3
"""Regressions for targeted printed-page 17 Arabic semantic corrections.

Tests check exact article IDs, independent examples and mirrored data.
They do not certify all 27 draft articles linguistically.
"""
import json
import unicodedata
import unittest
from pathlib import Path

DATA = Path(__file__).resolve().parents[1] / "assets" / "data"
AUDIT = Path(__file__).resolve().parents[1] / "research" / "dictionary_sources"
norm = lambda s: unicodedata.normalize("NFC", s)


class Print17SemanticExamplesTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = json.loads((DATA / "entries_bayna_scan_verified_20261112.json").read_text(encoding="utf-8"))
        reviewed = json.loads((DATA / "reviewed_articles_v1.json").read_text(encoding="utf-8"))
        cls.source = {e["id"]: e for e in source["entries"]}
        cls.review = {norm(e["arabic"]): e for e in reviewed["entries"]}
        cls.source_count = len(source["entries"])
        cls.review_count = len(reviewed["entries"])

    def test_original_ids_source_page_and_no_duplicate_udhiyah(self):
        self.assertEqual(self.source_count, 571)
        self.assertEqual(self.review_count, 685)
        ids = {x["id"] for x in self.source.values()
               if x.get("source_provenance", {}).get("pdf_page") == 21}
        self.assertEqual(ids, {f"bayna_scan_v1_{i}" for i in range(370, 398) if i != 378})
        self.assertEqual(self.source["bayna_scan_v1_378"]["source_provenance"]["pdf_page"], None)
        self.assertEqual(self.source["bayna_scan_v1_378"]["visual_verification"]["status"],
                         "source_headword_mismatch_requires_relocation")
        self.assertIn(norm("أُضْحِيَّةٌ"), self.review)

    def test_adhraba_is_not_restricted_to_work_only(self):
        x = self.source["bayna_scan_v1_380"]
        self.assertIn("فِعْلِ شَيْءٍ", norm(x["meaning_ar"]))
        self.assertIn(norm("الطَّعَامِ"), norm(" ".join(x["examples_ar"])))
        self.assertIn(norm("عَنْ"), norm(" ".join(x["grammar"])))
        self.assertIn(norm("الطَّعَامِ"), norm(x["usage_note_ar"]))

    def test_adhrama_preserves_printed_figurative_conflict_sense(self):
        x = self.source["bayna_scan_v1_381"]
        self.assertIn(norm("النَّارَ"), norm(x["meaning_ar"]))
        self.assertEqual(len(x["additional_meanings_ar"]), 1)
        self.assertIn(norm("الْحَرْبَ"), norm(x["additional_meanings_ar"][0]))
        self.assertIn(norm("الْخِلَافَ"), norm(x["examples_ar"][-1]))
        self.assertIn(norm("مَجَازِيٌّ"), norm(x["usage_note_ar"]))

    def test_atra_denotes_excessive_praise(self):
        x = self.source["bayna_scan_v1_397"]
        self.assertIn("بَالَغَ", norm(x["meaning_ar"]))
        self.assertIn("الْمُبَالَغَةِ", norm(x["usage_note_ar"]))
        self.assertIn("مَدْحٍ", norm(x["usage_note_ar"]))

    def test_examples_demonstrate_both_physical_and_figurative_frames(self):
        itar = self.source["bayna_scan_v1_388"]
        itarat = self.source["bayna_scan_v1_389"]
        self.assertEqual(len(itar["examples_ar"]), 2)
        self.assertEqual(len(itarat["examples_ar"]), 2)
        self.assertIn(norm("إِطَارِ الْمَشْرُوعِ"), norm(itar["examples_ar"][1]))
        self.assertIn(norm("إِطَارَاتٍ خَشَبِيَّةٍ"), norm(itarat["examples_ar"][1]))
        self.assertNotEqual(itar["examples_ar"][0], itar["examples_ar"][1])

    def test_changed_cards_and_new_examples_mirror_and_audit(self):
        for n in (380, 381, 388, 389, 397):
            x = self.source[f"bayna_scan_v1_{n}"]
            y = self.review[norm(x["arabic"])]
            self.assertEqual([x["meaning_ar"], *x["additional_meanings_ar"]],
                             [d["ar"] for d in y["definition"]])
            self.assertEqual(x["grammar"], [d["ar"] for d in y["grammar"]])
            self.assertEqual(x["examples_ar"], [d["ar"] for d in y["examples"]])
            self.assertEqual(x["usage_note_ar"], y["important"][0]["ar"])
            self.assertEqual(x["editorial_review"]["status"],
                             "individual_arabic_draft_requires_independent_linguistic_review")
            values = [x["meaning_ar"], *x["grammar"], *x["examples_ar"], x["usage_note_ar"]]
            for item in values:
                self.assertEqual(item, norm(item))
        audit = json.loads((AUDIT / "print17_semantic_examples_20261121.json").read_text(encoding="utf-8"))
        page_ids = {x["id"] for x in self.source.values()
                    if x.get("source_provenance", {}).get("pdf_page") == 21}
        self.assertEqual({e["source_entry_id"] for e in audit["entries"]}, page_ids)
        self.assertEqual(audit["scoped_entry_count"], 27)
        self.assertEqual(audit["corrected_entry_count"], 5)
        self.assertEqual(audit["full_article_certification_count"], 0)
        new_examples = audit["independent_examples_i3rab"]
        self.assertEqual(len(new_examples), 4)
        self.assertEqual(
            [x["source_entry_id"] for x in audit["unresolved_lexical_discrepancies"]],
            ["bayna_scan_v1_385"],
        )
        for row in new_examples:
            self.assertIn(row["example_ar"], self.source[row["source_entry_id"]]["examples_ar"])
            self.assertTrue(row["i3rab_ar"])
            self.assertEqual(row["authorship"], "new_editorial_example_not_in_printed_book")


if __name__ == "__main__":
    unittest.main()
