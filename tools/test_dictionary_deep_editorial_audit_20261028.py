"""Deep, non-destructive Arabic dictionary editorial audit.

A dictionary lemma may have legitimate alternatives in full harakat. Findings
from this audit MUST be review cues, not automatic deletion instructions.
"""
import unittest

from audit_dictionary_variants import iter_corpus_chunks

from audit_dictionary_deep_editorial import (
    vowel_coverage, detect_conflicting_metadata, inspect_deep_quality,
    find_wrong_solar_lam,
)


class DeepEditorialAuditTests(unittest.TestCase):
    def test_fully_vocalized_common_nouns_are_not_flagged(self):
        self.assertEqual(vowel_coverage("كِتَابٌ")["missing"], [])
        self.assertEqual(vowel_coverage("الْكِتَابُ")["missing"], [])
        self.assertEqual(vowel_coverage("التَّعْلِيمُ")["missing"], [])
        self.assertEqual(vowel_coverage("مُسْتَقِيمٌ")["missing"], [])

    def test_sun_letter_assimilation_with_prepositions_is_not_missing_sukun(self):
        self.assertEqual(vowel_coverage("لِلتَّنْفِيذِ")["missing"], [])
        self.assertEqual(vowel_coverage("بِالتَّنْقِيطِ")["missing"], [])
        self.assertEqual(vowel_coverage("لِلصُّورَةِ")["missing"], [])
        self.assertEqual(vowel_coverage("بِالرَّشِّ")["missing"], [])
        self.assertEqual(vowel_coverage("اللَّوْنِ")["missing"], [])

    def test_missing_moon_article_sukun_and_stem_harakat_are_flagged(self):
        self.assertIn("ل", vowel_coverage("الأَوْلَوِيَّاتِ")["missing"])
        self.assertIn("م", vowel_coverage("مُمتَازٌ")["missing"])
        self.assertIn("ج", vowel_coverage("آجلٌ")["missing"])

    def test_prefixed_conjunction_and_sun_article_does_not_require_sukun(self):
        self.assertEqual(vowel_coverage("وَالنَّتِيجَةِ")["missing"], [])
        self.assertEqual(vowel_coverage("فَالصُّورَةِ")["missing"], [])

    def test_all_source_headwords_have_no_unmarked_consonants_under_conservative_rules(self):
        offenders = [(p, card["id"], card["arabic"])
                     for p, card in iter_corpus_chunks()
                     if vowel_coverage(card.get("arabic", ""))["missing"]]
        self.assertFalse(offenders, f"{len(offenders)} headwords need orthographic attention: {offenders[:15]}")

    def test_partial_vowels_are_found_not_treated_as_an_absolute_error(self):
        result = vowel_coverage("كِتابٌ")
        self.assertIn("ت", result["missing"])
        self.assertGreater(result["coverage"], 0)
        self.assertLess(result["coverage"], 1)

    def test_distinct_valid_homographs_are_kept(self):
        data = [
            ("a.json", {"id": "a", "arabic": "عَلَمٌ", "meaning_ar": "رَايَةٌ", "grammar": ["اِسْمٌ"], "examples_ar": ["رُفِعَ الْعَلَمُ."]}),
            ("b.json", {"id": "b", "arabic": "عِلْمٌ", "meaning_ar": "مَعْرِفَةٌ", "grammar": ["اِسْمٌ"], "examples_ar": ["الْعِلْمُ نُورٌ."]}),
        ]
        result = inspect_deep_quality(data)
        self.assertEqual(result["repeated_meaning_across_distinct_headwords"], [])
        self.assertEqual(result["headwords_with_incomplete_harakat"], [])

    def test_identical_primary_meaning_for_distinct_words_is_reviewed(self):
        cards = [
            ("a.json", {"id": "a", "arabic": "قَلَمٌ", "meaning_ar": "أَدَاةٌ لِلْكِتَابَةِ."}),
            ("b.json", {"id": "b", "arabic": "مِمْحَاةٌ", "meaning_ar": "أَدَاةٌ لِلْكِتَابَةِ."}),
            ("c.json", {"id": "c", "arabic": "قَلَمٌ", "meaning_ar": "أَدَاةٌ لِلْكِتَابَةِ."}),
        ]
        r = inspect_deep_quality(cards)
        self.assertEqual(len(r["repeated_meaning_across_distinct_headwords"]), 1)
        self.assertEqual(r["repeated_meaning_across_distinct_headwords"][0]["headwords"], ["قَلَمٌ", "مِمْحَاةٌ"])

    def test_self_synonym_and_overlap_are_reviewed_not_deleted(self):
        example = {"id": "x", "arabic": "سَرِيعٌ", "meaning_ar": "يَتَحَرَّكُ بِسُرْعَةٍ.",
                   "synonyms": ["سَرِيعٌ", "عَاجِلٌ"], "antonyms": ["عَاجِلٌ"]}
        r = inspect_deep_quality([("a.json", example)])
        self.assertEqual(len(r["self_synonym"]), 1)
        self.assertEqual(len(r["synonym_antonym_overlap"]), 1)

    def test_grammar_conflicts_are_reported_only_when_exact_word_matches(self):
        rows = [
            ("a.json", {"id": "a", "arabic": "كَاتِبٌ", "meaning_ar": "مَنْ يَكْتُبُ.", "grammar": ["اِسْمٌ"]}),
            ("b.json", {"id": "b", "arabic": "كَاتِبٌ", "meaning_ar": "مَنْ يَكْتُبُ.", "grammar": ["فِعْلٌ مَاضٍ"]}),
            ("c.json", {"id": "c", "arabic": "كَتَبَ", "meaning_ar": "كِتَابَةٌ.", "grammar": ["فِعْلٌ مَاضٍ"]}),
        ]
        conflicts = detect_conflicting_metadata(rows)
        self.assertEqual(len(conflicts), 1)
        self.assertEqual(conflicts[0]["arabic"], "كَاتِبٌ")

    def test_solar_article_must_not_have_lam_sukun_before_shadda(self):
        self.assertEqual(len(find_wrong_solar_lam("الْسَّيْتُوبْلَازْمِ")), 1)
        self.assertEqual(len(find_wrong_solar_lam("وَالْنَّقْلِ")), 1)
        self.assertEqual(find_wrong_solar_lam("بِالتَّعَلُّمِ"), [])
        self.assertEqual(find_wrong_solar_lam("الْكِتَابُ"), [])

    def test_solar_sukun_is_reported_in_source_collocations_not_just_headwords(self):
        cards = [("x.json", {
            "id": "demo", "arabic": "كِتَابٌ", "meaning_ar": "مَجْمُوعَةٌ مِنَ الصَّفَحَاتِ.",
            "collocations": ["الْسَّيْتُوبْلَازْمِ"], "examples_ar": ["قَرَأَ الْكِتَابَ."],
        })]
        report = inspect_deep_quality(cards)
        self.assertEqual(len(report["wrong_solar_article_lam_sukun"]), 1)
        self.assertEqual(report["wrong_solar_article_lam_sukun"][0]["field"], "collocations")

    def test_all_source_arabic_fields_avoid_solar_lam_sukun(self):
        result = inspect_deep_quality(iter_corpus_chunks())
        found = result["wrong_solar_article_lam_sukun"]
        self.assertFalse(
            found,
            f"{len(found)} wrong sun-letter articles; first offenders: {found[:8]}",
        )


if __name__ == "__main__":
    unittest.main()
