"""Guard the independent 2026-10-27 subject-matter vocabulary expansion.

These authored definitions are not asserted to be official textbook entries.
"""
import json
import re
import unittest
from pathlib import Path
from validate_dictionary import ROOT, load_corpus

SUBJECTS = {
    "maritime_navigation": 65,
    "genetics_microbiology": 65,
    "archaeology_history": 65,
    "supply_chain": 65,
    "energy_utilities": 65,
}
FILES = [f"assets/data/entries_editorial_{name}_20261027.json" for name in SUBJECTS]
DIACRITICS = re.compile(r"[\u064b-\u065f\u0670\u06d6-\u06ed\u0640]")
WRONG_SCRIPT = re.compile(r"[A-Za-zА-Яа-яЁё]")

def normalized(word):
    return " ".join(DIACRITICS.sub("", word).split())

class IndependentSubjectExpansionTests(unittest.TestCase):
    def test_five_subjects_are_registered_and_content_complete(self):
        manifest = json.loads((ROOT / "assets/data/corpus_manifest.json").read_text(encoding="utf8"))
        headwords, identifiers = set(), set()
        for domain, minimum in SUBJECTS.items():
            path = f"assets/data/entries_editorial_{domain}_20261027.json"
            self.assertIn(path, manifest["files"])
            data = json.loads((ROOT / path).read_text(encoding="utf8"))
            self.assertEqual(data["schema_version"], 3)
            self.assertEqual(data["source_status"], "original_independent_arabic_lexicon_not_textbook_collated")
            self.assertGreaterEqual(len(data["entries"]), minimum, domain)
            for e in data["entries"]:
                word = e["arabic"]
                normalized_word = normalized(word)
                self.assertNotIn(normalized_word, headwords, word)
                self.assertNotIn(e["id"], identifiers, e["id"])
                headwords.add(normalized_word)
                identifiers.add(e["id"])
                self.assertRegex(word, r"[\u064b-\u0652]")
                self.assertGreaterEqual(len(e["meaning_ar"]), 30, word)
                self.assertGreaterEqual(len(e["usage_note_ar"]), 20, word)
                self.assertTrue(e["grammar"], word)
                self.assertTrue(e["collocations"], word)
                self.assertTrue(e["examples_ar"], word)
                self.assertEqual(e["book_references"], [], word)
                self.assertEqual(e["sources"], [], word)
                texts = [word, e["meaning_ar"], e["usage_note_ar"]]
                for field in ("collocations", "examples_ar", "grammar"):
                    texts.extend(e[field])
                self.assertIsNone(WRONG_SCRIPT.search(" ".join(texts)), word)
        combined = {e["arabic"] for e in load_corpus()["entries"]}
        for path in FILES:
            for e in json.loads((ROOT / path).read_text(encoding="utf8"))["entries"]:
                self.assertIn(e["arabic"], combined)

if __name__ == "__main__":
    unittest.main()
