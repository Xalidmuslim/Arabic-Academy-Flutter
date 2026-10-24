#!/usr/bin/env python3
"""Generate immutable transparent Gaussian silhouette masks for Flutter art.

Generated files are an optional build cache (NOT new art). FittedStudyArtwork
tints the masks at runtime, including proper dark/light alpha, and draws the
unaltered original WebP above them. This avoids ImageFiltered per-frame GPU
passes for static silhouettes. Only deterministic local artwork is processed.
"""
from pathlib import Path
import argparse
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets/artwork"
TARGET = SOURCE / "shadow_cache"


def mask_name(source: Path) -> str:
    return "__".join(source.relative_to(SOURCE).with_suffix("").parts) + ".png"


def generate_one(source: Path, destination: Path) -> None:
    with Image.open(source) as source_image:
        rgba = source_image.convert("RGBA")
        alpha = rgba.getchannel("A")
        # Flutter's live sigma was min(display width, height) * 0.025.
        # A proportional pre-blur preserves the radius after BoxFit.contain.
        sigma = min(rgba.size) * 0.025
        blurred_alpha = alpha.filter(ImageFilter.GaussianBlur(radius=sigma))
        mask = Image.new("RGBA", rgba.size, (255, 255, 255, 0))
        mask.putalpha(blurred_alpha)
        destination.parent.mkdir(parents=True, exist_ok=True)
        mask.save(destination, format="PNG", optimize=True)


def generate() -> int:
    sources = sorted(p for p in SOURCE.rglob("*.webp")
                     if TARGET not in p.parents)
    if not sources:
        raise RuntimeError("No WebP art to generate shadow masks from.")
    TARGET.mkdir(parents=True, exist_ok=True)
    names = [mask_name(p) for p in sources]
    if len(set(names)) != len(names):
        raise RuntimeError("Colliding generated shadow names.")
    # Keep regenerated builds byte-for-byte deterministic and remove stale
    # masks for assets that no longer exist.
    expected = set(names)
    for orphan in TARGET.glob("*.png"):
        # These cache entries are generated independently by the optional
        # cached-card shadow build step. Never delete them during art preblur.
        if orphan.name.startswith("card__"):
            continue
        if orphan.name not in expected:
            orphan.unlink()
    for image in sources:
        generate_one(image, TARGET / mask_name(image))
    print(f"Generated {len(sources)} shadow masks in {TARGET}")
    return len(sources)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    generate()
