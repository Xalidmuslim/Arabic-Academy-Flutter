"""All 38 lexical enrichment cards should be usable independently.

The editor has a separate optional enrichment file, but raw source cards still
need grammatical context and pedagogical example sentences. The full raw audit
must not hide holes simply because another file has the same headword.
"""
import json
import unicodedata
import unittest

from audit_dictionary_raw_cards import inspect_raw_cards
from audit_dictionary_variants import iter_corpus_chunks
from validate_dictionary import ROOT


class EnrichmentSourceCardQuality(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = json.loads(
            (ROOT / "assets/data/entries_editorial_enrichment_l4.json").read_text(encoding="utf-8")
        )

    def test_all_38_enrichment_cards_have_grammar_collocations_and_examples(self):
        self.assertEqual(len(self.data["entries"]), 38)
        for e in self.data["entries"]:
            with self.subTest(card=e["id"]):
                self.assertTrue(e["grammar"])
                self.assertTrue(e["collocations"])
                self.assertTrue(e["examples_ar"])
                self.assertTrue(all(isinstance(s, str) and len(s) >= 10 for s in e["examples_ar"]))

    def test_grammar_notes_are_lexical_and_not_generic_filler(self):
        for entry in self.data["entries"]:
            with self.subTest(card=entry["id"]):
                for note in entry["grammar"]:
                    self.assertNotIn("يُسْتَعْمَلُ لِتَسْمِيَةِ الْمَعْنَى", note)
                    self.assertTrue(note.startswith(("مَصْدَرٌ", "اِسْمٌ", "اِسْمُ فَاعِلٍ")))

    def test_all_raw_headwords_are_unicode_nfc(self):
        mismatches = [
            (path, e.get("id"), e.get("arabic"))
            for path, e in iter_corpus_chunks()
            if isinstance(e.get("arabic"), str)
            and e["arabic"] != unicodedata.normalize("NFC", e["arabic"])
        ]
        self.assertEqual([], mismatches)

    def test_no_raw_source_card_is_unexplained_or_missing_core_metadata(self):
        report = inspect_raw_cards(iter_corpus_chunks())
        self.assertEqual(0, report["repeated_card_ids"])
        self.assertEqual(0, report["invalid_definition_cards"])
        self.assertEqual(0, report["invalid_script_cards"])
        self.assertEqual(0, report["missing_grammar"])
        self.assertEqual(0, report["missing_collocations"])
        self.assertEqual(0, report["missing_examples"])
        self.assertEqual(0, report["non_nfc_headword_cards"])


if __name__ == "__main__":
    unittest.main()
