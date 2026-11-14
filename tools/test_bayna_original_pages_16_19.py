#!/usr/bin/env python3
"""Evidence and meaning regression for original printed pages 16–19.

Source-page checks protect exact printed headword matches. Arabic sentences
created for the app are independent and require their own grammar review.
"""
import json
import unicodedata
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "assets/data"
PAGE_COUNTS = {20: 25, 21: 28, 22: 22, 23: 31}
SCAN_SHA = "a2d98cbf6cd309bac2ac072e09679260b1fa20dec0af4cfa7ddf82d7fae2f995"
SCAN_STATUS = "printed_lemma_visible_vowels_checked_pedagogical_endings_not_literal_source"


def norm(w):
    return unicodedata.normalize("NFC", w)


class PrintPages16To19(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = json.loads(
            (DATA / "entries_bayna_scan_verified_20261112.json").read_text(encoding="utf-8")
        )["entries"]
        cls.batch = [e for e in cls.source if e["source_provenance"]["pdf_page"] in PAGE_COUNTS]
        cls.byword = {norm(e["arabic"]): e for e in cls.batch}
        cls.review = {
            norm(e["arabic"]): e for e in json.loads(
                (DATA / "reviewed_articles_v1.json").read_text(encoding="utf-8")
            )["entries"]
        }

    def test_source_page_counts_and_all_existing_ids_preserved(self):
        self.assertEqual(len(self.batch), 106)
        self.assertEqual(len(self.byword), len(self.batch))
        for page, count in PAGE_COUNTS.items():
            with self.subTest(pdf_page=page):
                records = [e for e in self.batch if e["source_provenance"]["pdf_page"] == page]
                self.assertEqual(len(records), count)
                for e in records:
                    self.assertTrue(e["id"].startswith("bayna_scan_v1_"))

    def test_printed_headword_evidence_and_independent_example_status(self):
        for e in self.batch:
            with self.subTest(lemma=e["arabic"]):
                proof = e["visual_verification"]
                self.assertEqual(proof["scan_sha256"], SCAN_SHA)
                self.assertEqual(proof["pdf_page"], e["source_provenance"]["pdf_page"])
                self.assertEqual(proof["printed_page"], proof["pdf_page"]-4)
                self.assertEqual(proof["status"], SCAN_STATUS)
                self.assertEqual(
                    proof["examples_status"],
                    "independently_authored_pending_separate_i3rab_review",
                )
                self.assertEqual(self.review[norm(e["arabic"])]["visual_verification"], proof)

    def test_original_contains_distinct_comparative_aslah_not_just_verb(self):
        e = self.byword[norm("أَصْلَحَ")]
        self.assertIn("أَصْلَحُ", e["visual_verification"]["uncovered_source_headwords"])

    def test_two_printed_arad_plural_senses_not_silently_collapsed(self):
        e = self.byword[norm("أَعْرَاضٌ")]
        gr = " ".join(e["grammar"])
        self.assertIn("عَرَضٍ", gr)
        self.assertIn("عِرْضٍ", gr)
        self.assertTrue(any("عِرْضٍ" in v for v in e["additional_meanings_ar"]))
        overlay = self.review[norm(e["arabic"])]
        self.assertTrue(any("عِرْضٍ" in x["ar"] for x in overlay["definition"]))

    def test_atlaqa_has_three_verb_senses_and_separate_adverbial_masdar(self):
        e = self.byword[norm("أَطْلَقَ")]
        all_senses = " ".join([e["meaning_ar"], *e["additional_meanings_ar"]])
        for term in ["الْقَيْدِ", "الرَّصَاصَ", "اسْمًا"]:
            with self.subTest(term=term):
                self.assertIn(term, all_senses)
        self.assertIn("إِطْلَاقًا", e["usage_note_ar"])
        overlay = self.review[norm("أَطْلَقَ")]
        self.assertGreaterEqual(len(overlay["definition"]), 3)
        self.assertIn("إِطْلَاقًا", " ".join(x["ar"] for x in overlay["important"]))

    def test_asgha_misspelled_verb_has_been_corrected(self):
        article = self.byword[norm("أَصْغَى")]
        self.assertIn("وَوَجَّهَ", article["meaning_ar"])
        self.assertNotIn("أَوْجَهَ", article["meaning_ar"])
        self.assertEqual(
            self.review[norm("أَصْغَى")]["definition"][0]["ar"],
            article["meaning_ar"]
        )

    def test_asil_multiple_printed_meanings_and_example_agree(self):
        article = self.byword[norm("أَصِيلٌ")]
        all_senses = " ".join([article["meaning_ar"], *article["additional_meanings_ar"]])
        self.assertIn("مُبْتَكَرٌ", all_senses)
        self.assertIn("جَوْدَةٍ", all_senses)
        self.assertTrue(any("مُبْتَكَرٌ" in d["ar"] for d in
                            self.review[norm("أَصِيلٌ")]["definition"]))

    def test_original_aslah_two_headings_not_to_be_mixed(self):
        e = self.byword[norm("أَصْلَحَ")]
        self.assertEqual(e["grammar"][0], self.review[norm("أَصْلَحَ")]["grammar"][0]["ar"])
        self.assertIn("يُصْلِحُ", e["grammar"][0])
        self.assertEqual(e["id"], "bayna_scan_v1_360")


if __name__ == "__main__":
    unittest.main()
