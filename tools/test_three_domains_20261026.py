"""Acceptance: independent Arabic-Arabic lexicon for arts, sport and planning.

These entries are original explanatory cards, NOT checked textbook vocabulary.
CI is intentionally content-only: no Flutter or Android build.
"""
import json
import re
import unittest
from pathlib import Path
from validate_dictionary import ROOT, load_corpus

DOMAINS = ("arts_media", "sports_recreation", "time_planning")
CHUNKS = [f"assets/data/entries_nouns_{domain}_20261026.json" for domain in DOMAINS]
DIACRITICS = re.compile(r"[\u064b-\u0652]")
NON_ARABIC_SCRIPTS = re.compile(r"[A-Za-zА-Яа-яЁё]")
UNVOWELLED = re.compile(r"[\u064b-\u065f\u0670\u06d6-\u06ed]")


class NewDomainNounsTest(unittest.TestCase):
    def test_articles_are_registered_unique_and_well_formed(self):
        manifest = json.loads((ROOT / "assets/data/corpus_manifest.json").read_text("utf-8"))
        cards = []
        for filename in CHUNKS:
            self.assertIn(filename, manifest["files"], filename)
            chunk = json.loads((ROOT / filename).read_text("utf-8"))
            self.assertEqual(chunk["schema_version"], 3)
            self.assertEqual(chunk["source_status"], "original_independent_arabic_lexicon_not_textbook_collated")
            self.assertGreaterEqual(len(chunk["entries"]), 90, filename)
            cards.extend(chunk["entries"])
        self.assertGreaterEqual(len(cards), 300)
        self.assertEqual(len(cards), len({entry["id"] for entry in cards}))
        self.assertEqual(len(cards), len({entry["arabic"] for entry in cards}))
        for entry in cards:
            lemma = entry["arabic"]
            self.assertTrue(DIACRITICS.search(lemma), lemma)
            self.assertGreaterEqual(len(entry["meaning_ar"]), 25, lemma)
            self.assertGreaterEqual(len(entry["usage_note_ar"]), 18, lemma)
            for field in ("grammar", "collocations", "examples_ar"):
                self.assertTrue(entry[field], (lemma, field))
            self.assertEqual(entry["book_references"], [], lemma)
            self.assertEqual(entry["sources"], [], lemma)
            for field in ("grammar", "collocations", "examples_ar", "additional_meanings_ar",
                          "synonyms", "antonyms"):
                self.assertIsInstance(entry[field], list, lemma)
            lexical = [lemma, entry["meaning_ar"], entry["usage_note_ar"]]
            lexical += [v for field in ("grammar", "collocations", "examples_ar", "additional_meanings_ar",
                                       "synonyms", "antonyms") for v in entry[field]]
            self.assertFalse(NON_ARABIC_SCRIPTS.search(" ".join(lexical)), lemma)
        corpus = {item["arabic"] for item in load_corpus()["entries"]}
        self.assertTrue({entry["arabic"] for entry in cards}.issubset(corpus))


if __name__ == "__main__":
    unittest.main()
