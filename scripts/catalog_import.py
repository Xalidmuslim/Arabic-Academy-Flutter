#!/usr/bin/env python3
"""Validate an owner-supplied licensed hierarchy, then plan, emit SQL, or call RPC.

No PDF reading, inferred numbering, generated IDs, credentials, or automatic
publication. A full manifest is validated before any output or network operation.
"""
import argparse
import copy
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import ssl
import tempfile
from urllib import error, parse, request
import uuid


class ValidationError(ValueError):
    pass


def _unique_keys(pairs):
    value = {}
    for key, item in pairs:
        if key in value:
            raise ValidationError(f"Duplicate JSON key: {key}")
        value[key] = item
    return value


def _nonfinite(value):
    raise ValidationError("Nonfinite JSON numbers are not allowed")


def load_manifest(path):
    path = Path(path)
    if path.stat().st_size > 32 * 1024 * 1024:
        raise ValidationError("Manifest exceeds 32 MiB")
    try:
        return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=_unique_keys,
                          parse_constant=_nonfinite)
    except (json.JSONDecodeError, UnicodeError, RecursionError) as exc:
        raise ValidationError("Manifest is not valid UTF-8 JSON") from exc


def _object(value, label):
    if not isinstance(value, dict):
        raise ValidationError(f"{label} must be an object")
    return value


def _text(value, label):
    if not isinstance(value, str) or not value.strip() or "\x00" in value:
        raise ValidationError(f"{label} must be a nonempty string")
    if value.strip().lower() in {"unknown", "tbd", "not_provided", "none", "-"}:
        raise ValidationError(f"{label} must contain actual owner-supplied information")
    return value


def _integer(value, label, minimum=0):
    if type(value) is not int or value < minimum:
        raise ValidationError(f"{label} must be an integer >= {minimum}")
    return value


def _uuid(value, label):
    try:
        parsed = uuid.UUID(value) if isinstance(value, str) else None
    except ValueError:
        parsed = None
    if parsed is None or parsed.int == 0 or str(parsed) != value:
        raise ValidationError(f"{label} must be a canonical, nonzero UUID")
    return value


def _pages(value, book, parent=None):
    locator = _object(value, "page_locator")
    if locator.get("book_id") != book["id"]:
        raise ValidationError("Page locator refers to a different book")
    start = _integer(locator.get("start"), "page start", 1)
    end = _integer(locator.get("end"), "page end", 1)
    if start > end or end > book["page_count"]:
        raise ValidationError("Page range is reversed or exceeds the source PDF page count")
    if parent and (start < parent["start"] or end > parent["end"]):
        raise ValidationError("Child page range is outside its parent's range")
    if "printed_label" in locator:
        _text(locator["printed_label"], "printed_label")
    return copy.deepcopy(locator)


def _source_locator(book, edition, pages=None):
    # Existing backend source_locator fields use these names. All values come
    # from verified owner metadata; unit/block locators also remain verbatim.
    locator = {"edition": edition, "pdf_sha256": book["source_sha256"],
               "source_reference": book["source_reference"]}
    if pages:
        locator.update(page_start=pages["start"], page_end=pages["end"])
        if "printed_label" in pages:
            locator["printed_label"] = pages["printed_label"]
    if len(edition) > 200 or len(json.dumps(locator, ensure_ascii=False).encode()) > 3000:
        raise ValidationError("Source locator exceeds the backend metadata limits")
    return locator


