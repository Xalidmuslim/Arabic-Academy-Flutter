#!/usr/bin/env python3
"""Reconcile two *git revisions* of every source card by stable ID.

This one-off audit clarifies whether a drop in the unique-lemma counter
represents lost cards or headword spelling consolidation. It never changes
the source corpus and never merges distinct Arabic homographs.
"""
from __future__ import annotations

import argparse
import json
import subprocess
from collections import defaultdict
from pathlib import Path
from typing import Any, Iterable


def _references(card: dict[str, Any]) -> set[tuple[int, int, int]]:
    refs = card.get("book_references")
    if refs is None:
        refs = [card["book_reference"]] if card.get("book_reference") else []
    return {
        (int(r["book"]), int(r["chapter"]), int(r["index"]))
        for r in refs if isinstance(r, dict)
        and all(isinstance(r.get(k), int) for k in ("book", "chapter", "index"))
    }


def _index(cards: Iterable[tuple[str, dict[str, Any]]]) -> dict[str, tuple[str, dict[str, Any]]]:
    by_id: dict[str, tuple[str, dict[str, Any]]] = {}
    for source_file, card in cards:
        key = card.get("id")
        if not isinstance(key, str) or not key:
            raise ValueError(f"Missing card id: {source_file}")
        if key in by_id:
            raise ValueError(f"Repeated card id: {key}")
        by_id[key] = (source_file, card)
    return by_id


def reconcile_cards(before: Iterable[tuple[str, dict[str, Any]]],
                    after: Iterable[tuple[str, dict[str, Any]]]) -> dict[str, Any]:
    earlier = _index(before)
    current = _index(after)
    common = sorted(earlier.keys() & current.keys())
    old_words = {card.get("arabic") for _, card in earlier.values()}
    new_words = {card.get("arabic") for _, card in current.values()}
    names_for_new: dict[str, set[str]] = defaultdict(set)
    examples: dict[str, list[dict[str, str]]] = defaultdict(list)
    changed = 0
    refs_removed = []
    moved = []
    for cid in common:
        old_file, old = earlier[cid]
        new_file, new = current[cid]
        old_word, new_word = old.get("arabic"), new.get("arabic")
        if old_word != new_word:
            changed += 1
        if isinstance(old_word, str) and isinstance(new_word, str):
            names_for_new[new_word].add(old_word)
            if old_word != new_word:
                examples[new_word].append({"id": cid, "before": old_word, "after": new_word})
        if old_file != new_file:
            moved.append(cid)
        lost_refs = _references(old) - _references(new)
        for ref in sorted(lost_refs):
            refs_removed.append({"id": cid, "reference": list(ref)})

    consolidated = [
        {"after": word, "old_forms": sorted(forms),
         "changed_cards": examples[word][:12]}
        for word, forms in names_for_new.items() if len(forms) > 1
    ]
    consolidated.sort(key=lambda row: (-len(row["old_forms"]), row["after"]))
    changed_examples = [
        {"id": cid, "from": earlier[cid][1].get("arabic"),
         "to": current[cid][1].get("arabic"), "file": current[cid][0]}
        for cid in common if earlier[cid][1].get("arabic") != current[cid][1].get("arabic")
    ]
    return {
        "before_raw": len(earlier),
        "after_raw": len(current),
        "before_unique_exact": len(old_words),
        "after_unique_exact": len(new_words),
        "net_unique_change": len(new_words) - len(old_words),
        "retained_ids": len(common),
        "deleted_ids": sorted(earlier.keys() - current.keys()),
        "added_ids": sorted(current.keys() - earlier.keys()),
        "changed_headwords": changed,
        "changed_headword_examples": changed_examples,
        "consolidated_headword_groups": len(consolidated),
        "consolidation_details": consolidated,
        "moved_ids": moved,
        "references_removed": len(refs_removed),
        "reference_loss_details": refs_removed,
    }


def _git_show(revision: str, path: str) -> str:
    if not revision or revision.startswith("-") or ":" in revision or any(c.isspace() for c in revision):
        raise ValueError("Invalid git revision")
    if not path.startswith("assets/data/") or ".." in Path(path).parts:
        raise ValueError("Invalid corpus file path")
    result = subprocess.run(
        ["git", "show", f"{revision}:{path}"],
        check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        encoding="utf-8",
    )
    return result.stdout


def read_revision(revision: str) -> list[tuple[str, dict[str, Any]]]:
    manifest = json.loads(_git_show(revision, "assets/data/corpus_manifest.json"))
    rows = []
    for file in manifest["files"]:
        part = json.loads(_git_show(revision, file))
        rows.extend((file, item) for item in part["entries"])
    return rows


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--before", required=True, help="Historical commit SHA")
    parser.add_argument("--after", default="HEAD", help="Current commit SHA")
    parser.add_argument("--json-out", type=Path)
    parser.add_argument("--max-changes", type=int, default=18)
    args = parser.parse_args()
    report = reconcile_cards(read_revision(args.before), read_revision(args.after))
    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    summary = {k: v for k, v in report.items() if k not in (
        "changed_headword_examples", "consolidation_details", "reference_loss_details",
        "deleted_ids", "added_ids", "moved_ids"
    )}
    summary["deleted_id_count"] = len(report["deleted_ids"])
    summary["added_id_count"] = len(report["added_ids"])
    summary["changed_headword_examples"] = report["changed_headword_examples"][:args.max_changes]
    summary["consolidation_details"] = report["consolidation_details"][:args.max_changes]
    summary["reference_loss_examples"] = report["reference_loss_details"][:args.max_changes]
    print("DICTIONARY_REVISION_RECONCILIATION_BEGIN")
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    print("DICTIONARY_REVISION_RECONCILIATION_END")


if __name__ == "__main__":
    main()
