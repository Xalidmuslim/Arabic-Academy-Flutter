"""Regression: predicate agreement/case in genetics editorial text.

Content QA fixture: checks both the corrected syntax and meaning without
altering the lemma, its ID, or its course provenance.
"""
import json
import unittest

from validate_dictionary import ROOT


class GeneticsEditorialGrammarTests(unittest.TestCase):
    def test_genetic_material_note_has_correct_kana_predicate_case(self):
        path = ROOT / "assets/data/entries_editorial_genetics_microbiology_20261027.json"
        entries = json.loads(path.read_text(encoding="utf-8"))["entries"]
        matches = [e for e in entries
                   if e["id"] == "editorial_genetics_microbiology_20261027_002"]
        self.assertEqual(len(matches), 1)
        entry = matches[0]
        self.assertEqual(entry["arabic"], "مَادَّةٌ وَرَاثِيَّةٌ")
        note = entry["usage_note_ar"]
        self.assertIn("يَكُونُ الْحَمْضُ النَّوَوِيُّ", note)
        self.assertIn("حَامِلَ الْمَعْلُومَاتِ الْوِرَاثِيَّةِ", note)
        self.assertIn("فِي مُعْظَمِ الْكَائِنَاتِ", note)
        self.assertNotIn("هُوَ الْحَمْضَ", note)
        self.assertEqual(entry["book_references"], [])
        self.assertEqual(entry["sources"], [])


if __name__ == "__main__":
    unittest.main()
