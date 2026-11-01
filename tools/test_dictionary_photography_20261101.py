"""Guard the original, independently drafted photography lexicon against accidental merging."""
import json
import re
import unittest
import unicodedata
from audit_dictionary_variants import strip_diacritics
from validate_dictionary import ROOT, load_corpus

CHUNK = "assets/data/entries_editorial_photography_20261101.json"
ARABIC = re.compile(r"[\u0621-\u064a]")
MARK = re.compile(r"[\u064b-\u065f\u0670]")
FOREIGN = re.compile(r"[A-Za-zА-Яа-яЁё]")

class PhotographyBatchTests(unittest.TestCase):
    def test_editorial_fields_and_independent_provenance(self):
        manifest = json.loads((ROOT / "assets/data/corpus_manifest.json").read_text("utf-8"))
        self.assertIn(CHUNK, manifest["files"])
        doc = json.loads((ROOT / CHUNK).read_text("utf-8"))
        self.assertEqual(doc["schema_version"], 3)
        self.assertEqual(doc["source_status"], "original_independent_arabic_lexicon_not_textbook_collated")
        self.assertEqual(len(doc["entries"]), 20)
        ids, words = set(), set()
        for card in doc["entries"]:
            word = card["arabic"]
            self.assertNotIn(card["id"], ids)
            self.assertNotIn(word, words)
            ids.add(card["id"])
            words.add(word)
            self.assertEqual(word, unicodedata.normalize("NFC", word))
            self.assertTrue(ARABIC.search(word) and MARK.search(word), word)
            self.assertGreaterEqual(len(card["meaning_ar"]), 25, word)
            self.assertGreaterEqual(len(card["usage_note_ar"]), 18, word)
            for field in ("grammar", "collocations", "examples_ar"):
                self.assertTrue(card[field], (word, field))
            self.assertEqual(card["book_references"], [])
            self.assertEqual(card["sources"], [])
            for field in ("grammar","collocations","examples_ar","synonyms","antonyms","additional_meanings_ar"):
                self.assertIsInstance(card[field], list)
            prose = [word, card["meaning_ar"], card["usage_note_ar"]]
            prose += [value for field in ("grammar","collocations","examples_ar","synonyms","antonyms","additional_meanings_ar") for value in card[field]]
            self.assertFalse(FOREIGN.search(" ".join(prose)), word)

    def test_new_headwords_do_not_shadow_old_senses_or_create_unreviewed_homographs(self):
        corpus = load_corpus()
        self.assertIn(CHUNK, corpus["files"])
        new_cards = json.loads((ROOT / CHUNK).read_text("utf-8"))["entries"]
        existing_words = set()
        existing_ids = set()
        for filename in corpus["files"]:
            if filename == CHUNK:
                continue
            cards = json.loads((ROOT / filename).read_text("utf-8"))["entries"]
            existing_words.update(strip_diacritics(c["arabic"]) for c in cards)
            existing_ids.update(c["id"] for c in cards)
        self.assertTrue(all(c["id"] not in existing_ids for c in new_cards))
        overlapping = [c["arabic"] for c in new_cards if strip_diacritics(c["arabic"]) in existing_words]
        self.assertFalse(overlapping, "Editorial review needed for existing spelling: " + repr(overlapping))
        self.assertEqual(len({strip_diacritics(c["arabic"]) for c in new_cards}), len(new_cards))

if __name__ == "__main__":
    unittest.main()
