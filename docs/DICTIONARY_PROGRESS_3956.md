# Arabic-Arabic dictionary checkpoint — 3,956 unique entries

Date: 2026-10-26. Branch: `codex/bayna-dictionary-demo-apk-20261024`.

## Verified corpus growth

- Previous checkpoint: **3,255 unique headwords**.
- Seven independent editorial noun batches registered in `assets/data/corpus_manifest.json`:
  - `assets/data/entries_nouns_health_20261025.json`: **147** cards.
  - `assets/data/entries_nouns_education_20261025.json`: **171** cards.
  - `assets/data/entries_nouns_environment_20261025.json`: **159** cards.
  - `assets/data/entries_nouns_transport_20261025.json`: **140** cards.
  - `assets/data/entries_nouns_commerce_20261025.json`: **157** cards.
  - `assets/data/entries_nouns_technology_20261025.json`: **163** cards.
  - `assets/data/entries_nouns_community_20261025.json`: **220** cards.
- **1,157 distinct fully vowelled headwords inside the new batches**, among which **701 increase the merged corpus**. Other batch headwords already existed in the historical corpus; their additional lexical arrays are merged rather than counted twice.
- Final manifest size: **59 files**.
- Final combined corpus: **3,956 unique headwords**, **1,795 with chapter references** (unchanged).
- Six duplicate entries *within the newly authored seven batches* were consolidated before manifest registration. Independent environment/commerce senses of `جَفَافٌ`, `مَعْدِنٌ`, `جَذْرٌ`, `عَامِلٌ`, `وَسِيطٌ` were preserved in `additional_meanings_ar`; redundant `قِيَاسٌ` definition was removed from later chunk.
- Strengthened `tools/test_independent_nouns_20261025.py`: at least 1,100 cards, each category at least 130, no intra-batch duplicate lemmas or IDs, fields present, Arabic script and diacritics, no invented lesson references, cross-domain senses retained and registered in corpus.

## Validation

GitHub Actions run **40344673714**: **25 tests passed**, dictionary validator `"entries": 3956`, `"referenced_entries": 1795`.

https://github.com/Xalidmuslim/Arabic-Academy-Flutter/actions/runs/40344673714

No Flutter / Android / APK build performed.

## Editorial provenance and caveats

All seven noun batches have `source_status: independent_editorial_nouns_not_book_collated`; `book_references` and `sources` deliberately remain empty. Their Arabic explanations, example sentences, collocations, and usage notes are independently written; they are **not a verified transcription of the Al-Arabiyyah Bayna Yadayk course glossary**. Do not infer a specific lesson, book, unit, or book order from them.

These automated checks establish JSON/schema and data-merging consistency, not linguistic or diacritic correctness. The dictionary requires human lexicographic proofreading, verification of plurals and cross-domain senses, and manual collation with lawfully available book indexes before claiming full textbook coverage.

## Next steps

1. Collate with original indexes of the textbook, recording reliable book and unit references only after evidence is checked.
2. Audit inflection, vowel marks, proper plurals, usage examples, and specialty terms in newly authored material.
3. Continue Arabic-Arabic dictionary data collection in separate chunks and make regular backups. Do **not** build APK until the vocabulary stage is complete.
