#!/usr/bin/env python3
"""Check deterministic cached card nine-patch textures without changing artwork."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "scripts/generate_cached_card_shadows.py"
SPEC = importlib.util.spec_from_file_location("cached_card_shadows", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class CachedCardShadowsTest(unittest.TestCase):
    def test_four_theme_and_emphasis_variants(self):
        self.assertEqual(set(MODULE.VARIANTS), {
            "regular_light", "emphasized_light",
            "regular_dark", "emphasized_dark",
        })

    def test_image_size_and_center_slice_are_valid_for_normal_cards(self):
        for name, (radius, layers) in MODULE.VARIANTS.items():
            with self.subTest(name=name):
                image = MODULE.rasterize(radius, layers)
                expected = 2 * (MODULE.PADDING + radius + 1)
                self.assertEqual(image.size, (expected, expected))
                self.assertEqual(image.mode, "RGBA")
                self.assertEqual(image.getpixel((0, 0))[3], 0)
                # The original surface will cover the center; nine-slicing
                # requires that the center area is uniform and stretchable.
                x = MODULE.PADDING + radius
                self.assertEqual(image.getpixel((x, x)),
                                 image.getpixel((x + 1, x + 1)))

    def test_shadow_bleeds_beyond_card_but_not_beyond_56px_margin(self):
        for name, (radius, layers) in MODULE.VARIANTS.items():
            with self.subTest(name=name):
                image = MODULE.rasterize(radius, layers)
                extent = image.size[0]
                mid = extent // 2
                self.assertGreater(image.getpixel((mid, MODULE.PADDING - 3))[3], 0)
                self.assertEqual(image.getpixel((mid, 0))[3], 0)

    def test_identical_input_produces_byte_identical_texture(self):
        radius, layers = MODULE.VARIANTS["regular_light"]
        self.assertEqual(MODULE.rasterize(radius, layers).tobytes(),
                         MODULE.rasterize(radius, layers).tobytes())


if __name__ == "__main__":
    unittest.main()
