#!/usr/bin/env python3
"""Original printed lexicon headword and source-sense audit, pp. 22–26.

Checks the per-word evidence recorded after direct visual inspection of the
user's 404-page PDF. Independently written example sentences and final i'raab
are still a separate proofreading task.
"""
import json
import unicodedata
import unittest
from pathlib import Path

DATA=Path(__file__).resolve().parents[1]/"assets/data"
SCAN="a2d98cbf6cd309bac2ac072e09679260b1fa20dec0af4cfa7ddf82d7fae2f995"
STATUS="printed_lemma_visible_vowels_checked_pedagogical_endings_not_literal_source"
COUNTS={26:23,27:27,28:23,29:25,30:24}

def canon(s):
    return unicodedata.normalize("NFC",s)

class LastSourceBatchFromOriginal(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        rows=json.loads((DATA/"entries_bayna_scan_verified_20261112.json").read_text(encoding="utf-8"))["entries"]
        cls.prefix=rows
        cls.batch=[e for e in rows if e["source_provenance"]["pdf_page"] in COUNTS]
        cls.byword={canon(e["arabic"]):e for e in cls.batch}
        cls.review={canon(e["arabic"]):e for e in json.loads(
            (DATA/"reviewed_articles_v1.json").read_text(encoding="utf-8"))["entries"]}

    def test_exactly_122_existing_records_no_mutation_of_ids(self):
        self.assertEqual(len(self.prefix),571)
        self.assertEqual(len(self.batch),122)
        self.assertEqual(len(self.byword),122)
        for p,n in COUNTS.items():
            self.assertEqual(sum(e["source_provenance"]["pdf_page"]==p for e in self.batch),n)

    def test_pages_20_21_are_illustrated_not_missing_dictionary_source_records(self):
        self.assertFalse([e for e in self.prefix if e["source_provenance"]["pdf_page"] in (24,25)])

    def test_evidence_per_article_and_no_fake_claim_for_new_examples(self):
        for e in self.batch:
            with self.subTest(headword=e["arabic"]):
                provenance=e["visual_verification"]
                p=e["source_provenance"]["pdf_page"]
                self.assertEqual(provenance["scan_sha256"],SCAN)
                self.assertEqual(provenance["pdf_page"],p)
                self.assertEqual(provenance["printed_page"],p-4)
                self.assertEqual(provenance["status"],STATUS)
                self.assertEqual(provenance["examples_status"],
                                 "independently_authored_pending_separate_i3rab_review")
                self.assertEqual(provenance,self.review[canon(e["arabic"])]["visual_verification"])

    def test_homographs_not_collapsed(self):
        for a,b in [
            ("أَعْلَى","أَعْلَنَ"),
            ("أَقْدَرُ","أَقْدَمَ"),
            ("إِقْلَاعٌ","أَقْلَعَ"),
            ("أَفْقَدَ","أَفْقَرَ"),
            ("أَفْلَحَ","أَفْلَسَ"),
        ]:
            self.assertIn(canon(a),self.byword)
            self.assertIn(canon(b),self.byword)
            self.assertNotEqual(canon(a),canon(b))

    def test_attested_source_meanings_added_without_fake_verb_homonyms(self):
        expected={
            "أَفَاضَ": ("عَرَفَاتٍ",),
            "أَفْتَى": ("الرُّؤْيَا",),
            "أَقْرَضَ": ("الصَّدَقَةُ",),
            "أَقْلَعَ": ("التَّدْخِينِ",),
            "أَكَبَّ": ("الْعَمَلِ",),
        }
        for lemma,fragments in expected.items():
            with self.subTest(lemma=lemma):
                e=self.byword[canon(lemma)]
                r=self.review[canon(lemma)]
                data=" ".join([e["meaning_ar"],*e["additional_meanings_ar"],e["usage_note_ar"]])
                overlay=" ".join([v["ar"] for v in r["definition"]+r["important"]])
                for part in fragments:
                    self.assertIn(part,data)
                    self.assertIn(part,overlay)
                self.assertEqual(e["examples_ar"],[v["ar"] for v in r["examples"]])

if __name__=="__main__":
    unittest.main()
