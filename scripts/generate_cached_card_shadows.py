#!/usr/bin/env python3
"""Generate deterministic 1x nine-slice RGBA matte card shadows.

The source of truth is the existing BoxShadow lists in
lib/ui/neumorphic_components.dart. Render a compact base RRect with 56 logical
pixels of transparent overflow, Gaussian-blur each original shadow layer, then
store a 2x2 center slice which Flutter stretches over any card size. All
foreground surfaces, outlines, fonts and art remain unchanged.

This optional build-only cache requires Pillow. Do not edit original art.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
TARGET = ROOT / "assets/artwork/shadow_cache"
PADDING = 56
SCALE = 3

# (RGBA, x/y offset, blurRadius, spreadRadius): Flutter BoxShadow originals.
LIGHT_REGULAR = (
    ((0x63, 0x4F, 0x3F, 0x28), 1, 5, 11, -4),
    ((0x58, 0x45, 0x35, 0x19), 0, 13, 25, -7),
)
LIGHT_EMPHASIZED = (
    ((0x58, 0x47, 0x3B, 0x2C), 0, 5, 12, -3),
    ((0x5B, 0x48, 0x3B, 0x20), 0, 13, 25, -6),
    ((0x5B, 0x48, 0x3B, 0x12), 0, 23, 35, -10),
)
DARK = (((0x00, 0x00, 0x00, 0x55), 0, 6, 16, 0),)
VARIANTS = {
    "regular_light": (22, LIGHT_REGULAR),
    "emphasized_light": (21, LIGHT_EMPHASIZED),
    "regular_dark": (22, DARK),
    "emphasized_dark": (21, DARK),
}


def rasterize(radius: int, shadows: tuple) -> Image.Image:
    # Two logical pixels at card center become the stretchable nine-slice region.
    size = 2 * (PADDING + radius + 1)
    px = size * SCALE
    result = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    right = PADDING + 2 * (radius + 1)
    for (red, green, blue, opacity), xoff, yoff, blur, spread in shadows:
        alpha = Image.new("L", (px, px), 0)
        drawing = ImageDraw.Draw(alpha)
        # Flutter's RRect.inflate(spread) contracts negative spread masks.
        x0 = (PADDING + xoff - spread) * SCALE
        y0 = (PADDING + yoff - spread) * SCALE
        x1 = (right + xoff + spread) * SCALE
        y1 = (right + yoff + spread) * SCALE
        drawing.rounded_rectangle(
            (x0, y0, x1, y1),
            radius=max(0, radius + spread) * SCALE,
            fill=255,
        )
        # Flutter's blurRadiusToSigma = blurRadius * 0.57735 + 0.5.
        sigma = (blur * 0.57735 + 0.5) * SCALE
        alpha = alpha.filter(ImageFilter.GaussianBlur(radius=sigma))
        alpha = alpha.point(lambda value: (value * opacity + 127) // 255)
        layer = Image.new("RGBA", (px, px), (red, green, blue, 0))
        layer.putalpha(alpha)
        result = Image.alpha_composite(result, layer)
    return result.resize((size, size), Image.Resampling.LANCZOS)


def generate() -> int:
    TARGET.mkdir(parents=True, exist_ok=True)
    for name, (radius, layers) in VARIANTS.items():
        output = TARGET / f"card__{name}.png"
        rasterize(radius, layers).save(output, "PNG", optimize=True)
    print(f"Generated {len(VARIANTS)} cached card-shadow 9-slice PNGs.")
    return len(VARIANTS)


if __name__ == "__main__":
    generate()
