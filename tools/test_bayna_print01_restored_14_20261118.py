#!/usr/bin/env python3
"""Protect scanned first-page restoration without asserting final Arabic proofreading."""
import json
import re
import unicodedata
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
SOURCE="assets/data/entries_bayna_print01_restored_20261118.json"
SHA="a2d98cbf6cd309bac2ac072e09679260b1fa20dec0af4cfa7ddf82d7fae2f995"
EXPECTED=["أَئِمَّةٌ","آبَاءٌ","إِبَاحَةٌ","أَبَادَ","آبَارٌ","أَبَارِيقُ","أَبَالِسَةٌ","أَبْجَدِيَّةٌ","أَبْحَاثٌ","أَبَدًا","أَبْدَانٌ","إِبَرٌ","أَبْرَدَ","أَبْرَزَ"]
EXPECTED_OLD={"أَبٌ":"demo13","أَبَاحَ":"bayna_scan_v1_001","أَبْحَرَ":"bayna_scan_v1_004","إِبْدَاعٌ":"l2u12_018","أَبْدَعَ":"bayna_scan_v1_002","أَبْدَى":"bayna_scan_v1_003","إِبْرَةٌ":"editorial_textiles_20261025_009"}

def nfc(s): return unicodedata.normalize("NFC",s)

class RestoredPageOneTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.part=json.loads((ROOT/SOURCE).read_text(encoding="utf-8"))["entries"]
        cls.manifest=json.loads((ROOT/"assets/data/corpus_manifest.json").read_text(encoding="utf-8"))["files"]
        cls.review=json.loads((ROOT/"assets/data/reviewed_articles_v1.json").read_text(encoding="utf-8"))["entries"]
    def test_restored_fourteen_and_manifest(self):
        self.assertIn(SOURCE,self.manifest)
        self.assertEqual(len(self.part),14)
        self.assertEqual({nfc(x["arabic"]) for x in self.part},{nfc(x) for x in EXPECTED})
    def test_no_old_ids_changed_and_no_unicode_duplicates(self):
        seen={}
        all_ids=set()
        for filename in self.manifest:
            entries=json.loads((ROOT/filename).read_text(encoding="utf-8"))["entries"]
            for entry in entries:
                if entry["id"] in all_ids:
                    self.fail("Repeated raw ID "+entry["id"])
                all_ids.add(entry["id"])
                seen.setdefault(nfc(entry["arabic"]),entry["id"])
        for lemma,wid in EXPECTED_OLD.items():
            self.assertEqual(seen[nfc(lemma)],wid)
        for row in self.part:
            self.assertEqual(seen[nfc(row["arabic"])],row["id"])
    def test_provenance_and_arabic_only(self):
        for r in self.part:
            with self.subTest(lemma=r["arabic"]):
                self.assertEqual(r["source_provenance"]["scan_sha256"],SHA)
                self.assertEqual((r["source_provenance"]["pdf_page"],r["source_provenance"]["printed_page"]),(5,1))
                self.assertEqual(r["visual_verification"]["examples_status"],"independently_authored_pending_separate_i3rab_review")
                self.assertEqual(r["book_references"],[])
                self.assertGreaterEqual(len(r["examples_ar"]),2)
                self.assertGreaterEqual(len(r["grammar"]),2)
                for s in [r["arabic"],r["meaning_ar"],r["usage_note_ar"],*r["additional_meanings_ar"],*r["grammar"],*r["collocations"],*r["synonyms"],*r["antonyms"],*r["examples_ar"]]:
                    self.assertEqual(s,nfc(s))
                    self.assertFalse(re.search(r"[A-Za-z\u0400-\u04ff]",s),s)
    def test_visible_reviewed_articles_keep_independent_example_status(self):
        byword={nfc(x["arabic"]):x for x in self.review}
        self.assertEqual(len(byword),len(self.review))
        for row in self.part:
            a=byword[nfc(row["arabic"])]
            self.assertEqual(a["editorial_batch"],"2026-11-18-original-print-page01-restored-14")
            self.assertEqual([f["ar"] for f in a["examples"]],row["examples_ar"])
            self.assertEqual(a["visual_verification"]["examples_status"],"independently_authored_pending_separate_i3rab_review")

if __name__=="__main__": unittest.main()
