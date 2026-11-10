"""Regression test: the launcher must contain the exact generated 3D art."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
import hashlib
import xml.etree.ElementTree as ET

MODULE_FILE = Path(__file__).with_name("install_android_icon.py")
spec = importlib.util.spec_from_file_location("bayna_3d_icon_installer", MODULE_FILE)
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)
ASSET_B64 = MODULE_FILE.with_name("bayna_3d_foreground.webp.base64")


class LauncherIconTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        path = self.root / "tooling/icon"
        path.mkdir(parents=True)
        (path / ASSET_B64.name).write_bytes(ASSET_B64.read_bytes())
        manifest = self.root / "android/app/src/main/AndroidManifest.xml"
        manifest.parent.mkdir(parents=True)
        manifest.write_text('<manifest><application android:icon="@mipmap/ic_launcher"/></manifest>')

    def tearDown(self):
        self.tmp.cleanup()

    def test_installer_preserves_artwork_and_adaptive_layers(self):
        installer.install(self.root)
        res = self.root / "android/app/src/main/res"
        img = res / "drawable-nodpi/bayna_3d_foreground.webp"
        self.assertTrue(img.is_file())
        self.assertEqual(hashlib.sha256(img.read_bytes()).hexdigest(),
            installer.EXPECTED_SHA256)
        self.assertIn('@drawable/bayna_launcher',
            (self.root / "android/app/src/main/AndroidManifest.xml").read_text())
        ns = {'a': 'http://schemas.android.com/apk/res/android'}
        adaptive = ET.parse(res / "drawable-anydpi-v26/bayna_launcher.xml").getroot()
        self.assertEqual(adaptive.tag, 'adaptive-icon')
        self.assertEqual(adaptive.find('foreground').attrib[
            '{http://schemas.android.com/apk/res/android}drawable'
        ], '@drawable/bayna_3d_foreground')
        legacy = ET.parse(res / "drawable/bayna_launcher.xml").getroot()
        self.assertEqual(legacy.tag, 'layer-list')

    def test_corrupt_artwork_fails_before_installing_resources(self):
        original = self.root / "tooling/icon/bayna_3d_foreground.webp.base64"
        original.write_text("ZHVtbXk=")
        with self.assertRaises(ValueError):
            installer.install(self.root)
        self.assertFalse((self.root /
            "android/app/src/main/res/drawable-nodpi/bayna_3d_foreground.webp").exists())


if __name__ == "__main__":
    unittest.main()
