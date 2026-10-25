"""Regression checks for optional, independently authored Arabic lexicographic enrichment.

The optional overlay must enrich existing entries, never change IDs, or create
fake textbook chapter memberships.
"""
import json
import unittest
from pathlib import Path
from validate_dictionary import MANIFEST, ROOT, load_corpus

OVERLAY = "assets/data/entries_editorial_enrichment_l4.json"

class EditorialEnrichmentTests(unittest.TestCase):
    def test_overlay_enriches_existing_headwords_without_changing_ids(self):
        manifest = json.loads(MANIFEST.read_text(encoding="utf8"))
        self.assertIn(OVERLAY, manifest["files"])
        overlay = json.loads((ROOT / OVERLAY).read_text(encoding="utf8"))["entries"]
        self.assertGreaterEqual(len(overlay), 30)
        self.assertEqual(len({x["arabic"] for x in overlay}), len(overlay))
        self.assertTrue(all(not x.get("book_references") for x in overlay))
        other = manifest["files"][:]
        other.remove(OVERLAY)
        # Forbid new ghost entries: every enriched headword must preexist.
        base = {}
        for path in other:
            for item in json.loads((ROOT / path).read_text(encoding="utf8"))["entries"]:
                base.setdefault(item["arabic"], item["id"])
        corpus = {item["arabic"]: item for item in load_corpus()["entries"]}
        for item in overlay:
            word = item["arabic"]
            self.assertIn(word, base)
            self.assertEqual(corpus[word]["id"], base[word])
            self.assertTrue(corpus[word]["usage_note_ar"])
        self.assertGreaterEqual(sum(bool(x["synonyms"]) for x in overlay), 20)
        self.assertGreaterEqual(sum(bool(x["antonyms"]) for x in overlay), 8)
        self.assertGreaterEqual(sum(bool(x["additional_meanings_ar"]) for x in overlay), 4)

if __name__ == "__main__":
    unittest.main()
