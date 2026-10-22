#!/usr/bin/env python3
"""Extract the actual green 3D icon silhouette, not a rounded beige rectangle.

This intentionally removes the broad ground shadow. It preserves the colors
and embossed Arabic lettering inside the original icon; no image redesign.
The Android adaptive foreground is generated inside the correct 66% safe zone.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "android" / "app" / "src" / "main" / "res"
DENSITIES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}


def is_tile_pixel(rgb: tuple[int, int, int]) -> bool:
    r, g, b = rgb
    # Olive tile material, excluding ivory letter, warm shadow, and paper.
    return g > r * 1.027 and g > b * 1.07 and g < 200


def silhouette_mask(image: Image.Image) -> Image.Image:
    """Bound each row by real olive pixels, filling the ivory artwork inside."""
    image = image.convert("RGB")
    width, height = image.size
    scale = 4
    mask = Image.new("L", (width * scale, height * scale), 0)
    draw = ImageDraw.Draw(mask)
    pixels = image.load()
    valid_rows = 0
    for y in range(height):
        active = [x for x in range(width) if is_tile_pixel(pixels[x, y])]
        if len(active) < max(3, width // 10):
            continue
        valid_rows += 1
        left = max(0, active[0] * scale - 2)
        right = min(width * scale - 1, (active[-1] + 1) * scale + 2)
        draw.rectangle((left, y * scale, right, (y + 1) * scale), fill=255)
    if valid_rows < height // 3:
        raise ValueError("Cannot identify original green icon; refusing to crop")
    mask = mask.resize((width, height), Image.Resampling.LANCZOS)
    return mask.filter(ImageFilter.GaussianBlur(max(0.3, width * 0.65 / 192)))


def clean_icon(path: Path, expected_size: int) -> None:
    with Image.open(path) as original:
        if original.size != (expected_size, expected_size):
            raise ValueError(f"Wrong launcher dimensions: {path}")
        icon = original.convert("RGBA")
    if icon.getpixel((0, 0))[3] != 0:
        icon.putalpha(silhouette_mask(icon))
        icon.save(path, optimize=True)


def create_adaptive_launcher(icon_path: Path, destination: Path) -> None:
    with Image.open(icon_path) as src:
        icon = src.convert("RGBA")
    # 390px inside 432px -> 278px true olive silhouette, staying in
    # Android's central 288px safe area after the launcher applies its mask.
    canvas = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    resized = icon.resize((390, 390), Image.Resampling.LANCZOS)
    canvas.alpha_composite(resized, (21, 21))
    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(destination, optimize=True)


def write_adaptive_xml(resource_dir: Path) -> None:
    folder = resource_dir / "mipmap-anydpi-v26"
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '  <background android:drawable="@android:color/transparent" />\n'
        '  <foreground android:drawable="@drawable/ic_launcher_foreground" />\n'
        '</adaptive-icon>\n',
        encoding="utf-8",
    )


if __name__ == "__main__":
    for density, px in DENSITIES.items():
        icon = RES / f"mipmap-{density}" / "ic_launcher.png"
        if not icon.is_file():
            raise SystemExit(f"Missing launcher: {icon}")
        clean_icon(icon, px)
        print(f"Transparent silhouette: {icon.relative_to(ROOT)}")
    create_adaptive_launcher(
        RES / "mipmap-xxxhdpi" / "ic_launcher.png",
        RES / "drawable-nodpi" / "ic_launcher_foreground.png",
    )
    write_adaptive_xml(RES)
    print("Adaptive launcher: transparent backing, icon inside Android safe zone")
