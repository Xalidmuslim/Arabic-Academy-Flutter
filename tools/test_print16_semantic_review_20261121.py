#!/usr/bin/env python3
"""Regression checks for three independently edited Arabic semantic cards.

Scope: original printed page 16 = PDF page 20. Tests assert content,
mirroring and provenance; they do not certify all 25 page articles.
"""
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "assets" / "data"
ORIGINAL = DATA / "entries_bayna_scan_verified_20261112.json"
REVIEWED = DATA / "reviewed_articles_v1.json"

class Print16SemanticReviewTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        src = json.loads(ORIGINAL.read_text(encoding="utf-8"))
        reviewed = json.loads(REVIEWED.read_text(encoding="utf-8"))
        cls.source = {e["id"]: e for e in src["entries"]}
        cls.mirror = {e["arabic"]: e for e in reviewed["entries"]}
        cls.source_count = len(src["entries"])
        cls.reviewed_count = len(reviewed["entries"])

    def test_legacy_card_counts_and_source_page_unchanged(self):
        self.assertEqual(self.source_count, 571)
        self.assertEqual(self.reviewed_count, 685)
        for n in (347, 368, 369):
            src = self.source[f"bayna_scan_v1_{n}"]
            self.assertEqual(src["source_provenance"]["pdf_page"], 20)
            self.assertEqual(src["source_provenance"]["printed_page"], 16)
            self.assertEqual(src["editorial_review"]["status"],
                             "individual_arabic_draft_requires_independent_linguistic_review")
            self.assertEqual(self.mirror[src["arabic"]]["source_pdf_page"], 20)

    def test_ashaab_does_not_define_companions_as_owners_of_each_other(self):
        x = self.source["bayna_scan_v1_347"]
        self.assertIn("جَمْعُ صَاحِبٍ", x["meaning_ar"])
        self.assertIn("الرُّفَقَاءُ", x["meaning_ar"])
        self.assertIn("الْحَقِّ", x["grammar"][1])
        self.assertNotIn("تَرْبِطُهُمْ صُحْبَةٌ أَوْ مِلْكِيَّةٌ", x["meaning_ar"])

    def test_usuli_matches_wider_printed_source_sense(self):
        x = self.source["bayna_scan_v1_368"]
        self.assertIn("الْقَوَاعِدِ وَالْأُصُولِ", x["meaning_ar"])
        self.assertIn("الْمَنَاهِجِ", x["meaning_ar"])
        self.assertIn("لِلْأَشْخَاصِ وَالْمَنَاهِجِ", x["grammar"][1])
        self.assertIn("لَيْسَ مَقْصُورًا", x["usage_note_ar"])

    def test_aseel_preserves_three_distinct_printed_senses(self):
        x = self.source["bayna_scan_v1_369"]
        senses = [x["meaning_ar"], *x["additional_meanings_ar"]]
        self.assertEqual(len(senses), 3)
        self.assertIn("الْأَصْلِ", senses[0])
        self.assertIn("مُبْتَكَرٌ", senses[1])
        self.assertIn("مِنْ نَوْعٍ جَيِّدٍ", senses[2])

    def test_edited_content_matches_mirror_without_changing_examples(self):
        for n in (347, 368, 369):
            x = self.source[f"bayna_scan_v1_{n}"]
            y = self.mirror[x["arabic"]]
            self.assertEqual([x["meaning_ar"], *x["additional_meanings_ar"]],
                             [d["ar"] for d in y["definition"]])
            self.assertEqual(x["grammar"], [d["ar"] for d in y["grammar"]])
            self.assertEqual(x["usage_note_ar"], y["important"][0]["ar"])
            self.assertEqual(x["examples_ar"], [d["ar"] for d in y["examples"]])

if __name__ == "__main__":
    unittest.main()
