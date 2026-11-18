#!/usr/bin/env python3
"""Five scanned pages, printed 4-8 (PDF 8-12): evidence and ID regressions.

This test verifies the recorded source collation and authored-card structure.
It does not certify the correctness of Arabic i3rab or substitute for scan reading.
"""
import json
import re
import unicodedata
import unittest
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "assets/data"
SHA = "a2d98cbf6cd309bac2ac072e09679260b1fa20dec0af4cfa7ddf82d7fae2f995"
REPORT = "research/dictionary_sources/printed_pages04_08_visual_inventory_20261118.json"
RESTORED = "assets/data/entries_bayna_print04_08_restored_20261118.json"
COUNTS = {8: 20, 9: 24, 10: 29, 11: 22, 12: 28}
OLD_COUNTS = {8: 20, 9: 18, 10: 29, 11: 20, 12: 25}
MISSING = {
    9: {"أَجْهَلُ", "أَجْيَالٌ", "آحَادٌ", "أُحُدٌ", "أَحْدَاقٌ", "إِحْدَى"},
    11: {"آخِذٌ", "أَخْطَرُ"},
    12: {"آخَى", "أُدَبَاءُ", "أَدْبَارٌ"},
}
def nfc(s):
    return unicodedata.normalize("NFC", s)

class FivePrintedPagesBatch(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report = json.loads((ROOT / REPORT).read_text(encoding="utf8"))
        cls.restored = json.loads((ROOT / RESTORED).read_text(encoding="utf8"))["entries"]
        cls.manifest = json.loads((DATA / "corpus_manifest.json").read_text(encoding="utf8"))["files"]
        cls.original = json.loads((DATA / "entries_bayna_scan_verified_20261112.json").read_text(encoding="utf8"))["entries"]
        cls.review = json.loads((DATA / "reviewed_articles_v1.json").read_text(encoding="utf8"))["entries"]

    def test_all_123_printed_headings_in_original_column_order(self):
        self.assertEqual(self.report["scan_sha256"], SHA)
        pages = self.report["pages"]
        self.assertEqual([p["pdf_page"] for p in pages], list(COUNTS))
        self.assertEqual(sum(len(p["headings"]) for p in pages), 123)
        seen = []
        for p in pages:
            pdf = p["pdf_page"]
            self.assertEqual(p["printed_page"], pdf - 4)
            self.assertEqual(len(p["headings"]), COUNTS[pdf])
            right = [e for e in p["headings"] if e["column"] == "right"]
            left = [e for e in p["headings"] if e["column"] == "left"]
            self.assertEqual([e["order_in_column"] for e in right], list(range(1, len(right) + 1)))
            self.assertEqual([e["order_in_column"] for e in left], list(range(1, len(left) + 1)))
            self.assertEqual([x["column"] for x in p["headings"]], ["right"]*len(right)+["left"]*len(left))
            seen.extend(e["headword"] for e in p["headings"])
        self.assertEqual(len({nfc(e) for e in seen}), 123)
        self.assertTrue(all(e == nfc(e) for e in seen))

    def test_all_112_old_scan_entries_remain_and_none_is_falsely_restored(self):
        old = [x for x in self.original if x["source_provenance"]["pdf_page"] in COUNTS]
        self.assertEqual(len(old), sum(OLD_COUNTS.values()))
        for pdf,count in OLD_COUNTS.items():
            self.assertEqual(len([e for e in old if e["source_provenance"]["pdf_page"] == pdf]), count)
        by_page = {p["pdf_page"]: p for p in self.report["pages"]}
        for e in old:
            page = e["source_provenance"]["pdf_page"]
            headwords = {nfc(row["headword"]) for row in by_page[page]["headings"]}
            self.assertIn(nfc(e["arabic"]), headwords)
            self.assertEqual(e["source_provenance"]["scan_sha256"], SHA)
            self.assertIn("bayna_scan_v1_", e["id"])
        self.assertEqual(len({e["id"] for e in old}), len(old))

    def test_eleven_distinct_missing_lemmas_added_and_manifest_appended(self):
        self.assertEqual(len(self.restored), 11)
        self.assertEqual({nfc(x["arabic"]) for x in self.restored},
                         {nfc(w) for words in MISSING.values() for w in words})
        self.assertEqual(self.manifest[-1], RESTORED)
        self.assertEqual([e["id"] for e in self.restored],
                         [f"bayna_print04_08_restored_20261118_{n:03d}" for n in range(1,12)])
        self.assertEqual(len({e["id"] for e in self.restored}), 11)
        self.assertNotEqual(nfc("أَحَدٌ"), nfc("أُحُدٌ"))
        self.assertNotEqual(nfc("أَخْطَارٌ"), nfc("أَخْطَرُ"))
        self.assertNotEqual(nfc("أَخَذَ"), nfc("آخِذٌ"))

    def test_every_new_article_has_bounded_provenance_and_an_Arabic_review_overlay(self):
        byword = {nfc(e["arabic"]):e for e in self.review}
        for e in self.restored:
            with self.subTest(word=e["arabic"]):
                pdf=e["source_provenance"]["pdf_page"]
                self.assertIn(pdf, MISSING)
                self.assertIn(nfc(e["arabic"]), {nfc(w) for w in MISSING[pdf]})
                self.assertEqual(e["source_provenance"]["scan_sha256"], SHA)
                self.assertEqual(e["source_provenance"]["printed_page"], pdf-4)
                self.assertEqual(e["book_references"], [])
                self.assertEqual(e["visual_verification"]["examples_status"],
                                 "independently_authored_pending_separate_i3rab_review")
                self.assertGreaterEqual(len(e["grammar"]),2)
                self.assertGreaterEqual(len(e["examples_ar"]),2)
                self.assertGreaterEqual(len(e["collocations"]),1)
                for value in [e["arabic"],e["meaning_ar"],e["usage_note_ar"],
                              *e["grammar"],*e["examples_ar"],*e["collocations"],
                              *e["additional_meanings_ar"],*e["synonyms"],*e["antonyms"]]:
                    self.assertEqual(nfc(value), value)
                    self.assertFalse(re.search(r"[A-Za-z\u0400-\u04ff]",value))
                overlay=byword[nfc(e["arabic"])]
                self.assertEqual([x["ar"] for x in overlay["examples"]],e["examples_ar"])
                self.assertEqual(overlay["visual_verification"], e["visual_verification"])

    def test_original_canonical_word_ids_are_not_reordered_or_dropped(self):
        ids=set()
        allkeys={}
        for filename in self.manifest:
            for entry in json.loads((ROOT/filename).read_text(encoding="utf8"))["entries"]:
                self.assertNotIn(entry["id"], ids)
                ids.add(entry["id"])
                allkeys.setdefault(nfc(entry["arabic"]), entry["id"])
        for e in self.original:
            k=nfc(e["arabic"])
            self.assertIn(k, allkeys)
            self.assertNotEqual(allkeys[k], "")
        for e in self.restored:
            self.assertEqual(allkeys[nfc(e["arabic"])],e["id"])

if __name__ == "__main__":
    unittest.main()
