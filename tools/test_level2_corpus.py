"""Corpus extension regression: second level must not overwrite level one."""
import json
import unittest
from pathlib import Path

DB = Path(__file__).resolve().parents[1] / "assets" / "data" / "entries.json"

class SecondLevelContentTests(unittest.TestCase):
    def test_level2_topic_entries_have_complete_arabic_cards(self):
        data = json.loads(DB.read_text(encoding="utf-8"))
        items = data["entries"]
        level2_refs = {}
        for item in items:
            references = item.get("book_references")
            if references is None:
                references = [item["book_reference"]] if item.get("book_reference") else []
            for ref in references:
                if ref["book"] == 2:
                    chapter = ref["chapter"]
                    level2_refs.setdefault(chapter, []).append((ref["index"], item))
                    self.assertFalse(ref["official_end_glossary_checked"])
                    self.assertTrue(item["meaning_ar"])
                    self.assertTrue(item["grammar"])
                    self.assertTrue(item["collocations"])
                    self.assertTrue(item["examples_ar"])
        self.assertGreaterEqual(len(level2_refs), 4)
        for chapter, values in level2_refs.items():
            self.assertGreaterEqual(len(values), 15, chapter)
            self.assertEqual(sorted(index for index, _ in values),
                             list(range(1, len(values) + 1)), chapter)

    def test_preserve_all_sixteen_first_level_chapters(self):
        data = json.loads(DB.read_text(encoding="utf-8"))
        groups = set()
        for item in data["entries"]:
            refs = item.get("book_references")
            if refs is None:
                refs = [item["book_reference"]] if item.get("book_reference") else []
            for ref in refs:
                if ref["book"] == 1:
                    groups.add(ref["chapter"])
        self.assertEqual(groups, set(range(1, 17)))

if __name__ == "__main__":
    unittest.main()
