#!/usr/bin/env python3
"""Check independently generated lesson pictures before packaging an APK.

Does not crop a source image and cannot automatically certify that artwork
semantically depicts its lesson or that faces are blank. Those are editorial
review requirements recorded in the manifest.
"""
import hashlib
import json
import re
from pathlib import Path

from verify_assets import webp_dimensions

ROOT = Path(__file__).resolve().parents[1]
DIR = ROOT / "assets/artwork/lesson_generated"
EXPECTED = {"unit": {(768, 768), (960, 720)}, "word": {(768, 768)},
            "lesson": {(1024, 1024), (960, 720)}, "dialogue": {(1280, 720), (960, 720)}}
FIELDS = {"id", "kind", "content_id", "meaning", "file",
          "source", "sha256", "width", "height",
          "semantics_reviewed", "blank_faces_reviewed", "standalone_reviewed"}


def check():
    manifest = json.loads((DIR / "manifest.json").read_text(encoding="utf-8"))
    if manifest.get("schema_version") != 1 or not isinstance(manifest.get("images"), list):
        raise ValueError("Expected version-1 standalone artwork manifest")
    ids, files, hashes, concepts = set(), set(), set(), set()
    registered = set()
    for name in ("level1.json", "original_lessons.json",
                 "book1_original_dialogues.json", "book1_part2_editorial.json"):
        catalog = json.loads((ROOT / "assets/content" / name).read_text(encoding="utf-8"))
        for item in catalog.get("modules", []):
            registered.add(("unit", item["id"]))
        for item in catalog.get("lessons", []):
            registered.add(("lesson", item["id"]))
            registered.add(("dialogue", item["id"]))
            for index, _ in enumerate(item.get("vocabulary", [])):
                registered.add(("word", f"{item['id']}:{index}"))
    for image in manifest["images"]:
        if not isinstance(image, dict) or set(image) != FIELDS:
            raise ValueError("Every illustration needs all provenance and review fields")
        identity, kind, content_id = image["id"], image["kind"], image["content_id"]
        if not isinstance(identity, str) or not re.fullmatch(r"[a-z0-9][a-z0-9_-]*", identity):
            raise ValueError("Illustration IDs must be safe lowercase slugs")
        if identity in ids:
            raise ValueError(f"Duplicate illustration ID: {identity}")
        ids.add(identity)
        if kind not in EXPECTED or (kind, content_id) not in registered:
            raise ValueError(f"Image has no matching content concept: {identity}")
        if (kind, content_id) in concepts:
            raise ValueError(f"More than one image assigned to {kind}:{content_id}")
        concepts.add((kind, content_id))
        if any(image[field] is not True for field in
               ("semantics_reviewed", "blank_faces_reviewed", "standalone_reviewed")):
            raise ValueError(f"Illustration lacks editorial review: {identity}")
        if not isinstance(image["meaning"], str) or not image["meaning"].strip():
            raise ValueError(f"Missing meaning label: {identity}")
        if not isinstance(image["source"], str) or "standalone" not in image["source"].lower():
            raise ValueError(f"Scene is not identified as standalone generation: {identity}")
        filename = f"assets/artwork/lesson_generated/{identity}.webp"
        if image["file"] != filename:
            raise ValueError(f"Incorrect asset name for {identity}")
        path = DIR / f"{identity}.webp"
        if not path.is_file() or path.is_symlink():
            raise ValueError(f"Missing standalone illustration: {identity}")
        if any(type(image[k]) is not int for k in ("width", "height")):
            raise ValueError("Image dimensions must be integers")
        size = (image["width"], image["height"])
        if size not in EXPECTED[kind] or webp_dimensions(path.read_bytes()) != size:
            raise ValueError(f"Invalid image dimensions: {identity}")
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if image["sha256"] != digest or digest in hashes:
            raise ValueError(f"Incorrect or duplicated image: {identity}")
        hashes.add(digest)
        files.add(path.resolve())
    for path in DIR.glob("*.webp"):
        if path.resolve() not in files:
            raise ValueError(f"Unregistered image: {path.name}")
    for name in ("level1.json", "original_lessons.json",
                 "book1_original_dialogues.json", "book1_part2_editorial.json"):
        catalog = json.loads((ROOT / "assets/content" / name).read_text(encoding="utf-8"))
        for kind, key, rows in (("unit", "illustration_asset", catalog.get("modules", [])),
                                ("lesson", "illustration_asset", catalog.get("lessons", [])),
                                ("dialogue", "dialogue_illustration_asset", catalog.get("lessons", []))):
            for row in rows:
                asset = row.get(key)
                if asset is not None:
                    if (kind, row["id"]) not in concepts:
                        raise ValueError(f"No unique illustration registered for {kind}:{row['id']}")
                    if not any(i["kind"] == kind and i["content_id"] == row["id"]
                               and i["file"] == asset for i in manifest["images"]):
                        raise ValueError(f"Mismatched content-image mapping for {row['id']}")
    return len(files)


if __name__ == "__main__":
    count = check()
    print(f"Standalone images verified: {count} (no crops or duplicates accepted)")
