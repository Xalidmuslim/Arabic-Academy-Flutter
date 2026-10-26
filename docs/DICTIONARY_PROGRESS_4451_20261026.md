# Arabic–Arabic dictionary — 4,451-headword verified checkpoint

Date: 2026-10-26. Branch: `codex/bayna-dictionary-demo-apk-20261024`.
This is an editorial dictionary in **Arabic-Academy-Flutter**, not the separate primary Bayna Yadayk course app.

## Corpus metrics (validated)

- Previous checkpoint: **3,956 unique headwords**.
- Newly authored: **542 complete Arabic-only cards** in three new chunks.
- Final corpus: **4,451 unique exact-vocalized headwords** (**+495**); **47** new cards reuse a headword already present in the earlier corpus.
- Corpus manifest: **62** JSON files.
- Entries with `book_references`: **1,795** (no change).
- Arts/media: `assets/data/entries_nouns_arts_media_20261026.json` — **160** cards. Photography, painting, cinema, stagecraft, sound, and journalism.
- Sports/recreation: `assets/data/entries_nouns_sports_recreation_20261026.json` — **218** cards. Matches, sports facilities, exercise, swimming, running, outdoor recreation and intellectual games.
- Time/planning: `assets/data/entries_nouns_time_planning_20261026.json` — **164** cards. Time units, calendar, scheduling, work shifts, prioritization, project planning, and bookings.

All three files use schema version 3, `source_status: original_independent_arabic_lexicon_not_textbook_collated`, and no asserted lesson or publisher references.

## Important integration correction

In `tools/validate_dictionary.py`, `load_corpus()` previously merged grammar, examples and additional senses but could silently discard a **different primary definition** when the same vocalized headword occurred in later files. The merge now retains an incoming **substantive primary definition (14+ characters)** as an additional sense without changing the original entry ID or its primary definition. Short synonym-like gloss fragments are excluded to preserve prior merge conventions.

`tools/test_duplicate_headword_meanings_20261026.py` verifies preservation, order, and deduplication of two contextual definitions across three cards, while the older split-corpus regression suite remains passing.

`tools/test_three_domains_20261026.py` checks all three registered data files, their exact minimum sizes (160 / 218 / 164), unique IDs and exact vocalized headwords inside the batch, essential morphological and usage fields, Arabic-only text, no fictitious source or book references, and integration into `load_corpus()`.

Editorial correction after acceptance tests: normalize sprint/endurance names to `سِبَاقُ سُرْعَةٍ` and `سِبَاقُ تَحَمُّلٍ` and correct the cycling-helmet definition to `غِطَاءٌ وَاقٍ صُلْبٌ`.

## Verification

Full GitHub Actions dictionary-content workflow:
https://github.com/Xalidmuslim/Arabic-Academy-Flutter/actions/runs/40388080090

- **PASS: 27 of 27** Python tests.
- Validator output: `"entries": 4451`, `"referenced_entries": 1795`.
- Only dictionary data, validation tests, and offline corpus-merge logic changed.
- **No APK or Flutter/Android build was performed.**

## Provenance / remaining quality work

The new Arabic explanations and examples are *independently authored*, **not** a verified, licensed copy or collation of any official Al-Arabiyyah Bayna Yadayk vocabulary index. The integer 4,451 counts distinct fully vocalized string headwords; it does not imply 4,451 officially matched book words, nor a complete course glossary. The 1,795 chapter-linked items are historically populated metadata, not necessarily proofread against the official books.

Automatic structural checks do **not** establish semantic correctness. Remaining editorial work includes Arabic spellings and diacritics, verified plurals and verbal forms, idiomatic collocations, false duplicates caused by differing vowel marks, appropriate dictionary register, and source-by-source textbook collation.

Preserve the dictionary as its own app. Continue data and editorial QA. **Do not build APK until the content stage is declared complete.**
