"""Regression coverage for dictionaries' editor-reviewed Arabic lexemes.

Each correction has been checked against the specific sense/usage, rather than
unvocalized equality. Distinct grammatical meanings must remain separate.
"""
import json
import unicodedata
import unittest

from validate_dictionary import ROOT

REPAIRS = {
    ("entries_level3_01_02.json", "l3u01_025"): "حِكْمَةٌ",
    ("entries_level4_draft_07_08.json", "l4draft08_028"): "حِرْفِيٌّ",
    ("entries_nouns_technology_20261025.json", "ind_noun_technology_20261026_045"): "مِلَفٌّ",
    ("entries_semantic_disambiguation_20261025.json", "semantic_polysemy_20261025_054"): "مِلَفٌّ",
    ("entries_verbs_home_20261025.json", "editorial_verbs_home_20261025_018"): "حَلَمَ",
    ("entries_nouns_time_planning_20261026.json", "editorial_time_20261026_040"): "مُهْلَةٌ",
    ("entries_nouns_health_20261025.json", "ind_noun_health_20261025_090"): "جُرْثُومَةٌ",
    ("entries_practical_crafts_20261025.json", "editorial_crafts_20261025_016"): "مَعْجُونٌ",
    ("entries_nouns_environment_20261025.json", "ind_noun_environment_20261026_110"): "سَمَادٌ",
}

def normalized(text):
    return unicodedata.normalize("NFC", text)

class ReviewedLexicalRepairs(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cards = {}
        for filename, _ in REPAIRS:
            if filename not in cls.cards:
                part = json.loads((ROOT / "assets/data" / filename).read_text(encoding="utf-8"))
                cls.cards[filename] = {e["id"]: e for e in part["entries"]}

    def test_headwords_match_the_attested_sense(self):
        self.assertEqual(9, len(REPAIRS))
        for (filename, entry_id), expected in REPAIRS.items():
            with self.subTest(entry_id=entry_id):
                self.assertIn(entry_id, self.cards[filename])
                self.assertEqual(normalized(expected), normalized(self.cards[filename][entry_id]["arabic"]))
                self.assertTrue(self.cards[filename][entry_id]["grammar"])
                self.assertTrue(self.cards[filename][entry_id]["examples_ar"])
                self.assertTrue(self.cards[filename][entry_id]["collocations"])

    def test_grammatical_examples_use_the_corrected_lemmas(self):
        required = {
            "l3u01_025": ["حِكْمَة", "حِكَم"],
            "l4draft08_028": ["حِرْفِي"],
            "ind_noun_technology_20261026_045": ["مِلَف"],
            "semantic_polysemy_20261025_054": ["مِلَف"],
            "editorial_verbs_home_20261025_018": ["حَلَم"],
            "editorial_time_20261026_040": ["مُهْلَة"],
            "ind_noun_health_20261025_090": ["جُرْثُومَة"],
            "editorial_crafts_20261025_016": ["مَعْجُون"],
            "ind_noun_environment_20261026_110": ["سَمَاد"],
        }
        bad_stems = {
            "l3u01_025": ["حَكْمَة"],
            "l4draft08_028": ["حَرْفِي"],
            "ind_noun_technology_20261026_045": ["مَلَف"],
            "semantic_polysemy_20261025_054": ["مَلَف"],
            "editorial_verbs_home_20261025_018": ["حَلُم"],
            "editorial_time_20261026_040": ["مَهْلَة"],
            "ind_noun_health_20261025_090": ["جَرْثُومَة"],
            "editorial_crafts_20261025_016": ["مِعْجُون"],
            "ind_noun_environment_20261026_110": ["سِمَاد"],
        }
        for (filename, entry_id), expected in REPAIRS.items():
            card = self.cards[filename][entry_id]
            context = [card["arabic"]]
            for field in ("grammar", "collocations", "examples_ar", "additional_meanings_ar"):
                context.extend(card.get(field, []))
            context.append(card["usage_note_ar"])
            text = normalized(" ".join(context))
            with self.subTest(entry_id=entry_id):
                for marker in bad_stems[entry_id]:
                    self.assertNotIn(normalized(marker), text, "obsolete headword vowels remained in context")
                self.assertTrue(any(normalized(s) in text for s in required[entry_id]))

    def test_book_references_preserved(self):
        for filename, entry_id in [
            ("entries_level3_01_02.json", "l3u01_025"),
            ("entries_level4_draft_07_08.json", "l4draft08_028"),
        ]:
            self.assertTrue(self.cards[filename][entry_id]["book_references"])


if __name__ == "__main__":
    unittest.main()
