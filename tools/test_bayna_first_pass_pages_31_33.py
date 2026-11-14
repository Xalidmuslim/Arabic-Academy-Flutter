#!/usr/bin/env python3
"""Guard the provenance and Arabic-only status of the November editorial batch."""
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/data/reviewed_articles_v1.json"
EXPECTED = {
    "أَكْثَرَ": 31, "أَكْرَمَ": 31, "أَكْمَلَ": 31,
    "أَكَّدَ": 31, "أَكَلَ": 31, "أُكْذُوبَةٌ": 31, "آلَةٌ": 31,
    "أَلْغَى": 32, "أَلْقَى": 32, "أَلْفٌ": 32,
    "أُلْفَةٌ": 32, "أَلِيمٌ": 32, "أَلْهَمَ": 32,
    "أَمَانَةٌ": 33, "أَمَامَ": 33, "أَمَاطَ": 33,
    "إِمَامٌ": 33, "إِمَارَةٌ": 33, "أُمَّةٌ": 33, "أَمَاتَ": 33,
}
STATUS = "original_printed_headword_and_senses_visually_checked_original_examples_second_pass_pending"


class FirstPassArabicEditorialTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        doc = json.loads(SOURCE.read_text(encoding="utf-8"))
        cls.batch = [e for e in doc["entries"] if e.get("editorial_batch") == "2026-11-14-pages-31-33"]

    def test_every_verified_scan_lemma_resolves_to_dictionary_word(self):
        """All 20 editorial articles must be reachable in the merged dictionary."""
        data = ROOT / "assets/data"
        manifest = json.loads((data / "corpus_manifest.json").read_text(encoding="utf-8"))
        self.assertIn(
            "assets/data/entries_bayna_scan_verified_20261114_pages31_33.json",
            manifest["files"],
        )
        def canon(value):
            return re.sub(r"[\\u064b-\\u065f\\u0670]+",
                          lambda m: "".join(sorted(m.group())), value)
        merged = {}
        for path in manifest["files"]:
            payload = json.loads((ROOT / path).read_text(encoding="utf-8"))
            for word in payload["entries"]:
                merged.setdefault(word["arabic"], word["id"])
        canonical = {}
        for lemma in merged:
            canonical.setdefault(canon(lemma), []).append(lemma)
        for article in self.batch:
            with self.subTest(word=article["arabic"]):
                lemma = article["arabic"]
                equivalents = canonical.get(canon(lemma), [])
                self.assertTrue(equivalents, f"No corpus match for {lemma}")
                self.assertTrue(len(equivalents) == 1 or lemma in equivalents,
                                f"Ambiguous corpus match for {lemma}")

    def test_source_page_images_are_separately_audited(self):
        for article in self.batch:
            with self.subTest(word=article["arabic"]):
                provenance = article["visual_verification"]
                self.assertEqual(
                    provenance["scan_sha256"],
                    "a2d98cbf6cd309bac2ac072e09679260b1fa20dec0af4cfa7ddf82d7fae2f995",
                )
                self.assertEqual(provenance["pdf_page"], EXPECTED[article["arabic"]])
                self.assertEqual(provenance["printed_page"], EXPECTED[article["arabic"]] - 4)
                self.assertEqual(
                    provenance["status"],
                    "printed_lemma_and_senses_visually_checked_examples_independently_authored",
                )

    def test_original_eating_entry_includes_backbiting_sense(self):
        article = next(e for e in self.batch if e["arabic"] == "أَكَلَ")
        full_meaning = " ".join(f["ar"] for f in article["definition"])
        self.assertIn("اغْتَابَ", full_meaning)

    def test_exact_headwords_without_duplicates(self):
        names = [e["arabic"] for e in self.batch]
        self.assertEqual(len(names), len(set(names)))
        self.assertEqual(set(names), set(EXPECTED))


    def test_arabic_headwords_use_nfc(self):
        import unicodedata
        for e in self.batch:
            with self.subTest(e=e["arabic"]):
                self.assertEqual(e["arabic"], unicodedata.normalize("NFC", e["arabic"]))

    def test_emirate_vowel_contrast_is_explicit(self):
        article = next(e for e in self.batch if e["arabic"] == "إِمَارَةٌ")
        notes = " ".join(f["ar"] for f in article["important"])
        self.assertIn("أَمَارَةٍ", notes, "Distinguish إِمَارَةٌ from أَمَارَةٌ")
        self.assertIn("إِمَارَةٍ", notes)

    def test_no_false_claim_of_visual_scan_review(self):
        for e in self.batch:
            with self.subTest(e=e["arabic"]):
                self.assertEqual(e["source_text_status"], STATUS)
                self.assertNotIn("source_review", e)
                self.assertEqual(e["source_pdf_page"], EXPECTED[e["arabic"]])
                self.assertEqual(e["source_printed_page"], EXPECTED[e["arabic"]] - 4)
                self.assertIn(
                    f'https://aljam3.com/ar/39951/73248/{EXPECTED[e["arabic"]]}',
                    e["source_urls"],
                )

    def test_arabic_content_with_tashkeel_and_required_facts(self):
        diacritics = re.compile(r"[\u064b-\u065f\u0670]")
        cyrillic = re.compile(r"[\u0400-\u04ff]")
        arabic = re.compile(r"[\u0621-\u064a]")
        for e in self.batch:
            with self.subTest(e=e["arabic"]):
                for key in ("definition", "grammar", "examples", "important"):
                    self.assertTrue(e.get(key), f'{e["arabic"]}: {key} is empty')
                for key in ("definition", "grammar", "examples", "important", "synonyms", "contrasts"):
                    for fact in e.get(key, []):
                        self.assertEqual(set(fact), {"ar"})
                        value = fact["ar"]
                        self.assertRegex(value, arabic)
                        self.assertRegex(value, diacritics)
                        self.assertNotRegex(value, cyrillic)
                self.assertNotIn("translation_ru", e)


if __name__ == "__main__":
    unittest.main()
