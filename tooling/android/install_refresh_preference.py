#!/usr/bin/env python3
"""Set a high-refresh window *preference* on generated Flutter Android.

Xiaomi/HyperOS, LTPO and battery policy still have final control.
Use preferredRefreshRate rather than preferredDisplayModeId so Android can
retain the user's resolution and dynamically vary refresh rate.
"""
import re
from pathlib import Path


MAIN_ACTIVITY = (
    "android/app/src/main/kotlin/"
    "com/xalidmuslim/bayna_dictionary/MainActivity.kt"
)

SOURCE = """package com.xalidmuslim.bayna_dictionary

import android.os.Build
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onResume() {
        super.onResume()
        // Apply when the window has focus/Flutter is attached, once per resume.
        window.decorView.post { requestHighRefreshPreference() }
    }

    @Suppress("DEPRECATION")
    private fun requestHighRefreshPreference() {
        // Display#getSupportedModes: older Android versions require supported Hz.
        val supportedRates = windowManager.defaultDisplay.supportedModes
            .map { it.refreshRate }
            .filter { it > 0f && it <= 120.5f }
        val requestedHz =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                120f
            } else {
                supportedRates.maxOrNull() ?: windowManager.defaultDisplay.refreshRate
            }
        val params = window.attributes
        // A nonzero mode ID would cause preferredRefreshRate to be IGNORED.
        params.preferredDisplayModeId = 0
        params.preferredRefreshRate = requestedHz
        window.attributes = params

        // This reports display mode only, not Flutter raster/frame performance.
        Log.i("BaynaRefresh", "Requested Hz=$requestedHz; activeDisplayHz=" +
            windowManager.defaultDisplay.refreshRate +
            "; supportedHz=$supportedRates")
    }
}
"""


def install(root: Path) -> Path:
    activity = root / MAIN_ACTIVITY
    if not activity.exists():
        raise FileNotFoundError(
            "Flutter-generated MainActivity.kt not found: " + str(activity))
    original = activity.read_text(encoding="utf-8")
    if not re.search(
        r"class\s+MainActivity\s*:\s*FlutterActivity\(\)", original
    ):
        raise ValueError("Refusing to overwrite a customized MainActivity")
    activity.write_text(SOURCE, encoding="utf-8")
    print("Installed native Android 120 Hz preference:", activity)
    return activity


if __name__ == "__main__":
    install(Path(__file__).resolve().parents[2])
