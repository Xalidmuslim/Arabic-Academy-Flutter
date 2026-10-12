"""Restore the approved original photographic/3D UI artwork into Flutter assets.
The embedded atlas contains ORIGINAL generated assets, not reference-screen crops.
Run after installing Pillow and before flutter pub get/analysis/build.
"""
from pathlib import Path
from io import BytesIO
import base64
import hashlib
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "assets" / "_embedded" / "v05"
PARTS = sorted(DATA_DIR.glob("atlas.part*.txt"))
if not PARTS:
    raise SystemExit("Missing embedded original artwork archive parts")
encoded = "".join(p.read_text(encoding="ascii").strip() for p in PARTS)
content = base64.b64decode(encoded, validate=True)
expected = "4998ffa3d701e67ff0732e76b9e1e75b5c36f865d5171ee1745f466216bf1ac7"
actual = hashlib.sha256(content).hexdigest()
if actual != expected:
    raise SystemExit(f"Atlas integrity mismatch: {actual} != {expected}")
image = Image.open(BytesIO(content)).convert("RGB")
if image.size != (640, 960):
    raise SystemExit(f"Unexpected original art atlas size: {image.size}")
dest = ROOT / "assets" / "images"
dest.mkdir(parents=True, exist_ok=True)

features = {
    "feature_lessons.webp": (0, 0, 320, 240),
    "feature_homework.webp": (320, 0, 640, 240),
    "feature_pronunciation.webp": (0, 240, 320, 480),
    "feature_vocabulary.webp": (320, 240, 640, 480),
    "feature_welcome.webp": (0, 480, 213, 640),
    "feature_classroom.webp": (213, 480, 426, 640),
    "feature_teacher.webp": (426, 480, 639, 640),
}
icon_names = [
    "icon_homework.webp", "icon_vocabulary.webp", "icon_analytics.webp",
    "icon_tests.webp", "icon_settings.webp", "icon_books.webp",
    "icon_video.webp", "icon_students.webp", "icon_microphone.webp",
    "icon_schedule.webp",
]
for idx, name in enumerate(icon_names):
    x = (idx % 5) * 120
    y = 660 + (idx // 5) * 120
    features[name] = (x, y, x + 120, y + 120)

for name, rect in features.items():
    area = image.crop(rect)
    area.save(dest / name, "WEBP", quality=87, method=5)
    print(name, area.size, (dest / name).stat().st_size)
print("Restored", len(features), "independently displayable original UI graphics")
