#!/usr/bin/env python3
"""Verify source-image vowel collations from printed pages 4-7 (PDF pages 8-11).

The visual collation confirms source-visible letters/harakat and the exact
page of origin. The novel example sentences are NOT a verbatim source copy.
"""
import json
import unittest
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "assets/data"
SHA256 = "a2d98cbf6cd309bac2ac072e09679260b1fa20dec0af4cfa7ddf82d7fae2f995"
STATUS = "printed_lemma_visible_vowels_checked_pedagogical_endings_not_literal_source"
COUNTS = {8: 20, 9: 18, 10: 29, 11: 20}
VOWEL_CRITICAL = {
    "آخِرٌ": 11,
    "آخَرُ": 11,
    "أَحَلَّ": 10,
    "أَخَلَّ": 11,
    "أَحَسَّ": 10,
    "أَحَدٌ": 9,
    "أَحَدَ عَشَرَ": 9,
    "أَخْرَسُ": 11,
    "أَجَرَ": 8,
    "أَجْرَى": 8,
}


def canon(word):
    return unicodedata.normalize("NFC", word)


class OriginalPrintedPagesFourToSeven(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = json.loads(
            (DATA / "entries_bayna_scan_verified_20261112.json").read_text(encoding="utf-8")
        )["entries"]
        cls.selected = [e for e in cls.source if e["source_provenance"]["pdf_page"] in COUNTS]
        cls.overlay = {
            canon(e["arabic"]): e for e in json.loads(
                (DATA / "reviewed_articles_v1.json").read_text(encoding="utf-8")
            )["entries"]
        }

    def test_no_omissions_in_this_previously_added_batch(self):
        self.assertEqual(len(self.selected), 87)
        for p, count in COUNTS.items():
            self.assertEqual(len([r for r in self.selected if r["source_provenance"]["pdf_page"] == p]), count)

    def test_original_image_provenance_is_per_lemma_not_just_per_batch(self):
        for source in self.selected:
            with self.subTest(word=source["arabic"]):
                evidence = source["visual_verification"]
                p = source["source_provenance"]["pdf_page"]
                self.assertEqual(evidence["scan_sha256"], SHA256)
                self.assertEqual(evidence["pdf_page"], p)
                self.assertEqual(evidence["printed_page"], p - 4)
                self.assertEqual(evidence["status"], STATUS)
                self.assertEqual(evidence["examples_status"], "independently_authored_pending_separate_i3rab_review")
                overlay = self.overlay[canon(source["arabic"])]
                self.assertEqual(overlay["visual_verification"], evidence)

    def test_vowel_sensitive_words_retain_distinct_forms(self):
        selected = {canon(e["arabic"]): e for e in self.selected}
        for word, page in VOWEL_CRITICAL.items():
            with self.subTest(word=word):
                self.assertIn(canon(word), selected)
                self.assertEqual(selected[canon(word)]["source_provenance"]["pdf_page"], page)
        self.assertNotEqual(canon("آخِرٌ"), canon("آخَرُ"))
        self.assertNotEqual(canon("أَحَلَّ"), canon("أَخَلَّ"))


if __name__ == "__main__":
    unittest.main()
