#!/usr/bin/env python3
"""Source-image collation for print 9-13 / PDF 13-17.

Automated tests protect literal source attribution and old IDs; they do not
certify independently authored Arabic examples or their full i'rab.
"""
import json
import unicodedata
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "assets/data"
AUDIT_PATH = ROOT / "research/dictionary_sources/printed_pages09_13_visual_reconciliation_20261119.json"
SHA = "a2d98cbf6cd309bac2ac072e09679260b1fa20dec0af4cfa7ddf82d7fae2f995"
MISMATCH = "source_headword_mismatch_requires_relocation"


def nfc(text):
    return unicodedata.normalize("NFC", text)


class PrintedPagesNineToThirteen(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.audit = json.loads(AUDIT_PATH.read_text(encoding="utf-8"))
        cls.scan = json.loads((DATA / "entries_bayna_scan_verified_20261112.json").read_text(encoding="utf-8"))["entries"]
        cls.scan_by_id = {row["id"]: row for row in cls.scan}
        cls.manifest = json.loads((DATA / "corpus_manifest.json").read_text(encoding="utf-8"))["files"]
        cls.review = json.loads((DATA / "reviewed_articles_v1.json").read_text(encoding="utf-8"))["entries"]
        cls.review_by_word = {nfc(e["arabic"]): e for e in cls.review}

    def test_inventory_counts_and_original_provenance(self):
        self.assertEqual(self.audit["scan_sha256"], SHA)
        pages = self.audit["pages"]
        self.assertEqual([(p["pdf_page"], p["printed_page"]) for p in pages], [(n, n - 4) for n in range(13, 18)])
        self.assertEqual([p["printed_headings"] for p in pages], [29, 29, 26, 30, 26])
        self.assertEqual([p["previously_attributed_scan_cards"] for p in pages], [23, 27, 26, 29, 22])
        self.assertEqual([p["confirmed_source_matches"] for p in pages], [22, 26, 26, 28, 20])
        self.assertEqual([len(p["not_in_existing_scan_chunk"]) for p in pages], [7, 3, 0, 2, 6])
        self.assertEqual(sum(p["printed_headings"] for p in pages), 140)
        self.assertEqual(sum(p["previously_attributed_scan_cards"] for p in pages), 127)
        self.assertEqual(sum(p["confirmed_source_matches"] for p in pages), 122)
        self.assertEqual(sum(len(p["source_mismatch_ids"]) for p in pages), 5)
        self.assertEqual(sum(len(p["not_in_existing_scan_chunk"]) for p in pages), 18)
        for p in pages:
            matches = [e for e in self.scan if e["source_provenance"]["pdf_page"] == p["pdf_page"]]
            self.assertEqual(len(matches), p["previously_attributed_scan_cards"])
            for headword in p["not_in_existing_scan_chunk"]:
                self.assertEqual(headword, nfc(headword))
            for e in matches:
                self.assertEqual(e["source_provenance"]["scan_sha256"], SHA)

    def test_no_false_scan_attribution_for_five_vowel_sensitive_entries(self):
        self.assertEqual(len(self.audit["source_attribution_mismatches"]), 5)
        for bad in self.audit["source_attribution_mismatches"]:
            with self.subTest(entry_id=bad["id"]):
                e = self.scan_by_id[bad["id"]]
                self.assertEqual(nfc(e["arabic"]), nfc(bad["old_headword"]))
                self.assertEqual(e["source_provenance"]["pdf_page"], bad["pdf_page"])
                self.assertIn("unmatched_printed_lemma", e["source_provenance"]["text_status"])
                self.assertEqual(e["visual_verification"]["status"], MISMATCH)
                self.assertEqual(nfc(e["visual_verification"]["printed_headword"]), nfc(bad["printed_headword"]))
                self.assertEqual(e["visual_verification"]["examples_status"],
                                 "independently_authored_pending_separate_i3rab_review")
                self.assertNotEqual(nfc(e["arabic"]), nfc(bad["printed_headword"]))
                self.assertEqual(self.review_by_word[nfc(e["arabic"])]["visual_verification"],
                                 e["visual_verification"])

    def test_old_source_ids_unchanged_and_no_new_duplicates(self):
        self.assertEqual(len(self.manifest), 89)
        seen = set()
        for filename in self.manifest:
            for e in json.loads((ROOT / filename).read_text(encoding="utf-8"))["entries"]:
                self.assertNotIn(e["id"], seen)
                seen.add(e["id"])
        for bad in self.audit["source_attribution_mismatches"]:
            self.assertIn(bad["id"], seen)
        self.assertIn("bayna_scan_v1_179", seen)
        self.assertIn("bayna_scan_v1_259", seen)
        self.assertIn("bayna_scan_v1_276", seen)

    def test_ambiguity_is_recorded_without_allocating_new_ids(self):
        p13 = self.audit["pages"][-1]
        self.assertEqual(sum(nfc(x) == nfc("أَسْرَى") for x in p13["not_in_existing_scan_chunk"]), 1)
        self.assertIn("أَسْرَى", p13["not_in_existing_scan_chunk"])
        self.assertNotEqual(nfc("أَسْرٌ"), nfc("أُسَر"))
        self.assertNotEqual(nfc("إِسْكَانٌ"), nfc("إِسْكَاف"))
        self.assertNotEqual(nfc("أَرْبَعَةٌ"), nfc("أَرْبَع"))


if __name__ == "__main__":
    unittest.main()
