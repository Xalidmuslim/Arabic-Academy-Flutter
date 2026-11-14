#!/usr/bin/env python3
"""Regression gate for word-by-word visual checks beginning at printed page 1.

This test validates the *documented human collation records*, not the pixels of
the original PDF. Newly composed pedagogical prose is a separate audit scope.
"""
import json
import unittest
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "assets/data"
EXPECTED_SHA256 = "a2d98cbf6cd309bac2ac072e09679260b1fa20dec0af4cfa7ddf82d7fae2f995"
STATUS = "printed_lemma_visible_vowels_checked_pedagogical_endings_not_literal_source"
PAGE_COUNTS = {5: 4, 6: 16, 7: 26}
KNOWN_INFLECTIONS = {
    "أَبَاحَ": ("يُبِيحُ", "إِبَاحَةٌ"),
    "أَبْدَعَ": ("يُبْدِعُ", "إِبْدَاعٌ"),
    "أَبْدَى": ("يُبْدِي", "إِبْدَاءٌ"),
    "أَبْحَرَ": ("يُبْحِرُ", "إِبْحَارٌ"),
    "أَبْصَرَ": ("يُبْصِرُ", "إِبْصَارٌ"),
    "أَبْطَأَ": ("يُبْطِئُ", "إِبْطَاءٌ"),
    "أَبْغَضَ": ("يُبْغِضُ", "إِبْغَاضٌ"),
    "أَبْقَى": ("يُبْقِي", "إِبْقَاءٌ"),
    "أَبَى": ("يَأْبَى", "إِبَاءٌ"),
    "أَتْقَنَ": ("يُتْقِنُ", "إِتْقَانٌ"),
    "أَتَى": ("يَأْتِي", "إِتْيَانٌ"),
}
AUGMENTED = {
    "أَبَاحَ": "ب ـ و ـ ح",
    "أَبْدَعَ": "ب ـ د ـ ع",
    "أَبْدَى": "ب ـ د ـ و",
    "أَبْحَرَ": "ب ـ ح ـ ر",
    "أَبْصَرَ": "ب ـ ص ـ ر",
    "أَبْطَأَ": "ب ـ ط ـ أ",
    "أَبْغَضَ": "ب ـ غ ـ ض",
    "أَبْقَى": "ب ـ ق ـ ي",
    "أَتْقَنَ": "ت ـ ق ـ ن",
}


def norm(word):
    return unicodedata.normalize("NFC", word)


class FirstPrintedPagesOriginalAudit(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = json.loads(
            (DATA / "entries_bayna_scan_verified_20261112.json").read_text(encoding="utf-8")
        )["entries"]
        cls.prefix = [
            x for x in cls.source if x["source_provenance"]["pdf_page"] in PAGE_COUNTS
        ]
        cls.overlay = {
            norm(x["arabic"]): x for x in json.loads(
                (DATA / "reviewed_articles_v1.json").read_text(encoding="utf-8")
            )["entries"]
        }

    def test_first_three_printed_pages_have_all_original_checked_entries(self):
        self.assertEqual(len(self.prefix), sum(PAGE_COUNTS.values()))
        for page, expected in PAGE_COUNTS.items():
            self.assertEqual(
                len([x for x in self.prefix if x["source_provenance"]["pdf_page"] == page]),
                expected,
            )
        self.assertEqual(len({norm(x["arabic"]) for x in self.prefix}), len(self.prefix))

    def test_individual_word_has_explicit_original_page_proofread_record(self):
        for x in self.prefix:
            with self.subTest(lemma=x["arabic"]):
                page = x["source_provenance"]["pdf_page"]
                evidence = x["visual_verification"]
                self.assertEqual(evidence["scan_sha256"], EXPECTED_SHA256)
                self.assertEqual(evidence["pdf_page"], page)
                self.assertEqual(evidence["printed_page"], page - 4)
                self.assertEqual(evidence["status"], STATUS)
                self.assertEqual(evidence["examples_status"], "independently_authored_pending_separate_i3rab_review")
                y = self.overlay[norm(x["arabic"])]
                self.assertEqual(y["visual_verification"]["status"], STATUS)
                self.assertEqual(y["visual_verification"]["pdf_page"], page)

    def test_first_original_page_conjugations_and_verbal_nouns_are_retained(self):
        for lemma, (present, masdar) in KNOWN_INFLECTIONS.items():
            with self.subTest(lemma=lemma):
                row = next(x for x in self.prefix if norm(x["arabic"]) == norm(lemma))
                grammar = " ".join(row["grammar"])
                self.assertIn(present, grammar)
                self.assertIn(masdar, grammar)
                self.assertEqual(
                    [x["grammar"] for x in [row]][0],
                    [f["ar"] for f in self.overlay[norm(lemma)]["grammar"]],
                )

    def test_af3ala_is_identified_as_augmented_triliteral_not_quadriliteral_root(self):
        for lemma, root in AUGMENTED.items():
            with self.subTest(lemma=lemma):
                row = next(x for x in self.prefix if norm(x["arabic"]) == norm(lemma))
                detail = row["grammar"][0]
                self.assertIn("ثُلَاثِيٌّ مَزِيدٌ", detail)
                self.assertIn(root, detail)


if __name__ == "__main__":
    unittest.main()
