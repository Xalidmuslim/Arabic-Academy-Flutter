import importlib.util
import tempfile
import unittest
from pathlib import Path

from PIL import Image

MODULE = Path(__file__).with_name('prepare_transparent_launcher_icons.py')
spec = importlib.util.spec_from_file_location('launcher_cleaner', MODULE)
assert spec and spec.loader
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class TransparentLauncherTests(unittest.TestCase):
    def test_masks_keep_interior_but_clear_original_white_outer_square(self):
        for size in module.DENSITIES.values():
            with self.subTest(size=size):
                mask = module.alpha_mask(size)
                self.assertEqual(mask.getpixel((0, 0)), 0)
                self.assertEqual(mask.getpixel((size // 2, size // 2)), 255)
                self.assertEqual(mask.getpixel((size - 1, size - 1)), 0)

    def test_regeneration_preserves_emblem_pixels_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as tmp:
            file = Path(tmp) / 'ic_launcher.png'
            original = Image.new('RGB', (192, 192), (252, 247, 233))
            original.putpixel((96, 96), (75, 98, 40))
            original.save(file)
            module.clean_icon(file, 192)
            first = file.read_bytes()
            with Image.open(file) as output:
                self.assertEqual(output.mode, 'RGBA')
                self.assertEqual(output.getpixel((0, 0))[3], 0)
                self.assertEqual(output.getpixel((96, 96)), (75, 98, 40, 255))
            module.clean_icon(file, 192)
            self.assertEqual(file.read_bytes(), first)


if __name__ == '__main__':
    unittest.main()
