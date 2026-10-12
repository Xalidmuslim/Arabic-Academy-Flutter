import hashlib
import json
from pathlib import Path
import shutil
import struct
import tempfile
import unittest

from scripts import verify_assets


ROOT = Path(__file__).resolve().parents[2]


class AssetTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        shutil.copy(ROOT / "pubspec.yaml", self.root / "pubspec.yaml")
        for folder in ["artwork", "content", "fonts"]:
            shutil.copytree(ROOT / "assets" / folder, self.root / "assets" / folder)

    def edit_manifest(self, edit):
        path = self.root / "assets/artwork/manifest.json"
        value = json.loads(path.read_text())
        edit(value)
        path.write_text(json.dumps(value))

    def test_actual_assets_and_local_fonts_are_valid(self):
        self.assertEqual(verify_assets.validate_assets(self.root)["scenes"], 10)

    def test_corrupted_bytes_and_wrong_dimensions_fail(self):
        with (self.root / "assets/artwork/hero.webp").open("ab") as file:
            file.write(b"corruption")
        with self.assertRaises(verify_assets.ValidationError):
            verify_assets.validate_assets(self.root)
        shutil.copy(ROOT / "assets/artwork/hero.webp", self.root / "assets/artwork/hero.webp")
        self.edit_manifest(lambda items: items[0].__setitem__("width", 1))
        with self.assertRaises(verify_assets.ValidationError):
            verify_assets.validate_assets(self.root)

    def test_missing_duplicate_unknown_scenes_or_fields_fail(self):
        original = (self.root / "assets/artwork/manifest.json").read_text()
        for edit in [lambda x: x.pop(), lambda x: x.append(x[0]),
                     lambda x: x[0].__setitem__("id", "reference"),
                     lambda x: x[0].__setitem__("unexpected", "value")]:
            (self.root / "assets/artwork/manifest.json").write_text(original)
            self.edit_manifest(edit)
            with self.assertRaises(verify_assets.ValidationError):
                verify_assets.validate_assets(self.root)

    def test_duplicate_hash_or_traversal_fail(self):
        self.edit_manifest(lambda items: items[1].__setitem__("sha256", items[0]["sha256"]))
        with self.assertRaises(verify_assets.ValidationError):
            verify_assets.validate_assets(self.root)
        self.edit_manifest(lambda items: items[0].__setitem__("file", "../outside.webp"))
        with self.assertRaises(verify_assets.ValidationError):
            verify_assets.validate_assets(self.root)

    def test_legacy_images_cannot_be_declared_in_pubspec(self):
        path = self.root / "pubspec.yaml"
        path.write_text(path.read_text().replace("    - assets/artwork/", "    - assets/images/"))
        with self.assertRaises(verify_assets.ValidationError):
            verify_assets.validate_assets(self.root)

    def test_symlink_cannot_hide_legacy_artwork(self):
        legacy = self.root / 'assets/images'
        legacy.mkdir()
        (legacy / 'old.webp').write_bytes(b'old')
        alias = self.root / 'assets/alias.webp'
        alias.symlink_to(legacy / 'old.webp')
        with self.assertRaises(verify_assets.ValidationError):
            verify_assets._safe_path(self.root, 'assets/alias.webp')

    def test_exercise_kind_rejects_wrong_json_types(self):
        for value in [[], {}, True, 1, None]:
            with self.subTest(value=value):
                with self.assertRaises(verify_assets.ValidationError):
                    verify_assets._exercise({'kind': value})

    def test_every_declared_asset_and_font_license_must_exist(self):
        (self.root / "assets/fonts/manrope-OFL.txt").unlink()
        with self.assertRaises(verify_assets.ValidationError):
            verify_assets.validate_assets(self.root)
        shutil.copy(ROOT / "assets/fonts/manrope-OFL.txt", self.root / "assets/fonts/manrope-OFL.txt")
        (self.root / "assets/content/grammar.json").unlink()
        with self.assertRaises(verify_assets.ValidationError):
            verify_assets.validate_assets(self.root)

    def test_json_duplicate_ids_keys_and_invalid_answer_indexes_fail(self):
        path = self.root / "assets/content/grammar.json"
        original = path.read_text()
        for edit in [lambda value: value["topics"].append(value["topics"][0]),
                     lambda value: value["topics"][0]["exercises"][0].__setitem__("correct", 999)]:
            value = json.loads(original)
            edit(value)
            path.write_text(json.dumps(value))
            with self.assertRaises(verify_assets.ValidationError):
                verify_assets.validate_assets(self.root)
        path.write_text('{"topics":[],"topics":[]}')
        with self.assertRaises(verify_assets.ValidationError):
            verify_assets.validate_assets(self.root)

    def test_webp_lossless_header_and_truncation_are_checked(self):
        bits = (32 - 1) | ((48 - 1) << 14)
        chunk = b"VP8L" + struct.pack("<I", 5) + b"\x2f" + struct.pack("<I", bits) + b"\x00"
        image = b"RIFF" + struct.pack("<I", len(chunk) + 4) + b"WEBP" + chunk
        self.assertEqual(verify_assets.webp_dimensions(image), (32, 48))
        with self.assertRaises(verify_assets.ValidationError):
            verify_assets.webp_dimensions(image[:-2])


if __name__ == "__main__":
    unittest.main()
