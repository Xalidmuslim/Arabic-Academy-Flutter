"""Regression for the Flutter native 120-Hz rendering-surface probe.

The normal dictionary APK and its data are untouched by this generated-platform patch.
"""
import unittest

from install_hyperos_120hz_probe import DEFAULT_ACTIVITY, patch_activity


class NativeRefreshProbeTests(unittest.TestCase):
    def test_flutter_surface_and_texture_receive_view_voted_120hz(self):
        result = patch_activity(DEFAULT_ACTIVITY)
        self.assertIn("onFlutterSurfaceViewCreated", result)
        self.assertIn("onFlutterTextureViewCreated", result)
        self.assertIn("view.requestedFrameRate = 120f", result)
        self.assertIn("Build.VERSION.SDK_INT >= 35", result)
        self.assertIn("super.onFlutterSurfaceViewCreated", result)
        self.assertIn("super.onFlutterTextureViewCreated", result)

    def test_no_hidden_apis_no_window_mode_lock(self):
        result = patch_activity(DEFAULT_ACTIVITY)
        for unsafe in ("preferredDisplayModeId", "Settings.System", "setprop",
                       "preferredRefreshRate", "surface.setFrameRate"):
            self.assertNotIn(unsafe, result)

    def test_patch_is_idempotent_and_preserves_package(self):
        first = patch_activity(DEFAULT_ACTIVITY)
        self.assertEqual(first, patch_activity(first))
        self.assertIn("package com.xalidmuslim.bayna_dictionary", first)
        self.assertIn("class MainActivity : FlutterActivity()", first)

    def test_unexpected_activity_is_not_overwritten(self):
        with self.assertRaises(ValueError):
            patch_activity("class MainActivity : Activity()")

if __name__ == "__main__":
    unittest.main()
