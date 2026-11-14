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

### Critical attachment-coverage finding — CI audit

The exact complete **successful** CI audit for commit `2434b8c67f459771c58be0c019194432ebe00b47` reports:

- **7,584** unique fully vocalized corpus headwords (this number supersedes earlier approximate reporting of 7,591).
- **594** reviewed article overlays.
- **581** unambiguously attached article overlays.
- **13** article overlays NOT ATTACHED; all are from the 20 newly drafted records.
- **7** of the 20 new editorial overlays therefore match existing corpus words.
- **7,003** corpus words lack an attached reviewed article.

The 13 unlinked first-pass entries:
`أَكْثَرَ`, `أَكْرَمَ`, `أَلْغَى`, `أَلْفٌ`, `أَمَامَ`, `أَمَاطَ`, `إِمَامٌ`, `أُكْذُوبَةٌ`, `أُلْفَةٌ`, `أَلِيمٌ`, `أَلْهَمَ`, `إِمَارَةٌ`, `أَمَاتَ`.

**Do not imply these 13 are already displayed in the app.** Their reviewed article records exist but are not matched by canonical fully vowelled headword in the current corpus. Before publication or linking: verify source scan letters and vowel patterns, disambiguate same-bare-letters senses, then attach/add an appropriate canonical record preserving original IDs and bookmarks. Do **not** force a bare-letter match, strip vowels, or silently graft an article onto a different inflection.

The test pipeline passed but did not treat this content-coverage gap as a failure; it is therefore an explicit outstanding release blocker for considering the 20-record expansion complete.

## Original supplied PDF received and visually inspected — definitive update

**This November 14 update supersedes earlier statements above that the original image was unavailable.**

- Uploaded user source: `12383.pdf`; checked locally using the actual file bytes.
- PDF metadata: **404 pages** (do not use a truncated preview's page count).
- Computed SHA-256: **`a2d98cbf6cd309bac2ac072e09679260b1fa20dec0af4cfa7ddf82d7fae2f995`**, exactly matching the project's original reference.
- Original PDF pages **31, 32, 33** were rendered at **240 DPI** and visually inspected (printed dictionary pages **27, 28, 29**).
- All **20** November batch headword spellings and principal contextual senses were located in the original printed pages. In a few cases the educational fully vocalized lemma includes grammatical case/tanwin not explicitly printed in the source heading; this is an added i'rab choice, not a verbatim transcription.
- Each reviewed overlay now contains `visual_verification` with PDF page, printed page, scan digest and `printed_lemma_and_senses_visually_checked_examples_independently_authored`; the prior `source_text_status` was replaced with `original_printed_headword_and_senses_visually_checked_original_examples_second_pass_pending`.
- The ***independently authored pedagogical explanations, examples, and every case ending*** are *not quotations from the source*. These are a separate grammatical editorial layer and are not certified as publisher-verified or full professional native-speaker proofread.

### Semantic corrections from the printed source

- `أَكَلَ` on printed p. 27 expressly has a third meaning `أَكَلَ لَحْمَهُ` in the sense of backbiting. That sense, an original new pedagogical example, and a contextual note were added to the reviewed article.
- `أَكْرَمَ`: the second definition was reworded in natural literary Arabic to match hospitality in the source.
- `أَمَاطَ`: the definition was broadened from removing only a path obstacle to removing or moving something aside, which covers the source's `أَمَاطَ` contexts.

### Critical fix: 13 reviewed articles not reachable from the app

A new schema-3 source chunk `assets/data/entries_bayna_scan_verified_20261114_pages31_33.json` adds the **13** formerly unattached source-verified headwords, with page and PDF SHA provenance and independently written Arabic examples. The new chunk is appended to `assets/data/corpus_manifest.json`. No existing old IDs, study references, old source chunks, or bookmarks are overwritten; the existing Flutter corpus merge retains first-occurrence canonical entries.

The new scan-linked entries are:
`أَكْثَرَ`, `أَكْرَمَ`, `أَلْغَى`, `أَلْفٌ`, `أَمَامَ`, `أَمَاطَ`, `إِمَامٌ`, `أُكْذُوبَةٌ`, `أُلْفَةٌ`, `أَلِيمٌ`, `أَلْهَمَ`, `إِمَارَةٌ`, `أَمَاتَ`.

The batch-specific regression test `tools/test_bayna_first_pass_pages_31_33.py` now verifies that **all 20** source-checked reviewed articles resolve unambiguously to corpus words; that the source digest and pagination are identical to the original; and that `أَكَلَ` includes the missing attested `اغْتَابَ` sense.

The Flutter corpus-integration test was updated to account for the 13 new standalone original dictionary lemmas and to compute merged count from the actual pre-scan corpus, rather than an outdated fixed baseline.

### What remains

Only the **20 headword and source-sense comparisons** were completed from these three pages in the present pass; this does *not* upgrade all 594 reviewed overlays nor all 7,597 unique dictionary words to linguistically proofread. Do not conflate the exact scan comparison with the separately authored instructional examples. Further Arabic grammatical and typographic line-editing and future pages still need their own evidence.

### Completed corpus integration audit

Github Actions `Bayna reviewed lexicon QA`, run `43578765747`, completed successfully after the restored 13-headword source chunk and regression corrections:
- **158 Python tests passed**
- **80 Flutter tests passed**, 2 skipped
- `flutter analyze`: no issues
- Corpus: **7,597** distinct fully vocalized headwords
- Reviewed overlays: **594**, all **594 attached unambiguously**
- 7,003 corpus words not yet covered by a reviewed enrichment
- Source audit and existing stable-ID preservation checks passed.

An additional source review of PDF page 33 (printed 29) identified a third distinct `أَمَانَةٌ` sense, `الْمَسْؤُولِيَّةُ`, alongside trustworthiness and deposit. The reviewed article now includes this meaning, a separate fully vowelled original educational example, and a contextual note, guarded by `test_amanah_third_source_sense_is_retained`.

Publication status remains **source headwords and printed senses checked; independent example/case-ending proofreading is still an editorial responsibility**, not a blanket attestation of all Arabic text across the 7,597-word dictionary.
