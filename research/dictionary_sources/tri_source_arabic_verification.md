# Arabic lexicographic cross-checks: Bayna / Arabily / Cairo Academy

Date: 2026-11-12. This file records a **first working pilot**, not blanket
validation of the dictionary.

## Source roles and known failure modes

| Source | Verified accessible example | What the editor may rely on |
|---|---|---|
| المعجم العربي بين يديك (OCR displayed by الجامع) | https://aljam3.com/ar/39951/73248/16 and https://aljam3.com/ar/39951/73248/29 | Identify the original dictionary's intended senses and their contexts **after manual checking**, not exact spelling/vowel marks |
| Bayna Yadayk lesson vocabulary (Arabily) | https://arabily.app/bayna-yadayk-1/unit-13/ | Lesson headwords, noun plurals, and verb past/present/masdar with harakat |
| مجمع اللغة العربية بالقاهرة / المعجم الوسيط | https://www.arabicacademy.gov.eg/ar/search_engine/roots/%D8%B3%D8%A8%D8%B9 and https://www.arabicacademy.gov.eg/ar/search_engine/roots/%D9%82%D9%88%D9%85 | Independent dictionary headwords, plurals, context and semantic distinctions |

**Warning:** the جامِع text is a transcription of an illustrated/scanned
dictionary, and demonstrably contains OCR artefacts. In page 29, for example,
the textual output adjacent to `أَقْحَمَ` is malformed. It must not supply
unreviewed **تشكيل** to our application. A selectable page is not proof of
machine text accuracy.

The Cairo Academy's root **سبع** confirms that `أُسْبُوعٌ` is a single
seven-day week and that `أَسَابِيعُ` is its plural; it also records a
contextual meaning involving seven circuits of **الطواف**. Arabily's Book 1,
lesson 13 independently confirms the singular/plural pair.

The Cairo Academy's root **قوم** identifies multiple meanings of `أَقَامَ`,
including residence and sustained actions, while Arabily Book 1 lesson 13
supplies `أَقَامَ — يُقِيمُ — إِقَامَةٌ`. The Bayna text page 29 offers
additional usage contexts (organizing an event, presenting evidence). These
are paraphrased in our own Arabic example sentences, not reproduced.

## What was actually changed

Source registry: `assets/data/lexical_source_crosschecks_v1.json`.

- `أُسْبُوعٌ`: corrected misleading note that called it a plural; added the
  proper plural and distinguished two contextual meanings.
- `أَقَامَ`: split contexts into separate meanings, preserving the exact
  past/present/masdar forms.
- `إِقَامَةٌ`: clarified that it is the verbal noun, with separate usage
  examples and no Russian translation.
- These three article overlays are synced to the source-added corpus, but
  previously-existing original dictionary IDs and content remain intact.
- For each entry, **all three checked URLs** are recorded; OCR-only claims
  cannot satisfy the vowel validation in `tools/source_crosschecks.py`.

Every new Arabic explanation and example is independently written. No
entire copyrighted dictionary page is copied to the project.

## Acceptance rules for larger batches

1. Compare exact vowel-marked headwords, hamza, shadda and forms with a
   non-OCR source (Arabily or Cairo Academy).
2. Use scanned Bayna text only for sense grouping; where the OCR is
   inconsistent, inspect the scanned image before adding a new meaning.
3. Never infer a synonym/antonym from the existence of a related word.
4. Keep different word senses separate and do not force a fabricated antonym
   on a word without a lexical opposite.
5. Attach source URLs and evidence scope to **each** checked headword.
6. Leave unconfirmed forms pending; never auto-approve a whole batch because
   a structural test passed.
7. Preserve original corpus ID and bookmarks, and avoid Russian translations.
8. Run `python3 -m unittest discover -s tools -p 'test_source_crosschecks.py' -v`,
   `python3 tools/source_crosschecks.py`, the full corpus audit, Flutter
   tests and static analysis before calling a batch technically verified.

### Coverage caveat

At this stage **3 of 574 expanded articles** have explicit three-source
cross-check records for selected forms/meanings. The other **571** expanded
articles, and unexpanded entries in the larger corpus, do not yet have these
cross-check records. Even these 3 have **not** passed an independent complete
native-speaker proofread; correctness of every invented example is therefore
not certified. The three-source registry is a manual QA evidence trail, **not
an automatic scraper or a mass-certification stamp**.
