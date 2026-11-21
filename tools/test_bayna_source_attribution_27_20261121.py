#!/usr/bin/env python3
"""Revoked printed-page claim must not delete a correct Arabic lexical entry."""
import json
import unicodedata
import unittest
from pathlib import Path

DATA = Path(__file__).resolve().parents[1] / "assets/data"
SCAN = DATA / "entries_bayna_scan_verified_20261112.json"
REV = DATA / "reviewed_articles_v1.json"
MAIN = DATA / "entries.json"

class IncorrectSourceAttribution(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.all_entries=json.loads(SCAN.read_text(encoding="utf-8"))["entries"]
        cls.by_id={r["id"]:r for r in cls.all_entries}
        cls.reviews={r["arabic"]:r for r in json.loads(REV.read_text(encoding="utf-8"))["entries"]}
        cls.main=json.loads(MAIN.read_text(encoding="utf-8"))["entries"]

    def test_verb_kept_but_not_attributed_to_sacrifice_lemma(self):
        e=self.by_id["bayna_scan_v1_378"]
        v=self.reviews["أَضْحَى"]
        self.assertEqual(e["arabic"],"أَضْحَى")
        self.assertEqual(e["examples_ar"],["أَضْحَى الْجَوُّ صَافِيًا."])
        self.assertIsNone(e["source_provenance"]["pdf_page"])
        self.assertIsNone(e["source_provenance"]["printed_page"])
        self.assertIsNone(v["source_pdf_page"])
        self.assertIsNone(v["source_printed_page"])
        self.assertEqual(e["source_provenance"]["text_status"],
                         "print_dictionary_attribution_revoked_source_not_located")
        self.assertEqual(e["visual_verification"]["status"], "source_headword_mismatch_requires_relocation")
        hist=e["source_provenance"]["misattribution_history"]
        self.assertEqual((hist["pdf_page"], hist["printed_page"]), (21,17))
        self.assertEqual(hist["printed_headword"],"أُضْحِيَّةٌ")
        self.assertEqual(v["visual_verification"],e["visual_verification"])

    def test_correct_sacrifice_lemma_and_all_ids_preserved(self):
        self.assertEqual(len(self.all_entries),571)
        self.assertEqual(len(set(self.by_id)),571)
        matches=[x for x in self.main if x["id"]=="l1u16_011"]
        self.assertEqual(len(matches),1)
        self.assertEqual(unicodedata.normalize("NFC",matches[0]["arabic"]),unicodedata.normalize("NFC","أُضْحِيَّةٌ"))
        self.assertEqual(self.by_id["bayna_scan_v1_377"]["arabic"],"أَضْحَكَ")
        self.assertEqual(self.by_id["bayna_scan_v1_379"]["arabic"],"أَضْرَارٌ")

    def test_all_other_historic_page_provenance_unchanged(self):
        others=[e for e in self.all_entries if e["id"]!="bayna_scan_v1_378"]
        self.assertEqual(len(others),570)
        self.assertTrue(all(isinstance(e["source_provenance"]["pdf_page"],int) for e in others))
        self.assertEqual(len([e for e in others if e["source_provenance"]["pdf_page"]==21]),27)

if __name__=="__main__": unittest.main()
