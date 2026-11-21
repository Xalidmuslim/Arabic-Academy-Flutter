#!/usr/bin/env python3
"""Check that printed pages 20-26 are inventoried without inventing lexical cards.

PDF 24-25 are illustrated anatomy diagrams, not ordinary dictionary-headword
pages. PDF 26-30 contain 122 headwords. The inventory verifies spelling/ID
mapping only; it does not certify independently authored Arabic examples.
"""
import json
import unicodedata
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/data/entries_bayna_scan_verified_20261112.json"
AUDIT = ROOT / "research/dictionary_sources/printed_pages20_26_anatomy_and_headwords_20261121.json"
PDF_SHA = "a2d98cbf6cd309bac2ac072e09679260b1fa20dec0af4cfa7ddf82d7fae2f995"


def nfc(value):
    return unicodedata.normalize("NFC", value)


class PrintedPagesTwentyThroughTwentySix(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.audit = json.loads(AUDIT.read_text(encoding="utf-8"))
        cls.source = json.loads(SOURCE.read_text(encoding="utf-8"))["entries"]

    def test_exact_pdf_provenance_and_separate_page_kinds(self):
        a = self.audit
        self.assertEqual(a["scan_sha256"], PDF_SHA)
        self.assertEqual(a["pdf_to_print_page_offset"], 4)
        self.assertEqual([p["pdf_page"] for p in a["illustration_pages"]], [24, 25])
        self.assertEqual([p["pdf_page"] for p in a["lexicon_pages"]], [26, 27, 28, 29, 30])
        for p in [*a["illustration_pages"], *a["lexicon_pages"]]:
            self.assertEqual(p["printed_page"], p["pdf_page"] - 4)

    def test_two_anatomy_diagrams_are_labelled_not_claimed_as_lexical_cards(self):
        pages = self.audit["illustration_pages"]
        self.assertEqual([len(p["labels"]) for p in pages], [30, 18])
        self.assertEqual(sum(len(p["labels"]) for p in pages), 48)
        self.assertTrue(all(p["kind"] == "anatomical_illustration" for p in pages))
        for p in pages:
            self.assertTrue(p["labels_are_not_independently_validated_dictionary_entries"])
            for x in p["labels"]:
                self.assertIn(x["side"], ("left", "right"))
                self.assertEqual(nfc(x["text"]), x["text"])
                self.assertNotIn("source_entry_id", x)
        self.assertFalse(any(24 <= x["source_provenance"]["pdf_page"] <= 25 for x in self.source))

    def test_all_122_headwords_resolve_to_existing_source_ids(self):
        a = self.audit
        self.assertEqual(a["existing_lexicon_headwords_total"], 122)
        self.assertEqual([len(p["headings"]) for p in a["lexicon_pages"]], [23, 27, 23, 25, 24])
        source_by_id = {x["id"]: x for x in self.source}
        registered_ids = set()
        for p in a["lexicon_pages"]:
            original_page = [x for x in self.source if x["source_provenance"]["pdf_page"] == p["pdf_page"]]
            self.assertEqual(len(original_page), len(p["headings"]))
            self.assertEqual([x["id"] for x in original_page], [x["existing_scan_id"] for x in p["headings"]])
            for i, h in enumerate(p["headings"], 1):
                self.assertEqual(h["position"], i)
                self.assertEqual(h["comparison_status"], "printed_base_letters_compared_full_harakat_recheck_pending")
                x = source_by_id[h["existing_scan_id"]]
                self.assertNotIn(x["id"], registered_ids)
                registered_ids.add(x["id"])
                self.assertEqual(x["source_provenance"]["pdf_page"], p["pdf_page"])
                self.assertEqual(nfc(h["headword"]), nfc(x["arabic"]))
        self.assertEqual(len(registered_ids), 122)

    def test_no_unjustified_grammar_example_or_irab_approval(self):
        for p in self.audit["lexicon_pages"]:
            for h in p["headings"]:
                self.assertEqual(h["examples_status"], "independently_authored_pending_i3rab_review")
        self.assertFalse(self.audit["certifies_independent_grammar_or_examples"])
        self.assertEqual(self.audit["corpus_data_files_modified"], [])

    def test_known_form_distinctions_preserved(self):
        rows = {h["existing_scan_id"]: h["headword"]
                for p in self.audit["lexicon_pages"] for h in p["headings"]}
        self.assertEqual(rows["bayna_scan_v1_490"], "أُغْمِيَ")
        self.assertEqual(rows["bayna_scan_v1_550"], "أَقْسَطَ")
        self.assertEqual(rows["bayna_scan_v1_549"], "أَقْسَاطٌ")
        self.assertEqual(rows["bayna_scan_v1_537"], "أَقَامَ")
        self.assertEqual(rows["bayna_scan_v1_538"], "إِقَامَةٌ")


if __name__ == "__main__":
    unittest.main()
