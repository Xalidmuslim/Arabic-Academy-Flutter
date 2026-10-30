"""Targeted regression tests: clear agreement and explicit referents in prose.

The headwords, card IDs, lesson links and editorial senses must be preserved.
This is not a blanket linguistic correctness claim.
"""
import json
import unittest
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = {
  "archaeology_history": {
    "112": "يُسَاعِدُ التَّصْوِيرُ الْجَوِّيُّ فِي مَعْرِفَةِ الْمَوَاقِعِ دُونَ حَفْرٍ.",
    "123": "تُسْتَعْمَلُ الْمُعَاصَرَةُ فِي تَرْتِيبِ الْأَحْدَاثِ وَمُقَارَنَةِ التَّوَارِيخِ.",
    "124": "تُسَاعِدُ الْوَثِيقَةُ الْإِدَارِيَّةُ عَلَى فَهْمِ الْإِدَارَةِ وَالِاقْتِصَادِ.",
    "125": "يَكْشِفُ السِّجِلُّ الضَّرِيبِيُّ عَنْ أَنْظِمَةِ الْمَالِ وَالْإِنْتَاجِ.",
    "018": "يَحْتَاجُ الْعَظْمُ الْأَثَرِيُّ إِلَى تَحْلِيلٍ مُتَخَصِّصٍ لِتَفْسِيرِ دَلَالَتِهِ.",
    "026": "تَخْتَلِفُ نِهَايَتُهَا بِحَسَبِ ظُهُورِ الْكِتَابَةِ فِي كُلِّ مِنْطَقَةٍ.",
    "040": "اسْتُعْمِلَتِ الْكِتَابَةُ الْمِسْمَارِيَّةُ فِي حَضَارَاتٍ مُتَعَدِّدَةٍ مِنَ الشَّرْقِ الْقَدِيمِ.",
    "041": "تَجْمَعُ رُمُوزُ الْكِتَابَةِ الْهِيرُوغْلِيفِيَّةِ بَيْنَ دَلَالَاتٍ صَوْتِيَّةٍ وَمَعْنَوِيَّةٍ.",
    "048": "قَدْ يَحْمِلُ النَّقْدُ الْأَثَرِيُّ اسْمَ حَاكِمٍ أَوْ عَلَامَةَ سَكٍّ.",
    "052": "قَدْ تَحْفَظُ مَحَطَّةُ الْقَوَافِلِ آثَارَ التِّجَارَةِ وَالسَّفَرِ."
  },
  "genetics_microbiology": {
    "128": "قَدْ يَكُونُ التَّعَايُشُ مُفِيدًا لِلطَّرَفَيْنِ أَوْ مُضِرًّا لِأَحَدِهِمَا.",
    "137": "تَجْرِي عَمَلِيَّةُ نَزْعِ النِّيتْرُوجِينِ فِي بَعْضِ الْبِيئَاتِ الْقَلِيلَةِ الْأُكْسِجِينِ.",
    "149": "تَخْتَلِفُ قُدْرَةُ الْخَطِّ الْخَلَوِيِّ عَلَى الِانْقِسَامِ بِحَسَبِ النَّوْعِ.",
    "099": "قَدْ يُسَاعِدُ الْهُدْبُ الْبَكْتِيرِيُّ عَلَى الِالْتِصَاقِ بِالْأَسْطُحِ."
  },
  "energy_utilities": {
    "040": "يُشَجِّعُ نِظَامُ التَّعْرِفَةِ الزَّمَنِيَّةِ عَلَى نَقْلِ بَعْضِ الْأَحْمَالِ خَارِجَ الذُّرْوَةِ."
  },
  "maritime_navigation": {
    "064": "يَتَطَلَّبُ الْبَحْثُ وَالْإِنْقَاذُ الْبَحْرِيُّ تَنْسِيقًا بَيْنَ السُّفُنِ وَالْجِهَاتِ الْمَسْؤُولَةِ.",
    "076": "يُصَمَّمُ حَاجِزُ الْأَمْوَاجِ وَفْقَ اتِّجَاهِ الرِّيَاحِ وَحَجْمِ الْمَوْجِ."
  },
  "supply_chain": {
    "053": "تَتَطَلَّبُ نَافِذَةُ التَّسْلِيمِ تَنْسِيقًا بَيْنَ الْمَنْدُوبِ وَالْعَمِيلِ.",
    "054": "يَتَأَثَّرُ تَسْلِيمُ الْمِيلِ الْأَخِيرِ بِكَثَافَةِ الطَّلَبَاتِ وَالْمَسَافَاتِ.",
    "070": "تَسْتَلْزِمُ السِّلْسِلَةُ الْبَارِدَةُ تَوْثِيقَ الْحَرَارَةِ خِلَالَ مَرَاحِلِ النَّقْلِ."
  }
}

class ExplicitArabicReferentsTests(unittest.TestCase):
    def test_20_manually_reviewed_usage_notes(self):
        reviewed = 0
        for topic, corrections in EXPECTED.items():
            path = ROOT / ('assets/data/entries_editorial_' + topic + '_20261027.json')
            cards = {card['id'].rsplit('_', 1)[-1]: card for card in json.loads(path.read_text(encoding='utf-8'))['entries']}
            for code, expected in corrections.items():
                with self.subTest(topic=topic, code=code):
                    self.assertIn(code, cards)
                    card = cards[code]
                    self.assertEqual(card['usage_note_ar'], unicodedata.normalize('NFC', expected))
                    self.assertEqual(card['id'], 'editorial_' + topic + '_20261027_' + code)
                    self.assertEqual(unicodedata.normalize('NFC', card['arabic']), card['arabic'])
                    self.assertEqual(card['book_references'], [])
                    reviewed += 1
        self.assertEqual(reviewed, 20)

if __name__ == '__main__':
    unittest.main()
