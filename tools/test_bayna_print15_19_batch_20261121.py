#!/usr/bin/env python3
"""Print pages 15-19/PDF 19-23: 138 printed headings vs. 136 original scan records.

Paper source proves printed words/short glosses only; separate Arabic grammar
and independently authored examples are not automatically editorially certified.
"""
import json
import unicodedata
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
DATA=ROOT/"assets/data"
SHA="a2d98cbf6cd309bac2ac072e09679260b1fa20dec0af4cfa7ddf82d7fae2f995"
AUDIT=ROOT/"research/dictionary_sources/printed_pages15_19_visual_reconciliation_20261121.json"
RESTORED="assets/data/entries_bayna_print15_19_restored_20261121.json"

def nfc(s):
    return unicodedata.normalize("NFC",s)

class OriginalPrintedPagesFifteenNineteen(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.scan=json.loads((DATA/"entries_bayna_scan_verified_20261112.json").read_text(encoding="utf-8"))["entries"]
        cls.manifest=json.loads((DATA/"corpus_manifest.json").read_text(encoding="utf-8"))["files"]
        cls.restored=json.loads((ROOT/RESTORED).read_text(encoding="utf-8"))["entries"]
        cls.reviewed=json.loads((DATA/"reviewed_articles_v1.json").read_text(encoding="utf-8"))["entries"]
        cls.audit=json.loads(AUDIT.read_text(encoding="utf-8"))

    def test_all_138_printed_blocks_in_five_pages(self):
        a=self.audit
        self.assertEqual(a["scan_sha256"],SHA)
        self.assertEqual((a["pdf_first"],a["pdf_last"]),(19,23))
        self.assertEqual(a["total_printed_heading_blocks"],138)
        self.assertEqual(a["existing_scan_attributed_records"],136)
        self.assertEqual(a["exact_scan_heading_matches"],135)
        self.assertEqual(a["original_scan_mismatches"],1)
        self.assertEqual(a["original_scan_absent_headwords"],1)
        self.assertEqual(a["repeated_printed_lexeme_blocks"],1)
        actual={x["pdf_page"]:len(x["headings"]) for x in a["pages"]}
        self.assertEqual(actual,{19:30,20:26,21:28,22:22,23:32})
        self.assertEqual(sum(actual.values()),138)
        for p in a["pages"]:
            self.assertEqual(p["printed_page"],p["pdf_page"]-4)
            for j,x in enumerate(p["headings"],1):
                self.assertEqual(x["position"],j)
                self.assertEqual(nfc(x["headword"]),x["headword"])

    def test_source_page_16_previously_missing_comparative_restored(self):
        self.assertIn(RESTORED,self.manifest)
        self.assertEqual(len(self.restored),1)
        x=self.restored[0]
        self.assertEqual(x["id"],"bayna_print15_19_restored_20261121_001")
        self.assertEqual(x["arabic"],"أَصْلَحُ")
        self.assertEqual((x["source_provenance"]["pdf_page"],x["source_provenance"]["printed_page"]),(20,16))
        self.assertEqual(x["visual_verification"]["scan_sha256"],SHA)
        self.assertEqual(x["visual_verification"]["examples_status"],"independently_authored_pending_separate_i3rab_review")
        self.assertEqual(x["book_references"],[])
        self.assertGreaterEqual(len(x["examples_ar"]),2)
        self.assertGreaterEqual(len(x["grammar"]),2)
        self.assertEqual(x["synonyms"],[])
        self.assertEqual(x["antonyms"],[])
        ov=next(z for z in self.reviewed if nfc(z["arabic"])==nfc(x["arabic"]))
        self.assertEqual([z["ar"] for z in ov["grammar"]],x["grammar"])
        self.assertEqual([z["ar"] for z in ov["examples"]],x["examples_ar"])
        self.assertEqual(ov["visual_verification"],x["visual_verification"])

    def test_verb_and_existing_sacrifice_lemma_not_overwritten(self):
        scan={x["id"]:x for x in self.scan}
        old=scan["bayna_scan_v1_360"]
        self.assertEqual(old["arabic"],"أَصْلَحَ")
        self.assertEqual(old["source_provenance"]["pdf_page"],20)
        old_sacrifice=scan["bayna_scan_v1_378"]
        self.assertEqual(old_sacrifice["arabic"],"أَضْحَى")
        self.assertEqual(old_sacrifice["visual_verification"]["status"],"source_headword_mismatch_requires_relocation")
        self.assertIn("أُضْحِي",old_sacrifice["visual_verification"]["printed_headword"])
        main=json.loads((DATA/"entries.json").read_text(encoding="utf-8"))["entries"]
        match=[x for x in main if x["id"]=="l1u16_011"]
        self.assertEqual(len(match),1)
        self.assertEqual(nfc(match[0]["arabic"]),nfc("أُضْحِيَّةٌ"))

    def test_two_printed_senses_of_one_plural_without_duplicate_card(self):
        page=next(x for x in self.audit["pages"] if x["pdf_page"]==23)
        print_occurrences=[x for x in page["headings"] if x["headword"]=="أَعْرَاضٌ"]
        self.assertEqual(len(print_occurrences),2)
        self.assertNotEqual(print_occurrences[0]["printed_singular"],print_occurrences[1]["printed_singular"])
        x=next(x for x in self.scan if x["id"]=="bayna_scan_v1_439")
        self.assertEqual(x["arabic"],"أَعْرَاضٌ")
        defs=[x["meaning_ar"],*x["additional_meanings_ar"]]
        self.assertTrue(any("الْمَرَضِ" in y for y in defs))
        self.assertTrue(any("الشَّرَفُ" in y or "شَرَفِهِمْ" in y for y in defs))
        article=next(z for z in self.reviewed if z["arabic"]=="أَعْرَاضٌ")
        self.assertEqual([e["ar"] for e in article["definition"]],defs)

    def test_no_duplicate_or_loss_of_corpus_ids(self):
        self.assertEqual(len(self.manifest),90)
        self.assertEqual(len(self.reviewed),685)
        ids=set()
        forms=[]
        for path in self.manifest:
            entries=json.loads((ROOT/path).read_text(encoding="utf-8"))["entries"]
            for e in entries:
                self.assertNotIn(e["id"],ids)
                ids.add(e["id"])
                forms.append(nfc(e["arabic"]))
        self.assertEqual(forms.count(nfc("أَصْلَحُ")),1)
        self.assertEqual(forms.count(nfc("أَعْرَاضٌ")),1)
        self.assertIn("bayna_scan_v1_360",ids)
        self.assertIn("bayna_scan_v1_378",ids)
        self.assertIn("bayna_scan_v1_439",ids)
        self.assertIn("l1u16_011",ids)
        self.assertIn("bayna_print15_19_restored_20261121_001",ids)

if __name__=="__main__":
    unittest.main()
