"""Regression: let HyperOS own the per-app screen refresh policy."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github/workflows/dictionary-system-managed-apk.yml"
DART = ROOT / "lib/ui/dictionary_shell.dart"
PUBSPEC = ROOT / "pubspec.yaml"


class SystemRefreshPolicyTest(unittest.TestCase):
    def test_no_in_app_refresh_rate_override(self):
        dart = DART.read_text(encoding="utf-8")
        pubspec = PUBSPEC.read_text(encoding="utf-8")
        workflow = WORKFLOW.read_text(encoding="utf-8")
        self.assertNotIn("FlutterDisplayMode", dart)
        self.assertNotIn("flutter_displaymode:", pubspec)
        self.assertNotIn("install_refresh_preference.py", workflow)
        self.assertNotIn("preferredRefreshRate", dart)
        self.assertNotIn("preferredDisplayModeId", dart)
        self.assertIn("Test Android system-managed refresh policy", workflow)
        self.assertIn("Build Android ARM64 APK", workflow)

    def test_native_generated_activity_keeps_system_policy(self):
        activity = ROOT / "android/app/src/main/kotlin/com/xalidmuslim/bayna_dictionary/MainActivity.kt"
        if not activity.is_file():
            self.skipTest("Android platform generated only by CI")
        text = activity.read_text(encoding="utf-8")
        self.assertNotIn("preferredRefreshRate", text)
        self.assertNotIn("preferredDisplayModeId", text)
        self.assertIn("FlutterActivity", text)


if __name__ == "__main__":
    unittest.main()