def build_plan(manifest):
    root = _object(manifest, "manifest")
    if type(root.get("schema_version")) is not int or root["schema_version"] != 1:
        raise ValidationError("Unsupported schema_version; expected 1")
    catalog_id = _uuid(root.get("catalog_id"), "catalog_id")
    edition = _text(root.get("edition"), "edition")
    license_info = _object(root.get("license"), "license")
    if license_info.get("status") != "granted":
        raise ValidationError("Owner's verified license permission is required")
    for field in ["reference", "holder", "permission_reference"]:
        _text(license_info.get(field), f"license.{field}")
    uses = license_info.get("permitted_uses")
    if not isinstance(uses, list) or "digital_learning" not in uses:
        raise ValidationError("License must explicitly permit digital_learning")
    for use in uses:
        _text(use, "license permitted use")
    provenance = _object(root.get("provenance"), "provenance")
    for field in ["publisher", "source_reference", "verified_by", "verified_at"]:
        _text(provenance.get(field), f"provenance.{field}")
    try:
        datetime.date.fromisoformat(provenance["verified_at"])
    except ValueError as exc:
        raise ValidationError("verified_at must be an ISO date YYYY-MM-DD") from exc
    rows = {name: [] for name in ["courses", "levels", "books", "units", "lessons", "blocks"]}
    seen = {catalog_id}
    slugs = set()

    def nodes(parent, name, parent_id=None, parent_key=None):
        values = parent.get(name)
        if not isinstance(values, list) or not values:
            raise ValidationError(f"Complete hierarchy requires a nonempty {name} list")
        positions = set()
        for value in values:
            node = _object(value, name)
            identity = _uuid(node.get("id"), f"{name}.id")
            if identity in seen:
                raise ValidationError("Duplicate ID in catalog hierarchy")
            seen.add(identity)
            if parent_key and node.get(parent_key) != parent_id:
                raise ValidationError(f"{name}.{parent_key} does not match the enclosing parent")
            if name != "courses":
                position = _integer(node.get("position"), f"{name}.position")
                if name == "blocks":
                    _text(node.get("step"), "block.step")
                slot = (node.get("step"), position) if name == "blocks" else position
                if slot in positions:
                    raise ValidationError(f"Duplicate sibling position in {name}")
                positions.add(slot)
            if name != "blocks":
                _text(node.get("title"), f"{name}.title")
            yield node

    for course in nodes(root, "courses"):
        slug = _text(course.get("slug"), "course.slug")
        if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", slug) or slug in slugs:
            raise ValidationError("Course slugs must be unique lowercase hyphenated identifiers")
        slugs.add(slug)
        if course.get("access_tier") not in ("free", "paid") or course.get("status") != "draft":
            raise ValidationError("Course requires an explicit access_tier and draft status")
        rows["courses"].append({key: course[key] for key in
                                ["id", "title", "slug", "access_tier", "status"]})
        for level in nodes(course, "levels", course["id"], "course_id"):
            rows["levels"].append({key: level[key] for key in ["id", "course_id", "title", "position"]})
            for book in nodes(level, "books", level["id"], "level_id"):
                if book.get("edition") != edition or book.get("license_reference") != license_info["reference"]:
                    raise ValidationError("Book edition/license must match the declared licensed edition")
                _integer(book.get("page_count"), "book.page_count", 1)
                _text(book.get("source_reference"), "book.source_reference")
                if not isinstance(book.get("source_sha256"), str) or not re.fullmatch(
                        r"[0-9a-f]{64}", book["source_sha256"]) or book["source_sha256"] == "0" * 64:
                    raise ValidationError("Book needs its owner's actual source SHA-256")
                book_row = {key: book[key] for key in
                            ["id", "level_id", "title", "position", "edition", "license_reference"]}
                book_row["source_locator"] = _source_locator(book, edition)
                rows["books"].append(book_row)
                for unit in nodes(book, "units", book["id"], "book_id"):
                    unit_pages = _pages(unit.get("page_locator"), book)
                    rows["units"].append({key: unit[key] for key in ["id", "book_id", "title", "position"]})
                    for lesson in nodes(unit, "lessons", unit["id"], "unit_id"):
                        if lesson.get("status") != "draft":
                            raise ValidationError("Imported lessons must be drafts")
                        lesson_pages = _pages(lesson.get("page_locator"), book, unit_pages)
                        row = {key: lesson[key] for key in ["id", "unit_id", "title", "position", "status"]}
                        row["source_locator"] = _source_locator(book, edition, lesson_pages)
                        for field in ["title_ar", "goal", "legacy_id"]:
                            if field in lesson:
                                _text(lesson[field], f"lesson.{field}")
                                row[field] = lesson[field]
                        rows["lessons"].append(row)
                        for block in nodes(lesson, "blocks", lesson["id"], "lesson_id"):
                            if block.get("step") not in ("dialogue", "vocabulary", "grammar", "practice", "test", "homework"):
                                raise ValidationError("Invalid learning step in block")
                            if block.get("kind") not in ("text", "heading", "image", "audio", "video", "exercise"):
                                raise ValidationError("Invalid block kind")
                            body = _object(block.get("body"), "block.body")
                            if not body or {"page_locator", "source_metadata"}.intersection(body):
                                raise ValidationError("Block body must be nonempty and leave provenance keys reserved")
                            if len(json.dumps(body, ensure_ascii=False).encode()) > 1024 * 1024:
                                raise ValidationError("Block body exceeds 1 MiB")
                            locator = _pages(block.get("page_locator"), book, lesson_pages)
                            row = {key: block[key] for key in ["id", "lesson_id", "step", "kind", "position"]}
                            row["body"] = {**copy.deepcopy(body), "page_locator": locator,
                                           "source_metadata": {"edition": edition, "license_reference": license_info["reference"],
                                                               "source_reference": book["source_reference"],
                                                               "source_sha256": book["source_sha256"], "provenance": copy.deepcopy(provenance)}}
                            rows["blocks"].append(row)
    counts = {key: len(value) for key, value in rows.items()}
    expected = _object(root.get("counts"), "counts")
    if set(expected) != set(counts) or any(type(expected[key]) is not int or expected[key] != counts[key] for key in counts):
        raise ValidationError("Declared complete counts do not match the full manifest")
    try:
        canonical = json.dumps(root, ensure_ascii=False, sort_keys=True, allow_nan=False, separators=(",", ":"))
    except (ValueError, TypeError) as exc:
        raise ValidationError("Manifest contains values that are not JSON compatible") from exc
    return {"schema_version": 1, "catalog_id": catalog_id, "status": "draft", "counts": counts,
            "manifest_sha256": hashlib.sha256(canonical.encode()).hexdigest(),
            "rows": rows, "manifest": copy.deepcopy(root), "required_rpc": "import_licensed_catalog"}


