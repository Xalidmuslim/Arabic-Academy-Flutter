# Asset integrity and origin

New UI artwork is ten independently generated scenes: `hero`, `lessons`,
`grammar`, `vocabulary`, `progress`, `oral`, `live`, `teacher`, `exercises`, and
`emblem`. Files are under `assets/artwork/`; hero is 1200×800, the others 768×768.
Arabic teaching text remains selectable Flutter text with its original vowels.
No reference-screen crops, restored atlases, religious imagery, or textbook
imagery inferred from a demonstration are accepted as new product artwork.

`assets/artwork/manifest.json` is a list with exactly these fields per scene:
`id`, `file`, `source_filename`, `origin`, `sha256`, `width`, `height`.
IDs, file paths, and SHA-256 values must be unique; a file path must be
`assets/artwork/<id>.webp`. Each record identifies its standalone generated source
and declares no reference crops. The validator checks actual bytes and WebP
dimensions using Python's standard library. Hashes establish byte identity;
they do not independently prove copyright rights or detect every prohibited
visual subject. Origin and visual suitability also require editorial review.

Local fonts are `Manrope` and `NotoNaskhArabic`, each with its approved SHA-256,
upstream project reference, copyright statement, and SIL Open Font License 1.1
text under `assets/fonts/`. The font license metadata is declared in
`scripts/verify_assets.py`, alongside the pinned binary hashes. Font or license
changes require reviewing that metadata rather than replacing an expected hash
to silence a failure. Distribution must retain the corresponding license notice.

`python3 scripts/verify_assets.py` validates every local Flutter asset/font path,
UTF-8 JSON and duplicate JSON keys, collection IDs, lesson-ID collisions across
catalogs, choice indexes/configuration, Arabic/Russian records, grammar table
shapes, the exact scene inventory, source hashes and font license metadata. Its
pubspec parser supports explicit block-list local asset and font declarations;
unsupported YAML structures fail rather than silently hiding a missing asset.

Legacy `assets/images/**` and `assets/_embedded/**` stay in repository history and
the current tracked tree for preservation. They must not be declared in pubspec
or packaged in APK/AAB. The old restoration/reference/modern-import/icon scripts
and their automatic import workflows are removed; their source history remains
in Git. Native launcher icons and splash configuration are prepared separately
by the platform/asset owner; CI never regenerates them.

Android package validation independently compares packaged artwork, manifest,
font binaries, and content JSON with the verified source. A successful source
check alone does not prove an already-built APK contains those exact files.
No runtime image/font download or signed temporary source URL is required.
