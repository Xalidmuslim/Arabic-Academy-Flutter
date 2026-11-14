#!/usr/bin/env python3
"""Verify that the two print-attested headwords missing from old page citations are present.

Grounding: the actual 404-page scanned source supplied 2026-11-14;
SHA256 a2d98cbf6cd309bac2ac072e09679260b1fa20dec0af4cfa7ddf82d7fae2f995.
These checks guarantee source provenance, not full proofread of new examples.
"""
import json
import unicodedata
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT/"assets"/"data"
CORRECTIONS = DATA/"entries_bayna_scan_restored_print_20261114.json"
MANIFEST = DATA/"corpus_manifest.json"
REVIEW = DATA/"reviewed_articles_v1.json"
EXPECTED = {"أَسْمَعُ": (17, 13), "أُضْحِيَّةٌ": (21, 17)}
SHA = "a2d98cbf6cd309bac2ac072e09679260b1fa20dec0af4cfa7ddf82d7fae2f995"


class RestoredPrintedLemmaTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.scan = json.loads(CORRECTIONS.read_text(encoding="utf-8"))["entries"]
        cls.manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))["files"]
        cls.review = json.loads(REVIEW.read_text(encoding="utf-8"))["entries"]

    def test_both_printed_lemmas_are_represented_without_rewriting_mismatched_ids(self):
        self.assertEqual(len(self.scan), 2)
        self.assertEqual(set(x["arabic"] for x in self.scan), set(EXPECTED))
        for entry in self.scan:
            with self.subTest(headword=entry["arabic"]):
                self.assertIn("أُضْحِيَّةٌ", EXPECTED)
                self.assertTrue(entry["id"].startswith("bayna_scan_print_restored_20261114_"))
                self.assertEqual(
                    (entry["source_provenance"]["pdf_page"], entry["source_provenance"]["printed_page"]),
                    EXPECTED[entry["arabic"]],
                )
                self.assertEqual(entry["source_provenance"]["scan_sha256"], SHA)
                self.assertEqual(entry["visual_verification"]["scan_sha256"], SHA)
                self.assertEqual(
                    entry["visual_verification"]["examples_status"],
                    "independently_authored_pending_separate_i3rab_review",
                )
                self.assertEqual(entry["visual_verification"]["status"],
                                 "printed_lemma_and_gloss_manually_checked_original_pdf")
                self.assertTrue(entry["grammar"])
                self.assertTrue(entry["examples_ar"])
                self.assertTrue(all(
                    unicodedata.normalize("NFC", s) == s
                    for s in [entry["arabic"], entry["meaning_ar"], *entry["examples_ar"]]
                ))
        self.assertIn("assets/data/entries_bayna_scan_restored_print_20261114.json", self.manifest)

    def test_new_reviewed_overlays_keep_source_and_example_evidence_separate(self):
        for lemma, (page, printed_page) in EXPECTED.items():
            matches=[x for x in self.review if x["arabic"] == lemma]
            with self.subTest(lemma=lemma):
                self.assertEqual(len(matches), 1)
                article=matches[0]
                self.assertEqual(article.get("editorial_batch"), "2026-11-14-original-restored-two")
                self.assertEqual(article["visual_verification"]["pdf_page"], page)
                self.assertEqual(article["visual_verification"]["printed_page"], printed_page)
                self.assertEqual(article["visual_verification"]["examples_status"],
                                 "independently_authored_pending_separate_i3rab_review")
                for field in ("definition", "grammar", "examples", "important"):
                    self.assertTrue(article[field])
                    self.assertTrue(all(set(x)=={"ar"} for x in article[field]))

    def test_wrong_legacy_print_provenance_is_still_flagged_not_silently_relabelled(self):
        old=json.loads((DATA/"entries_bayna_scan_verified_20261112.json").read_text(encoding="utf-8"))["entries"]
        for word in ("أَرْذَالٌ", "أَسْمَعَ", "أَضْحَى"):
            with self.subTest(word=word):
                matches=[e for e in old if e["arabic"] == word]
                self.assertEqual(len(matches), 1)
                self.assertEqual(matches[0]["visual_verification"]["status"],
                                 "source_headword_mismatch_requires_relocation")
                self.assertIn("unmatched_printed_lemma",matches[0]["source_provenance"]["text_status"])


if __name__=="__main__":
    unittest.main()