def _sql_value(value):
    if type(value) is int:
        return str(value)
    if isinstance(value, dict):
        return "'" + json.dumps(value, ensure_ascii=False, allow_nan=False).replace("'", "''") + "'::jsonb"
    return "'" + str(value).replace("'", "''") + "'"


def render_sql(plan):
    # Plain INSERTs: existing IDs/slugs/positions abort the entire transaction.
    # PostgreSQL enforces the caller's privileges/RLS. No grants or bypasses.
    lines = ["BEGIN;", "SET LOCAL standard_conforming_strings = on;",
             "-- Execute only through the server's authorized catalog administrator."]
    for name, values in plan["rows"].items():
        table = "lesson_blocks" if name == "blocks" else name
        for original in values:
            row = dict(original)
            if name == "courses":
                row["source_policy"] = json.dumps({"catalog_id": plan["catalog_id"],
                    "manifest_sha256": plan["manifest_sha256"], "manifest": plan["manifest"]}, ensure_ascii=False)
            lines.append(f"INSERT INTO public.{table} ({', '.join(row)}) VALUES ({', '.join(_sql_value(v) for v in row.values())});")
    return "\n".join([*lines, "COMMIT;", ""])


def validate_receipt(plan, receipt):
    if not isinstance(receipt, dict) or not isinstance(receipt.get("counts"), dict) or \
            any(type(value) is not int for value in receipt["counts"].values()) or any(receipt.get(key) != plan[key] for key in
                                          ["catalog_id", "manifest_sha256", "counts", "status"]):
        raise ValidationError("RPC receipt does not verify this complete draft import")


