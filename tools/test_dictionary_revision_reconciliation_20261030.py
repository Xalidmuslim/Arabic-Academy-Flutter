"""Regression tests: distinguish spelling consolidation from lost dictionary cards."""
import unittest

from audit_dictionary_revision_history import reconcile_cards


class RevisionReconciliationTests(unittest.TestCase):
    def test_changed_vowel_collisions_reduce_unique_count_without_loss(self):
        before = [
            ("a.json", {"id": "a", "arabic": "بَابٌ", "meaning_ar": "أَوَّلٌ"}),
            ("b.json", {"id": "b", "arabic": "بَابُ", "meaning_ar": "ثَانٍ"}),
            ("c.json", {"id": "c", "arabic": "عِلْمٌ", "meaning_ar": "مَعْرِفَةٌ"}),
        ]
        after = [
            ("a.json", {"id": "a", "arabic": "بَابٌ", "meaning_ar": "أَوَّلٌ"}),
            ("b.json", {"id": "b", "arabic": "بَابٌ", "meaning_ar": "ثَانٍ"}),
            ("c.json", {"id": "c", "arabic": "عِلْمٌ", "meaning_ar": "مَعْرِفَةٌ"}),
        ]
        report = reconcile_cards(before, after)
        self.assertEqual(report["before_raw"], 3)
        self.assertEqual(report["after_raw"], 3)
        self.assertEqual(report["before_unique_exact"], 3)
        self.assertEqual(report["after_unique_exact"], 2)
        self.assertEqual(report["net_unique_change"], -1)
        self.assertEqual(report["deleted_ids"], [])
        self.assertEqual(report["added_ids"], [])
        self.assertEqual(report["changed_headwords"], 1)
        self.assertEqual(report["consolidated_headword_groups"], 1)
        self.assertEqual(report["consolidation_details"][0]["after"], "بَابٌ")
        self.assertEqual(report["consolidation_details"][0]["old_forms"], ["بَابٌ", "بَابُ"])

    def test_loss_of_card_is_not_mislabeled_as_consolidation(self):
        before = [
            ("a.json", {"id": "a", "arabic": "بَابٌ"}),
            ("b.json", {"id": "b", "arabic": "قَلَمٌ"}),
        ]
        after = [("a.json", {"id": "a", "arabic": "بَابٌ"})]
        report = reconcile_cards(before, after)
        self.assertEqual(report["deleted_ids"], ["b"])
        self.assertEqual(report["consolidated_headword_groups"], 0)
        self.assertEqual(report["net_unique_change"], -1)

    def test_variants_remain_distinct_when_meanings_differ(self):
        before = [
            ("a.json", {"id": "a", "arabic": "عَلَمٌ"}),
            ("b.json", {"id": "b", "arabic": "عِلْمٌ"}),
        ]
        report = reconcile_cards(before, before)
        self.assertEqual(report["before_unique_exact"], 2)
        self.assertEqual(report["after_unique_exact"], 2)
        self.assertEqual(report["consolidated_headword_groups"], 0)
        self.assertEqual(report["changed_headwords"], 0)

    def test_duplicate_ids_are_rejected_not_silently_overwritten(self):
        with self.assertRaisesRegex(ValueError, "Repeated card id"):
            reconcile_cards(
                [("a.json", {"id": "a", "arabic": "أَوَّلٌ"}),
                 ("b.json", {"id": "a", "arabic": "ثَانٍ"})],
                [],
            )

    def test_classifies_unicode_only_vs_vowel_vs_letter_changes(self):
        before = [
            ("a.json", {"id": "a", "arabic": "تَعَلَّمَ"}),
            ("b.json", {"id": "b", "arabic": "كِتَابٌ"}),
            ("c.json", {"id": "c", "arabic": "كَلْبٌ"}),
        ]
        after = [
            ("a.json", {"id": "a", "arabic": "تَعَلَّمَ"}),
            ("b.json", {"id": "b", "arabic": "كُتَّابٌ"}),
            ("c.json", {"id": "c", "arabic": "قَلْبٌ"}),
        ]
        report = reconcile_cards(before, after)
        self.assertEqual(report["unicode_equivalent_changes"], 1)
        self.assertEqual(report["vocalization_only_changes"], 1)
        self.assertEqual(report["letter_spelling_changes"], 1)
        self.assertEqual(report["changed_headwords"], 3)

    def test_original_card_provenance_and_reference_loss_detected(self):
        old = [("a.json", {
            "id": "a", "arabic": "مَدْرَسَةٌ",
            "book_references": [{"book": 1, "chapter": 2, "index": 2}],
        })]
        new = [("a.json", {
            "id": "a", "arabic": "مَدْرَسَةٌ", "book_references": [],
        })]
        report = reconcile_cards(old, new)
        self.assertEqual(report["references_removed"], 1)


if __name__ == "__main__":
    unittest.main()
