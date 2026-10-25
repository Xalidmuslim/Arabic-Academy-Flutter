"""Tests independently authored fourth-level candidate vocabulary without claiming book collation."""
import unittest
from validate_dictionary import load_corpus

class FourthLevelDraftTests(unittest.TestCase):
    def test_all_sixteen_candidate_themes_have_definitions_and_examples(self):
        corpus = load_corpus()
        positions = {}
        for entry in corpus["entries"]:
            refs = entry.get("book_references")
            if refs is None:
                refs = [entry["book_reference"]] if entry.get("book_reference") else []
            for ref in refs:
                if ref.get("book") != 4:
                    continue
                chapter = ref["chapter"]
                positions.setdefault(chapter, []).append(ref["index"])
                self.assertFalse(ref.get("official_end_glossary_checked", False))
                self.assertTrue(ref.get("chapter_title_not_verified", False))
                self.assertGreater(len(entry["meaning_ar"]), 16)
                self.assertTrue(entry.get("grammar"))
                self.assertTrue(entry.get("collocations"))
                self.assertTrue(entry.get("examples_ar"))
        self.assertEqual(set(positions), set(range(1, 17)))
        for chapter, indices in positions.items():
            self.assertGreaterEqual(len(indices), 20, chapter)
            self.assertEqual(sorted(indices), list(range(1, len(indices) + 1)))

if __name__ == "__main__":
    unittest.main()