class _NoRedirect(request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValidationError("Catalog RPC redirects are refused; credentials stay on the configured origin")


def apply_rpc(plan):
    names = ["CATALOG_SUPABASE_URL", "CATALOG_API_KEY", "CATALOG_ACCESS_TOKEN"]
    values = {name: os.environ.get(name, "") for name in names}
    if any(not value for value in values.values()):
        raise ValidationError("RPC requires environment names: " + ", ".join(names))
    if any(any(ord(char) < 33 or ord(char) > 126 for char in values[name]) for name in names[1:]):
        raise ValidationError("Catalog credential headers contain invalid characters")
    try:
        url = parse.urlsplit(values["CATALOG_SUPABASE_URL"])
        url.port  # Reject malformed ports without printing the URL.
    except ValueError:
        raise ValidationError("CATALOG_SUPABASE_URL must be a valid root HTTPS origin") from None
    if url.scheme != "https" or not url.hostname or url.username or url.password or url.query or url.fragment or url.path not in {"", "/"}:
        raise ValidationError("CATALOG_SUPABASE_URL must be a root HTTPS origin")
    payload = json.dumps({"p_manifest": plan["manifest"], "p_manifest_sha256": plan["manifest_sha256"]},
                         ensure_ascii=False, allow_nan=False).encode()
    req = request.Request(values["CATALOG_SUPABASE_URL"].rstrip("/") + "/rest/v1/rpc/import_licensed_catalog",
                          data=payload, headers={"Authorization": "Bearer " + values["CATALOG_ACCESS_TOKEN"],
                                                "apikey": values["CATALOG_API_KEY"], "Content-Type": "application/json"}, method="POST")
    try:
        opener = request.build_opener(request.ProxyHandler(),
                                      request.HTTPSHandler(context=ssl.create_default_context()), _NoRedirect())
        with opener.open(req, timeout=30) as response:
            body = response.read(1024 * 1024 + 1)
        if len(body) > 1024 * 1024:
            raise ValidationError("RPC receipt exceeds its size limit")
        try:
            receipt = json.loads(body, object_pairs_hook=_unique_keys, parse_constant=_nonfinite)
        except (ValidationError, json.JSONDecodeError, UnicodeError, RecursionError):
            raise ValidationError("Catalog RPC returned invalid JSON; no receipt verified") from None
    except error.HTTPError as exc:
        raise ValidationError(f"Catalog RPC rejected the request (HTTP {exc.code}); no receipt verified") from None
    except (error.URLError, TimeoutError, json.JSONDecodeError, UnicodeError) as exc:
        raise ValidationError("Catalog RPC result is unknown; reconcile using the manifest hash before retrying") from None
    validate_receipt(plan, receipt)
    return receipt


def _write_output(path, text):
    path = Path(path)
    if path.exists():
        raise ValidationError("Output already exists; choose a new review artifact path")
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent, delete=False) as output:
        temporary = Path(output.name)
        output.write(text)
    try:
        # Exclusive destination creation avoids replacing existing user files.
        os.link(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--format", choices=["plan", "sql"], default="plan")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--apply-rpc", action="store_true", help="Explicitly submit a validated plan to an authorized, installed atomic RPC")
    args = parser.parse_args()
    try:
        plan = build_plan(load_manifest(args.manifest))
        text = render_sql(plan) if args.format == "sql" else json.dumps(plan, ensure_ascii=False, indent=2) + "\n"
        if args.output:
            _write_output(args.output, text)
        elif not args.apply_rpc:
            print(text, end="")
        if args.apply_rpc:
            receipt = apply_rpc(plan)
            print(json.dumps(receipt, ensure_ascii=False))
    except (ValidationError, OSError) as exc:
        parser.exit(1, f"Catalog validation/import failed: {exc}\n")


if __name__ == "__main__":
    main()
