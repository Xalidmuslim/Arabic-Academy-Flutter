#!/usr/bin/env python3
"""Printed page 14 / PDF 18: distinguish أَشْبَهَ (verb) and أَشْبَهُ (comparative).

These are independent lexemes; a successful test does not certify authored i3rab.
"""
import json
import unicodedata
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
DATA=ROOT/"assets/data"
SHA="a2d98cbf6cd309bac2ac072e09679260b1fa20dec0af4cfa7ddf82d7fae2f995"
MISMATCH="source_headword_mismatch_requires_relocation"
VERB_ID="bayna_print14_restored_20261119_001"
VERB_FILE="assets/data/entries_bayna_print14_restored_20261119.json"

def nfc(s):
    return unicodedata.normalize("NFC",s)

class PrintedPageFourteenCollation(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.scan=json.loads((DATA/"entries_bayna_scan_verified_20261112.json").read_text(encoding="utf-8"))["entries"]
        cls.manifest=json.loads((DATA/"corpus_manifest.json").read_text(encoding="utf-8"))["files"]
        cls.restored=json.loads((ROOT/VERB_FILE).read_text(encoding="utf-8"))["entries"]
        cls.review={nfc(x["arabic"]):x for x in json.loads((DATA/"reviewed_articles_v1.json").read_text(encoding="utf-8"))["entries"]}

    def test_existing_comparative_keeps_its_id_and_rejects_false_source_page(self):
        old=next(x for x in self.scan if x["id"]=="bayna_scan_v1_312")
        self.assertEqual(old["arabic"],"أَشْبَهُ")
        self.assertEqual(old["source_provenance"]["pdf_page"],18)
        self.assertEqual(old["source_provenance"]["text_status"],"unmatched_printed_lemma_source_page_18_relocation_required")
        self.assertEqual(old["visual_verification"]["status"],MISMATCH)
        self.assertEqual(old["visual_verification"]["printed_headword"],"أَشْبَهَ")
        self.assertEqual(self.review[nfc(old["arabic"])]["visual_verification"],old["visual_verification"])

    def test_new_printed_verb_has_distinct_stable_id(self):
        self.assertIn(VERB_FILE,self.manifest)
        self.assertEqual(len(self.restored),1)
        verb=self.restored[0]
        self.assertEqual(verb["id"],VERB_ID)
        self.assertEqual(verb["arabic"],"أَشْبَهَ")
        self.assertEqual(verb["book_references"],[])
        self.assertEqual((verb["source_provenance"]["pdf_page"],verb["source_provenance"]["printed_page"]),(18,14))
        self.assertEqual(verb["visual_verification"]["scan_sha256"],SHA)
        self.assertEqual(verb["visual_verification"]["examples_status"],"independently_authored_pending_separate_i3rab_review")
        self.assertIn("يُشْبِهُ"," ".join(verb["grammar"]))
        self.assertGreaterEqual(len(verb["examples_ar"]),2)
        self.assertEqual(self.review[nfc(verb["arabic"])]["visual_verification"],verb["visual_verification"])
        self.assertEqual([x["ar"] for x in self.review[nfc(verb["arabic"])]["examples"]],verb["examples_ar"])

    def test_all_old_ids_and_other_vocalized_headwords_preserved(self):
        ids=set()
        words=[]
        for path in self.manifest:
            for row in json.loads((ROOT/path).read_text(encoding="utf-8"))["entries"]:
                self.assertNotIn(row["id"],ids)
                ids.add(row["id"])
                words.append(nfc(row["arabic"]))
        for word in ("أَشْبَهُ","أَشْبَهَ"):
            self.assertEqual(words.count(nfc(word)),1)
        self.assertIn("bayna_scan_v1_312",ids)
        self.assertIn(VERB_ID,ids)

if __name__=="__main__":
    unittest.main()
