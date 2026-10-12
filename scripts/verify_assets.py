#!/usr/bin/env python3
"""Offline asset, provenance, local-font, and teaching JSON integrity checks."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import struct


class ValidationError(ValueError):
    pass


SCENES = {"hero", "lessons", "grammar", "vocabulary", "progress", "oral",
          "live", "teacher", "exercises", "emblem"}
MANIFEST_FIELDS = {"id", "file", "source_filename", "origin", "sha256", "width", "height"}
FONT_LICENSES = {
    "Manrope": {"file": "assets/fonts/Manrope.ttf", "license": "assets/fonts/manrope-OFL.txt",
                "source": "https://github.com/googlefonts/manrope",
                "sha256": "3ae11c49db0455a3cc33e37d380f20fdb8c7f8b41dc07625c177e3d87a9d6ae6"},
    "NotoNaskhArabic": {"file": "assets/fonts/NotoNaskhArabic.ttf", "license": "assets/fonts/notonaskharabic-OFL.txt",
                       "source": "https://github.com/notofonts/arabic",
                       "sha256": "67b5a525a661b607971fbd3f96a81b89d3a768e74534fca84f18ac97e6fab72f"},
}


def _fail(message):
    raise ValidationError(message)


def _keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            _fail(f"Duplicate JSON key: {key}")
        result[key] = value
    return result


def _json(path):
    try:
        return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=_keys,
                          parse_constant=lambda _: _fail("Nonfinite JSON number"))
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise ValidationError(f"Invalid UTF-8 JSON: {path.name}") from exc


def _safe_path(root, value):
    if not isinstance(value, str) or not value or "\\" in value:
        _fail("Asset path must be a nonempty relative POSIX path")
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts or "images" in path.parts or "_embedded" in path.parts:
        _fail(f"Unsafe or prohibited asset path: {value}")
    resolved = (root / value).resolve()
    if not resolved.is_relative_to(root.resolve()) or not resolved.exists():
        _fail(f"Missing asset or path outside checkout: {value}")
    if {"images", "_embedded"}.intersection(resolved.relative_to(root.resolve()).parts):
        _fail(f"Asset aliases cannot package legacy artwork: {value}")
    return resolved


def webp_dimensions(data):
    if len(data) < 20 or data[:4] != b"RIFF" or data[8:12] != b"WEBP":
        _fail("Invalid WebP container")
    if struct.unpack_from("<I", data, 4)[0] + 8 != len(data):
        _fail("WebP RIFF length mismatch")
    offset = 12
    while offset + 8 <= len(data):
        tag = data[offset:offset + 4]
        length = struct.unpack_from("<I", data, offset + 4)[0]
        payload = data[offset + 8:offset + 8 + length]
        if len(payload) != length or offset + 8 + length + (length % 2) > len(data):
            _fail("Truncated WebP chunk")
        if tag == b"VP8X" and length == 10:
            return int.from_bytes(payload[4:7], "little") + 1, int.from_bytes(payload[7:10], "little") + 1
        if tag == b"VP8L" and length >= 5 and payload[0] == 0x2f:
            bits = int.from_bytes(payload[1:5], "little")
            if bits >> 29:
                _fail("Unsupported lossless WebP version")
            return (bits & 0x3fff) + 1, ((bits >> 14) & 0x3fff) + 1
        if tag == b"VP8 " and length >= 10 and payload[3:6] == b"\x9d\x01\x2a":
            return struct.unpack_from("<H", payload, 6)[0] & 0x3fff, struct.unpack_from("<H", payload, 8)[0] & 0x3fff
        offset += 8 + length + (length % 2)
    _fail("WebP contains no supported image dimensions")


def _scalar(value):
    value = value.strip()
    if value.startswith('"'):
        try:
            value = json.loads(value)
        except json.JSONDecodeError:
            _fail("Unsupported quoted pubspec asset")
    elif value.startswith("'") and value.endswith("'"):
        value = value[1:-1].replace("''", "'")
    else:
        value = value.split(" #", 1)[0].strip()
    if not isinstance(value, str) or re.search(r"[\[\]{}&*!]", value):
        _fail("Pubspec asset syntax needs an explicit supported local path")
    return value


def _pubspec(root):
    # Deliberately small fail-closed parser for Flutter's block-list asset/font
    # declarations. No third-party YAML package or silently ignored inline list.
    text = (root / "pubspec.yaml").read_text(encoding="utf-8")
    if "\t" in text:
        _fail("Pubspec cannot use tab indentation")
    flutter = False
    section = None
    assets = []
    fonts = {}
    family = None
    for line in text.splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        indent = len(line) - len(line.lstrip())
        value = line.strip()
        if indent == 0:
            flutter = value == "flutter:"
            section = None
            continue
        if not flutter:
            continue
        if indent == 2:
            section = value[:-1] if value.endswith(":") else None
            if value.startswith(("assets:", "fonts:")) and not value.endswith(":"):
                _fail("Use block lists for Flutter assets/fonts")
            continue
        if section == "assets":
            if not value.startswith("- ") or indent != 4:
                _fail("Unsupported asset declaration; use one explicit path per block-list entry")
            assets.append(_scalar(value[2:]))
        elif section == "fonts":
            if indent == 4 and value.startswith("- family:"):
                family = _scalar(value.partition(":")[2])
                if family in fonts:
                    _fail("Duplicate font family")
                fonts[family] = []
            elif indent == 6 and value == "fonts:":
                continue
            elif indent == 8 and value.startswith("- asset:") and family:
                fonts[family].append(_scalar(value.partition(":")[2]))
            elif indent == 10 and value.startswith(("weight:", "style:")):
                continue
            else:
                _fail("Unsupported font declaration; ensure every font has a family and local asset")
    if not assets or set(fonts) != set(FONT_LICENSES):
        _fail("Flutter assets and both licensed local font families must be declared")
    if len(assets) != len(set(assets)):
        _fail("Duplicate Flutter asset declaration")
    return assets, fonts


def _identified(items, label):
    if not isinstance(items, list):
        _fail(f"{label} must be a list")
    seen = set()
    for item in items:
        if not isinstance(item, dict) or not isinstance(item.get("id"), str) or not item["id"].strip():
            _fail(f"{label} needs explicit nonempty IDs")
        if item["id"] in seen:
            _fail(f"Duplicate ID within {label}")
        seen.add(item["id"])
    return items


def _exercise(item):
    kind = item.get("kind", "singleChoice" if "options" in item else None)
    if not isinstance(kind, str) or not kind.strip():
        _fail("Exercise kind must be an explicit nonempty string")
    if kind in {"singleChoice", "listeningChoice", "imageChoice", "readingComprehension"}:
        options = item.get("options")
        correct = item.get("correct")
        if not isinstance(options, list) or not options or any(not isinstance(x, str) or not x.strip() for x in options):
            _fail("Choice options must be nonempty strings")
        if type(correct) is not int or not 0 <= correct < len(options):
            _fail("Choice answer key is not a valid original option index")
    config = item.get("config", {})
    if not isinstance(config, dict):
        _fail("Exercise config must be an object")
    for field, minimum in [("points", 0), ("maxAttempts", 1), ("timeLimitSeconds", 1)]:
        if field in config and (type(config[field]) is not int or config[field] < minimum):
            _fail(f"Invalid exercise {field}")
    if "randomizeOptions" in config and type(config["randomizeOptions"]) is not bool:
        _fail("randomizeOptions must be a boolean")
    if "passThreshold" in config and (type(config["passThreshold"]) not in {int, float} or not 0 <= config["passThreshold"] <= 1):
        _fail("Invalid exercise passThreshold")


def _content(path):
    value = _json(path)
    if not isinstance(value, dict):
        _fail(f"Content root must be an object: {path.name}")
    for key in ["modules", "lessons", "topics"]:
        if key not in value:
            continue
        for item in _identified(value[key], key):
            if key == "modules":
                if item.get("access_default") not in ("free", "purchase_or_subscription"):
                    _fail("Unknown module access policy")
                continue
            if not isinstance(item.get("title"), str) or not item["title"].strip():
                _fail("Lessons/topics need titles")
            if "options" in item:
                _exercise(item)
            for exercise in _identified(item.get("exercises", []), f"{key}:{item['id']}:exercises"):
                if not isinstance(exercise.get("prompt"), str) or not exercise["prompt"].strip():
                    _fail("Exercises need prompts")
                _exercise(exercise)
            for field in ["dialogue", "vocabulary", "examples"]:
                if field in item and (not isinstance(item[field], list) or any(not isinstance(x, dict) or
                        not isinstance(x.get("ar"), str) or not x["ar"].strip() or not isinstance(x.get("ru"), str)
                        for x in item[field])):
                    _fail(f"Invalid Arabic/Russian {field} entries")
            if "table" in item:
                table = item["table"]
                if not isinstance(table, dict) or not isinstance(table.get("columns"), list) or not table["columns"] or \
                        not isinstance(table.get("rows"), list) or any(not isinstance(row, list) or len(row) != len(table["columns"]) or
                        any(not isinstance(cell, str) for cell in row) for row in table["rows"]):
                    _fail("Invalid grammar table shape")
    return value


def validate_assets(root):
    root = Path(root).resolve()
    assets, fonts = _pubspec(root)
    declared = set()
    for name in assets:
        path = _safe_path(root, name)
        if path.is_dir():
            if not name.endswith("/") or name in {"assets/", "./"}:
                _fail("Asset directories must be explicitly scoped and end with /")
            files = [p for p in path.rglob("*") if p.is_file()]
            if not files:
                _fail("Declared asset directory is empty")
            for file in files:
                declared.add(_safe_path(root, file.relative_to(root).as_posix()))
        else:
            declared.add(path)
    manifest_path = _safe_path(root, "assets/artwork/manifest.json")
    manifest = _json(manifest_path)
    if not isinstance(manifest, list) or len(manifest) != len(SCENES):
        _fail("Artwork manifest must describe exactly ten standalone scenes")
    identities, hashes, files = set(), set(), set()
    for entry in manifest:
        if not isinstance(entry, dict) or set(entry) != MANIFEST_FIELDS:
            _fail("Artwork metadata fields must exactly match the documented manifest schema")
        identity = entry["id"]
        if not isinstance(identity, str) or identity not in SCENES or identity in identities:
            _fail("Artwork IDs must be unique members of the ten approved scenes")
        identities.add(identity)
        name = f"assets/artwork/{identity}.webp"
        if entry["file"] != name:
            _fail("Scene file must match its ID in assets/artwork")
        path = _safe_path(root, name)
        if path not in declared:
            _fail("Every approved scene must be declared as a Flutter asset")
        source = entry["source_filename"]
        if not isinstance(source, str) or not re.fullmatch(r"exec-[0-9a-f-]{36}\.png", source):
            _fail("Scene source_filename must identify its standalone generated source")
        origin = entry["origin"]
        if not isinstance(origin, str) or not origin.startswith("OpenAI ImageGen; standalone original generation ") or "no reference crops" not in origin:
            _fail("Scene origin must declare standalone original generation, never reference extraction")
        digest = entry["sha256"]
        if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest) or digest in hashes:
            _fail("Artwork hashes must be unique SHA-256 values")
        hashes.add(digest)
        data = path.read_bytes()
        if hashlib.sha256(data).hexdigest() != digest:
            _fail(f"Artwork hash mismatch: {identity}")
        expected_dimensions = (1200, 800) if identity == "hero" else (768, 768)
        if any(type(entry[field]) is not int for field in ["width", "height"]) or \
                (entry["width"], entry["height"]) != expected_dimensions or webp_dimensions(data) != expected_dimensions:
            _fail(f"Artwork dimensions mismatch: {identity}")
        files.add(path)
    if identities != SCENES or set((root / "assets/artwork").glob("*.webp")) != files:
        _fail("Unmanifested or missing artwork scene")
    if manifest_path not in declared:
        _fail("Artwork provenance manifest must be packaged")
    for family, metadata in FONT_LICENSES.items():
        if fonts[family] != [metadata["file"]]:
            _fail("Font family must use its approved local binary")
        path = _safe_path(root, metadata["file"])
        data = path.read_bytes()
        if data[:4] not in {b"\x00\x01\x00\x00", b"OTTO", b"true"} or hashlib.sha256(data).hexdigest() != metadata["sha256"]:
            _fail(f"Font binary/hash mismatch: {family}")
        license_text = _safe_path(root, metadata["license"]).read_text(encoding="utf-8")
        if "SIL OPEN FONT LICENSE Version 1.1" not in license_text or "Copyright" not in license_text or metadata["source"] not in license_text:
            _fail(f"Font license/provenance is missing: {family}")
    lessons = set()
    content_files = sorted(p for p in declared if p.suffix == ".json" and p.parent.name == "content")
    for path in content_files:
        content = _content(path)
        for lesson in content.get("lessons", []):
            if lesson["id"] in lessons:
                _fail("Lesson IDs collide across packaged catalogs")
            lessons.add(lesson["id"])
    for path in declared:
        if path.suffix == ".json" and path != manifest_path and path not in content_files:
            _json(path)
    return {"scenes": len(files), "fonts": len(fonts), "content_files": len(content_files),
            "declared_files": len(declared)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    try:
        result = validate_assets(args.root)
    except (ValidationError, OSError) as exc:
        parser.exit(1, f"Asset validation failed: {exc}\n")
    print("Asset integrity verified: " + json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main()
