# Arabic–Arabic lexicon checkpoint: 5,106 headwords

**Date:** 2026-10-27  
**Repository:** Xalidmuslim/Arabic-Academy-Flutter  
**Working branch:** `codex/bayna-dictionary-demo-apk-20261024`  
**Use:** Independent Arabic–Arabic dictionary app. **Do not merge with the separate Bayna Yadayk textbook/course app.**

## Verified statistics

- Previous validated checkpoint: **4,451 unique exact-vocalized headwords**.
- New original explanatory cards authored: **760**.
- Newly distinct exact-vocalized headwords: **655**; **105** added cards reuse existing headings and enrich their attached material.
- Validated combined corpus: **5,106** unique headwords across **66 manifest files**.
- Entries with pre-existing book references: **1,795**, unchanged. These are existing metadata, not a guarantee that references were checked against source textbooks.

| Independent domain file | Articles |
| --- | ---: |
| `assets/data/entries_editorial_architecture_20261026.json` | 166 |
| `assets/data/entries_editorial_culinary_20261026.json` | 182 |
| `assets/data/entries_editorial_agriculture_20261026.json` | 187 |
| `assets/data/entries_editorial_astronomy_20261026.json` | 225 |
| **New cards** | **760** |

Each card is in Arabic and contains: a vocalized Arabic headword, Arabic definition, grammar/declension note, collocation, example and original usage note. Some entries are multi-word terminology, not single dictionary lemmas. Book reference lists and citations for **all four new independent files are empty**; no textbook source alignment is claimed.

## Quality assurance and validation

- Content schema: `schema_version: 3` and `source_status: original_independent_arabic_lexicon_not_textbook_collated`.
- Editorial validation includes basic required fields, minimum definition/note lengths, no Latin or Cyrillic letters in Arabic prose, no within-batch exact duplicates, and corpus registration.
- New acceptance test: `tools/test_editorial_four_domains_20261026.py`, verifying **all 760 cards** and four exact batch sizes.
- Proofread selected headings before validation (e.g., `كُسُوفٌ حَلَقِيٌّ`, `مَرْكَبَةٌ جَوَّالَةٌ`, `جَرَانِيتٌ`, `مَخْبُوزَاتٌ`) and corrected a definition of astronomical midnight.
- Validation workflow: https://github.com/Xalidmuslim/Arabic-Academy-Flutter/actions/runs/40412426463
- **PASS: 28/28 Python tests**, plus corpus validator output **5,106** entries.

## Editorial caveats

The 5,106 figure counts **distinct exactly vocalized headword strings**; it is not a verified number of textbook vocabulary items or morphological lexemes after removal of vowel-mark variations. Automatic tests do **not** prove that each plural, collocation, diacritic, example, technical translation or semantic distinction is perfect. Human lexicographic review, near-duplicate merging and source collation remain to be done. The new material is independently composed, and **must not be represented as a verbatim extract from the Bayna Yadayk books**.

## Build policy

The task remains dictionary-content completion and QA. **No APK/Android/Flutter build performed.** Do not generate the APK before the corpus content stage is declared complete.
