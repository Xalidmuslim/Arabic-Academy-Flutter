#!/usr/bin/env python3
"""Printed page 16/PDF20: preserve IDs and separate independently authored drafts from print."""
import json
import unicodedata
import unittest
from pathlib import Path

BASE = Path(__file__).resolve().parents[1] / "assets" / "data"
SHA = "a2d98cbf6cd309bac2ac072e09679260b1fa20dec0af4cfa7ddf82d7fae2f995"

class DeepEditorialPrint16(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = json.loads((BASE/"entries_bayna_scan_verified_20261112.json").read_text(encoding="utf-8"))["entries"]
        cls.rows = [x for x in cls.source if x["source_provenance"]["pdf_page"]==20]
        cls.review = {unicodedata.normalize("NFC",x["arabic"]):x for x in
                      json.loads((BASE/"reviewed_articles_v1.json").read_text(encoding="utf-8"))["entries"]}

    def test_all_source_ids_preserved(self):
        self.assertEqual(len(self.rows),25)
        self.assertEqual({r["id"] for r in self.rows},{f"bayna_scan_v1_{i:03d}" for i in range(345,370)})
        for row in self.rows:
            self.assertEqual(row["source_provenance"]["scan_sha256"],SHA)
            self.assertEqual(row["source_provenance"]["printed_page"],16)
            self.assertEqual(row["visual_verification"]["examples_status"],"independently_authored_pending_separate_i3rab_review")

    def test_draft_quality_and_mirrors(self):
        notes=set()
        for x in self.rows:
            with self.subTest(x=x["arabic"]):
                self.assertGreaterEqual(len(x["grammar"]),2)
                self.assertGreaterEqual(len(x["examples_ar"]),2)
                self.assertGreaterEqual(len(x["collocations"]),1)
                self.assertNotIn(x["usage_note_ar"],notes)
                notes.add(x["usage_note_ar"])
                self.assertNotIn("هَذِهِ صِيغَةُ جَمْعٍ؛ وَتَعْيِينُ مُفْرَدِهَا",x["usage_note_ar"])
                self.assertEqual(x.get("editorial_review",{}).get("status"),"individual_arabic_draft_requires_independent_linguistic_review")
                values=[x["meaning_ar"],*x["additional_meanings_ar"],*x["grammar"],*x["collocations"],*x["examples_ar"],x["usage_note_ar"]]
                for item in values:self.assertEqual(item,unicodedata.normalize("NFC",item))
                v=self.review[unicodedata.normalize("NFC",x["arabic"])]
                self.assertEqual([y["ar"] for y in v["definition"]],[x["meaning_ar"],*x["additional_meanings_ar"]])
                self.assertEqual([y["ar"] for y in v["grammar"]],x["grammar"])
                self.assertEqual([y["ar"] for y in v["examples"]],x["examples_ar"])
                self.assertEqual(v["important"][0]["ar"],x["usage_note_ar"])
                self.assertEqual(v["visual_verification"],x["visual_verification"])

    def test_specific_morphology(self):
        a={x["arabic"]:x for x in self.rows}
        for w in ["أَصْدَقُ","أَصْعَبُ","أَصْغَرُ"]:
            self.assertIn("أَفْعَلُ"," ".join(a[w]["grammar"]))
            self.assertNotIn("أَفْعَلَ."," ".join(a[w]["grammar"]))
        self.assertIn("إِلَى"," ".join(a["أَصْغَى"]["collocations"]))
        self.assertIn("بَيْنَ"," ".join(a["أَصْلَحَ"]["collocations"]))
        self.assertIn(nfc("نَشْرِ"), a["أَصْدَرَ"]["usage_note_ar"])
        self.assertIn("صَفْرَاءُ"," ".join(a["أَصْفَرُ"]["grammar"]))
        self.assertTrue(any("أُصُولٌ" in g for g in a["أَصْلٌ"]["grammar"]))
        self.assertTrue(any("مَعْنَى" in g for g in a["أَصْحَابٌ"]["grammar"]))

if __name__=="__main__": unittest.main()
