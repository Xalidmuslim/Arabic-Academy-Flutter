"""Structural acceptance for independently written Arabic noun vocabulary.

No textbook chapter attribution is implied. Check does not build APK.
"""
import json
import re
import unittest
from validate_dictionary import ROOT, load_corpus

CHUNKS = [
    "assets/data/entries_nouns_health_20261025.json",
    "assets/data/entries_nouns_education_20261025.json",
    "assets/data/entries_nouns_environment_20261025.json",
    "assets/data/entries_nouns_transport_20261025.json",
    "assets/data/entries_nouns_commerce_20261025.json",
    "assets/data/entries_nouns_technology_20261025.json",
    "assets/data/entries_nouns_community_20261025.json"
]
DIACRITICS = re.compile(r"[\u064b-\u0652]")
UNEXPECTED = re.compile(r"[A-Za-zА-Яа-яЁё]")

class IndependentNounVocabularyTest(unittest.TestCase):
    def test_seven_complete_batches(self):
        manifest=json.loads((ROOT/"assets/data/corpus_manifest.json").read_text("utf-8"))
        entries=[]
        for filename in CHUNKS:
            self.assertIn(filename, manifest["files"])
            part=json.loads((ROOT/filename).read_text("utf-8"))
            self.assertEqual(part["schema_version"],3)
            self.assertEqual(part["source_status"],"independent_editorial_nouns_not_book_collated")
            self.assertGreaterEqual(len(part["entries"]),85,filename)
            entries+=part["entries"]
        self.assertGreaterEqual(len(entries),650)
        self.assertEqual(len(entries),len({item["arabic"] for item in entries}))
        self.assertEqual(len(entries),len({item["id"] for item in entries}))
        for entry in entries:
            lemma=entry["arabic"]
            self.assertRegex(lemma,DIACRITICS)
            self.assertGreaterEqual(len(entry["meaning_ar"]),25,lemma)
            self.assertGreaterEqual(len(entry["usage_note_ar"]),15,lemma)
            for field in ("grammar","collocations","examples_ar"):
                self.assertTrue(entry[field],lemma)
            self.assertEqual(entry["book_references"],[],lemma)
            self.assertEqual(entry["sources"],[],lemma)
            for field in ("grammar","collocations","examples_ar","synonyms","antonyms","additional_meanings_ar"):
                self.assertIsInstance(entry[field],list,lemma)
            arabic=[lemma,entry["meaning_ar"],entry["usage_note_ar"]]
            for field in ("grammar","collocations","examples_ar","additional_meanings_ar","synonyms","antonyms"):
                arabic.extend(entry[field])
            self.assertIsNone(UNEXPECTED.search(" ".join(arabic)),lemma)
        merged={entry["arabic"] for entry in load_corpus()["entries"]}
        self.assertTrue({entry["arabic"] for entry in entries}.issubset(merged))

if __name__=="__main__":
    unittest.main()
