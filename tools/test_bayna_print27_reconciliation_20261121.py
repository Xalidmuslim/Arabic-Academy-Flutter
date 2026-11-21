#!/usr/bin/env python3
"""Print27/PDF31: reconcile all visible headings against the full 90-file corpus.

A homograph differing in final haraka is NOT an existing verified headword.
No speculative new entries are created by this audit.
"""
import json
import unicodedata
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
DATA=ROOT/"assets/data"
INDEX=ROOT/"research/dictionary_sources/printed_page27_visual_inventory_20261121.json"
norm=lambda s:unicodedata.normalize("NFC",s)

class PrintedPage27CorpusReconciliation(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report=json.loads(INDEX.read_text(encoding="utf-8"))
        files=json.loads((DATA/"corpus_manifest.json").read_text(encoding="utf-8"))["files"]
        cls.files=files
        cls.existing={}
        for path in files:
            for e in json.loads((ROOT/path).read_text(encoding="utf-8"))["entries"]:
                cls.existing.setdefault(norm(e["arabic"]),[]).append((e["id"],path))

    def test_source_coordinates_and_number_of_headings(self):
        r=self.report
        self.assertEqual((r["pdf_page"],r["printed_page"]),(31,27))
        self.assertEqual(r["source_sha256"],"a2d98cbf6cd309bac2ac072e09679260b1fa20dec0af4cfa7ddf82d7fae2f995")
        self.assertEqual(len(self.files),90)
        self.assertEqual(len(r["headings"]),23)
        self.assertEqual([h["position"] for h in r["headings"]],list(range(1,24)))
        self.assertEqual(len({norm(h["headword"]) for h in r["headings"]}),23)
        self.assertTrue(all(norm(h["headword"])==h["headword"] for h in r["headings"]))

    def test_existing_eight_and_missing_fifteen_are_measured_from_entire_manifest(self):
        found=missing=0
        for h in self.report["headings"]:
            with self.subTest(headword=h["headword"]):
                actual=self.existing.get(norm(h["headword"]),[])
                self.assertEqual(
                    {item["id"] for item in h["existing_corpus_matches"]},
                    {id for id,_ in actual}
                )
                self.assertEqual(
                    h["status"],
                    "already_in_corpus" if actual else "not_present_as_exact_vocalized_lemma"
                )
                if actual:found+=1
                else:missing+=1
        self.assertEqual((found,missing),(8,15))

    def test_comparative_aktharu_is_not_confused_with_verb_akthara(self):
        by={h["headword"]:h for h in self.report["headings"]}
        self.assertEqual(by["أَكْثَرُ"]["existing_corpus_matches"],[])
        self.assertEqual([m["id"] for m in by["أَكْثَرَ"]["existing_corpus_matches"]],
                         ["bayna_scan_20261114_001"])
        self.assertEqual([m["id"] for m in by["أَكْرَمَ"]["existing_corpus_matches"]],
                         ["bayna_scan_20261114_002"])

    def test_preexisting_oxygen_duplicate_does_not_create_a_new_id(self):
        by={h["headword"]:h for h in self.report["headings"]}
        oxygen={m["id"] for m in by["أُكْسِجِينٌ"]["existing_corpus_matches"]}
        self.assertEqual(oxygen,{"l2u15_014","ind_noun_health_20261025_055"})
        self.assertEqual([m["id"] for m in by["أُكْذُوبَةٌ"]["existing_corpus_matches"]],
                         ["bayna_scan_20261114_008"])
        self.assertEqual(self.report["new_dictionary_entries_created"],0)

if __name__=="__main__": unittest.main()
