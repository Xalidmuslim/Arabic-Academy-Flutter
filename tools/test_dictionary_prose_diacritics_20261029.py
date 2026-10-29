"""Audits the internal vowelization of Arabic explanations without destructive edits."""
import unittest

from audit_dictionary_prose_diacritics import (
    unvocalized_tokens, partially_vocalized_tokens, audit_prose_diacritics,
)


class DictionaryProseDiacriticsTests(unittest.TestCase):
    def test_fully_vocalized_example_has_no_missing_words(self):
        self.assertEqual(unvocalized_tokens("وَضَعَ الْكِتَابَ عَلَى الطَّاوِلَةِ."), [])

    def test_unvocalized_words_in_meaning_are_detected(self):
        self.assertEqual(unvocalized_tokens("وَضَعَ الكتاب عَلَى الطَّاوِلَةِ."), ["الكتاب"])

    def test_partial_diacritics_in_arabic_prose_are_reviewed_separately(self):
        self.assertEqual(
            partially_vocalized_tokens("وَضَعَ الكتابَ عَلَى الطَّاوِلَةِ."),
            ["الكتابَ"],
        )
        self.assertEqual(
            partially_vocalized_tokens("وَضَعَ الْكِتَابَ عَلَى الطَّاوِلَةِ."),
            [],
        )

    def test_partial_diacritics_are_distinct_from_wholly_unmarked_words(self):
        rows = [("a.json", {
            "id": "a", "arabic": "كِتَابٌ",
            "meaning_ar": "قَرَأَ الكتابَ عَلَى الطَّاوِلَةِ.",
            "usage_note_ar": "تُسْتَعْمَلُ كتب كَثِيرَةٌ.",
            "examples_ar": ["الْكِتَابُ مُفِيدٌ."],
            "grammar": ["اِسْمٌ"], "collocations": ["كِتَابٌ مُفِيدٌ"]
        })]
        report = audit_prose_diacritics(rows)
        self.assertEqual(report["unvocalized_token_occurrences"], 1)
        self.assertEqual(report["partially_vocalized_token_occurrences"], 1)
        self.assertEqual(report["partially_vocalized_tokens"][0]["token"], "الكتابَ")

    def test_only_arabic_tokens_are_checked(self):
        self.assertEqual(unvocalized_tokens("كَتَبَ 2026، ثُمَّ أَضَافَ HTML."), [])

    def test_same_unvocalized_token_in_two_fields_is_counted_twice(self):
        cards = [("sample.json", {
            "id": "a", "arabic": "كِتَابٌ",
            "meaning_ar": "مَجْمُوعَةٌ مِنْ صفحات مَكْتُوبَةٍ.",
            "usage_note_ar": "تُسْتَعْمَلُ صفحات كَثِيرَةٌ.",
            "examples_ar": ["قَرَأَ كِتَابًا."],
            "collocations": ["كِتَابٌ مُفِيدٌ"],
            "grammar": ["اِسْمٌ"],
        })]
        report = audit_prose_diacritics(cards)
        self.assertEqual(report["source_cards"], 1)
        self.assertEqual(report["unvocalized_token_occurrences"], 2)
        self.assertEqual(report["affected_cards"], 1)
        self.assertEqual(report["affected_files"], 1)
        self.assertEqual(report["tokens"][0]["token"], "صفحات")
        self.assertEqual(report["tokens"][0]["count"], 2)
        self.assertEqual(len(report["examples"]), 2)

    def test_audit_does_not_delete_text_or_resolve_linguistic_uncertainty(self):
        rows = [("a.json", {"id": "1", "arabic": "وَجْهَةٌ",
                            "meaning_ar": "الْمَكَانُ الَّذِي يُقْصَدُ.",
                            "usage_note_ar": "", "examples_ar": [],
                            "grammar": [], "collocations": []})]
        self.assertEqual(audit_prose_diacritics(rows)["affected_cards"], 0)


if __name__ == "__main__":
    unittest.main()
