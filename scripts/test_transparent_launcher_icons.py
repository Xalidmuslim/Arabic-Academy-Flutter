import importlib.util
import tempfile
import unittest
from pathlib import Path
from PIL import Image, ImageDraw

SCRIPT = Path(__file__).with_name("prepare_transparent_launcher_icons.py")
spec = importlib.util.spec_from_file_location("launcher_cleaner", SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class TransparentLauncherTests(unittest.TestCase):
    def make_icon(self, path: Path, size: int) -> None:
        original = Image.new("RGB", (size, size), (252, 247, 233))
        pen = ImageDraw.Draw(original)
        s = size / 192
        pen.rounded_rectangle(
            (27*s, 24*s, 165*s, 159*s),
            radius=27*s, fill=(76, 97, 48),
        )
        pen.ellipse((75*s, 78*s, 110*s, 104*s), fill=(244, 228, 198))
        # A broad beige drop shadow below the actual tile is NOT foreground.
        pen.rectangle((65*s, 167*s, 140*s, 179*s), fill=(200, 180, 148))
        original.save(path)

    def test_extracts_real_silhouette_without_ground_shadow(self):
        with tempfile.TemporaryDirectory() as folder:
            for size in module.DENSITIES.values():
                with self.subTest(size=size):
                    path = Path(folder) / f"{size}.png"
                    self.make_icon(path, size)
                    module.clean_icon(path, size)
                    with Image.open(path) as image:
                        image = image.convert("RGBA")
                        self.assertEqual(image.getpixel((0, 0))[3], 0)
                        self.assertEqual(image.getpixel((size//2, size//2))[3], 255)
                        self.assertEqual(image.getpixel((size//2, int(size*0.91)))[3], 0)
                        self.assertEqual(image.getpixel((size//2, size//2))[:3],
                                         (244, 228, 198))
                    first = path.read_bytes()
                    module.clean_icon(path, size)
                    self.assertEqual(path.read_bytes(), first)

    def test_adaptive_foreground_is_transparent_and_uses_safe_zone(self):
        with tempfile.TemporaryDirectory() as folder:
            parent = Path(folder)
            src = parent / "icon.png"
            dst = parent / "drawable-nodpi" / "ic_launcher_foreground.png"
            self.make_icon(src, 192)
            module.clean_icon(src, 192)
            module.create_adaptive_launcher(src, dst)
            module.write_adaptive_xml(parent)
            with Image.open(dst) as image:
                self.assertEqual(image.size, (432, 432))
                self.assertEqual(image.getpixel((0, 0))[3], 0)
                self.assertEqual(image.getpixel((216, 216))[3], 255)
            xml = (parent / "mipmap-anydpi-v26" / "ic_launcher.xml").read_text()
            self.assertIn("@android:color/transparent", xml)
            self.assertIn("@drawable/ic_launcher_foreground", xml)


if __name__ == "__main__":
    unittest.main()
