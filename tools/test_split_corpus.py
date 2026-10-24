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

    def test_manifest_must_list_at_least_one_existing_chunk(self):
        with tempfile.TemporaryDirectory() as directory:
            manifest = Path(directory) / "manifest.json"
            manifest.write_text('{"files":[]}', encoding="utf-8")
            with patch.object(validate_dictionary, "MANIFEST", manifest):
                with self.assertRaises(AssertionError):
                    validate_dictionary.load_corpus()


if __name__ == "__main__":
    unittest.main()
