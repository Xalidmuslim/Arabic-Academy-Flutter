#!/usr/bin/env python3
"""Regression for source-image vs exact-lemma collation, printed pages 8-11.

This is a provenance contract, not OCR or a substitute for an Arabic linguist.
"""
import json
import unittest
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "assets/data"
SHA = "a2d98cbf6cd309bac2ac072e09679260b1fa20dec0af4cfa7ddf82d7fae2f995"
PAGE_COUNTS = {12: 25, 13: 23, 14: 27, 15: 26}
PRINT_STATUS = "printed_lemma_visible_vowels_checked_pedagogical_endings_not_literal_source"
MISMATCH_STATUS = "source_headword_mismatch_requires_relocation"
MISMATCH_LEMMA = "أَرْذَالٌ"
MISMATCH_PRINTED = "أَرْذَل"


def key(s):
    return unicodedata.normalize("NFC", s)


class PrintedPagesEightToEleven(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = json.loads(
            (DATA / "entries_bayna_scan_verified_20261112.json").read_text(encoding="utf8")
        )["entries"]
        cls.prefix = [e for e in cls.source if e["source_provenance"]["pdf_page"] in PAGE_COUNTS]
        cls.overlays = {key(e["arabic"]): e for e in json.loads(
            (DATA / "reviewed_articles_v1.json").read_text(encoding="utf8")
        )["entries"]}

    def test_the_batch_has_101_existing_lemmas_in_original_order(self):
        self.assertEqual(len(self.prefix), 101)
        self.assertEqual(len({key(e["arabic"]) for e in self.prefix}), 101)
        for page, count in PAGE_COUNTS.items():
            with self.subTest(pdf_page=page):
                self.assertEqual(len([e for e in self.prefix
                                      if e["source_provenance"]["pdf_page"] == page]), count)

    def test_original_image_evidence_does_not_claim_author_written_examples_are_from_book(self):
        for e in self.prefix:
            with self.subTest(lemma=e["arabic"]):
                proof = e["visual_verification"]
                self.assertEqual(proof["scan_sha256"], SHA)
                self.assertEqual(proof["pdf_page"], e["source_provenance"]["pdf_page"])
                self.assertEqual(proof["printed_page"], proof["pdf_page"] - 4)
                self.assertEqual(proof["examples_status"],
                                 "independently_authored_pending_separate_i3rab_review")
                if key(e["arabic"]) == key(MISMATCH_LEMMA):
                    self.assertEqual(proof["status"], MISMATCH_STATUS)
                    self.assertEqual(proof["printed_headword"], MISMATCH_PRINTED)
                    self.assertNotEqual(proof["printed_headword"], e["arabic"])
                else:
                    self.assertEqual(proof["status"], PRINT_STATUS)
                self.assertEqual(self.overlays[key(e["arabic"])]["visual_verification"], proof)

    def test_mismatch_lemma_is_not_silently_changed_or_presented_as_verified(self):
        e = next(x for x in self.prefix if key(x["arabic"]) == key(MISMATCH_LEMMA))
        self.assertEqual(e["id"], "bayna_scan_v1_204")
        self.assertEqual(e["arabic"], MISMATCH_LEMMA)
        self.assertIn("أَرْذَل", e["visual_verification"]["note"])
        self.assertIn("أَرْذَال", e["visual_verification"]["note"])


if __name__ == "__main__":
    unittest.main()
