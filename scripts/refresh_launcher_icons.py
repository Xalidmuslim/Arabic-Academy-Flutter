"""Create platform launcher icons from the app's own abstract emblem.
Called after flutter create, never needs private keys or original textbook content.
"""
from pathlib import Path
from PIL import Image

source = Path("assets/images/academy_emblem.webp")
img = Image.open(source).convert("RGB")
android = {
 "mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192,
}
for density, px in android.items():
    dest = Path("android/app/src/main/res") / ("mipmap-"+density) / "ic_launcher.png"
    dest.parent.mkdir(parents=True, exist_ok=True)
    img.resize((px,px),Image.Resampling.LANCZOS).save(dest,"PNG",optimize=True)
    print("Android icon",dest,px)
ios = Path("ios/Runner/Assets.xcassets/AppIcon.appiconset")
if ios.exists():
    # Flutter's generated icon catalog references these filenames.
    for entry in ios.glob("Icon-App-*.png"):
        # Use existing generated icon width as the required export size.
        with Image.open(entry) as sample:
            px = sample.width
        img.resize((px,px),Image.Resampling.LANCZOS).save(entry,"PNG",optimize=True)
        print("iOS icon",entry,px)
