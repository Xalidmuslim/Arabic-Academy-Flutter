"""Regression tests for the read-only Bayna Arabic audit."""
import json
import tempfile
import unittest
from pathlib import Path

from bayna_linguistic_audit import audit, iter_entries, root_from_grammar, quran_lookup, to_arabic, valid_arabic, comparable_diac


class FakeMorph:
    def analyze(self, word):
        return [{"root": "كتب", "diac": "كِتَابٌ", "pos": "noun"}]


class BaynaLinguisticAuditTests(unittest.TestCase):
    def test_original_corpus_shape_and_reviewed_overlay(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "assets/data").mkdir(parents=True)
            (root / "assets/data/corpus_manifest.json").write_text(json.dumps({"files": ["assets/data/raw.json"]}), encoding="utf-8")
            raw = {"entries": [{"id": "book-1", "arabic": "كِتَابٌ", "meaning_ar": "شَيْءٌ لِلقِرَاءَةِ.", "grammar": ["اِسْمٌ، وَجَذْرُهُ: ك ـ ت ـ ب."], "examples_ar": ["هَذَا كِتَابٌ."], "synonyms": [], "antonyms": [], "usage_note_ar": "مُفْرَدٌ."}]}
            (root / "assets/data/raw.json").write_text(json.dumps(raw, ensure_ascii=False), encoding="utf-8")
            reviewed = {"entries": [{"arabic": "كِتَابٌ", "definition": [{"ar": "مَجْمُوعَةٌ مِنَ الصَّفَحَاتِ."}], "grammar": [{"ar": "اِسْمٌ مَفْرَدٌ."}], "examples": [{"ar": "هَذَا كِتَابٌ."}], "important": [{"ar": "قِرَاءَةٌ."}], "synonyms": [], "contrasts": []}]}
            (root / "assets/data/reviewed_articles_v1.json").write_text(json.dumps(reviewed, ensure_ascii=False), encoding="utf-8")
            data = list(iter_entries(root))
            self.assertEqual(len(data), 2)
            self.assertEqual(data[0]["id"], "book-1")
            self.assertEqual(data[0]["root"], "كتب")
            self.assertEqual(data[1]["id"], "reviewed:كِتَابٌ")
            self.assertEqual(data[1]["word"], "كِتَابٌ")
            self.assertEqual(data[0]["synonyms"], [])
            before = (root / "assets/data/raw.json").read_bytes()
            result = audit(data, morph=FakeMorph())
            self.assertEqual((root / "assets/data/raw.json").read_bytes(), before)
            self.assertEqual(result["summary"]["entries"], 2)
            self.assertEqual(result["engines"]["camel_tools"], "enabled")
            self.assertFalse(any(x["code"] == "missing_synonyms" for x in result["results"][0]["findings"]))

    def test_optional_fatha_before_alif_is_not_a_diacritic_error(self):
        self.assertEqual(comparable_diac("كِتَابٌ"), comparable_diac("كِتابٌ"))
        self.assertEqual(comparable_diac("بَابٌ"), comparable_diac("بابٌ"))
        self.assertEqual(comparable_diac("جَامِعَةٌ"), comparable_diac("جامِعَةٌ"))
        # Genuine consonantal vowel distinctions must remain visible.
        self.assertNotEqual(comparable_diac("كَتَبَ"), comparable_diac("كُتِبَ"))
        self.assertNotEqual(comparable_diac("كِتَابٌ"), comparable_diac("كُتّابٌ"))

    def test_diacritics_and_foreign_text_flagged_not_fixed(self):
        e = {"id": "1", "word": "كتاب", "meaning": ["Привет"], "grammar": ["اِسْمٌ"], "examples": ["هذا كتاب"], "important": ["معنى"]}
        original = dict(e)
        findings = valid_arabic(e)
        self.assertIn("missing_word_diacritics", [x["code"] for x in findings])
        self.assertIn("non_arabic_meaning", [x["code"] for x in findings])
        self.assertEqual(e, original)

    def test_quran_is_reference_not_proof_of_exact_vowels(self):
        with tempfile.TemporaryDirectory() as folder:
            p = Path(folder) / "corpus.tsv"
            p.write_text("# unchanged corpus header\n(1:2:3:1)\tkitAb\tN\tSTEM|POS:N|LEM:kitAb|ROOT:ktb\n", encoding="utf-8")
            matches = quran_lookup(p, "كِتَابٌ", "كتب", limit=2)
            self.assertEqual(matches[0]["location"], "(1:2:3:1)")
            self.assertEqual(matches[0]["match_type"], "root_reference")
            # Only a reference location is retained in public audit artifacts.
            # Do not reproduce third-party Quranic morphological annotations.
            self.assertEqual(set(matches[0]), {"location", "match_type"})
            self.assertEqual(to_arabic("kitAb"), "كِتاب")
            self.assertEqual(quran_lookup(p, "سَلَامٌ", "سلم"), [])

    def test_root_extraction_and_nonmatching(self):
        self.assertEqual(root_from_grammar(["اِسْمٌ وَجَذْرُهُ: ب ـ و ـ ح."]), "بوح")
        self.assertEqual(root_from_grammar(["اِسْمٌ مَفْرُودٌ."]), "")

    def test_no_claim_of_optional_engines_without_models(self):
        report = audit([{"id": "1", "word": "كِتَابٌ", "meaning": ["مَكْتُوبٌ"], "grammar": ["اِسْمٌ"], "examples": ["هَذَا كِتَابٌ"], "important": ["يُقْرَأُ"]}])
        self.assertEqual(report["engines"], {"camel_tools": "not_run", "quranic_arabic_corpus": "not_run", "camel_parser": "not_run"})

    def test_reject_manifest_escape_outside_repo(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "assets/data").mkdir(parents=True)
            (root / "assets/data/corpus_manifest.json").write_text(json.dumps({"files": ["../../outside.json"]}), encoding="utf-8")
            with self.assertRaises(ValueError):
                list(iter_entries(root))


if __name__ == '__main__':
    unittest.main()
