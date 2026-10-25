"""Fourth-level independently authored thematic draft regression checks.
These editorial themes are NOT official book unit headings or verified glossaries.
"""
import unittest
from validate_dictionary import load_corpus

class LevelFourCandidateTests(unittest.TestCase):
    def test_first_eight_editorial_batches_have_usable_arabic_entries(self):
        groups = {}
        for entry in load_corpus()["entries"]:
            refs = entry.get("book_references", [])
            for ref in refs:
                if ref.get("book") != 4: continue
                if ref["chapter"] not in range(1, 9): continue
                chapter = ref["chapter"]
                groups.setdefault(chapter, []).append(ref["index"])
                self.assertFalse(ref.get("official_end_glossary_checked", False))
                self.assertEqual(ref.get("source_type"), "original_editorial_theme_unverified")
                self.assertTrue(ref.get("chapter_title_not_verified"))
                self.assertTrue(entry["meaning_ar"].strip())
                self.assertTrue(entry["grammar"])
                self.assertTrue(entry["collocations"])
                self.assertTrue(entry["examples_ar"])
        self.assertEqual(set(groups), set(range(1, 9)))
        for chapter in range(1, 9):
            self.assertGreaterEqual(len(groups[chapter]), 25)
            self.assertEqual(sorted(groups[chapter]), list(range(1,len(groups[chapter])+1)))

if __name__ == "__main__":
    unittest.main()
