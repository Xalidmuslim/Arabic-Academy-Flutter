#!/usr/bin/env python3
"""Guard Arabic editorial specificity and source/review consistency.

This is a data regression test; it does not independently proofread tashkeel,
Arabic i'rab, or the user's printed 404-page source scan.
"""
import json
import re
import unittest
import unicodedata
from pathlib import Path

DATA = Path(__file__).resolve().parents[1] / "assets" / "data"
SCAN = "a2d98cbf6cd309bac2ac072e09679260b1fa20dec0af4cfa7ddf82d7fae2f995"
GENERIC = ("يُنْظَرُ إِلَى صِيغَةِ الْمَاضِي وَالْمُضَارِعِ وَالْمَصْدَرِ "
           "عِنْدَ تَحْلِيلِ الْفِعْلِ.")
WORDS = (
    "أَرْجَأَ", "أَرْدَى", "أَرْسَلَ", "أَرْشَدَ", "أَرْضَعَ", "أَرْضَى",
    "أَرْغَمَ", "أَرِقَ", "أَزْعَجَ", "أَزْمَعَ", "أَرْهَقَ", "أَزَاحَ",
    "أَزَالَ", "أَسَاءَ", "أَسْبَغَ", "أَسْبَلَ", "أَضْحَى", "أُغْمِيَ",
    "أَسْدَلَ", "أَسْدَى", "أَسَرَ", "أَسْرَعَ", "أَسْرَفَ", "أَسْرَى",
    "أَسِفَ", "أَسْمَعَ", "أَسْهَبَ", "أَسْهَمَ", "أَسِيَ", "أَشَاحَ",
    "أَشَادَ", "أَشَّرَ", "أَشْرَقَ", "أَشْعَلَ", "أَشْهَرَ", "أَصْبَحَ",
    "أَصَرَّ", "أَصْغَى", "أَضَاءَ", "أَضَاعَ", "أَضَافَ", "أَضْحَكَ",
    "أَضْرَبَ", "أَضْرَمَ", "أَضْعَفَ", "أَضْنَى", "أَطَاعَ", "أَطَاقَ",
)


class SpecificArabicUsageNotes(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = {
            entry["arabic"]: entry for entry in json.loads(
                (DATA / "entries_bayna_scan_verified_20261112.json").read_text("utf-8")
            )["entries"]
        }
        cls.review = {
            entry["arabic"]: entry for entry in json.loads(
                (DATA / "reviewed_articles_v1.json").read_text("utf-8")
            )["entries"]
        }

    def test_forty_eight_edited_notes_are_specific_and_mirrored(self):
        self.assertEqual(len(WORDS), 48)
        self.assertEqual(len(set(WORDS)), 48)
        for word in WORDS:
            with self.subTest(word=word):
                src, article = self.source[word], self.review[word]
                note = src["usage_note_ar"]
                self.assertNotEqual(note, GENERIC)
                self.assertEqual(note, article["important"][0]["ar"])
                self.assertEqual(note, unicodedata.normalize("NFC", note))
                self.assertTrue(re.search(r"[\u0621-\u064A]", note))
                self.assertTrue(re.search(r"[\u064B-\u065F]", note))
                self.assertFalse(re.search(r"[\u0400-\u04FF]", note))
                self.assertEqual(src["visual_verification"]["scan_sha256"], SCAN)
                self.assertEqual(
                    src["visual_verification"], article["visual_verification"]
                )
                self.assertEqual(
                    src["visual_verification"]["examples_status"],
                    "independently_authored_pending_separate_i3rab_review",
                )

    def test_no_boilerplate_note_remains_in_594_reviewed_articles(self):
        self.assertEqual(len(self.review), 594)
        for word, article in self.review.items():
            with self.subTest(word=word):
                self.assertFalse(
                    any(fact["ar"] == GENERIC for fact in article["important"])
                )
        for word, source in self.source.items():
            with self.subTest(scan_word=word):
                self.assertNotEqual(source["usage_note_ar"], GENERIC)

    def test_specific_verb_forms_match_in_both_files(self):
        for word, fragments in {
            "أَضْحَى": ("يُضْحِي", "إِضْحَاءٌ"),
            "أُغْمِيَ": ("يُغْمَى", "إِغْمَاءٌ", "لِلْمَجْهُولِ"),
        }.items():
            with self.subTest(word=word):
                src, article = self.source[word], self.review[word]
                self.assertEqual(
                    src["grammar"], [f["ar"] for f in article["grammar"]]
                )
                for fragment in fragments:
                    self.assertIn(fragment, src["grammar"][0])

    def test_original_source_mismatches_are_not_promoted(self):
        for word, printed in {
            "أَرْذَالٌ": "أَرْذَل",
            "أَسْمَعَ": "أَسْمَعُ",
            "أَضْحَى": "أُضْحِيَّةٌ",
        }.items():
            with self.subTest(word=word):
                proof = self.source[word]["visual_verification"]
                self.assertEqual(
                    proof["status"], "source_headword_mismatch_requires_relocation"
                )
                self.assertEqual(proof["printed_headword"], printed)


if __name__ == "__main__":
    unittest.main()
