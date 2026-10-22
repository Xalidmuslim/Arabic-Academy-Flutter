#!/usr/bin/env python3
"""Remove the baked-in pale square without changing the original 3D emblem.

Run BEFORE Flutter/Gradle bundle resources. Operates in-place on all mipmaps;
original binaries remain available in the previous Git commit for rollback.
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / 'android' / 'app' / 'src' / 'main' / 'res'
DENSITIES = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}


def alpha_mask(size: int) -> Image.Image:
    supersample = 4
    mask = Image.new('L', (size * supersample, size * supersample), 0)
    draw = ImageDraw.Draw(mask)
    bounds = tuple(round(value * size * supersample) for value in
                   (27 / 192, 24 / 192, 166 / 192, 166 / 192))
    draw.rounded_rectangle(
        bounds, radius=round(25 * size * supersample / 192), fill=255)
    return mask.resize((size, size), Image.Resampling.LANCZOS)


def clean_icon(path: Path, expected_size: int) -> None:
    with Image.open(path) as source:
        if source.size != (expected_size, expected_size):
            raise ValueError(f'Unexpected icon dimensions: {path}: {source.size}')
        image = source.convert('RGBA')
    if image.getpixel((0, 0))[3] == 0:
        return  # idempotent after regeneration / local rebuild
    image.putalpha(alpha_mask(expected_size))
    image.save(path, optimize=True)


if __name__ == '__main__':
    for density, px in DENSITIES.items():
        path = RES / f'mipmap-{density}' / 'ic_launcher.png'
        if not path.is_file():
            raise SystemExit(f'Launcher asset missing: {path}')
        clean_icon(path, px)
        print(f'Clean alpha launcher: {path.relative_to(ROOT)}')
