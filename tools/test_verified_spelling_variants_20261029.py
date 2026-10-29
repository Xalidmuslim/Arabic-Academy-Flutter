"""Evidence-led lexicographic regression tests. Source:
Cairo Arabic Academy: root عبو (عَبْوَة / عُبُوَّة),
الوجهة (وِجْهَة / وُجْهَة), root قبض (مَقْبَض / مِقْبَض).
The two alternate pronunciations remain DISTINCT original lexical cards.
"""
import json
import unicodedata
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "assets/data"


def by_id(filename, stable_id):
    cards = json.loads((ROOT / filename).read_text(encoding="utf-8"))["entries"]
    return next(c for c in cards if c["id"] == stable_id)


class VerifiedArabicSpellingVariants(unittest.TestCase):
    def test_packaging_uses_recorded_ubuwwa_not_undocumented_ubwa(self):
        card = by_id("entries_practical_crafts_20261025.json", "editorial_crafts_20261025_076")
        self.assertEqual(card["arabic"], unicodedata.normalize("NFC", "عُبُوَّةٌ"))
        self.assertTrue(any(unicodedata.normalize("NFC", "عُبُوَّاتٌ") in g for g in card["grammar"]))
        self.assertIn(unicodedata.normalize("NFC", "عُبُوَّةُ الطِّلَاءِ"), card["collocations"])
        self.assertIn(unicodedata.normalize("NFC", "عُبُوَّةَ الطِّلَاءِ"), card["examples_ar"][0])
        self.assertFalse(any("عُبْوَة" in x for x in (
            [card["arabic"], card["usage_note_ar"]] + card["grammar"] +
            card["collocations"] + card["examples_ar"]
        )))

    def test_both_accepted_readings_of_destination_remain_and_are_explained(self):
        options = [
            by_id("entries_daily_travel_20261025.json", "editorial_daily_travel_20261025_002"),
            by_id("entries_nouns_transport_20261025.json", "ind_noun_transport_20261026_019"),
        ]
        self.assertEqual({c["arabic"] for c in options}, {"وِجْهَةٌ", "وُجْهَةٌ"})
        for c in options:
            self.assertIn("وِجْهَةٌ", c["usage_note_ar"])
            self.assertIn("وُجْهَةٌ", c["usage_note_ar"])

    def test_both_accepted_grip_readings_remain_and_are_explained(self):
        options = [
            by_id("entries_editorial_architecture_20261026.json", "editorial_architecture_20261026_036"),
            by_id("entries_practical_home_20261025.json", "editorial_home_20261025_010"),
        ]
        self.assertEqual({c["arabic"] for c in options}, {"مَقْبَضٌ", "مِقْبَضٌ"})
        for c in options:
            self.assertIn("مَقْبَضٌ", c["usage_note_ar"])
            self.assertIn("مِقْبَضٌ", c["usage_note_ar"])


if __name__ == "__main__":
    unittest.main()
