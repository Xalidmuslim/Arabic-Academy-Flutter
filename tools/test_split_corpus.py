import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import validate_dictionary


class SplitCorpusTests(unittest.TestCase):
    def test_repeated_headword_merges_but_maintains_stable_id_and_refs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            a = root / "a.json"
            b = root / "b.json"
            manifest = root / "manifest.json"
            old = {"entries": [{"id": "original", "arabic": "عِلْمٌ",
                "meaning_ar": "مَعْرِفَةٌ تُكْتَسَبُ بِالتَّعَلُّمِ.",
                "book_reference": {"book": 1, "chapter": 7, "index": 1}}]}
            newer = {"entries": [{"id": "new", "arabic": "عِلْمٌ",
                "meaning_ar": "مَعْرِفَةٌ",
                "book_reference": {"book": 2, "chapter": 7, "index": 2}}]}
            a.write_text(json.dumps(old, ensure_ascii=False), encoding="utf-8")
            b.write_text(json.dumps(newer, ensure_ascii=False), encoding="utf-8")
            manifest.write_text(json.dumps({"files": [str(a), str(b)]}),
                                encoding="utf-8")
            with patch.object(validate_dictionary, "MANIFEST", manifest):
                result = validate_dictionary.load_corpus()
            self.assertEqual(len(result["entries"]), 1)
            entry = result["entries"][0]
            self.assertEqual(entry["id"], "original")
            self.assertEqual(entry["meaning_ar"], old["entries"][0]["meaning_ar"])
            self.assertEqual({r["book"] for r in entry["book_references"]}, {1, 2})

    def test_appends_distinct_secondary_meanings_from_later_chunks(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            a, b, manifest = (root / n for n in ("a.json", "b.json", "manifest.json"))
            old = {"entries": [{
                "id": "canonical", "arabic": "بَيْتٌ",
                "meaning_ar": "مَسْكَنٌ يَعِيشُ فِيهِ النَّاسُ.",
                "additional_meanings_ar": ["أَسْرَةٌ تَعِيشُ فِي الْمَنْزِلِ."],
                "examples_ar": ["هَذَا بَيْتٌ وَاسِعٌ."],
                "grammar": ["اِسْمٌ"],
                "collocations": ["بَيْتٌ جَمِيلٌ"],
                "usage_note_ar": "",
            }]}
            newer = {"entries": [{
                "id": "editorial", "arabic": "بَيْتٌ",
                "meaning_ar": "مَسْكَنٌ.",
                "additional_meanings_ar": [
                    "أَسْرَةٌ تَعِيشُ فِي الْمَنْزِلِ.",
                    "جُمْلَةٌ شِعْرِيَّةٌ تَتَكَوَّنُ مِنْ شَطْرَيْنِ."],
                "examples_ar": ["حَفِظْتُ بَيْتًا مِنَ الشِّعْرِ."],
                "grammar": ["اِسْمٌ"],
                "collocations": ["بَيْتٌ مِنَ الشِّعْرِ"],
                "usage_note_ar": "بَيْتُ الشِّعْرِ جَمْعُهُ أَبْيَاتٌ.",
            }]}
            a.write_text(json.dumps(old, ensure_ascii=False), encoding="utf-8")
            b.write_text(json.dumps(newer, ensure_ascii=False), encoding="utf-8")
            manifest.write_text(json.dumps({"files": [str(a), str(b)]}), encoding="utf-8")
            with patch.object(validate_dictionary, "MANIFEST", manifest):
                entry = validate_dictionary.load_corpus()["entries"][0]
            self.assertEqual(entry["id"], "canonical")
            self.assertEqual(entry["meaning_ar"], old["entries"][0]["meaning_ar"])
            self.assertEqual(len(entry["additional_meanings_ar"]), 2)
            self.assertEqual(len(entry["grammar"]), 1)
            self.assertEqual(len(entry["examples_ar"]), 2)
            self.assertEqual(len(entry["collocations"]), 2)
            self.assertEqual(entry["usage_note_ar"], newer["entries"][0]["usage_note_ar"])

    def test_manifest_must_list_at_least_one_existing_chunk(self):
        with tempfile.TemporaryDirectory() as directory:
            manifest = Path(directory) / "manifest.json"
            manifest.write_text('{"files":[]}', encoding="utf-8")
            with patch.object(validate_dictionary, "MANIFEST", manifest):
                with self.assertRaises(AssertionError):
                    validate_dictionary.load_corpus()


if __name__ == "__main__":
    unittest.main()
