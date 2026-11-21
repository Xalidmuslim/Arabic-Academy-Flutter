#!/usr/bin/env python3
"""Arabic editorial regression: printed page 15 (PDF 19), 30 existing entries.

Checks the scope/consistency of human-authored draft edits, NOT external
certification of every vowel or independent i3rab.
"""
import json
import unicodedata
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "assets" / "data"
SCAN = DATA / "entries_bayna_scan_verified_20261112.json"
OVERLAY = DATA / "reviewed_articles_v1.json"

def nfc(s):
    return unicodedata.normalize("NFC", s)

class PrintedPage15DeepEditorial(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.all_scan = json.loads(SCAN.read_text(encoding="utf-8"))["entries"]
        cls.page = [x for x in cls.all_scan if x["source_provenance"]["pdf_page"] == 19]
        cls.reviewed = {
            nfc(x["arabic"]): x
            for x in json.loads(OVERLAY.read_text(encoding="utf-8"))["entries"]
        }

    def test_all_30_preexisting_ids_preserved_and_sources_unchanged(self):
        self.assertEqual(len(self.page), 30)
        self.assertEqual(
            {x["id"] for x in self.page},
            {f"bayna_scan_v1_{i:03d}" for i in range(315, 345)}
        )
        for x in self.page:
            self.assertEqual(x["source_provenance"]["printed_page"], 15)
            self.assertEqual(x["source_provenance"]["scan_sha256"],
                             "a2d98cbf6cd309bac2ac072e09679260b1fa20dec0af4cfa7ddf82d7fae2f995")
            self.assertEqual(x["visual_verification"]["examples_status"],
                             "independently_authored_pending_separate_i3rab_review")

    def test_30_detailed_individual_drafts_and_reviewed_mirror(self):
        notes = set()
        for e in self.page:
            with self.subTest(e=e["arabic"]):
                self.assertGreaterEqual(len(e["grammar"]), 2)
                self.assertGreaterEqual(len(e["examples_ar"]), 2)
                self.assertGreaterEqual(len(e["collocations"]), 1)
                self.assertNotIn(e["usage_note_ar"], notes)
                notes.add(e["usage_note_ar"])
                self.assertNotIn("هَذِهِ صِيغَةُ جَمْعٍ؛ وَتَعْيِينُ مُفْرَدِهَا", e["usage_note_ar"])
                self.assertEqual(
                    e.get("editorial_review", {}).get("status"),
                    "individual_arabic_draft_requires_independent_linguistic_review")
                ov = self.reviewed[nfc(e["arabic"])]
                self.assertEqual([z["ar"] for z in ov["definition"]],
                                 [e["meaning_ar"], *e["additional_meanings_ar"]])
                self.assertEqual([z["ar"] for z in ov["grammar"]], e["grammar"])
                self.assertEqual([z["ar"] for z in ov["examples"]], e["examples_ar"])
                self.assertEqual(ov["important"][0]["ar"], e["usage_note_ar"])
                self.assertEqual(ov["visual_verification"], e["visual_verification"])

    def test_every_changed_arabic_field_has_unicode_nfc_order(self):
        for e in self.page:
            with self.subTest(word=e["arabic"]):
                fields = [
                    e["meaning_ar"], *e["additional_meanings_ar"],
                    *e["grammar"], *e["examples_ar"],
                    *e["collocations"], e["usage_note_ar"]
                ]
                for value in fields:
                    self.assertEqual(value, nfc(value))

    def test_documented_grammar_and_semantic_regressions(self):
        d = {e["arabic"]: e for e in self.page}
        for word in ("أَشَدُّ", "أَشْمَلُ", "أَشْهَرُ"):
            g = " ".join(d[word]["grammar"])
            self.assertIn("أَفْعَلُ", g)
            self.assertNotIn("أَفْعَلَ.", g)
        for word in ("أَشْيَاءُ", "أَصَابِعُ"):
            self.assertIn("مَمْنُوعٌ مِنَ الصَّرْفِ", d[word]["usage_note_ar"])
        self.assertIn("الْأَبِ وَالْأُمِّ", d["أَشِقَّاءُ"]["usage_note_ar"])
        self.assertIn("فِعْلٌ نَاقِصٌ", " ".join(d["أَصْبَحَ"]["grammar"]))
        self.assertIn("فِعْلٌ تَامٌّ", " ".join(d["أَصْبَحَ"]["grammar"]))
        self.assertIn("عَلَى", " ".join(d["إِشْرَافٌ"]["collocations"]))
        self.assertEqual(len(d["أَصَابَ"]["additional_meanings_ar"]), 1)
        self.assertGreaterEqual(len(d["إِصَابَةٌ"]["additional_meanings_ar"]), 1)

if __name__ == "__main__":
    unittest.main()
