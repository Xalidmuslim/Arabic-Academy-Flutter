#!/usr/bin/env python3
"""Regression for conservative editing of scanned pages 4-8.

Visual headword evidence, application IDs and Arabic editorial contents are
separate checks. Automated assertions do not certify semantic or i3rab quality.
"""
import json
import unicodedata
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
DATA=ROOT/"assets/data"
SHA="a2d98cbf6cd309bac2ac072e09679260b1fa20dec0af4cfa7ddf82d7fae2f995"
MISMATCH="source_headword_mismatch_requires_relocation"
GENERIC="يُفْهَمُ مَعْنَى الْكَلِمَةِ مِنْ سِيَاقِ الْجُمْلَةِ."

class PagesFourEightDeepReview(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original=json.loads((DATA/"entries_bayna_scan_verified_20261112.json").read_text(encoding="utf8"))["entries"]
        cls.overlay=json.loads((DATA/"reviewed_articles_v1.json").read_text(encoding="utf8"))["entries"]
        cls.manifest=json.loads((DATA/"corpus_manifest.json").read_text(encoding="utf8"))["files"]
        cls.inventory=json.loads((ROOT/"research/dictionary_sources/printed_pages04_08_visual_inventory_20261118.json").read_text(encoding="utf8"))
        cls.selected=[e for e in cls.original if 8<=e["source_provenance"]["pdf_page"]<=12]
        cls.reviewed={unicodedata.normalize("NFC",e["arabic"]):e for e in cls.overlay}

    def test_source_mismatch_does_not_relabel_old_id(self):
        old=next(x for x in self.selected if x["id"]=="bayna_scan_v1_047")
        self.assertEqual(old["arabic"],"أَجَرَ")
        self.assertEqual(old["source_provenance"]["text_status"],MISMATCH)
        self.assertEqual(old["visual_verification"]["status"],MISMATCH)
        self.assertEqual(self.reviewed[old["arabic"]]["visual_verification"],old["visual_verification"])
        print4=self.inventory["pages"][0]
        self.assertEqual(print4["headings"][0]["headword"],"أَجَّرَ")
        self.assertEqual(print4["headings"][0]["source_match_status"],"printed_headword_missing_from_existing_scan_chunk")
        self.assertIsNone(print4["headings"][0]["existing_scan_id"])

    def test_original_printed_form_is_new_distinct_entry(self):
        fname="assets/data/entries_bayna_print04_corrected_20261119.json"
        self.assertIn(fname,self.manifest)
        arr=json.loads((ROOT/fname).read_text(encoding="utf8"))["entries"]
        self.assertEqual(len(arr),1)
        e=arr[0]
        self.assertEqual(e["id"],"bayna_print04_corrected_20261119_001")
        self.assertEqual(e["arabic"],"أَجَّرَ")
        self.assertEqual(e["source_provenance"]["pdf_page"],8)
        self.assertEqual(e["source_provenance"]["printed_page"],4)
        self.assertEqual(e["source_provenance"]["scan_sha256"],SHA)
        self.assertEqual(e["visual_verification"]["examples_status"],"independently_authored_pending_separate_i3rab_review")
        self.assertIn(e["arabic"],self.reviewed)
        self.assertNotEqual(e["id"],next(x for x in self.selected if x["arabic"]=="أَجَرَ")["id"])

    def test_111_preserved_entries_get_individual_clarifications_and_context(self):
        self.assertEqual(len(self.selected),112)
        valid=[e for e in self.selected if e["id"]!="bayna_scan_v1_047"]
        self.assertEqual(len(valid),111)
        remarks=set()
        for e in valid:
            with self.subTest(word=e["arabic"]):
                self.assertGreaterEqual(len(e["examples_ar"]),2)
                self.assertGreaterEqual(len(e["collocations"]),1)
                self.assertGreaterEqual(len(e["grammar"]),2)
                self.assertNotEqual(e["usage_note_ar"],GENERIC)
                self.assertNotIn(e["usage_note_ar"],remarks)
                remarks.add(e["usage_note_ar"])
                self.assertEqual(e["visual_verification"]["examples_status"],
                                 "independently_authored_pending_separate_i3rab_review")
                self.assertEqual(e["editorial_review"]["status"],
                                 "individual_arabic_draft_requires_independent_linguistic_review")
                ov=self.reviewed[unicodedata.normalize("NFC",e["arabic"])]
                self.assertEqual(ov["examples"],[{"ar":s} for s in e["examples_ar"]])
                self.assertEqual(ov["grammar"],[{"ar":s} for s in e["grammar"]])
                self.assertEqual(ov["important"][0],{"ar":e["usage_note_ar"]})
                self.assertGreaterEqual(len(ov["important"]),1)
                self.assertEqual(ov["visual_verification"],e["visual_verification"])

    def test_corpus_article_ids_and_normalized_headwords(self):
        self.assertEqual(len(self.reviewed),668)
        all_ids=[]
        all_words=[]
        for filename in self.manifest:
            for e in json.loads((ROOT/filename).read_text(encoding="utf8"))["entries"]:
                all_ids.append(e["id"])
                all_words.append(unicodedata.normalize("NFC",e["arabic"]))
        self.assertEqual(len(all_ids),len(set(all_ids)))
        self.assertEqual(len(all_words),len(set(all_words)))
        self.assertIn("bayna_scan_v1_047",all_ids)

if __name__=="__main__":
    unittest.main()
