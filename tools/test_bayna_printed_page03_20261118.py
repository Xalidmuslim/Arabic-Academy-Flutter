#!/usr/bin/env python3
"""Printed 3 / PDF 7: prove source alignment and preserve all existing word IDs.

A passing structural test is not a certificate for Arabic examples or i'rab.
"""
import json
import re
import unicodedata
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "assets/data"
SHA = "a2d98cbf6cd309bac2ac072e09679260b1fa20dec0af4cfa7ddf82d7fae2f995"
RESTORED = "assets/data/entries_bayna_print03_restored_20261118.json"
AUDIT = "research/dictionary_sources/printed_page03_source_vs_corpus_20261118.json"
ORDER = [
    "أَثَاثٌ", "آثَارٌ", "أَثَارَ", "إِثَارَةٌ", "أَثْبَتَ", "آثَرَ",
    "أَثَرٌ", "أَثَّرَ", "إِثْرَاءٌ", "أَثْرَى", "أَثْقَلُ",
    "إِثْمٌ", "أَثْمَنُ", "أَثْنَاءَ", "أَثْنَى", "أَثْوَابٌ",
    "أَثِيرٌ", "أَثِيمٌ", "أَجَابَ", "أَجَادَ", "أَجَازَ", "إِجَازَةٌ",
    "أَجَانِبُ", "إِجْبَارٌ", "أَجْبَرَ", "أَجْدَادٌ", "أُجُورٌ",
]
EXPECTED_OLD = {
    "أَثَاثٌ": "l1u3_012",
    "أَثَّرَ": "l2u09_027",
    "أَثْبَتَ": "l2u14_038",
    "أَثَرٌ": "l4draft08_005",
    "أَجَابَ": "level1_topic1_042",
    "أَجَادَ": "l2u06_037",
    "إِجَازَةٌ": "ind_noun_community_20261026_183",
    "أَثِمَ": "bayna_scan_v1_032",
}

def nfc(word):
    return unicodedata.normalize("NFC", word)

def letters(word):
    return re.sub(r"[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]", "", nfc(word))

class PrintedPageThreeTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.audit = json.loads((ROOT / AUDIT).read_text(encoding="utf-8"))
        cls.restored = json.loads((ROOT / RESTORED).read_text(encoding="utf-8"))["entries"]
        cls.manifest = json.loads((DATA / "corpus_manifest.json").read_text(encoding="utf-8"))["files"]
        cls.scan = json.loads((DATA / "entries_bayna_scan_verified_20261112.json").read_text(encoding="utf-8"))["entries"]
        cls.review = json.loads((DATA / "reviewed_articles_v1.json").read_text(encoding="utf-8"))["entries"]

    def test_complete_printed_27_heading_inventory(self):
        self.assertEqual(len(self.audit["entries"]), 27)
        self.assertEqual([nfc(e["headword"]) for e in self.audit["entries"]], [nfc(s) for s in ORDER])
        self.assertTrue(all(e["headword"] == nfc(e["headword"]) for e in self.audit["entries"]))
        self.assertEqual(sum(e["column"] == "right" for e in self.audit["entries"]), 11)
        self.assertEqual(sum(e["column"] == "left" for e in self.audit["entries"]), 16)
        self.assertEqual(self.audit["scan_sha256"], SHA)
        self.assertEqual((self.audit["pdf_page"], self.audit["printed_page"]), (7, 3))

    def test_two_missing_lemmas_restored_as_distinct_headwords(self):
        self.assertIn(RESTORED, self.manifest)
        self.assertEqual(len(self.restored), 2)
        self.assertEqual({nfc(e["arabic"]) for e in self.restored}, {"إِثْمٌ", "أَثِيرٌ"})
        self.assertEqual({e["id"] for e in self.restored},
                         {"bayna_print03_restored_20261118_001",
                          "bayna_print03_restored_20261118_002"})
        self.assertFalse(any(e["arabic"] == "أَثِمَ" for e in self.restored))

    def test_false_printed_verb_claim_is_relocated_without_id_loss(self):
        verb = next(e for e in self.scan if e["id"] == "bayna_scan_v1_032")
        self.assertEqual(verb["arabic"], "أَثِمَ")
        proof = verb["visual_verification"]
        self.assertEqual(proof["status"], "source_headword_mismatch_requires_relocation")
        self.assertEqual(proof["printed_headword"], "إِثْمٌ")
        self.assertEqual((proof["pdf_page"], proof["printed_page"]), (7, 3))
        self.assertEqual(proof["examples_status"], "independently_authored_pending_separate_i3rab_review")
        self.assertIn("unmatched_printed_lemma", verb["source_provenance"]["text_status"])
        reviewed_verb = next(e for e in self.review if e["arabic"] == "أَثِمَ")
        self.assertEqual(reviewed_verb["visual_verification"], proof)

    def test_restored_Arabic_NFC_and_external_examples_are_distinct(self):
        overlays = {nfc(e["arabic"]): e for e in self.review}
        for e in self.restored:
            with self.subTest(lemma=e["arabic"]):
                p = e["source_provenance"]
                v = e["visual_verification"]
                self.assertEqual((p["pdf_page"], p["printed_page"], p["scan_sha256"]), (7, 3, SHA))
                self.assertEqual(v["examples_status"], "independently_authored_pending_separate_i3rab_review")
                self.assertEqual(e["book_references"], [])
                self.assertGreaterEqual(len(e["grammar"]), 2)
                self.assertGreaterEqual(len(e["examples_ar"]), 2)
                self.assertGreaterEqual(len(e["collocations"]), 1)
                for value in [e["arabic"], e["meaning_ar"], e["usage_note_ar"],
                              *e["grammar"], *e["collocations"], *e["examples_ar"],
                              *e["additional_meanings_ar"], *e["synonyms"], *e["antonyms"]]:
                    self.assertEqual(nfc(value), value)
                    self.assertFalse(re.search(r"[A-Za-z\u0400-\u04ff]", value))
                overlay = overlays[nfc(e["arabic"])]
                self.assertEqual(overlay["visual_verification"], v)
                self.assertEqual([x["ar"] for x in overlay["examples"]], e["examples_ar"])

    def test_all_earlier_canonical_ids_preserved(self):
        seen = {}
        ids = set()
        for name in self.manifest:
            data = json.loads((ROOT / name).read_text(encoding="utf-8"))
            for e in data["entries"]:
                self.assertNotIn(e["id"], ids)
                ids.add(e["id"])
                seen.setdefault(nfc(e["arabic"]), e["id"])
        for headword, wid in EXPECTED_OLD.items():
            self.assertEqual(seen[nfc(headword)], wid)
        for e in self.restored:
            self.assertEqual(seen[nfc(e["arabic"])], e["id"])

if __name__ == "__main__":
    unittest.main()
