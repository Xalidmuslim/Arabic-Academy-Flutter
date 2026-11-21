#!/usr/bin/env python3
"""Deep editorial drafting for printed page 17 / PDF21.

The archived source ID 378 (أضحى) is NOT the printed أضحية. This test must not
mistake the old source attribution for a newly verified headword.
"""
import json
import unicodedata
import unittest
from pathlib import Path

DATA=Path(__file__).resolve().parents[1]/"assets"/"data"
norm=lambda s:unicodedata.normalize("NFC",s)

class DeepEditorialPrint17(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.scan=json.loads((DATA/"entries_bayna_scan_verified_20261112.json").read_text(encoding="utf-8"))["entries"]
        cls.page=[x for x in cls.scan if x["source_provenance"]["pdf_page"]==21]
        cls.review={norm(x["arabic"]):x for x in json.loads((DATA/"reviewed_articles_v1.json").read_text(encoding="utf-8"))["entries"]}

    def test_28_source_rows_27_eligible_drafts_one_mismatch(self):
        self.assertEqual(len(self.page),28)
        self.assertEqual({x["id"] for x in self.page},{f"bayna_scan_v1_{i:03d}" for i in range(370,398)})
        mismatch=next(x for x in self.page if x["id"]=="bayna_scan_v1_378")
        self.assertEqual(mismatch["arabic"],"أَضْحَى")
        self.assertEqual(mismatch["visual_verification"]["status"],"source_headword_mismatch_requires_relocation")
        self.assertEqual(mismatch["visual_verification"]["printed_headword"],"أُضْحِيَّةٌ")
        self.assertNotIn("editorial_review",mismatch)

    def test_individual_editing_mirrors_and_no_false_proofread(self):
        rows=[x for x in self.page if x["id"]!="bayna_scan_v1_378"]
        self.assertEqual(len(rows),27)
        notes=set()
        for x in rows:
            with self.subTest(head=x["arabic"]):
                self.assertGreaterEqual(len(x["grammar"]),2)
                self.assertGreaterEqual(len(x["examples_ar"]),2)
                self.assertGreaterEqual(len(x["collocations"]),1)
                self.assertNotIn(x["usage_note_ar"],notes)
                notes.add(x["usage_note_ar"])
                self.assertEqual(x["editorial_review"]["status"],"individual_arabic_draft_requires_independent_linguistic_review")
                self.assertEqual(x["visual_verification"]["examples_status"],"independently_authored_pending_separate_i3rab_review")
                fields=[x["meaning_ar"],*x["additional_meanings_ar"],*x["grammar"],*x["examples_ar"],*x["collocations"],x["usage_note_ar"]]
                for s in fields:self.assertEqual(s,norm(s))
                y=self.review[norm(x["arabic"])]
                self.assertEqual([z["ar"] for z in y["definition"]],[x["meaning_ar"],*x["additional_meanings_ar"]])
                self.assertEqual([z["ar"] for z in y["grammar"]],x["grammar"])
                self.assertEqual([z["ar"] for z in y["examples"]],x["examples_ar"])
                self.assertEqual(y["important"][0]["ar"],x["usage_note_ar"])
                self.assertEqual(y["visual_verification"],x["visual_verification"])

    def test_core_sense_differentiation(self):
        d={x["arabic"]:x for x in self.page}
        self.assertIn("مُضَافٌ إِلَيْهِ"," ".join(d["إِضَافَةٌ"]["grammar"]))
        self.assertIn("عَنِ"," ".join(d["أَضْرَبَ"]["collocations"]))
        self.assertIn("إِلَى"," ".join(d["أَضَافَ"]["collocations"]))
        self.assertIn("إِطَارَاتٌ"," ".join(d["إِطَارٌ"]["grammar"]))
        self.assertIn("أَطَاقَ"," ".join(d["أَطَاقَ"]["grammar"]))
        self.assertIn("أَطَاعَ"," ".join(d["أَطَاعَ"]["grammar"]))

if __name__=="__main__": unittest.main()
