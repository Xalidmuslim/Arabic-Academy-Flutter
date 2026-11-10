#!/usr/bin/env python3
"""Install the original 3D book artwork as an Android launcher icon.

The book is inside the adaptive safe area, so circular, rounded-rectangle,
and OEM squircle launcher masks do not clip the pages. The teal background
is drawn natively for both adaptive and legacy launchers.
"""
import base64
import hashlib
from pathlib import Path

EXPECTED_SHA256 = "bdf4ffdda02e6f8028b226a1bbfc3ca6901cb9a9e8c32f6327ce46c9aae2832f"
ICON_NAME = "bayna_3d_foreground.webp"


def install(root: Path) -> None:
    encoded = (root / "tooling/icon/bayna_3d_foreground.webp.base64").read_text().strip()
    data = base64.b64decode(encoded, validate=True)
    if hashlib.sha256(data).hexdigest() != EXPECTED_SHA256:
        raise ValueError("3D launcher icon checksum mismatch")
    if not data.startswith(b"RIFF") or data[8:12] != b"WEBP":
        raise ValueError("3D launcher asset is not WebP")

    res = root / "android/app/src/main/res"
    drawable = res / "drawable"
    raster = res / "drawable-nodpi"
    adaptive = res / "drawable-anydpi-v26"
    colors = res / "values"
    for folder in (drawable, raster, adaptive, colors):
        folder.mkdir(parents=True, exist_ok=True)

    (raster / ICON_NAME).write_bytes(data)
    # Older launchers: 3D pages sit over a matte rounded panel with a fine
    # gold outline, so the icon keeps its visual language without white edges.
    (drawable / "bayna_launcher.xml").write_text("""<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item>
        <shape android:shape="rectangle">
            <solid android:color="#0B463F"/>
            <corners android:radius="24dp"/>
            <stroke android:width="2dp" android:color="#C9A364"/>
        </shape>
    </item>
    <item android:drawable="@drawable/bayna_3d_foreground"
          android:gravity="fill"/>
</layer-list>
""")
    # Adaptive icons: Android supplies the contour, and the foreground book
    # stays centered inside the documented mask-safe region.
    (adaptive / "bayna_launcher.xml").write_text("""<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/bayna_launcher_background"/>
    <foreground android:drawable="@drawable/bayna_3d_foreground"/>
</adaptive-icon>
""")
    (colors / "bayna_launcher_colors.xml").write_text("""<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="bayna_launcher_background">#0B463F</color>
</resources>
""")

    manifest = root / "android/app/src/main/AndroidManifest.xml"
    original = manifest.read_text()
    if 'android:icon="@mipmap/ic_launcher"' not in original:
        raise ValueError("Expected Flutter launcher icon not found in manifest")
    manifest.write_text(original.replace(
        'android:icon="@mipmap/ic_launcher"',
        'android:icon="@drawable/bayna_launcher"', 1))
    print(f"Installed original 3D book launcher: {len(data)} bytes, verified")


if __name__ == "__main__":
    install(Path(__file__).resolve().parents[2])
