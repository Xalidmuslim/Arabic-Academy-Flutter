# Bayna Yadayk dictionary — Arabic editorial continuation, 14 November 2026

## Scope and actual state

- Branch: `codex/bayna-lexicon-reviewed-details-20261112`.
- New independent Arabic-only editorial overlays: **20**.
- The reviewed overlay has increased from **574** to **594** entries.
- Source locator: `المعجم العربي بين يديك`, online OCR rendition at `https://aljam3.com/ar/39951/73248/`.
- OCR page numbers **31–33**, visually marked printed pages **27–29** in the online rendition.
- The user's original 404-page `12383.pdf` **was not available for direct inspection in this editing session**.
- The online rendition contains demonstrable OCR character and vowel-mark errors. The editor therefore used it to locate candidate entries and meanings, *not as authoritative tashkeel*.
- **No article in this batch is approved as fully proofread**. The `source_text_status` field is deliberately
  `online_ocr_page_located_arabic_editorial_first_pass_pending_print_image_proofread`.
- These articles use the existing `reviewed_articles_v1.json` schema and do **not** set `source_review`, which is reserved for page-image verification.
- UI, Flutter navigation, source-corpus word IDs, bookmarks, and original study state have not been edited in this pass.

## Article inventory

| Source OCR page | Printed page | New Arabic articles |
|---|---|---|
| 31 | 27 | أَكْثَرَ، أَكْرَمَ، أَكْمَلَ، أَكَّدَ، أَكَلَ، أُكْذُوبَةٌ، آلَةٌ |
| 32 | 28 | أَلْغَى، أَلْقَى، أَلْفٌ، أُلْفَةٌ، أَلِيمٌ، أَلْهَمَ |
| 33 | 29 | أَمَانَةٌ، أَمَامَ، أَمَاطَ، إِمَامٌ، إِمَارَةٌ، أُمَّةٌ، أَمَاتَ |

Each record contains Arabic definitions, context-dependent grammar, examples, editorial notes, plus selective synonyms and antonyms when meaningful. Related terms must never be presented as unconditional strict antonyms. Some root/morphological examples have independent external dictionary links; do **not** claim three-source checks for all 20.

## QA

- Regression tests: `tools/test_bayna_first_pass_pages_31_33.py`.
- The test requires exactly 20 distinct headwords, their Arabic-only mandatory fields, diacritic presence, correct OCR-page and printed-page metadata, and an explicit **pending-visual-check** status.
- Repository CI: `Bayna reviewed lexicon QA` (Python unit tests, source crosschecks, full corpus audits, Flutter tests and static analysis).
- **Passing automatic tests establish structural and technical consistency only**. They do not establish correctness of every Arabic vowel mark, syntax, or lexical relation.

## Mandatory follow-up before approving these articles

1. Retrieve the original `12383.pdf` or an independently verifiable printed-page image, compare page by page and confirm source pagination is equivalent to the online rendition.
2. Independently compare each fully vowelled lemma, triliteral root, morphological pattern, tense, verbal noun, plurals, and semantic senses against reliable Arabic lexical material such as `مجمع اللغة العربية بالقاهرة` and, where applicable, Bayna Yadayk lesson glossaries.
3. Proofread **each** Arabic sentence, including hamza, shadda, tanwin, declension, government of prepositions, and natural usage.
4. Investigate OCR ambiguities instead of automatically normalizing or guessing.
5. Record per-lemma verification references and explicit review status; only then promote from preliminary to verified.
6. Re-run complete CI; do not build or claim a ready APK until a distinct build is actually performed and checked.

## Next source page

Continue with online-page 34 / printed-page 30 only after the candidate-word list is grounded in the original page image or all uncertain forms are explicitly marked pending.
