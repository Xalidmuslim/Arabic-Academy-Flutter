#!/usr/bin/env python3
"""TDD: authoritative scanned 15-19 pages / 137 DISTINCT headwords, 138 print slots.

Verifies source boundary, original IDs, no duplicate headword, individually
extended author examples left pending independent Arabic grammar review.
"""
import json
import unicodedata
import unittest
from collections import Counter
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
DATA=ROOT/"assets/data"
REPORT=ROOT/"research/dictionary_sources/printed_pages15_19_visual_reconciliation_20261119.json"
RESTORE="assets/data/entries_bayna_print15_19_restored_20261119.json"
SHA="a2d98cbf6cd309bac2ac072e09679260b1fa20dec0af4cfa7ddf82d7fae2f995"
BATCH="2026-11-19-original-printed-pages15-19-137-editorial"
EXPECTED={19:(30,15,15),20:(26,12,14),21:(28,12,16),22:(22,10,12),23:(32,14,18)}

def nfc(v): return unicodedata.normalize("NFC",v)

class Printed15To19Batch137(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report=json.loads(REPORT.read_text(encoding="utf8"))
        cls.old=json.loads((DATA/"entries_bayna_scan_verified_20261112.json").read_text(encoding="utf8"))["entries"]
        cls.manifest=json.loads((DATA/"corpus_manifest.json").read_text(encoding="utf8"))["files"]
        cls.reviewed=json.loads((DATA/"reviewed_articles_v1.json").read_text(encoding="utf8"))["entries"]
        cls.restored=json.loads((ROOT/RESTORE).read_text(encoding="utf8"))["entries"]

    def test_visually_collated_138_printed_slots_137_distinct_headwords(self):
        report=self.report
        self.assertEqual(report["scan_sha256"],SHA)
        self.assertEqual(report["printed_slots_count"],138)
        self.assertEqual(report["distinct_vocalized_headwords_count"],137)
        self.assertEqual(len(report["pages"]),5)
        all_slots=[]
        for p, (total,right,left) in EXPECTED.items():
            slots=next(a for a in report["pages"] if a["pdf_page"]==p)["slots"]
            self.assertEqual(len(slots),total)
            self.assertEqual([a["column"] for a in slots],["right"]*right+["left"]*left)
            self.assertEqual([a["column_index"] for a in slots[:right]],list(range(1,right+1)))
            self.assertEqual([a["column_index"] for a in slots[right:]],list(range(1,left+1)))
            for row in slots:
                self.assertEqual(nfc(row["headword"]),row["headword"])
                self.assertEqual(row["printed_page"],p-4)
            all_slots.extend(slots)
        counts=Counter(x["headword"] for x in all_slots)
        self.assertEqual(len(counts),137)
        self.assertEqual([w for w,c in counts.items() if c==2],["أَعْرَاضٌ"])
        homonym=[x for x in all_slots if x["headword"]=="أَعْرَاضٌ"]
        self.assertEqual({x["printed_singular"] for x in homonym},{"عَرَضٌ","عِرْضٌ"})
        self.assertEqual(len([x for x in all_slots if x["headword"]=="أُضْحِيَّةٌ"]),1)

    def test_comparative_and_verb_separated_and_already_present_sacrifice_preserved(self):
        self.assertIn(RESTORE,self.manifest)
        self.assertEqual(len(self.restored),1)
        restored=self.restored[0]
        self.assertEqual(restored["arabic"],"أَصْلَحُ")
        self.assertEqual(restored["id"],"bayna_print15_19_restored_20261119_001")
        self.assertEqual(restored["source_provenance"]["pdf_page"],20)
        self.assertEqual(restored["source_provenance"]["printed_page"],16)
        self.assertEqual(restored["source_provenance"]["scan_sha256"],SHA)
        self.assertIn("pending",restored["visual_verification"]["examples_status"])
        self.assertEqual(restored["synonyms"],[])
        self.assertEqual(restored["antonyms"],[])
        ids,words=[],[]
        for f in self.manifest:
            rows=json.loads((ROOT/f).read_text(encoding="utf8"))["entries"]
            ids.extend(x["id"] for x in rows)
            words.extend(nfc(x["arabic"]) for x in rows)
        self.assertEqual(len(ids),len(set(ids)))
        self.assertEqual(words.count(nfc("أَصْلَحُ")),1)
        self.assertIn("bayna_scan_v1_360",ids)
        self.assertIn("bayna_scan_v1_378",ids)
        self.assertIn("l1u16_011",ids)
        self.assertEqual(words.count(nfc("أَضْحَى")),2)  # Two pre-existing records; no new one created

    def test_every_137_headword_has_individual_editorial_review_with_examples(self):
        forms={nfc(x["headword"]) for p in self.report["pages"] for x in p["slots"]}
        byword={nfc(x["arabic"]):x for x in self.reviewed}
        self.assertEqual(len(forms),137)
        self.assertEqual(len(self.reviewed),685)
        self.assertTrue(forms.issubset(byword))
        for word in forms:
            with self.subTest(word=word):
                entry=byword[word]
                self.assertEqual(entry.get("latest_editorial_batch", entry.get("editorial_batch")), BATCH)
                self.assertGreaterEqual(len(entry["examples"]),2)
                self.assertTrue(entry["important"])
                self.assertTrue(entry["grammar"])
                self.assertTrue(entry["definition"])
                self.assertEqual(entry["visual_verification"]["scan_sha256"],SHA)
                self.assertEqual(entry["visual_verification"]["examples_status"],
                                 "independently_authored_pending_separate_i3rab_review")
                # Pre-existing source strings may have historical combining-mark order.
                # Require canonical NFC for the newly authored note and final example.
                self.assertEqual(nfc(entry["important"][0]["ar"]),entry["important"][0]["ar"])
                self.assertEqual(nfc(entry["examples"][-1]["ar"]),entry["examples"][-1]["ar"])
                self.assertFalse(any("هَذِهِ صِيغَةُ جَمْعٍ؛ وَتَعْيِينُ مُفْرَدِهَا" in t
                                     for t in [x["ar"] for x in entry["important"]]))

    def test_wrong_printed_attributions_do_not_become_verified(self):
        row=next(x for x in self.old if x["id"]=="bayna_scan_v1_378")
        self.assertEqual(row["arabic"],"أَضْحَى")
        self.assertEqual(row["visual_verification"]["status"],
                         "source_headword_mismatch_requires_relocation")
        self.assertEqual(row["visual_verification"]["printed_headword"],
                         "أُضْحِيَّةٌ")
        self.assertEqual(self.report["misattributed_source_ids"],["bayna_scan_v1_378"])

    def test_no_duplicate_honor_and_medical_symptom_lemma(self):
        review={nfc(x["arabic"]):x for x in self.reviewed}["أَعْرَاضٌ"]
        self.assertEqual(len([x for x in self.reviewed if nfc(x["arabic"])=="أَعْرَاضٌ"]),1)
        all_defs=" ".join(d["ar"] for d in review["definition"])
        self.assertIn("مَرَضٍ",all_defs)
        self.assertIn("عِرْضٍ",all_defs)

if __name__=="__main__": unittest.main()
