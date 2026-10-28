"""Prevent generic grammar placeholders in legal and medical dictionary cards."""
import json
import unittest
import unicodedata

from validate_dictionary import ROOT


class EditorialGrammarTagTests(unittest.TestCase):
    def test_law_and_health_headwords_use_specific_nominal_categories(self):
        for filename in (
            "entries_editorial_law_civics_20261027.json",
            "entries_editorial_health_anatomy_20261027.json",
        ):
            data = json.loads((ROOT / "assets/data" / filename).read_text(encoding="utf-8"))
            self.assertGreaterEqual(len(data["entries"]), 100)
            for item in data["entries"]:
                with self.subTest(file=filename, word=item["arabic"]):
                    expected = "تَرْكِيبٌ اسْمِيٌّ" if " " in item["arabic"].strip() else "اِسْمٌ"
                    self.assertEqual(len(item["grammar"]), 1)
                    actual = unicodedata.normalize("NFC", item["grammar"][0])
                    normalized_expected = unicodedata.normalize("NFC", expected)
                    self.assertTrue(
                        actual == normalized_expected
                        or actual.startswith(normalized_expected + "؛"),
                        f"Unexpected grammatical category for {item['arabic']}: {item['grammar']}",
                    )


if __name__ == "__main__":
    unittest.main()
