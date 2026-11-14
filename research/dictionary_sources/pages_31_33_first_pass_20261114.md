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

## Independent quality review — 14 November 2026

### Actual scope of verification

- All **594** reviewed articles were checked programmatically for required Arabic-only fields, at least one Arabic diacritic in every fact, obvious Cyrillic/Latin contamination, duplicate headwords, and NFC integrity. These checks **do not** establish linguistic accuracy.
- Of the 20 new articles, **two headwords** had a noncanonical Unicode combining-mark order for shadda and fatha: `أَكَّدَ` and `أُمَّةٌ`. Their storage was normalized to NFC without changing the spoken vowel or meaning.
- The term `أَكَّدَ` is now accurately described as a triliteral root with augmentation by middle-radical gemination, instead of potentially misleading `مُضَعَّفُ الْعَيْنِ`.
- The augmented triliteral forms and original three-consonant roots for `أَمَاتَ`, `أَلْغَى`, `أَلْقَى`, `أَمَاطَ`, and `أَلْهَمَ` were clarified.
- The weak unrelated `إِمَارَةٌ / إِشَارَةٌ` contrast was replaced with the source-attested, learner-critical vowel opposition `إِمَارَةٌ` (government/emirate) vs `أَمَارَةٌ` (sign/indication).
- Controlled Arabic educational examples were retained; no original book pages or extended publisher text were copied.

### Independently checked lexicographic references

1. `أُكْذُوبَةٌ`, plural `أَكَاذِيبُ` — Cairo Academy, `https://www.arabicacademy.gov.eg/ar/search_engine/roots/كذب`.
2. `أُلْفَةٌ` with damma on hamza — Cairo Academy, `https://www.arabicacademy.gov.eg/ar/search_engine/roots/ألف`.
3. `أَلْفٌ` with plurals `آلَافٌ`, `أُلُوفٌ` — the same Cairo Academy root page.
4. `إِمَارَةٌ` and `أَمَارَةٌ` semantic and hamza-vowel contrast — Cairo Academy, `https://www.arabicacademy.gov.eg/ar/search_engine/roots/أمر`.
5. `أَلْقَى`, root `لقي` — `https://www.arabicacademy.gov.eg/ar/search_engine/roots/لقي`.
6. `أَمَاطَ`, root `ميط` and verbal noun `إِمَاطَةٌ` — `https://www.mofradat.com/root/3926/ميط` as secondary lexical corroboration, not as an original-page proof.

**Do not overstate this evidence:** the Academy references support selected lexical forms and senses, not every fully diacritized example sentence in the user-facing cards.

### Original page-image limitation

- A 404-page edition was located at `https://archive.org/details/5136pdf` and the text-only pages at `https://aljam3.com/ar/39951/73248/31`, `/32`, and `/33`.
- **The actual source page images 31–33 were not opened or examined in this session.** Attempts to access the scan viewer failed/timed out. The original, checksum-known `12383.pdf` is not available among mounted conversation/Library files.
- There is **no line-by-line diacritic collation against the original** and **no permission to promote these 20 records to professionally proofread**.
- Priority next action is to obtain the same original scan `12383.pdf` (sha256 `a2d98cbf6cd309bac2ac072e09679260b1fa20dec0af4cfa7ddf82d7fae2f995`), render PDF pages **31, 32, 33** at high resolution, and compare every lexeme letter/shadda/hamza/vowel to the original. Then proofread every independently written sentence against Arabic syntax and morphology.
- If original-page letters differ from online OCR, original print takes precedence, while known original typos are not blindly perpetuated: resolve by documented independent Arabic scholarship.

### Regression assurance

- The existing CI for reviewed lexicon tests structural data, Python lexical QA, Flutter tests, and static analysis.
- A failing-test-first pass caught two NFC problems and one missing vowel-sensitive homograph distinction; the minimal data patch then resolved these.
- New entries retain `source_text_status=online_ocr_page_located_arabic_editorial_first_pass_pending_print_image_proofread` and do not set the stronger `source_review` flag.
