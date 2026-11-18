#!/usr/bin/env python3
"""Printed page 2 / scanned PDF page 6: exact-vowel disambiguation and ID safety.

These tests validate the manually recorded scan provenance and raw/overlay data;
they do NOT certify independently authored example sentences.
"""
import json
import re
import unicodedata
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "assets/data"
SHA = "a2d98cbf6cd309bac2ac072e09679260b1fa20dec0af4cfa7ddf82d7fae2f995"
NEW_CHUNK = "assets/data/entries_bayna_print02_restored_20261118.json"
EXPECTED = {
    "أَبْرَصُ", "إِبْطٌ", "أَبْعَدُ", "أَبْغَضُ", "إِبْقَاءٌ", "إِبْلِيسُ",
    "آتٍ", "أَتْبَاعٌ", "إِتْقَانٌ", "أَتْقَى", "أَتْقِيَاءُ", "أَثَابَ",
}
MISMATCH = "source_headword_mismatch_requires_relocation"


def nfc(s):
    return unicodedata.normalize("NFC", s)


class PrintedPageTwoRestoration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        manifest = json.loads((DATA / "corpus_manifest.json").read_text("utf8"))
        cls.files = manifest["files"]
        cls.restored = json.loads((ROOT / NEW_CHUNK).read_text("utf8"))["entries"]
        cls.old = json.loads(
            (DATA / "entries_bayna_scan_verified_20261112.json").read_text("utf8")
        )["entries"]
        cls.overlay = json.loads(
            (DATA / "reviewed_articles_v1.json").read_text("utf8")
        )["entries"]

    def test_twelve_distinct_printed_headwords_restored_without_rewriting_old_word(self):
        self.assertIn(NEW_CHUNK, self.files)
        self.assertEqual(len(self.restored), 12)
        self.assertEqual({nfc(e["arabic"]) for e in self.restored}, {nfc(e) for e in EXPECTED})
        self.assertEqual(len({nfc(e["arabic"]) for e in self.restored}), 12)
        self.assertNotIn("أَبْغَضَ", {e["arabic"] for e in self.restored})
        originals = [e for e in self.old if e["arabic"] == "أَبْغَضَ"]
        self.assertEqual(len(originals), 1)
        self.assertEqual(originals[0]["id"], "bayna_scan_v1_007")

    def test_wrong_verb_source_does_not_claim_printed_comparative(self):
        verb = next(x for x in self.old if x["arabic"] == "أَبْغَضَ")
        proof = verb["visual_verification"]
        self.assertEqual(proof["status"], MISMATCH)
        self.assertEqual(proof["printed_headword"], "أَبْغَضُ")
        self.assertEqual(proof["pdf_page"], 6)
        self.assertEqual(proof["printed_page"], 2)
        self.assertEqual(proof["examples_status"], "independently_authored_pending_separate_i3rab_review")
        self.assertIn("unmatched_printed_lemma", verb["source_provenance"]["text_status"])
        overlay = next(x for x in self.overlay if x["arabic"] == "أَبْغَضَ")
        self.assertEqual(overlay["visual_verification"], proof)

    def test_source_boundaries_arabic_nfc_and_overlay_attachment(self):
        articles = {nfc(x["arabic"]): x for x in self.overlay}
        for e in self.restored:
            with self.subTest(lemma=e["arabic"]):
                self.assertEqual(e["source_provenance"]["scan_sha256"], SHA)
                self.assertEqual(e["source_provenance"]["pdf_page"], 6)
                self.assertEqual(e["source_provenance"]["printed_page"], 2)
                self.assertEqual(e["book_references"], [])
                self.assertEqual(e["visual_verification"]["examples_status"],
                                 "independently_authored_pending_separate_i3rab_review")
                self.assertGreaterEqual(len(e["grammar"]), 2)
                self.assertGreaterEqual(len(e["examples_ar"]), 2)
                for part in [e["arabic"], e["meaning_ar"], e["usage_note_ar"],
                             *e["grammar"], *e["examples_ar"], *e["collocations"],
                             *e["additional_meanings_ar"], *e["synonyms"], *e["antonyms"]]:
                    self.assertEqual(nfc(part), part)
                    self.assertFalse(re.search(r"[A-Za-z\u0400-\u04ff]", part))
                overlay = articles[nfc(e["arabic"])]
                self.assertEqual(overlay["editorial_batch"], "2026-11-18-original-print-page02-restored-12")
                self.assertEqual([x["ar"] for x in overlay["examples"]], e["examples_ar"])

    def test_old_ids_survive_manifest_merge(self):
        seen = {}
        for path in self.files:
            part = json.loads((ROOT / path).read_text("utf8"))
            for e in part["entries"]:
                seen.setdefault(nfc(e["arabic"]), e["id"])
        self.assertEqual(seen[nfc("أَبْغَضَ")], "bayna_scan_v1_007")
        for e in self.restored:
            self.assertEqual(seen[nfc(e["arabic"])], e["id"])


if __name__ == "__main__":
    unittest.main()
