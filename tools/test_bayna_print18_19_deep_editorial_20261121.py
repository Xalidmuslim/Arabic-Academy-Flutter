#!/usr/bin/env python3
"""Printed pages 18-19 / PDF22-23: 53 independently authored Arabic drafts."""
import json
import unicodedata
import unittest
from pathlib import Path
D=Path(__file__).resolve().parents[1]/"assets"/"data"
nfc=lambda s:unicodedata.normalize("NFC",s)

class DeepEditorialPrint18And19(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.scan=json.loads((D/"entries_bayna_scan_verified_20261112.json").read_text(encoding="utf-8"))["entries"]
        cls.rows=[x for x in cls.scan if x["source_provenance"]["pdf_page"] in (22,23)]
        cls.ov={nfc(x["arabic"]):x for x in json.loads((D/"reviewed_articles_v1.json").read_text(encoding="utf-8"))["entries"]}

    def test_no_id_loss_and_exact_source_pages(self):
        self.assertEqual(len(self.rows),53)
        self.assertEqual({x["id"] for x in self.rows},{f"bayna_scan_v1_{i:03d}" for i in range(398,451)})
        self.assertEqual({p:sum(x["source_provenance"]["pdf_page"]==p for x in self.rows) for p in (22,23)}, {22:22,23:31})
        for x in self.rows:
            self.assertEqual(x["source_provenance"]["printed_page"],x["source_provenance"]["pdf_page"]-4)
            self.assertEqual(x["visual_verification"]["examples_status"],"independently_authored_pending_separate_i3rab_review")

    def test_individual_drafts_and_mirrors_no_bogus_certification(self):
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
                parts=[x["meaning_ar"],*x["additional_meanings_ar"],*x["grammar"],*x["collocations"],*x["examples_ar"],x["usage_note_ar"]]
                for part in parts:self.assertEqual(part,nfc(part))
                y=self.ov[nfc(x["arabic"])]
                self.assertEqual([z["ar"] for z in y["definition"]],[x["meaning_ar"],*x["additional_meanings_ar"]])
                self.assertEqual([z["ar"] for z in y["grammar"]],x["grammar"])
                self.assertEqual([z["ar"] for z in y["examples"]],x["examples_ar"])
                self.assertEqual(y["important"][0]["ar"],x["usage_note_ar"])
                self.assertEqual(y["visual_verification"],x["visual_verification"])

    def test_distinct_senses_and_grammar_traps_preserved(self):
        a={x["arabic"]:x for x in self.rows}
        self.assertIn("عَرَضٍ"," ".join(a["أَعْرَاضٌ"]["grammar"]))
        self.assertIn("عِرْضٍ"," ".join(a["أَعْرَاضٌ"]["grammar"]))
        self.assertIn("عَلَى"," ".join(a["أَطْلَعَ"]["collocations"]))
        self.assertIn("عَنْ"," ".join(a["أَعْرَبَ"]["collocations"]))
        self.assertIn("أَفْعَلُ"," ".join(a["أَطْهَرُ"]["grammar"]))
        self.assertIn("أَفْعَلُ"," ".join(a["أَعَزُّ"]["grammar"]))
        self.assertIn("سَرَاحَ"," ".join(a["أَطْلَقَ"]["collocations"]))
        self.assertEqual(a["إِعْجَازُ الْقُرْآنِ"]["arabic"],"إِعْجَازُ الْقُرْآنِ")

if __name__=="__main__": unittest.main()
