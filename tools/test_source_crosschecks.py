"""Regression tests: evidence from a digitized scan is not proof of Arabic vowels."""
import json
import unittest

from source_crosschecks import validate_registry, verify_article_alignment


def sample():
    return {
        "schema_version": 1,
        "records": [{
            "arabic": "أُسْبُوعٌ",
            "review_scope": "forms_and_meanings_only",
            "sources": {
                "bayna_ocr": {
                    "url": "https://aljam3.com/ar/39951/73248/16",
                    "mode": "ocr_context_only",
                },
                "arabily": {
                    "url": "https://arabily.app/bayna-yadayk-1/unit-13/",
                    "mode": "selectable_vocabulary",
                },
                "academy": {
                    "url": "https://www.arabicacademy.gov.eg/ar/search_engine/roots/%D8%B3%D8%A8%D8%B9",
                    "mode": "official_selectable_lexicon",
                },
            },
            "forms": [
                {
                    "role": "headword",
                    "arabic": "أُسْبُوعٌ",
                    "verified_by": ["arabily", "academy"],
                },
                {
                    "role": "plural",
                    "arabic": "أَسَابِيعُ",
                    "verified_by": ["arabily", "academy"],
                },
            ],
            "source_independent_full_proofread": False,
        }],
    }


def article():
    return {
        "arabic": "أُسْبُوعٌ",
        "grammar": [{"ar": "اِسْمٌ مُذَكَّرٌ؛ الْجَمْعُ: أَسَابِيعُ."}],
        "definition": [{"ar": "مُدَّةٌ تَتَكَوَّنُ مِنْ سَبْعَةِ أَيَّامٍ."}],
        "source_urls": [v["url"] for v in sample()["records"][0]["sources"].values()],
        "source_review": "scan_page_inspected_first_pass_pending_linguistic_proofread",
    }


class SourceCrosscheckTests(unittest.TestCase):
    def test_verified_source_registry_is_valid(self):
        data = sample()
        self.assertEqual(validate_registry(data), 1)
        self.assertEqual(verify_article_alignment(data, {article()["arabic"]: article()}), 1)

    def test_ocr_cannot_validate_vowel_marks(self):
        data = sample()
        data["records"][0]["forms"][0]["verified_by"] = ["bayna_ocr"]
        with self.assertRaises(ValueError):
            validate_registry(data)

    def test_unrelated_official_site_or_http_is_rejected(self):
        data = sample()
        data["records"][0]["sources"]["academy"]["url"] = "https://example.org/fake"
        with self.assertRaises(ValueError):
            validate_registry(data)
        data["records"][0]["sources"]["academy"]["url"] = (
            "http://www.arabicacademy.gov.eg/ar/search_engine/roots/سبع")
        with self.assertRaises(ValueError):
            validate_registry(data)

    def test_missing_or_differently_vocalized_lemma_fails(self):
        data = sample()
        with self.assertRaises(ValueError):
            verify_article_alignment(data, {"أَسْبُوعٌ": article()})
        bad = article()
        bad["grammar"] = [{"ar": "الْجَمْعُ: أَسْبَاعٌ."}]
        with self.assertRaises(ValueError):
            verify_article_alignment(data, {"أُسْبُوعٌ": bad})

    def test_no_russian_or_claim_of_final_proofreading(self):
        data = sample()
        data["records"][0]["translation_ru"] = "неделя"
        with self.assertRaises(ValueError):
            validate_registry(data)
        del data["records"][0]["translation_ru"]
        data["records"][0]["source_independent_full_proofread"] = True
        with self.assertRaises(ValueError):
            validate_registry(data)

    def test_duplicate_lemma_not_allowed(self):
        data = sample()
        data["records"].append(json.loads(json.dumps(data["records"][0], ensure_ascii=False)))
        with self.assertRaises(ValueError):
            validate_registry(data)

    def test_only_three_distinct_sources_with_correct_roles(self):
        data = sample()
        del data["records"][0]["sources"]["academy"]
        with self.assertRaises(ValueError):
            validate_registry(data)
        data = sample()
        data["records"][0]["forms"][0]["verified_by"] = ["arabily", "invented"]
        with self.assertRaises(ValueError):
            validate_registry(data)


if __name__ == "__main__":
    unittest.main()
