#!/usr/bin/env python3
"""Regression protection for the complete first printed page of the user scan.

This validates metadata, candidate coverage and preserved IDs. It is NOT an
OCR test or independent Arabic grammatical validation.
"""
import json
import re
import unicodedata
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUDIT = ROOT / "research/dictionary_sources/printed_page01_source_vs_corpus_20261117.json"
MANIFEST = ROOT / "assets/data/corpus_manifest.json"
SHA256 = "a2d98cbf6cd309bac2ac072e09679260b1fa20dec0af4cfa7ddf82d7fae2f995"
LEGACY_IDS = {
    "أَبٌ": "demo13",
    "أَبَاحَ": "bayna_scan_v1_001",
    "أَبْحَرَ": "bayna_scan_v1_004",
    "إِبْدَاعٌ": "l2u12_018",
    "أَبْدَعَ": "bayna_scan_v1_002",
    "أَبْدَى": "bayna_scan_v1_003",
    "إِبْرَةٌ": "editorial_textiles_20261025_009",
}


class PrintedPageOneMetadataTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.audit = json.loads(AUDIT.read_text(encoding="utf-8"))
        cls.rows = cls.audit["entries"]
        cls.manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))["files"]

    def test_every_printed_heading_appears_once_in_audit(self):
        self.assertEqual(len(self.rows), 21)
        words = [x["headword"] for x in self.rows]
        self.assertEqual(len(set(words)), 21)
        self.assertEqual(len([x for x in self.rows
                              if x["position"] == "العمود الأيمن"]), 11)
        self.assertEqual(len([x for x in self.rows
                              if x["position"] == "العمود الأيسر"]), 10)

    def test_metadata_never_claims_a_full_linguistic_proofread(self):
        self.assertEqual(self.audit["source"]["sha256"], SHA256)
        for row in self.rows:
            with self.subTest(word=row["headword"]):
                self.assertEqual((row["original_pdf_page"], row["printed_page"]), (5, 1))
                self.assertEqual(row["source_scan_sha256"], SHA256)
                self.assertIn("not_finally_proofread", row["source_evidence_status"])
                self.assertIn("pending", row["morphology_status"])
                self.assertIn("pending", row["authored_examples_i3rab_status"])
                self.assertEqual(unicodedata.normalize("NFC", row["headword"]), row["headword"])
                self.assertEqual(
                    unicodedata.normalize("NFC", row["source_sense_summary_ar"]),
                    row["source_sense_summary_ar"],
                )
                self.assertFalse(re.search(r"[A-Za-zА-Яа-яЁё]",
                                           row["source_sense_summary_ar"]))

    def test_historical_ids_are_preserved(self):
        audited = {x["headword"]: x for x in self.rows}
        for word, legacy_id in LEGACY_IDS.items():
            with self.subTest(word=word):
                self.assertTrue(audited[word]["corpus_existing"])
                self.assertEqual(audited[word]["corpus_canonical_id"], legacy_id)

        by_headword = {}
        for filename in self.manifest:
            part = json.loads((ROOT / filename).read_text(encoding="utf-8"))
            for entry in part.get("entries", []):
                by_headword.setdefault(entry["arabic"], entry["id"])
        for word, legacy_id in LEGACY_IDS.items():
            self.assertEqual(by_headword.get(word), legacy_id, word)

    def test_missing_candidates_are_tracked_not_falsely_published(self):
        initially_missing = [x for x in self.rows if not x["corpus_existing"]]
        self.assertEqual(len(initially_missing), 14)
        self.assertTrue(all(x["corpus_canonical_id"] is None
                            and not x["corpus_source_files"]
                            for x in initially_missing))
        # This is a dated audit snapshot, not a claim these forms must
        # remain absent forever: a future verified import should pass.


if __name__ == "__main__":
    unittest.main()
