# Licensed catalog import contract

No publisher PDF, verified edition, complete licensed hierarchy, or permission
document is currently supplied. The repository's original editorial demo lessons
are preserved as such. They are not an exact full-book catalog. This importer
does not read/extract a PDF, infer missing pages/chapters, generate IDs, or publish
content automatically. A real complete catalog cannot be asserted until its
owner supplies and verifies the manifest and licensing evidence.

## Validate and produce a review artifact

```bash
python3 scripts/catalog_import.py /path/to/owner-manifest.json --output /tmp/catalog-plan.json
python3 scripts/catalog_import.py /path/to/owner-manifest.json --format sql --output /tmp/catalog-import.sql
python3 -m unittest discover -s scripts/tests -v
python3 scripts/test_catalog_sql.py  # disposable Docker PostgreSQL; synthetic fixture only
```

The entire manifest is validated before any output file or network request.
Outputs are exclusively created; existing files are preserved. The default is a
reviewable JSON plan. SQL is a single insert-only PostgreSQL transaction aligned
with the existing courses/levels/books/units/lessons/lesson_blocks tables. Existing
IDs, slugs, or positions cause rollback, rather than overwriting owner content.
Nothing is executed by generating SQL. An authorized server database administrator
must review and execute it under existing permissions/RLS; no grants or bypasses
are generated. All courses/lessons stay drafts.

## Owner manifest schema, version 1

The root is an object containing:

| Field | Requirement |
| --- | --- |
| schema_version | Integer 1 |
| catalog_id | Canonical nonzero UUID supplied by the owner |
| edition | Exact edition identifier, nonempty string |
| license | Object with status `granted`, reference, holder, permission_reference, and permitted_uses containing `digital_learning` |
| provenance | Object with publisher, source_reference, verified_by, and verified_at as YYYY-MM-DD |
| counts | Exact positive counts for courses, levels, books, units, lessons, blocks |
| courses | Complete nonempty course list |

Every node has a globally unique canonical owner UUID. No IDs are synthesized.
Each non-course node has a nonnegative integer position; sibling positions are
unique (blocks use step + position). Every parent reference is explicit and must
match the enclosing parent. Every hierarchy child list is nonempty.

| Node | Required fields in addition to id |
| --- | --- |
| course | title, unique lowercase hyphenated slug, explicit access_tier `free`/`paid`, status `draft`, levels |
| level | course_id, title, position, books |
| book | level_id, title, position, edition matching root, license_reference matching root, positive page_count, source_reference, actual lowercase source_sha256, units |
| unit | book_id, title, position, page_locator, lessons |
| lesson | unit_id, title, position, status `draft`, page_locator, blocks; optional title_ar, goal, legacy_id |
| block | lesson_id, step, kind, position, page_locator, nonempty body object |

Block steps: dialogue, vocabulary, grammar, practice, test, homework. Block kinds:
text, heading, image, audio, video, exercise. Body is owner-authored structured
content, at most 1 MiB; it must leave reserved `page_locator` and `source_metadata`
keys available. The importer adds verified source provenance without changing the
original Arabic/vowels. The full original manifest, including unknown metadata,
is retained in the plan and SQL course source_policy.
Book and lesson `source_locator` columns receive the owner edition, PDF hash,
source reference, and the lesson's actual page range using the backend's
`page_start`/`page_end` names. Unit/block locators remain in the manifest and block
body. No printed page numbers are inferred.

`page_locator` is `{book_id, start, end, printed_label?}`. Start/end are integers
identifying **one-based source PDF page indexes**, never guessed printed page
numbers. `1 <= start <= end <= book.page_count`; lesson pages must be contained in
unit pages, block pages in lesson pages. `printed_label`, when known, is supplied
verbatim by the owner. Page counts/hash/reference must correspond to the declared
edition. Declared counts detect incomplete/truncated manifests; they cannot prove
that an owner's claimed hierarchy exactly matches an absent publisher source.

JSON duplicate keys, nonfinite values, placeholder licensing, missing edition,
missing/duplicate IDs, foreign parents, malformed/out-of-range pages, collisions,
wrong counts and automatic publication are errors. A syntactically valid license
claim is not a substitute for human verification of the permission document.

## Explicit server RPC mode and permissions

No complete-hierarchy import RPC exists in the current backend migrations.
`--apply-rpc` is an adapter for a future **installed, authorized atomic** RPC named
`import_licensed_catalog`, with arguments `p_manifest` and `p_manifest_sha256`.
It requires environment names `CATALOG_SUPABASE_URL` (root HTTPS origin),
`CATALOG_API_KEY`, and `CATALOG_ACCESS_TOKEN`. Supply values through secure
environment settings; never in chat, source, logs, or a mobile app. No secrets or
remote import were provided/executed during this work.

The server must independently authorize its catalog administrator, validate the
license/source/edition/full hierarchy, enforce existing RLS/permissions, and
commit all rows atomically as drafts. It must claim the canonical manifest hash
idempotently, reject changed content under an existing import identity, and
return an exact receipt: catalog_id, manifest_sha256, counts, status `draft`.
The client refuses an absent/mismatched receipt and never treats a timeout as
success. Reconcile unknown outcomes by the stable manifest hash before retrying.
TLS is verified through the normal configured proxy/CA path; credential values
and server error bodies are not printed.

Current executable choices are local validation/planning and reviewed SQL. Do
not claim remote licensed ingestion until the backend RPC, permissions, owner
manifest, publisher source and rights evidence actually exist and are verified.
