import tempfile
import unittest
from pathlib import Path
from PIL import Image

from scripts.generate_static_artwork_shadows import generate_one, mask_name


class StaticBlurCacheTest(unittest.TestCase):
    def test_generates_alpha_shaped_soft_shadow_with_same_source_geometry(self):
        with tempfile.TemporaryDirectory() as tmp:
            original = Path(tmp) / "source.webp"
            output = Path(tmp) / "shadow.png"
            pic = Image.new("RGBA", (160, 160), (0, 0, 0, 0))
            for x in range(32, 128):
                for y in range(32, 128):
                    pic.putpixel((x, y), (42, 90, 33, 255))
            pic.save(original, "WEBP", lossless=True)
            generate_one(original, output)
            self.assertTrue(output.exists())
            with Image.open(output) as shadow:
                self.assertEqual(shadow.size, pic.size)
                self.assertEqual(shadow.mode, "RGBA")
                self.assertEqual(shadow.getpixel((80, 80))[3], 255)
                self.assertEqual(shadow.getpixel((0, 0))[3], 0)
                self.assertGreater(shadow.getpixel((30, 80))[3], 0)
                self.assertEqual(shadow.getpixel((80, 80))[:3], (255, 255, 255))

    def test_source_is_not_modified(self):
        with tempfile.TemporaryDirectory() as tmp:
            original = Path(tmp) / "source.webp"
            output = Path(tmp) / "shadow.png"
            Image.new("RGBA", (64, 64), (20, 30, 40, 150)).save(
                original, "WEBP", lossless=True)
            before = original.read_bytes()
            generate_one(original, output)
            self.assertEqual(before, original.read_bytes())


if __name__ == "__main__":
    unittest.main()
