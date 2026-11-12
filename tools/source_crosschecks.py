#!/usr/bin/env python3
"""Validate manually recorded multi-source Arabic lexical evidence offline.

NOT a web scraper and NOT an OCR/transcription tool. Printed Bayna dictionary
pages on aljam3 have OCR errors; never treat them as proof of diacritics.
Keep independently written Arabic explanations in the app, not source extracts.

Run from the project root:
    python3 tools/source_crosschecks.py
"""
from __future__ import annotations

import json
import re
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "assets" / "data"
SOURCES = {
    "bayna_ocr": ("aljam3.com", "ocr_context_only", "/ar/39951/73248/"),
    "arabily": ("arabily.app", "selectable_vocabulary", "/bayna-yadayk-"),
    "academy": (
        "www.arabicacademy.gov.eg",
        "official_selectable_lexicon",
        "/ar/",
    ),
}
TRUSTED_FORM_SOURCES = {"arabily", "academy"}
ROLES = {"headword", "plural", "imperfect", "masdar", "feminine", "origin_verb"}
ARABIC = re.compile(r"[\u0621-\u064a]")
HARAKAT = re.compile(r"[\u064b-\u065f\u0670]")
CYRILLIC = re.compile(r"[\u0400-\u04ff]")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def validate_registry(registry: dict) -> int:
    """Structural source QC: proof-of-reading is explicitly narrower than proof-of-Arabic."""
    require(registry.get("schema_version") == 1, "Unsupported evidence schema")
    records = registry.get("records")
    require(isinstance(records, list) and records, "Missing source checks")
    seen = set()
    for record in records:
        require(not CYRILLIC.search(json.dumps(record, ensure_ascii=False)),
                "Russian text is forbidden in Arabic source evidence")
        word = record.get("arabic")
        require(isinstance(word, str) and ARABIC.search(word) and HARAKAT.search(word),
                f"Unvowelled Arabic word: {word}")
        require(word not in seen, f"Repeated source check: {word}")
        seen.add(word)
        require(record.get("review_scope") == "forms_and_meanings_only",
                f"Unproven review scope for: {word}")
        require(record.get("source_independent_full_proofread") is False,
                f"Full Arabic proofread not established: {word}")
        sources = record.get("sources")
        require(isinstance(sources, dict) and set(sources) == set(SOURCES),
                f"Three sources required for: {word}")
        for source_id, (hostname, mode, path_prefix) in SOURCES.items():
            source = sources[source_id]
            require(isinstance(source, dict) and source.get("mode") == mode,
                    f"Incorrect source mode: {word}/{source_id}")
            uri = source.get("url", "")
            parsed = urlsplit(uri)
            require(parsed.scheme == "https" and parsed.hostname == hostname
                    and parsed.path.startswith(path_prefix),
                    f"Untrusted source link: {word}/{source_id}")
        forms = record.get("forms")
        require(isinstance(forms, list) and forms, f"Missing checked forms: {word}")
        checked = set()
        for fact in forms:
            role, value = fact.get("role"), fact.get("arabic")
            providers = fact.get("verified_by")
            require(role in ROLES and isinstance(value, str)
                    and ARABIC.search(value) and HARAKAT.search(value),
                    f"Invalid form: {word}/{role}")
            require(role not in checked, f"Repeated role: {word}/{role}")
            checked.add(role)
            require(isinstance(providers, list) and providers
                    and len(providers) == len(set(providers))
                    and set(providers) <= TRUSTED_FORM_SOURCES,
                    f"OCR or unknown source cannot validate harakat: {word}/{role}")
            if role == "headword":
                require(value == word, f"Headword does not match: {word}")
        require("headword" in checked, f"Unchecked headword: {word}")
    return len(records)


def verify_article_alignment(registry: dict, articles: dict) -> int:
    """Ensure checked facts really appear in the existing independent articles."""
    matched = 0
    for record in registry["records"]:
        word = record["arabic"]
        article = articles.get(word)
        require(isinstance(article, dict), f"No reviewed Arabic article: {word}")
        grammar = " ".join(
            item.get("ar", "") for item in article.get("grammar", []))
        urls = set(article.get("source_urls", []))
        for source in record["sources"].values():
            require(source["url"] in urls,
                    f"Source citation absent from reviewed article: {word}")
        for form in record["forms"]:
            value, role = form["arabic"], form["role"]
            if role == "headword":
                require(article.get("arabic") == value,
                        f"Article headword mismatch: {word}")
            else:
                require(value in grammar, f"Wrong or missing harakat in {word}: {role}")
        require(article.get("source_review") in (
            "scan_page_inspected_first_pass_pending_linguistic_proofread",
            "visual_check_of_user_supplied_scan_12383_pdf",
        ), f"Missing provenance marker: {word}")
        matched += 1
    return matched


def main() -> None:
    registry = json.loads(
        (DATA / "lexical_source_crosschecks_v1.json").read_text(encoding="utf-8"))
    reviewed = json.loads(
        (DATA / "reviewed_articles_v1.json").read_text(encoding="utf-8"))
    checked_count = validate_registry(registry)
    articles = {entry["arabic"]: entry for entry in reviewed["entries"]}
    attached = verify_article_alignment(registry, articles)
    print(f"Three-source checked articles (select forms / meanings): {attached}")
    print(f"Total reviewed Arabic articles: {len(articles)}")
    print(f"Still not independently proofread: {len(articles)}")
    print(f"Each checked article includes links to {len(SOURCES)} distinct sources.")
    assert checked_count == attached


if __name__ == "__main__":
    main()
