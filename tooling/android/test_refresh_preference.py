"""Native window refresh request regression tests (no device FPS claims)."""
import importlib.util
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
INSTALLER = HERE / "install_refresh_preference.py"


class NativeRefreshRequestTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.activity = (self.root / "android/app/src/main/kotlin/com/xalidmuslim"
                         "/bayna_dictionary/MainActivity.kt")
        self.activity.parent.mkdir(parents=True)
        self.activity.write_text("""package com.xalidmuslim.bayna_dictionary

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
""", encoding="utf-8")

    def tearDown(self):
        self.temp.cleanup()

    def test_native_120hz_hint_respects_android_policy(self):
        spec = importlib.util.spec_from_file_location("refresh_installer", INSTALLER)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        module.install(self.root)
        native = self.activity.read_text(encoding="utf-8")
        self.assertIn("preferredRefreshRate = requestedHz", native)
        self.assertIn("preferredDisplayModeId = 0", native)
        self.assertIn("120f", native)
        self.assertIn("override fun onResume()", native)
        self.assertIn("Display#getSupportedModes", native)
        self.assertIn("FlutterActivity", native)
        self.assertNotIn("setHighRefreshRate()", native)
        self.assertIn("BaynaRefresh", native)

    def test_cannot_overwrite_custom_activity(self):
        spec = importlib.util.spec_from_file_location("refresh_installer", INSTALLER)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.activity.write_text("class CustomOtherMainActivity {}")
        with self.assertRaises(ValueError):
            module.install(self.root)

    def test_old_plugin_no_longer_overrides_native_window_hint(self):
        pubspec = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
        dart = (ROOT / "lib/ui/dictionary_shell.dart").read_text(encoding="utf-8")
        self.assertNotIn("flutter_displaymode:", pubspec)
        self.assertNotIn("FlutterDisplayMode.setHighRefreshRate", dart)


if __name__ == "__main__":
    unittest.main()
