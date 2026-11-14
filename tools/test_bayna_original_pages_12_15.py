#!/usr/bin/env python3
"""Source-image audit contract: original printed pages 12–15 (PDF 16–19).

This checks documented visual evidence and preserves original lexical IDs.
It does not certify independently authored example sentences or fully
reproduce a human comparison with the printed page.
"""
import json
import unicodedata
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
DATA=ROOT/"assets/data"
SHA="a2d98cbf6cd309bac2ac072e09679260b1fa20dec0af4cfa7ddf82d7fae2f995"
COUNTS={16:29,17:22,18:28,19:30}
OK_STATUS="print_headword_and_visible_vowels_compared_examples_unchecked"
MISMATCH_STATUS="source_headword_mismatch_requires_relocation"

def canon(s):
    return unicodedata.normalize("NFC",s)

class OriginalPrintedPages12To15(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rows=json.loads((DATA/"entries_bayna_scan_verified_20261112.json").read_text(encoding="utf-8"))["entries"]
        cls.subset=[e for e in cls.rows if e["source_provenance"]["pdf_page"] in COUNTS]
        cls.overlays={canon(e["arabic"]):e for e in json.loads((DATA/"reviewed_articles_v1.json").read_text(encoding="utf-8"))["entries"]}

    def test_109_source_records_have_exact_page_provenance(self):
        self.assertEqual(len(self.subset),109)
        self.assertEqual(len({canon(e["arabic"]) for e in self.subset}),109)
        for p,count in COUNTS.items():
            self.assertEqual(sum(e["source_provenance"]["pdf_page"]==p for e in self.subset),count)

    def test_visual_status_per_entry_and_honest_example_scope(self):
        for e in self.subset:
            with self.subTest(lemma=e["arabic"]):
                proof=e["visual_verification"]
                page=e["source_provenance"]["pdf_page"]
                self.assertEqual(proof["scan_sha256"],SHA)
                self.assertEqual(proof["pdf_page"],page)
                self.assertEqual(proof["printed_page"],page-4)
                self.assertEqual(proof["examples_status"],"independently_authored_pending_separate_i3rab_review")
                if e["arabic"]=="أَسْمَعَ":
                    self.assertEqual(proof["status"],MISMATCH_STATUS)
                    self.assertEqual(proof["printed_headword"],"أَسْمَعُ")
                    self.assertIn("أَسْمَع",proof["note"])
                    self.assertEqual(e["source_provenance"]["text_status"],"unmatched_printed_lemma_source_page_17_relocation_required")
                else:
                    self.assertEqual(proof["status"],OK_STATUS)
                self.assertEqual(self.overlays[canon(e["arabic"])]["visual_verification"],proof)

    def test_meaning_and_id_of_unmatched_verb_are_not_overwritten(self):
        row=next(e for e in self.subset if e["arabic"]=="أَسْمَعَ")
        self.assertEqual(row["id"],"bayna_scan_v1_286")
        self.assertIn("يُسْمِعُ",row["grammar"][0])
        self.assertIn("إِسْمَاعٌ",row["grammar"][0])
        self.assertIn("جَعَلَ",row["meaning_ar"])

    def test_vocalized_homographs_not_collapsed(self):
        headwords={canon(e["arabic"]) for e in self.subset}
        for w in ("أُسْقُفٌ","أَسْقُفٌ","أَشْهَرُ","أَشْهَرَ","أَسْرَى"):
            self.assertIn(canon(w),headwords)
        self.assertNotEqual(canon("أُسْقُفٌ"),canon("أَسْقُفٌ"))
        self.assertNotEqual(canon("أَشْهَرُ"),canon("أَشْهَرَ"))
        sir=next(e for e in self.subset if e["arabic"]=="أَسْرَى")
        self.assertTrue(any("جَمْعًا لِأَسِيرٍ" in g for g in sir["grammar"]))

if __name__=="__main__":
    unittest.main()
