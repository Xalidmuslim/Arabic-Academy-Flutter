"""Quality and provenance tests for the independent advanced Arabic dictionary batch."""
import json
import unittest
from pathlib import Path
from validate_dictionary import load_corpus, ROOT, MANIFEST

NEW_CHUNKS = (
    "assets/data/entries_advanced_research_editing_20261025.json",
    "assets/data/entries_advanced_verbs_20261025.json",
)

class IndependentAdvancedArticlesTests(unittest.TestCase):
    def test_advanced_articles_registered_without_false_textbook_references(self):
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        for name in NEW_CHUNKS:
            self.assertIn(name, manifest["files"])
        all_articles = []
        for name in NEW_CHUNKS:
            doc = json.loads((ROOT / name).read_text(encoding="utf-8"))
            all_articles.extend(doc["entries"])
        self.assertGreaterEqual(len(all_articles), 110)
        for item in all_articles:
            self.assertEqual(item.get("book_references"), [])
            self.assertNotIn("book_reference", item)
            self.assertEqual(item.get("editorial_level_hint"), 4)
            self.assertGreater(len(item["meaning_ar"]), 18)
            self.assertTrue(item.get("grammar"), item["arabic"])
            self.assertTrue(item.get("collocations"), item["arabic"])
            self.assertTrue(item.get("examples_ar"), item["arabic"])
        all_words = {word["arabic"] for word in load_corpus()["entries"]}
        self.assertTrue({item["arabic"] for item in all_articles}.issubset(all_words))
        
    def test_multiword_definition_is_explanatory_not_only_synonym(self):
        first = json.loads((ROOT / NEW_CHUNKS[0]).read_text(encoding="utf-8"))["entries"]
        second = json.loads((ROOT / NEW_CHUNKS[1]).read_text(encoding="utf-8"))["entries"]
        for item in first + second:
            self.assertGreater(len(item["meaning_ar"].split()), 6, item["arabic"])


if __name__ == "__main__":
    unittest.main()
