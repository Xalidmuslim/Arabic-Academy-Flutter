# المعجم العربي بين يديك — source collation, printed pages 8–11

**Date:** 2026-11-14  
**Working branch:** `codex/bayna-lexicon-reviewed-details-20261112`  
**Source:** User-uploaded `12383.pdf`; 404 scanned PDF pages; no usable machine-readable text  
**Source SHA-256:** `a2d98cbf6cd309bac2ac072e09679260b1fa20dec0af4cfa7ddf82d7fae2f995`

## Four sequential original pages inspected

| Original PDF page | Printed dictionary page | Existing review overlays assigned | Visibly located lemma | Source mismatch |
|---:|---:|---:|---:|---:|
| 12 | 8 | 25 | 25 | 0 |
| 13 | 9 | 23 | 23 | 0 |
| 14 | 10 | 27 | 26 | 1 |
| 15 | 11 | 26 | 26 | 0 |
| **Total** | **8–11** | **101** | **100** | **1** |

Each individual entry has explicit `visual_verification` in both
`assets/data/entries_bayna_scan_verified_20261112.json`
and `assets/data/reviewed_articles_v1.json`.
This includes scan digest, original PDF page, printed page and an honest editorial status.

These 101 records are **a subset of the original book**, not a claim that all publisher headwords in pages 8–11 have been entered or expanded.

## One confirmed source mismatch — do not silently rename

- Existing app entry: `أَرْذَالٌ`, source ID `bayna_scan_v1_204`, assigned to PDF page 14 / printed page 10.
- On **the actual scan image**, the headword in this position is **`أَرْذَل`**, not `أَرْذَال`.
- These are distinct Arabic forms. The Cairo Arabic Language Academy confirms that `الأَرْذَل` denotes the inferior or the meanest, while `أَرْذَالٌ` is an attested plural of `الرَّذْلُ`.
- The `أَرْذَالٌ` record is a valid word but **not visually attested at the claimed source page**. It remains in the app unchanged with its previous ID, and the source mapping is explicitly flagged `source_headword_mismatch_requires_relocation`. Its correct printed source location must be established before marking the card verified.
- Primary independent references:
  - Cairo Academy `https://www.arabicacademy.gov.eg/ar/محرك-البحث/الأَرْذَلُ?exact_search=true`
  - Cairo Academy `https://www.arabicacademy.gov.eg/ar/محرك-البحث/الرَّذْلُ?exact_search=true`

## Specific vowel-sensitive reading checks

- Printed page 9: `إِذَنْ/إِذَا` is a paired lexicographic heading; the app's separate `إِذَنْ` lemma remains distinguishable from the original paired entry. This is NOT a claimed absent lemma.
- Printed page 9: `أَذَان` (call to prayer) vs `أُذُن` (ear) must remain independent.
- Printed page 10: `أَرْسُغ`, an attested broken plural of `رُسْغ`, must **not** be auto-corrected to `أَرْسَاغ` solely because the latter is more common. Both plurals are documented by Cairo Academy: `https://www.arabicacademy.gov.eg/ar/محرك-البحث/الرُّسْغُ?exact_search=true`.
- Printed page 11: distinct lexemes `أَرْزَاق`, `أَرْقَام`, `أَرَق`, `أَرِقَ` must retain vowel distinctions; only the existing entries actually on the corresponding printed page were marked visually collated.

## Audit limits

Visible publisher headword letters and printed vowel marks on these four rendered pages were the basis of the collation. The app's noun endings and independent educational examples are *not* necessarily printed identically in the book; they still require a separate pass for syntax, agreement, grammatical case and full diacritics. No OCR output was used to certify a headword, and no whole-dictionary linguistic review is claimed.

Previously inspected from the beginning: printed pages 1–7, 133 existing entries.  
In this pass: printed pages 8–11, **100 matched + 1 disputed**.  
Cumulative: **234 existing reviewed entries processed in sequential page order, 233 exact printed source matches and one source-location mismatch**, subject to distinct full sentence proofreading.

Next original PDF target: page **16** (printed dictionary page **12**).

## Technical regression and CI guard

- `tools/test_bayna_original_pages_8_11.py` requires a precise, non-deceptive status for all 101 entries, with a negative source assertion for `أَرْذَالٌ`.
- `tools/audit_reviewed_lexicon.py` explicitly recognizes the single known publisher-location mismatch instead of silently presenting all mapped entries as faithful source quotations.
- `.github/workflows/dictionary-reviewed-lexicon-qa.yml` now uses Bash `set -o pipefail` with `tee`, so a failing dictionary coverage audit fails the CI job. A prior "success" had incorrectly masked a Python assertion failure in the auditing step.
- Do not merge into `main` or build an APK while the remaining manuscript and educational examples are still undergoing collation.
