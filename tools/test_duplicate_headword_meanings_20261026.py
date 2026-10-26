"""Regression tests: merging two headword cards must not drop a definition."""
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import validate_dictionary


def article(identifier, meaning, additional=None):
    return {
        "id": identifier,
        "arabic": "بَيْتٌ",
        "meaning_ar": meaning,
        "additional_meanings_ar": additional or [],
        "grammar": ["اِسْمٌ"],
        "collocations": ["بَيْتٌ كَبِيرٌ"],
        "examples_ar": ["دَخَلَ الرَّجُلُ الْبَيْتَ."],
        "usage_note_ar": "يَتَحَدَّدُ الْمَعْنَى بِحَسَبِ السِّيَاقِ.",
        "synonyms": [],
        "antonyms": [],
        "book_references": [],
        "sources": [],
    }


class DuplicateHeadwordMergeTest(unittest.TestCase):
    def test_distinct_primary_meanings_survive_repeated_cards(self):
        home = "مَكَانٌ يَسْكُنُ فِيهِ الْإِنْسَانُ مَعَ أَهْلِهِ."
        poetry = "وَحْدَةٌ مِنَ الشِّعْرِ تَتَكَوَّنُ مِنْ شَطْرَيْنِ."
        extra = "اسْمٌ يُطْلَقُ عَلَى أَهْلِ الدَّارِ فِي بَعْضِ السِّيَاقَاتِ."
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            parts = [
                article("first", home),
                article("second", poetry, [extra]),
                article("third", poetry),
            ]
            for index, entry in enumerate(parts):
                (root / f"part{index}.json").write_text(
                    json.dumps({"entries": [entry]}, ensure_ascii=False), encoding="utf-8"
                )
            manifest = root / "manifest.json"
            manifest.write_text(
                json.dumps({"files": [f"part{i}.json" for i in range(3)]}),
                encoding="utf-8",
            )
            with patch.object(validate_dictionary, "ROOT", root), patch.object(
                validate_dictionary, "MANIFEST", manifest
            ):
                merged = validate_dictionary.load_corpus()["entries"]

        self.assertEqual(len(merged), 1)
        self.assertEqual(merged[0]["id"], "first")
        self.assertEqual(merged[0]["meaning_ar"], home)
        self.assertEqual(merged[0]["additional_meanings_ar"], [poetry, extra])
        self.assertEqual(merged[0]["book_references"], [])


if __name__ == "__main__":
    unittest.main()
