"""Regression gate for the 68 manually reviewed Arabic prose diacritic repairs.

Checks *original source entries*, including cases hidden by lemma deduplication.
Headword spelling and dictionary references must not change.
"""
import json
import unittest
from pathlib import Path

from validate_dictionary import ROOT

MANIFEST = ROOT / "tools/data/reviewed_prose_harakat_20261029.json"


class ReviewedProseHarakatTests(unittest.TestCase):
    def test_all_68_reviewed_instances_are_corrected_in_original_cards(self):
        catalog = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(len(catalog["changes"]), 68)
        loaded = {}
        for case in catalog["changes"]:
            with self.subTest(source=case["file"], card=case["id"], token=case["from"]):
                filename = case["file"]
                if filename not in loaded:
                    source = json.loads((ROOT / filename).read_text(encoding="utf-8"))
                    loaded[filename] = {str(e["id"]): e for e in source["entries"]}
                self.assertIn(case["id"], loaded[filename])
                entry = loaded[filename][case["id"]]
                self.assertTrue(entry["arabic"])
                parts = entry[case["field"]]
                if isinstance(parts, list):
                    parts = parts[case["index"]]
                self.assertIsInstance(parts, str)
                self.assertNotIn(case["from"], parts)
                self.assertIn(case["to"], parts)

    def test_catalog_contains_only_prose_changes_not_lemmas(self):
        data = json.loads(MANIFEST.read_text(encoding="utf-8"))
        for case in data["changes"]:
            self.assertIn(case["field"], (
                "meaning_ar", "usage_note_ar", "examples_ar",
                "collocations", "additional_meanings_ar",
            ))
            self.assertNotEqual(case["from"], case["to"])
            self.assertNotIn(case["from"], data["reviewed_not_changed"])


if __name__ == "__main__":
    unittest.main()
