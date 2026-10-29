"""Regression gate for frequent confirmed under-vocalized Arabic prose patterns.

These substitutions are only for prose; never silently alter lemma spellings
or merge distinct entries.
"""
import unittest
from audit_dictionary_variants import iter_corpus_chunks

CONFIRMED_UNDER_VOCALIZED = (
    "كَلام", "عَلاق", "عَلام", "آلي", "اكتَشَف",
    "أَنْماط", "الْهِلال", "يَنْمو", "تَنْمو",
    "خِلاف", "لِلوُصُولِ",
)
PROSE_FIELDS = ("meaning_ar", "usage_note_ar", "examples_ar",
                "collocations", "additional_meanings_ar")


class ConfirmedProseVowelCorrections(unittest.TestCase):
    def test_known_missing_internal_harakat_are_absent_from_all_source_prose(self):
        issues = []
        for filename, entry in iter_corpus_chunks():
            for field in PROSE_FIELDS:
                v = entry.get(field)
                parts = [v] if isinstance(v, str) else v if isinstance(v, list) else []
                for part in parts:
                    for pattern in CONFIRMED_UNDER_VOCALIZED:
                        if pattern in part:
                            issues.append((filename, entry["id"], field, pattern))
        self.assertEqual([], issues[:15], f"{len(issues)} under-vocalized prose strings")


if __name__ == "__main__":
    unittest.main()
