"""Regressions for concrete terminology mismatches found in contextual prose."""
import json
import unittest

from validate_dictionary import ROOT


def entry_in_file(source, stable_id):
    data = json.loads((ROOT / source).read_text(encoding="utf-8"))
    return next(card for card in data["entries"] if card["id"] == stable_id)


class ProcurementEnergyLexicalTests(unittest.TestCase):
    def test_request_for_quote_is_sent_by_buyer_not_supplier_quotation(self):
        card = entry_in_file(
            "assets/data/entries_editorial_supply_chain_20261027.json",
            "editorial_supply_chain_20261027_008",
        )
        self.assertEqual(card["arabic"], "طَلَبُ عَرْضِ سِعْرٍ")
        self.assertTrue(any("الْمُشْتَرِي" in v and "طَلَبَ عَرْضِ سِعْرٍ" in v
                            for v in card["examples_ar"]))
        self.assertTrue(any("طَلَبِ عَرْضِ سِعْرٍ" in v for v in card["collocations"]))
        self.assertTrue(any("الْمُوَرِّد" in v for v in card["examples_ar"]))
        self.assertEqual(card["book_references"], [])

    def test_power_factor_example_explains_factor_not_generic_energy_loss(self):
        card = entry_in_file(
            "assets/data/entries_editorial_energy_utilities_20261027.json",
            "editorial_energy_utilities_20261027_026",
        )
        self.assertEqual(card["arabic"], "مُعَامِلُ الْقُدْرَةِ")
        self.assertTrue(any("مُعَامِلَ الْقُدْرَةِ" in v for v in card["examples_ar"]))
        self.assertTrue("الْقُدْرَةِ الْفَعَّالَةِ" in card["meaning_ar"])
        self.assertTrue("الْقُدْرَةِ الظَّاهِرِيَّةِ" in card["meaning_ar"])
        self.assertEqual(card["book_references"], [])


if __name__ == "__main__":
    unittest.main()
