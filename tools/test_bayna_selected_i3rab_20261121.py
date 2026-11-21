#!/usr/bin/env python3
"""Separate grammatical proofreading from original print-headword collation."""
import json
import unicodedata
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
DATA=ROOT/"assets/data"
AUDIT=ROOT/"research/dictionary_sources/selected_i3rab_print16_19_20261121.json"
nfc=lambda x:unicodedata.normalize("NFC",x)

class SelectedIrabIndependentSecondPass(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.all=json.loads((DATA/"entries_bayna_scan_verified_20261112.json").read_text(encoding="utf-8"))["entries"]
        cls.byid={x["id"]:x for x in cls.all}
        cls.review={nfc(x["arabic"]):x for x in json.loads((DATA/"reviewed_articles_v1.json").read_text(encoding="utf-8"))["entries"]}
        cls.report=json.loads(AUDIT.read_text(encoding="utf-8"))

    def test_targeted_corrections_of_verified_errors(self):
        yellow=self.byid["bayna_scan_v1_357"]
        self.assertTrue(any(nfc("اِشْتَرَتِ الْأُمُّ") in x for x in yellow["examples_ar"]))
        # Corrected example contains the full sentence, not only a phrase.
        self.assertIn(nfc("اِشْتَرَتِ الْأُمُّ وَرْدَةً صَفْرَاءَ لِلْبَيْتِ."),yellow["examples_ar"])
        self.assertIn(nfc("أَفْعَلُ"),yellow["usage_note_ar"])
        self.assertNotIn(nfc("وَزْنِ «أَفْعَلَ»"),yellow["usage_note_ar"])
        self.assertEqual(self.review[nfc(yellow["arabic"])]["examples"][-1]["ar"],
                         yellow["examples_ar"][-1])

    def test_twelve_individual_authored_examples_reviewed_without_fake_print_certification(self):
        items=self.report["examples"]
        self.assertEqual(len(items),12)
        self.assertEqual(len({x["source_entry_id"] for x in items}),12)
        for x in items:
            with self.subTest(x=x["source_entry_id"]):
                entry=self.byid[x["source_entry_id"]]
                self.assertIn(x["example_ar"],entry["examples_ar"])
                self.assertEqual(entry["visual_verification"]["examples_status"],
                                 "independently_authored_pending_separate_i3rab_review")
                self.assertEqual(entry["editorial_review"]["status"],
                                 "individual_arabic_draft_requires_independent_linguistic_review")
                self.assertGreaterEqual(len(x["i3rab_ar"]),2)
                for phrase in [x["example_ar"],*x["i3rab_ar"]]:
                    self.assertEqual(phrase,nfc(phrase))
                    self.assertFalse(any('А'<=ch<='я' for ch in phrase))
        self.assertFalse(self.report["certifies_all_105_examples"])
        self.assertFalse(self.report["certifies_all_article_grammar"])

if __name__=="__main__": unittest.main()
