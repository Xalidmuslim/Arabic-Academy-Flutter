#!/usr/bin/env python3
"""Focused independent i3rab checks for original printed pages 16-19.

The test checks evidence traceability and mirrored content, not whether
all authored Arabic has passed an academic linguistic review.
"""
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets/data/entries_bayna_scan_verified_20261112.json"
MIRROR = ROOT / "assets/data/reviewed_articles_v1.json"
AUDIT = ROOT / "research/dictionary_sources/i3rab_batch48_print16_19_20261121.json"
AUDIT_REMAINDER = ROOT / "research/dictionary_sources/i3rab_batch45_remaining_print16_19_20261121.json"
AUDIT_PRIOR = ROOT / "research/dictionary_sources/selected_i3rab_print16_19_20261121.json"
ARABIC = re.compile(r"[\u0621-\u064a]")
CYRILLIC = re.compile(r"[\u0400-\u04ff]")
PREVIOUSLY_CHECKED = {354,357,360,375,390,398,402,406,413,418,426,439}


class Print16To19SeparateExampleAudit(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = {e["id"]: e for e in
                      json.loads(SRC.read_text(encoding="utf-8"))["entries"]}
        cls.reviewed = {e["arabic"]: e for e in
                        json.loads(MIRROR.read_text(encoding="utf-8"))["entries"]}
        cls.audit = json.loads(AUDIT.read_text(encoding="utf-8"))
        cls.remainder = json.loads(AUDIT_REMAINDER.read_text(encoding="utf-8"))
        cls.prior = json.loads(AUDIT_PRIOR.read_text(encoding="utf-8"))

    def test_forty_eight_new_distinct_example_reviews(self):
        entries = self.audit["examples"]
        self.assertEqual(len(entries), 48)
        self.assertEqual(self.audit["reviewed_example_count"], 48)
        self.assertEqual(len({e["source_entry_id"] for e in entries}), 48)
        self.assertFalse(self.audit["certifies_full_articles"])
        self.assertFalse(self.audit["certifies_all_examples_per_article"])
        self.assertEqual(self.audit["source_pdf_sha256"],
                         "a2d98cbf6cd309bac2ac072e09679260b1fa20dec0af4cfa7ddf82d7fae2f995")
        for e in entries:
            with self.subTest(entry=e["source_entry_id"]):
                original = self.source[e["source_entry_id"]]
                mirror = self.reviewed[original["arabic"]]
                self.assertIn(original["source_provenance"]["pdf_page"], (20,21,22,23))
                self.assertEqual(e["source_pdf_page"], original["source_provenance"]["pdf_page"])
                self.assertEqual(e["headword"], original["arabic"])
                self.assertNotIn(int(e["source_entry_id"].split("_")[-1]), PREVIOUSLY_CHECKED)
                self.assertIn(e["example_ar"], original["examples_ar"])
                self.assertIn(e["example_ar"], [x["ar"] for x in mirror["examples"]])
                self.assertGreaterEqual(len(e["i3rab_ar"]), 2)
                for line in e["i3rab_ar"]:
                    self.assertTrue(ARABIC.search(line))
                    self.assertFalse(CYRILLIC.search(line))
                self.assertEqual(e["source_relationship"],
                                 "author_composed_example_not_verbatim_book_source")
                self.assertEqual(original["editorial_review"]["status"],
                                 "individual_arabic_draft_requires_independent_linguistic_review")

    def test_forty_five_remaining_source_linked_examples(self):
        entries = self.remainder["examples"]
        self.assertEqual(len(entries), 45)
        self.assertEqual(self.remainder["reviewed_example_count"], 45)
        self.assertEqual(len({e["source_entry_id"] for e in entries}), 45)
        self.assertFalse(self.remainder["certifies_full_articles"])
        self.assertFalse(self.remainder["certifies_all_examples_per_article"])
        self.assertEqual(self.remainder["source_pdf_sha256"],
                         self.audit["source_pdf_sha256"])
        earlier_ids = {e["source_entry_id"] for e in self.audit["examples"]}
        earlier_ids.update(e["source_entry_id"] for e in self.prior["examples"])
        for e in entries:
            with self.subTest(entry=e["source_entry_id"]):
                self.assertNotIn(e["source_entry_id"], earlier_ids)
                original = self.source[e["source_entry_id"]]
                mirror = self.reviewed[original["arabic"]]
                self.assertEqual(e["headword"], original["arabic"])
                self.assertEqual(e["source_pdf_page"],
                                 original["source_provenance"]["pdf_page"])
                self.assertEqual(e["source_printed_page"],
                                 original["source_provenance"]["printed_page"])
                self.assertIn(e["example_ar"], original["examples_ar"])
                self.assertIn(e["example_ar"], [x["ar"] for x in mirror["examples"]])
                self.assertEqual(e["source_relationship"],
                                 "author_composed_example_not_verbatim_book_source")
                self.assertGreaterEqual(len(e["i3rab_ar"]), 2)
                for item in e["i3rab_ar"]:
                    self.assertTrue(ARABIC.search(item))
                    self.assertFalse(CYRILLIC.search(item))
                self.assertEqual(original["editorial_review"]["status"],
                                 "individual_arabic_draft_requires_independent_linguistic_review")

    def test_every_source_card_has_one_separately_reviewed_sample(self):
        groups = [self.prior["examples"], self.audit["examples"],
                  self.remainder["examples"]]
        ids = [e["source_entry_id"] for group in groups for e in group]
        self.assertEqual(len(ids), 105)
        self.assertEqual(len(set(ids)), 105)
        printed = {
            e["id"] for e in self.source.values()
            if e.get("source_provenance", {}).get("pdf_page") in (20,21,22,23)
        }
        self.assertEqual(set(ids), printed)
        for group in groups:
            for entry in group:
                original = self.source[entry["source_entry_id"]]
                self.assertIn(entry["example_ar"], original["examples_ar"])
                self.assertIn(entry["example_ar"],
                              [x["ar"] for x in self.reviewed[original["arabic"]]["examples"]])

    def test_attested_use_of_aada_is_expressed_in_passive_in_both_files(self):
        # Reproduces the former incorrect active وَيَسْتَعْمِلُ.
        original = self.source["bayna_scan_v1_433"]
        mirror = self.reviewed["أَعْدَى"]
        expected = "وَيُسْتَعْمَلُ لِلدَّلَالَةِ عَلَى نَقْلِ الْعَدْوَى"
        self.assertIn(expected, original["grammar"][1])
        self.assertIn(expected, mirror["grammar"][1]["ar"])
        self.assertNotIn("وَيَسْتَعْمِلُ", original["grammar"][1])


if __name__ == "__main__":
    unittest.main()
