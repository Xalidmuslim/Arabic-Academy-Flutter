#!/usr/bin/env python3
"""Arabic-only enrichment of 32 existing educational nouns; editorial, not source-print certification."""
import json
import re
import unicodedata
import unittest
from pathlib import Path

DATA = Path(__file__).resolve().parents[1]/"assets"/"data"
SOURCE_FILE = "entries_daily_education_20261025.json"
WORDS = ['مَنْهَجٌ','مُقَرَّرٌ','حِصَّةٌ','مُحَاضَرَةٌ','نَدْوَةٌ','وَرْشَةٌ','مُدَرِّسٌ','مُتَعَلِّمٌ','مُبْتَدِئٌ','مُتَقَدِّمٌ','تَمْرِينٌ','وَاجِبٌ','اِخْتِبَارٌ','اِمْتِحَانٌ','دَرَجَةٌ','نَتِيجَةٌ','مُرَاجَعَةٌ','مُلَخَّصٌ','مِلَفٌّ','شَهَادَةٌ','مَكْتَبَةٌ','فِهْرِسٌ','مَرْجِعٌ','مَوْسُوعَةٌ','قَامُوسٌ','مُعْجَمٌ','مُفْرَدَةٌ','مُصْطَلَحٌ','قَاعِدَةٌ','اِسْتِثْنَاءٌ','تَعْرِيفٌ','مِثَالٌ']


def canonical(word):
    return re.sub(r"[\u064B-\u065F\u0670]+",lambda m: "".join(sorted(m.group(0))),unicodedata.normalize("NFC",word))


class NewEducationalArticles(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.legacy = json.loads((DATA/SOURCE_FILE).read_text("utf-8"))["entries"]
        cls.articles = json.loads((DATA/"reviewed_articles_v1.json").read_text("utf-8"))["entries"]
        cls.by_review={canonical(e["arabic"]):e for e in cls.articles}

    def test_exactly_32_existing_words_have_nontrivial_explanations(self):
        self.assertEqual(len(WORDS),32)
        self.assertEqual(len(set(canonical(w) for w in WORDS)),32)
        source_keys={canonical(e["arabic"]) for e in self.legacy}
        for word in WORDS:
            with self.subTest(word=word):
                k=canonical(word)
                self.assertIn(k,source_keys)
                self.assertIn(k,self.by_review)
                a=self.by_review[k]
                self.assertGreaterEqual(len(a["grammar"]),3)
                self.assertGreaterEqual(len(a["examples"]),2)
                self.assertGreaterEqual(len(a["important"]),1)
                self.assertTrue(a["source_urls"])
                self.assertEqual(a.get("source_text_status"),"existing_corpus_editorial_enrichment_pending_independent_final_i3rab_review")
                self.assertNotIn("source_review",a)
                self.assertNotIn("visual_verification",a)
                for field in ("definition","grammar","synonyms","contrasts","examples","important"):
                    for fact in a[field]:
                        self.assertSetEqual(set(fact),{"ar"})
                        s=fact["ar"]
                        self.assertRegex(s,r"[\u0621-\u064A]")
                        self.assertRegex(s,r"[\u064B-\u065F]")
                        self.assertNotRegex(s,r"[\u0400-\u04FF]")
                        self.assertEqual(unicodedata.normalize("NFC",s),s)

    def test_existing_headwords_and_ids_unchanged(self):
        self.assertEqual(len(self.legacy),77)
        self.assertEqual(len({e["id"] for e in self.legacy}),77)
        self.assertTrue(all(e["source_group"]=="independently_written_everyday_arabic_lexicon" for e in self.legacy))

    def test_sense_sensitive_relations_not_fabricated(self):
        for word in ("مَكْتَبَةٌ","فِهْرِسٌ","مِثَالٌ"):
            self.assertFalse(self.by_review[canonical(word)]["contrasts"])
        syllabus=self.by_review[canonical("مَنْهَجٌ")]
        self.assertTrue(any("مَنَاهِجُ" in x["ar"] for x in syllabus["grammar"]))
        section=self.by_review[canonical("حِصَّةٌ")]
        self.assertTrue(any("حِصَصٌ" in x["ar"] for x in section["grammar"]))
        example=self.by_review[canonical("مِثَالٌ")]
        self.assertTrue(any("أَمْثِلَةٌ" in x["ar"] for x in example["grammar"]))


if __name__=="__main__":
    unittest.main()
