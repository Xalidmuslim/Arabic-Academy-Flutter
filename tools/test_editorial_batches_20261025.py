"""Quality gate for original Arabic-Arabic editorial vocabulary batches."""
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FILES = (
 "assets/data/entries_emotional_literacy_20261025.json",
 "assets/data/entries_rights_procedures_20261025.json",
)
AR = re.compile(r"[\u0621-\u064A]")
LATIN = re.compile(r"[A-Za-zА-Яа-яЁё]")

class EditorialBatchTests(unittest.TestCase):
    def test_two_new_chunks_are_in_manifest_and_form_complete_articles(self):
        manifest = json.loads((ROOT / "assets/data/corpus_manifest.json").read_text(encoding="utf-8"))
        for filename in FILES:
            with self.subTest(filename=filename):
                self.assertIn(filename, manifest["files"])
                blob = json.loads((ROOT / filename).read_text(encoding="utf-8"))
                self.assertEqual(blob["source_status"], "original_editorial_not_book_collated")
                entries = blob["entries"]
                self.assertGreaterEqual(len(entries), 30)
                self.assertEqual(len({x["arabic"] for x in entries}), len(entries))
                for item in entries:
                    self.assertEqual(item["book_references"], [])
                    for key in ("meaning_ar", "usage_note_ar"):
                        self.assertGreaterEqual(len(item[key]), 18, item["arabic"])
                        self.assertTrue(AR.search(item[key]))
                        self.assertFalse(LATIN.search(item[key]))
                    for key in ("grammar", "collocations", "examples_ar"):
                        self.assertTrue(item[key], item["arabic"])
                    for key in ("additional_meanings_ar", "synonyms", "antonyms"):
                        self.assertIsInstance(item[key], list)
                    for field in ("grammar", "collocations", "examples_ar",
                                  "synonyms", "antonyms", "additional_meanings_ar"):
                        for value in item[field]:
                            self.assertFalse(LATIN.search(value), item["arabic"])

if __name__ == "__main__":
    unittest.main()
