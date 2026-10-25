"""Regression test for provisional third-level Arabic-to-Arabic corpus."""
import unittest
from validate_dictionary import load_corpus

class ThirdLevelCorpusTests(unittest.TestCase):
    def test_sixteen_advanced_topics_have_explanatory_cards(self):
        data = load_corpus()
        groups = {}
        for entry in data["entries"]:
            refs = entry.get("book_references")
            if refs is None:
                refs = [entry["book_reference"]] if entry.get("book_reference") else []
            for ref in refs:
                if ref.get("book") != 3:
                    continue
                chapter = ref["chapter"]
                groups.setdefault(chapter, []).append(ref["index"])
                self.assertFalse(ref["official_end_glossary_checked"])
                self.assertGreater(len(entry["meaning_ar"]), 14)
                self.assertTrue(entry["grammar"], entry["arabic"])
                self.assertTrue(entry["collocations"], entry["arabic"])
                self.assertTrue(entry["examples_ar"], entry["arabic"])
        self.assertTrue(set(range(1, 17)).issubset(groups.keys()))
        for ch in range(1, 17):
            self.assertGreaterEqual(len(groups[ch]), 20, ch)
            self.assertEqual(sorted(groups[ch]), list(range(1, len(groups[ch])+1)))
if __name__ == "__main__":
    unittest.main()
