"""Editorial gate for independent Arabic-to-Arabic verb vocabulary, not textbook-collated."""
import json
import re
import unittest

from validate_dictionary import ROOT, load_corpus

FILES = [
    "assets/data/entries_verbs_home_20261025.json",
    "assets/data/entries_verbs_learning_20261025.json",
    "assets/data/entries_verbs_social_20261025.json",
    "assets/data/entries_verbs_nature_20261025.json",
]


class VerbLexiconTests(unittest.TestCase):
    def test_independent_verb_bundles(self):
        manifest = json.loads((ROOT / "assets/data/corpus_manifest.json").read_text("utf-8"))
        entries = []
        for filename in FILES:
            self.assertIn(filename, manifest["files"])
            data = json.loads((ROOT / filename).read_text("utf-8"))
            self.assertEqual(data["schema_version"], 3)
            self.assertEqual(data["source_status"], "independent_original_unverified_against_books")
            self.assertGreaterEqual(len(data["entries"]), 50)
            entries.extend(data["entries"])
        self.assertGreaterEqual(len(entries), 220)
        self.assertEqual(len({e["arabic"] for e in entries}), len(entries))
        self.assertEqual(len({e["id"] for e in entries}), len(entries))
        for e in entries:
            self.assertTrue(re.search(r"[\u064b-\u0652]", e["arabic"]), e["arabic"])
            self.assertGreaterEqual(len(e["meaning_ar"]), 32, e["arabic"])
            self.assertGreaterEqual(len(e["usage_note_ar"]), 20, e["arabic"])
            self.assertEqual(e["book_references"], [], e["arabic"])
            self.assertEqual(e["sources"], [], e["arabic"])
            for key in ("grammar", "collocations", "examples_ar"):
                self.assertTrue(e[key], e["arabic"])
            for key in ("synonyms", "antonyms", "additional_meanings_ar"):
                self.assertIsInstance(e[key], list)
            self.assertIn("الْمُضَارِعُ", " ".join(e["grammar"]), e["arabic"])
            fields = [e["arabic"], e["meaning_ar"], e["usage_note_ar"]]
            for key in ("grammar", "collocations", "examples_ar", "additional_meanings_ar"):
                fields += e[key]
            self.assertIsNone(re.search(r"[A-Za-zА-Яа-яЁё]", " ".join(fields)), e["arabic"])
        words = {e["arabic"] for e in load_corpus()["entries"]}
        self.assertTrue({e["arabic"] for e in entries}.issubset(words))

if __name__ == "__main__":
    unittest.main()
