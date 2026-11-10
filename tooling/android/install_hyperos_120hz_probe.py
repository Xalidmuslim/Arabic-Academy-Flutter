"""Install a narrowly scoped 120-Hz vote in Flutter's generated Android Activity.

Flutter's Android platform directory is generated in GitHub Actions. This
script patches only MainActivity.kt; it does not touch Dart, dictionary JSON,
fonts, navigation, state, or the original app's application ID.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
ACTIVITY_PATH = ROOT / "android/app/src/main/kotlin/com/xalidmuslim/bayna_dictionary/MainActivity.kt"

DEFAULT_ACTIVITY = """package com.xalidmuslim.bayna_dictionary

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
"""

EXTRA_IMPORTS = """import android.os.Build
import android.util.Log
import android.view.Surface
import android.view.SurfaceHolder
import android.view.View
import io.flutter.embedding.android.FlutterSurfaceView
import io.flutter.embedding.android.FlutterTextureView
"""

# FlutterActivity exposes callbacks for the actual Flutter rendering SurfaceView
# or TextureView. Unlike a parent ViewGroup, its preferred rate is not lost
# because requested-frame-rate preferences don't propagate to children.
ACTIVITY_CLASS = """class MainActivity : FlutterActivity() {
    override fun onFlutterSurfaceViewCreated(flutterSurfaceView: FlutterSurfaceView) {
        super.onFlutterSurfaceViewCreated(flutterSurfaceView)
        request120Hz(flutterSurfaceView)
        // Flutter may recreate its rendering surface. Vote on each valid surface
        // rather than only on its Android View container.
        flutterSurfaceView.holder.addCallback(object : SurfaceHolder.Callback {
            override fun surfaceCreated(holder: SurfaceHolder) {
                requestSurface120Hz(holder)
            }

            override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
                requestSurface120Hz(holder)
            }

            override fun surfaceDestroyed(holder: SurfaceHolder) = Unit
        })
        requestSurface120Hz(flutterSurfaceView.holder)
    }

    override fun onFlutterTextureViewCreated(flutterTextureView: FlutterTextureView) {
        super.onFlutterTextureViewCreated(flutterTextureView)
        request120Hz(flutterTextureView)
    }

    private fun request120Hz(view: View) {
        if (Build.VERSION.SDK_INT >= 35) {
            view.requestedFrameRate = 120f
        }
    }

    private fun requestSurface120Hz(holder: SurfaceHolder) {
        if (Build.VERSION.SDK_INT < 30 || !holder.surface.isValid) return
        try {
            // Android 16+: AT_LEAST is intended for scrolling/animated UIs.
            val compatibility = if (Build.VERSION.SDK_INT >= 36)
                Surface.FRAME_RATE_COMPATIBILITY_AT_LEAST
            else Surface.FRAME_RATE_COMPATIBILITY_DEFAULT

            if (Build.VERSION.SDK_INT >= 31) {
                holder.surface.setFrameRate(
                    120f, compatibility, Surface.CHANGE_FRAME_RATE_ONLY_IF_SEAMLESS
                )
            } else {
                holder.surface.setFrameRate(120f, compatibility)
            }
        } catch (error: RuntimeException) {
            // A surface can become invalid during recreation; don't crash the dictionary.
            Log.w("BaynaHzProbe", "Rendering surface rejected 120 Hz vote", error)
        }
    }
}"""


def patch_activity(source: str) -> str:
    if "holder.surface.setFrameRate(" in source and (
        "onFlutterSurfaceViewCreated" in source
        and "onFlutterTextureViewCreated" in source
    ):
        return source

    original_import = "import io.flutter.embedding.android.FlutterActivity"
    match = re.search(
        r"\bclass\s+MainActivity\s*:\s*FlutterActivity\s*\(\s*\)",
        source,
    )
    if (
        source.count(original_import) != 1
        or not match
        or source.count("class MainActivity") != 1
        or "package com.xalidmuslim.bayna_dictionary" not in source
    ):
        raise ValueError("Unexpected Flutter Activity; refusing to overwrite Android code")

    source = source.replace(original_import, original_import + "\n" + EXTRA_IMPORTS, 1)
    match = re.search(
        r"\bclass\s+MainActivity\s*:\s*FlutterActivity\s*\(\s*\)",
        source,
    )
    assert match is not None
    return source[:match.start()] + ACTIVITY_CLASS + source[match.end():]


if __name__ == "__main__":
    if not ACTIVITY_PATH.is_file():
        raise SystemExit("Expected generated Flutter Android platform is missing")
    original = ACTIVITY_PATH.read_text(encoding="utf-8")
    updated = patch_activity(original)
    ACTIVITY_PATH.write_text(updated, encoding="utf-8")
    print("Installed 120 Hz View + Surface votes (Android 16 UI AT_LEAST)")
