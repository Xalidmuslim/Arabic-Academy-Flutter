"""One-time import of original, independently generated modern UI artwork.
No religious imagery or protected textbook images. Runtime uses compact local assets.
"""
from pathlib import Path
from io import BytesIO
from urllib.request import Request, urlopen
from PIL import Image

OUT = Path("assets/images")
OUT.mkdir(parents=True, exist_ok=True)
URLS = {
    "background": "https://pikaso.cdnpk.net/private/production/5709214765/3717726827.png?token=exp=1792108800~hmac=c3ebc2f3ac6404d89dfea76a1a6f3d9ec23631f7e2f2f964226272a5b6028859",
    "hero": "https://pikaso.cdnpk.net/private/production/5709215250/3717727086.png?token=exp=1792108800~hmac=8627551b1cc7372187c16013e2e049e12e85002d016f977ba1e110d4b204e97a",
    "icons": "https://pikaso.cdnpk.net/private/production/5709215954/3717727402.png?token=exp=1792108800~hmac=fa8fd852de3edffa8180c35ea7604d7972eec86dc9a27226e5f59a2e31c4a7a0",
    "emblem": "https://pikaso.cdnpk.net/private/production/5709216387/3717727584.png?token=exp=1792108800~hmac=2ab48f9277e11a162e3feba4e56a6ab4ab22e4782377b58b14add5b59610d260",
}

def fetch(url):
    req = Request(url, headers={"User-Agent": "Mozilla/5.0 (mobile learning app asset importer)"})
    with urlopen(req, timeout=45) as response:
        raw = response.read()
    if len(raw) < 10000: raise ValueError("Suspiciously small downloaded image")
    return Image.open(BytesIO(raw))

def save_webp(img, filename, bounds, quality=76):
    img = img.copy()
    img.thumbnail(bounds, Image.Resampling.LANCZOS)
    path = OUT / filename
    img.save(path, "WEBP", quality=quality, method=6)
    print(filename, img.size, path.stat().st_size)

background = fetch(URLS["background"]).convert("RGB")
save_webp(background, "modern_background.webp", (720, 1280), quality=66)
hero = fetch(URLS["hero"]).convert("RGB")
save_webp(hero, "modern_hero.webp", (900, 560), quality=73)
emblem = fetch(URLS["emblem"]).convert("RGB")
save_webp(emblem, "academy_emblem.webp", (500, 500), quality=80)

sprite = fetch(URLS["icons"]).convert("RGBA")
cols, rows = 4, 2
names = ["books", "video", "homework", "students", "wallet", "microphone", "tests", "settings"]
w, h = sprite.size
for row in range(rows):
    for col in range(cols):
        left, upper = col*w//cols, row*h//rows
        right, lower = (col+1)*w//cols, (row+1)*h//rows
        cell = sprite.crop((left, upper, right, lower))
        bbox = cell.getchannel("A").getbbox()
        if bbox is None: raise ValueError(f"Empty asset {row} {col}")
        pad = 7
        x0 = max(0,bbox[0]-pad)
        y0 = max(0,bbox[1]-pad)
        x1 = min(cell.width,bbox[2]+pad)
        y1 = min(cell.height,bbox[3]+pad)
        icon = cell.crop((x0,y0,x1,y1))
        canvas = Image.new("RGBA",(max(icon.size),max(icon.size)),(0,0,0,0))
        canvas.alpha_composite(icon,((canvas.width-icon.width)//2,(canvas.height-icon.height)//2))
        save_webp(canvas,f"icon_{names[row*4+col]}.webp",(280,280),quality=79)

# Source content never contains phone numbers, client data or API keys.
