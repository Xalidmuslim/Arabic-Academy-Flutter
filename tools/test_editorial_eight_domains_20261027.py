"""Structural acceptance tests for new independently written Arabic–Arabic dictionary data.

These articles are not claimed to be a verbatim or verified Bayna Yadayk
book glossary. Tests check integration, not full linguistic correctness.
"""
import json
import re
import unittest

from validate_dictionary import ROOT, load_corpus

DOMAINS = (
    "software_networks", "health_anatomy", "law_civics", "finance_accounting",
    "geology_climate", "manufacturing", "communication_media", "mathematics_science",
)
CHUNKS = [f"assets/data/entries_editorial_{name}_20261027.json" for name in DOMAINS]
DIACRITICS = re.compile(r"[\u064b-\u0652]")
BAD_SCRIPTS = re.compile(r"[A-Za-zА-Яа-яЁё]")


class EightDomainEditorialBatchTests(unittest.TestCase):
    def test_800_or_more_independent_cards_have_lexical_fields(self):
        manifest = json.loads((ROOT / "assets/data/corpus_manifest.json").read_text(encoding="utf-8"))
        entries = []
        for path in CHUNKS:
            self.assertIn(path, manifest["files"], path)
            doc = json.loads((ROOT / path).read_text(encoding="utf-8"))
            self.assertEqual(doc["schema_version"], 3, path)
            self.assertEqual(doc["source_status"], "original_independent_arabic_lexicon_not_textbook_collated", path)
            self.assertGreaterEqual(len(doc["entries"]), 95, path)
            entries.extend(doc["entries"])
        self.assertGreaterEqual(len(entries), 800)
        self.assertEqual(len(entries), len({e["id"] for e in entries}))
        self.assertEqual(len(entries), len({e["arabic"] for e in entries}))
        corpus_words = {item["arabic"] for item in load_corpus()["entries"]}
        for entry in entries:
            word = entry["arabic"]
            self.assertIn(word, corpus_words)
            self.assertTrue(DIACRITICS.search(word), word)
            self.assertGreaterEqual(len(entry["meaning_ar"]), 25, word)
            self.assertGreaterEqual(len(entry["usage_note_ar"]), 18, word)
            self.assertTrue(entry["grammar"], word)
            self.assertTrue(entry["collocations"], word)
            self.assertTrue(entry["examples_ar"], word)
            self.assertEqual(entry["book_references"], [], word)
            self.assertEqual(entry["sources"], [], word)
            for field in ("additional_meanings_ar", "grammar", "collocations", "examples_ar", "synonyms", "antonyms"):
                self.assertIsInstance(entry[field], list, (word, field))
            parts = [word, entry["meaning_ar"], entry["usage_note_ar"]]
            parts.extend(x for field in ("additional_meanings_ar", "grammar", "collocations", "examples_ar", "synonyms", "antonyms") for x in entry[field])
            self.assertFalse(BAD_SCRIPTS.search(" ".join(parts)), word)


if __name__ == "__main__":
    unittest.main()
