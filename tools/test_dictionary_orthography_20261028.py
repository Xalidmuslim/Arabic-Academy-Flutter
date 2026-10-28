"""Corpus-level regression checks for conservatively verified Arabic spellings.

Source JSON (not only merged output) is checked: a wrong source lemma
must not be silently hidden by a later merge. Distinct grammatical
homographs remain separate entries.
"""
import unittest

from audit_dictionary_variants import audit_entries, iter_corpus_chunks

# Only exact rejected forms that have another attested spelling for the
# SAME sense. Never add variants with distinct parts of speech here.
WRONG_HEADWORDS = {
    "تَصْحُّرٌ": "تَصَحُّرٌ",                 # Cairo Academy (صحر)
    "مَصْدَاقِيَّةٌ": "مِصْدَاقِيَّةٌ",         # Cairo Academy (صدق)
    "كِفَاءَةٌ": "كَفَاءَةٌ",                 # Cairo Academy (كفأ)
    "مِهَارَةٌ": "مَهَارَةٌ",
    "وَقَايَةٌ": "وِقَايَةٌ",
    "مَقَاوَلٌ": "مُقَاوِلٌ",
    "مُفْتَاحٌ": "مِفْتَاحٌ",
    "مِعَالِجٌ": "مُعَالِجٌ",
    "مَشْكِلَةٌ": "مُشْكِلَةٌ",
    "مَفَاجَأَةٌ": "مُفَاجَأَةٌ",
    "فَئَةٌ": "فِئَةٌ",
    "مَقْبَسٌ": "مِقْبَسٌ",
    "مَقْبَضٌ": "مِقْبَضٌ",
    "مَسْتَنْقَعٌ": "مُسْتَنْقَعٌ",
    "نَيِزَكٌ": "نَيْزَكٌ",
}


def is_unmarked_initial_alif_variant(forms):
    if len(forms) != 2:
        return False
    # All other characters and harakat must be identical.
    return forms[0].removeprefix("اِ") == forms[1].removeprefix("اِ") and (
        forms[0].startswith("اِ") != forms[1].startswith("اِ")
    )


class ArabicOrthographyRegressionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.corpus = list(iter_corpus_chunks())
        cls.report = audit_entries(cls.corpus)

    def test_no_unicode_equivalent_headwords_from_different_raw_cards(self):
        groups = [g for g in self.report["groups"] if g["kind"] == "unicode_equivalent"]
        self.assertEqual([], groups, [(g["unvocalized"], g["forms"]) for g in groups])

    def test_no_initial_alif_mark_variants_for_same_headword(self):
        groups = [
            g for g in self.report["groups"]
            if is_unmarked_initial_alif_variant(g["forms"])
        ]
        self.assertEqual([], groups, [(g["unvocalized"], g["forms"]) for g in groups])

    def test_specific_wrong_dictionary_forms_are_absent(self):
        observed = {e["arabic"] for _, e in self.corpus}
        wrong = sorted(observed.intersection(WRONG_HEADWORDS))
        self.assertEqual([], wrong)

    def test_semantically_distinct_vocalized_pairs_remain_distinct(self):
        # Removing Arabic diacritics blindly would collapse these pairs.
        observed = {e["arabic"] for _, e in self.corpus}
        for a, b in [
            ("حَلَّ", "حَلٌّ"),
            ("سَلَطَةٌ", "سُلْطَةٌ"),
            ("سَنَةٌ", "سُنَّةٌ"),
            ("كُلِّيَّةٌ", "كُلْيَةٌ"),
        ]:
            self.assertIn(a, observed)
            self.assertIn(b, observed)


if __name__ == "__main__":
    unittest.main()
