"""Regression tests for known morphology-note contradictions in Arabic cards."""
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FILE = ROOT / "assets" / "data" / "reviewed_articles_v1.json"


class ReviewedArticleNoteTests(unittest.TestCase):
    def test_singular_nouns_never_claim_to_be_a_plural_form(self):
        articles = json.loads(FILE.read_text(encoding="utf-8"))["entries"]
        mistaken = []
        for article in articles:
            grammar = " ".join(item["ar"] for item in article.get("grammar", []))
            notes = " ".join(item["ar"] for item in article.get("important", []))
            if "هَذِهِ صِيغَةُ جَمْعٍ" in notes:
                if not grammar.startswith("جَمْعُ ") and not grammar.startswith("جَمْعٌ"):
                    mistaken.append(article["arabic"])
        self.assertEqual(mistaken, [], f"Singular nouns mislabeled as plurals: {mistaken}")

    def test_week_and_family_singular_are_explicit(self):
        articles = {
            entry["arabic"]: entry
            for entry in json.loads(FILE.read_text(encoding="utf-8"))["entries"]
        }
        for singular, plural in [("أُسْبُوعٌ", "أَسَابِيعُ"), ("أُسْرَةٌ", "أُسَرٌ")]:
            a = articles[singular]
            grammar = " ".join(item["ar"] for item in a["grammar"])
            notes = " ".join(item["ar"] for item in a["important"])
            self.assertIn(plural, grammar)
            self.assertNotIn("هَذِهِ صِيغَةُ جَمْعٍ", notes)


if __name__ == "__main__":
    unittest.main()
