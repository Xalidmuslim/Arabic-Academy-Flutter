#!/usr/bin/env python3
"""Install the scalable Bayna dictionary icon into the Android project.

flutter create generates Android on CI, so run this after flutter create.
No external packages or network services are needed.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
res = root / 'android/app/src/main/res'
drawable = res / 'drawable'
adaptive = res / 'drawable-anydpi-v26'
colors = res / 'values'
for folder in (drawable, adaptive, colors):
    folder.mkdir(parents=True, exist_ok=True)

foreground = (root / 'tooling/icon/bayna_book_foreground.xml').read_text()
(drawable / 'bayna_book_foreground.xml').write_text(foreground)

background = (
    '    <path android:fillColor="#123F38" '
    'android:pathData="M0,0 H108 V108 H0 Z"/>\n'
)
assert '    <!-- Matte ivory open book' in foreground
legacy = foreground.replace(
    '    <!-- Matte ivory open book', background + '    <!-- Matte ivory open book',
    1,
)
(drawable / 'bayna_launcher.xml').write_text(legacy)

(adaptive / 'bayna_launcher.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/bayna_launcher_background"/>
    <foreground android:drawable="@drawable/bayna_book_foreground"/>
</adaptive-icon>
''')
(colors / 'bayna_launcher_colors.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="bayna_launcher_background">#123F38</color>
</resources>
''')

manifest = root / 'android/app/src/main/AndroidManifest.xml'
source = manifest.read_text()
old = 'android:icon="@mipmap/ic_launcher"'
assert old in source, 'Expected generated Flutter launcher icon not found'
source = source.replace(old, 'android:icon="@drawable/bayna_launcher"', 1)
manifest.write_text(source)

assert (adaptive / 'bayna_launcher.xml').is_file()
assert 'android:icon="@drawable/bayna_launcher"' in manifest.read_text()
print('Bayna launcher icon installed (vector and adaptive variants).')
