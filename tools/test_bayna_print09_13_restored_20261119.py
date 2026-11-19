#!/usr/bin/env python3
"""Restore only 15 truly absent, print-verified headwords on PDF 13-17.

Tests preserve old IDs and source boundaries. They DO NOT certify invented
examples' i'rab or any unverifiable synonym or form.
"""
import json
import re
import unicodedata
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "assets/data"
TARGET = "assets/data/entries_bayna_print09_13_restored_20261119.json"
SOURCE_SHA = "a2d98cbf6cd309bac2ac072e09679260b1fa20dec0af4cfa7ddf82d7fae2f995"
EXPECTED = [
    ("أَذْوَاقٌ", 13), ("آذَى", 13), ("أَذًى", 13), ("أَرَاكٌ", 13),
    ("أَرَاكَةٌ", 13), ("أَرْبَعُ", 13), ("أَرْبَعَةَ عَشَرَ", 13),
    ("أَرْسُنٌ", 14), ("أَرْطَالٌ", 14), ("أَرْطَبَ", 14),
    ("أُسَرٌ", 16), ("إِسْرَائِيلُ", 16),
    ("أَسِرَّةٌ", 17), ("أَسْرَعُ", 17), ("إِسْكَافٌ", 17)
]

def nfc(x):
    return unicodedata.normalize("NFC", x)

class PrintedNineThirteenRestorations(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.items = json.loads((ROOT / TARGET).read_text(encoding="utf8"))["entries"]
        cls.manifest = json.loads((DATA / "corpus_manifest.json").read_text(encoding="utf8"))["files"]
        cls.review = json.loads((DATA / "reviewed_articles_v1.json").read_text(encoding="utf8"))["entries"]

    def test_exactly_15_new_entries_with_original_pages(self):
        self.assertIn(TARGET, self.manifest)
        self.assertEqual(len(self.items), 15)
        self.assertEqual([(nfc(x["arabic"]), x["source_provenance"]["pdf_page"])
                          for x in self.items], [(nfc(w), p) for w, p in EXPECTED])
        self.assertEqual([x["id"] for x in self.items],
                         [f"bayna_print09_13_restored_20261119_{n:03d}"
                          for n in range(1, 16)])
        self.assertEqual(len({x["id"] for x in self.items}), len(self.items))

    def test_evidence_boundaries_and_quality(self):
        overlay = {nfc(x["arabic"]): x for x in self.review}
        for x in self.items:
            with self.subTest(word=x["arabic"]):
                prov, proof = x["source_provenance"], x["visual_verification"]
                self.assertEqual(prov["scan_sha256"], SOURCE_SHA)
                self.assertEqual(proof["scan_sha256"], SOURCE_SHA)
                self.assertEqual(prov["printed_page"], prov["pdf_page"] - 4)
                self.assertEqual(proof["pdf_page"], prov["pdf_page"])
                self.assertIn("pending", proof["examples_status"])
                self.assertEqual(x["book_references"], [])
                self.assertTrue(x["meaning_ar"])
                self.assertGreaterEqual(len(x["grammar"]), 2)
                self.assertGreaterEqual(len(x["examples_ar"]), 2)
                self.assertGreaterEqual(len(x["collocations"]), 1)
                self.assertTrue(x["usage_note_ar"])
                self.assertEqual(x["synonyms"], [])
                self.assertEqual(x["antonyms"], [])
                texts = [x["arabic"], x["meaning_ar"], x["usage_note_ar"],
                         *x["grammar"], *x["examples_ar"], *x["collocations"],
                         *x["additional_meanings_ar"]]
                for word in texts:
                    self.assertEqual(word, nfc(word))
                    self.assertFalse(re.search(r"[A-Za-z\u0400-\u04ff]", word))
                rv = overlay[nfc(x["arabic"])]
                self.assertEqual(rv["source_pdf_page"], prov["pdf_page"])
                self.assertEqual(rv["visual_verification"], proof)
                self.assertEqual([e["ar"] for e in rv["examples"]], x["examples_ar"])
                self.assertEqual([g["ar"] for g in rv["grammar"]], x["grammar"])

    def test_no_id_loss_and_no_duplicate_vocalized_lemma(self):
        all_ids, all_words = [], []
        for file in self.manifest:
            for x in json.loads((ROOT / file).read_text(encoding="utf8"))["entries"]:
                all_ids.append(x["id"])
                all_words.append(nfc(x["arabic"]))
        self.assertEqual(len(all_ids), len(set(all_ids)))
        for new in self.items:
            self.assertEqual(all_words.count(nfc(new["arabic"])), 1)
        for old_id in ("bayna_scan_v1_179", "bayna_scan_v1_204",
                       "bayna_scan_v1_259", "bayna_scan_v1_276",
                       "bayna_scan_v1_286", "bayna_scan_v1_266",
                       "bayna_scan_print_restored_20261114_001"):
            self.assertIn(old_id, all_ids)

    def test_vowel_sensitive_entries_remain_distinct(self):
        wanted = {nfc(x["arabic"]) for x in self.items}
        self.assertIn(nfc("أَسْرَعُ"), wanted)
        self.assertNotIn(nfc("أَسْرَعَ"), wanted)
        self.assertIn(nfc("أُسَرٌ"), wanted)
        self.assertNotIn(nfc("أَسْرٌ"), wanted)
        self.assertIn(nfc("إِسْكَافٌ"), wanted)
        self.assertNotIn(nfc("إِسْكَانٌ"), wanted)

if __name__ == "__main__":
    unittest.main()
