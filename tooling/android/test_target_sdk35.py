"""Controlled test for target-SDK 35 vs Flutter-generated target SDK 36."""
import unittest
from set_target_sdk35 import patch_gradle

TEMPLATE = '''
android {
  namespace = "com.xalidmuslim.bayna_dictionary"
  compileSdk = flutter.compileSdkVersion
  defaultConfig {
    applicationId = "com.xalidmuslim.bayna_dictionary"
    minSdk = flutter.minSdkVersion
    targetSdk = flutter.targetSdkVersion
    versionCode = flutter.versionCode
  }
}
'''

class TargetSdk35Test(unittest.TestCase):
    def test_only_target_sdk_changes(self):
        actual = patch_gradle(TEMPLATE)
        expected = TEMPLATE.replace("targetSdk = flutter.targetSdkVersion", "targetSdk = 35")
        self.assertEqual(expected,actual)
    def test_idempotent(self):
        once = patch_gradle(TEMPLATE)
        self.assertEqual(once,patch_gradle(once))
    def test_fail_closed_on_unknown_format(self):
        with self.assertRaises(ValueError):
            patch_gradle('android { }')
if __name__ == "__main__":
    unittest.main()
