"""Import locally optimized imagery from the reference image supplied by the project owner.

Retains only photographic areas, NEVER baked captions, buttons, or complete screen screenshots.
Generated assets ship inside the APK; no runtime downloads or signing keys.
The temporary upstream source URL is only used in this one-time CI import.
"""
from pathlib import Path
from urllib.request import Request, urlopen
from io import BytesIO
from PIL import Image, ImageEnhance, ImageFilter

URL = "https://pikaso.cdnpk.net/private/production/5709857373/3718031382.jpg?token=exp=1792108800~hmac=f52287ceeea7a324e24480f043b5fafd9f8a9899fdccbac24a5299ca5155e082"
req = Request(URL, headers={"User-Agent":"Mozilla/5.0"})
with urlopen(req, timeout=60) as response:
    raw = response.read()
img = Image.open(BytesIO(raw)).convert("RGB")
if img.width < 800 or img.height < 550:
    raise ValueError(f"unexpected reference dimensions {img.size}")
out = Path("assets/images")
out.mkdir(parents=True,exist_ok=True)

# Coordinate boxes use the original 1536x1024 reference.
areas = {
  "feature_lessons.webp": (353,362,485,449),
  "feature_homework.webp": (506,362,638,449),
  "feature_pronunciation.webp": (353,501,485,588),
  "feature_vocabulary.webp": (506,501,638,588),
  "feature_welcome.webp": (27,171,286,420),
  "feature_classroom.webp": (671,225,941,355),
  "feature_teacher.webp": (1236,186,1325,321),
}
for name, box in areas.items():
    coords = tuple(round(value*(img.width if k%2==0 else img.height)/(1536 if k%2==0 else 1024))
                   for k,value in enumerate(box))
    crop = img.crop(coords)
    maxw = 720 if name.startswith("feature_welcome") else 570
    maxh = 820 if name.startswith("feature_welcome") else 390
    scale = min(maxw/crop.width,maxh/crop.height)
    crop = crop.resize((round(crop.width*scale),round(crop.height*scale)), Image.Resampling.LANCZOS)
    crop = ImageEnhance.Sharpness(crop).enhance(1.12)
    dest = out/name
    crop.save(dest, "WEBP",quality=82,method=6)
    print(f"{dest}: {crop.size}, {dest.stat().st_size} bytes")
