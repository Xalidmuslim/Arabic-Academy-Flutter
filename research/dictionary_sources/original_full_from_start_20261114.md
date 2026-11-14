# Arabic dictionary: verification from the original first lexical page

**Date:** 14 November 2026  
**Branch:** `codex/bayna-lexicon-reviewed-details-20261112`  
**Source:** User-supplied `12383.pdf`, *المعجم العربي بين يديك*  
**Source extent:** 404 PDF pages  
**SHA-256:** `a2d98cbf6cd309bac2ac072e09679260b1fa20dec0af4cfa7ddf82d7fae2f995`  

## Scope: start at first Arabic dictionary entry, not most recent entries

The first lexical page is **PDF page 5, printed page 1**. This audit starts there, proceeding in printed-page order.

| PDF page | Printed page | Already-existing scan-source entries checked |
|---:|---:|---:|
| 5 | 1 | 4 |
| 6 | 2 | 16 |
| 7 | 3 | 26 |
| 8 | 4 | 20 |
| 9 | 5 | 18 |
| 10 | 6 | 29 |
| 11 | 7 | 20 |
| **Total** | **1–7** | **133** |

All **133** records are from the existing `assets/data/entries_bayna_scan_verified_20261112.json` subset. Headword letters and the **vowel marks visibly present in the printed lemma** were compared with the image rather than OCR, with reference to exact PDF/printed page. Both this source chunk and `assets/data/reviewed_articles_v1.json` carry per-lemma `visual_verification` evidence including the source SHA and page numbers. **Case endings/tanwin supplied pedagogically by the app may not appear in the source's uninflected lemma label** and have not been falsely described as verbatim print.

### Corrective edits

The first nine augmented Form-IV verbs previously had imprecise descriptions such as `فِعْلٌ مَاضٍ رُبَاعِيٌّ`. The data now explicitly identifies their **triliteral underlying roots** and the augmentation by hamza, keeping the original lemma, present-tense vocalization, verbal noun, IDs and user-facing content:

| Verb | Verified triliteral root |
|---|---|
| أَبَاحَ | ب ـ و ـ ح |
| أَبْدَعَ | ب ـ د ـ ع |
| أَبْدَى | ب ـ د ـ و |
| أَبْحَرَ | ب ـ ح ـ ر |
| أَبْصَرَ | ب ـ ص ـ ر |
| أَبْطَأَ | ب ـ ط ـ أ |
| أَبْغَضَ | ب ـ غ ـ ض |
| أَبْقَى | ب ـ ق ـ ي |
| أَتْقَنَ | ت ـ ق ـ ن |

Key disambiguation preserved and tested across printed pages 4–7: `آخِرٌ` (last) vs `آخَرُ` (another); `أَحَلَّ` vs `أَخَلَّ`; `أَحَسَّ`; `أَحَدٌ` vs `أَحَدَ عَشَرَ`; and separate `أَجَرَ` / `أَجْرَى`.

### Exactly what is *not* yet certified

- The **133** count is not a claim that only 133 printed headwords exist on pages 1–7, nor that every headword on those pages is already imported. It represents the **133 pre-existing expanded records in this specific source chunk**. For example, printed page 1 has entries including `إِبَاحَةٌ`, `آبَاءٌ`, `أَبَدًا`, `أَبْرَزَ` beyond the four records enriched from that page. Their other-corpus coverage must be separately reconciled.
- The newly authored *definitions, example sentences, case endings, synonyms, antonyms, explanations* are **not word-for-word book quotations** and require a distinct full Arabic philological proofreading. Their metadata remains `examples_status=independently_authored_pending_separate_i3rab_review`, not `original_examples_verified`.
- The initial 571-record source subset has **438 remaining records**, starting **PDF page 12 / printed page 8** with `إِخْلَاصٌ` (`bayna_scan_v1_134`). Record batches cover PDF pages 5–23 and 26–30; PDF pages 24–25 have no records in this particular subset. This is a coverage gap to investigate before claiming full-source coverage.
- The previously separately verified 20 late-page records from printed pages 27–29 do not substitute for this sequential start-to-finish review.
- The whole 7,597-word app corpus has **not** received a 7,597-item original-image vowel collation. Do not call the complete dictionary fully linguistically verified.

### Technical checks

Regression scripts:
- `tools/test_bayna_original_prefix_pages_1_3.py`
- `tools/test_bayna_original_prefix_pages_4_7.py`

Both validate explicit per-word provenance with the exact PDF SHA, page numbers and editorial status; the first checks 11 conjugation/verbal-noun pairs; both safeguard vowel-sensitive word identities. They do **not** automatically determine visual truth from scanned pixels.

GitHub Actions `Bayna reviewed lexicon QA` [run 43580589253](https://github.com/Xalidmuslim/Arabic-Academy-Flutter/actions/runs/43580589253) completed successfully:
- **166** Python tests
- **80** Flutter tests passed, **2** skipped
- `flutter analyze`: no issues
- **7,597** unique corpus headwords; **594 of 594** reviewed overlays attached

No APK was compiled or published and the default `main` branch was not changed.

## Next chronological source target

**PDF page 12 / printed page 8; first source-record lemma: `إِخْلَاصٌ`.** Continue comparing original scanned marks and grammatical forms, then independently proofread the Arabic educational text, keeping separate evidence categories.
