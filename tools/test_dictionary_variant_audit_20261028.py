"""Regression tests for conservative vocalization/orthography audits.

Similar Arabic skeletons can have unrelated lexical meanings; this diagnostic
must NEVER automatically merge or rewrite such headwords.
"""
import unittest

from audit_dictionary_variants import audit_entries, strip_diacritics, classify_pair


class DictionaryVariantAuditTests(unittest.TestCase):
    def test_strip_diacritics_preserves_letters_that_distinguish_lemmas(self):
        self.assertEqual(strip_diacritics("كِتَابٌ"), "كتاب")
        self.assertEqual(strip_diacritics("كـِتَابٌ"), "كتاب")
        self.assertNotEqual(strip_diacritics("آمَنَ"), strip_diacritics("أَمِنَ"))
        self.assertNotEqual(strip_diacritics("سُورَةٌ"), strip_diacritics("صُورَةٌ"))

    def test_final_diacritic_only_difference_is_not_proof_of_duplicate(self):
        self.assertEqual(classify_pair("كِتَابٌ", "كِتَابُ"), "final_mark_only")
        self.assertEqual(classify_pair("مَدِينَةٌ", "مَدِينَةٍ"), "final_mark_only")
        # Verb vs noun: identical consonants and interior diacritics can be DISTINCT lexemes.
        self.assertEqual(classify_pair("حَلَّ", "حَلٌّ"), "final_mark_only")

    def test_interior_vowels_remain_distinct_not_automatic_duplicates(self):
        self.assertEqual(classify_pair("عَلِمَ", "عُلِمَ"), "vocalization_diff")
        self.assertEqual(classify_pair("عَلَمٌ", "عِلْمٌ"), "vocalization_diff")
        self.assertIsNone(classify_pair("آمَنَ", "أَمِنَ"))
        # Canonical Unicode ordering differences are not new lexical entries.
        self.assertEqual(classify_pair("رَتَّبَ", "رَتَّبَ"), "unicode_equivalent")

    def test_raw_repetition_and_vowel_variants_counted_separately(self):
        entries = [
            ("file1.json", {"id":"a","arabic":"كِتَابٌ","meaning_ar":"وِعَاءٌ مِنْ صَفَحَاتٍ."}),
            ("file2.json", {"id":"b","arabic":"كِتَابٌ","meaning_ar":"مَصْدَرٌ مَكْتُوبٌ."}),
            ("file2.json", {"id":"c","arabic":"كِتَابُ","meaning_ar":"كِتَابٌ فِي نَحْوٍ."}),
            ("file3.json", {"id":"d","arabic":"عَلَمٌ","meaning_ar":"رَايَةٌ."}),
            ("file3.json", {"id":"e","arabic":"عِلْمٌ","meaning_ar":"مَعْرِفَةٌ."}),
            ("file3.json", {"id":"f","arabic":"آمَنَ","meaning_ar":"صَدَّقَ."}),
            ("file4.json", {"id":"g","arabic":"أَمِنَ","meaning_ar":"شَعَرَ بِالسَّلَامَةِ."}),
        ]
        report = audit_entries(entries)
        self.assertEqual(report["raw_entries"], 7)
        self.assertEqual(report["exact_unique"], 6)
        self.assertEqual(report["exact_repeated"], 1)
        self.assertEqual(report["unvocalized_variant_groups"], 2)
        self.assertEqual(report["final_mark_only_groups"], 1)
        self.assertEqual(report["vocalization_diff_groups"], 1)
        self.assertEqual({g["unvocalized"] for g in report["groups"]}, {"كتاب", "علم"})
        case = next(g for g in report["groups"] if g["unvocalized"] == "كتاب")
        self.assertEqual(case["source_files"], ["file1.json", "file2.json"])
        self.assertEqual(case["forms"], ["كِتَابٌ", "كِتَابُ"])

    def test_unknown_or_empty_words_not_grouped(self):
        report = audit_entries([
            ("a.json", {"arabic": ""}),
            ("b.json", {"arabic": ""}),
            ("c.json", {"arabic": "سُؤَالٌ"}),
        ])
        self.assertEqual(report["unvocalized_variant_groups"], 0)


if __name__ == "__main__":
    unittest.main()
