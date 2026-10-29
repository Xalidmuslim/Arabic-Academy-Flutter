# Arabic–Arabic dictionary: verified QA checkpoint (2026-10-29)

Repository: `Xalidmuslim/Arabic-Academy-Flutter`
Branch: `codex/bayna-dictionary-demo-apk-20261024`

## Evidence of successful source correction

- Earlier GitHub Actions run [40876932247](https://github.com/Xalidmuslim/Arabic-Academy-Flutter/actions/runs/40876932247) failed: 68 specific missing-internal-vowel occurrences in Arabic prose.
- Reviewed deterministic substitutions were tested separately, applied **only** to `meaning_ar`, `usage_note_ar`, `examples_ar`, `collocations` and `additional_meanings_ar`; the script did **not** edit the lemma, article identifier, grammar, or references.
- **68 occurrences across 68 cards and 27 source JSON files** were corrected and persisted to branch in commit `8eb82e52922ed070eb5e38fb1b0b851ffc55c26b`.
- The corrected corpus passed **110/110 Python unit tests**, `tools/validate_dictionary.py`, and all content-audit jobs: [successful run 40923340765](https://github.com/Xalidmuslim/Arabic-Academy-Flutter/actions/runs/40923340765).
- The workflow was then returned to **read-only validation**, without automatic commits or token write permission, and succeeded again: [run 40923558596](https://github.com/Xalidmuslim/Arabic-Academy-Flutter/actions/runs/40923558596).
- Reusable manually invoked repair tool: `tools/fix_dictionary_confirmed_prose_vowels_20261029.py`, dry-run by default; `--apply` is explicit.
- Regression tests: `tools/test_dictionary_common_prose_vowels_20261029.py` and `tools/test_fix_dictionary_prose_vowels_20261029.py`.

## Current corpus counts (from the latest successful validation)

| Metric | Value |
| --- | ---: |
| Raw source cards | **8,840** |
| Unique merged vowelized headword entries | **7,105** |
| Entries with chapter references | **1,772** |
| Manifest-listed source files | **79** |
| Passing tests | **110** |
| Fully unvocalized prose-token occurrences detected | **0** |
| Headwords flagged by the deeper harakat checker | **0** |
| Suspect solar-article / moon-article lam marks | **0 / 0** |
| Self-synonyms / synonym–antonym overlaps | **0 / 0** |
| Exact headword metadata conflicts (noun vs verb) | **0** |
| Orthographically equivalent *variant review groups* | **190** |

**Correction to historical progress claims:** the earlier checkpoint `DICTIONARY_PROGRESS_7209_20261028.md` described **7,209** unique articles at that historical commit. The **current** validator explicitly reports **7,105**; use the current number, not the older snapshot. This report does not claim the change of 104 entries was caused by the 68 prose corrections (which do not edit headwords).

## What is NOT yet confirmed correct

- The read-only prose audit still lists **94 partially marked token occurrences**, involving **82 source cards across 42 files**. They are linguistic *review candidates*, not 94 established errors; e.g. some words contain valid unmarked long-vowel letters or unusual compounds.
- The **190 headword-variant groups** are not automatic duplicates. Distinct Arabic vowels may distinguish a noun from a verb, active from passive, or unrelated words. They require meaning-aware editorial review.
- One repeated definition across distinct lemmas was reported for `سَنَةٌ` and `عَامٌ` in the base data; this is not necessarily an error because the words overlap semantically.
- The checks cover syntax, structure, known orthographic patterns and selected linguistic heuristics. They **cannot certify every definition, example, or accepted technical term**. A professional Arabic-language editorial pass is still needed for complete linguistic sign-off.
- Independently written dictionary material has **not** been checked against chapters of the textbook «العربية بين يديك». Do not assert that its chapter coverage is complete or fabricate textbook references.

No APK build was performed. This work is limited to the **standalone dictionary**; the separate textbook application was not changed.
