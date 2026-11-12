# Source verification: المعجم العربي بين يديك

## Reference scan

- User-provided source: `12383.pdf` (not committed to GitHub).
- PDF SHA-256: `a2d98cbf6cd309bac2ac072e09679260b1fa20dec0af4cfa7ddf82d7fae2f995`
- Pages checked by PDF file metadata: **404**.
- Scanned RGB page images at approximately 300 dpi; no searchable Arabic text layer.
- Main Arabic dictionary begins on **PDF page 5**, marked **printed page 1**.
- PDF pages 3–4 explain the alphabetic index and editorial conventions.
- PDF pages near the end include grammatical, spelling and punctuation reference appendices.
- The source introduction says approximately **7,600** items in the original dictionary; this is **not equivalent** to our app's current 7,125 merged headwords.

The source itself explicitly says explanations may use synonymy (الترادف),
contrast (التضاد), contextual explanation or definition, sometimes with images.
It does **not** imply that every lemma has a literal antonym.

### Initial visually checked source-backed entries

| PDF page | Printed page | Lemma | Visual evidence |
|---:|---:|---|---|
| 5 | 1 | أَبَاحَ | يبيح، إباحة; meaning "أحل، أجاز" for permission, and a separate "أظهر ونشر" sense |
| 5 | 1 | أَبْدَعَ | يبدع، إبداع; near synonyms اخترع، ابتكر, with distinct usage |
| 5 | 1 | أَبْدَى | يبدي، إبداء; examples with رأيه and رغبته |
| 5 | 1 | أَبْحَرَ | يبحر، إبحار; ship travels by sea, traveller goes by sea |

### Next visually checked batch — PDF page 6, printed page 2

16 Arabic headwords: **أَبْصَرَ، أَبْطَأَ، أَبْغَضَ، أَبْقَى، أَبَى، أَتْقَنَ، أَتَى، أَبْيَضُ، إِبْرِيقٌ، إِبِلٌ، أُبُوَّةٌ، أَبْوَابٌ، أَبْنَاءٌ، أَبْيَاتٌ، أَبْطَالٌ، أَبْرِيَاءُ**.

The source page records vocabulary, plurals, verb forms, and some sense-based
semantic comparisons. The application keeps independently authored explanatory
sentences and examples, with separate meanings for **أَبْقَى** and **أَتَى**.
Not every headword has a strict antonym; a related term is not automatically
recorded as an opposite.

**Editorial progress:** 20 page-linked articles (four from page 5,
sixteen from page 6) and 3 earlier independent articles. This is **not**
a complete collation of the 404-page reference.

The new `assets/data/reviewed_articles_v1.json` entries contain **independently
written Arabic explanations and original pedagogical examples** based on these
verified meanings. They are not long verbatim transcriptions. Each such entry
has `source_pdf_page`, `source_printed_page` and `source_review` metadata.

Do not claim the entire corpus has been verified against this PDF.
The manuscript has no text layer; automatic Arabic extraction can distort
vowel marks, shadda, hamza, letter identities and word boundaries. Every
individual transcription requires visual proofreading and context-sensitive
sense separation. For words absent from the app, keep a separately tracked
source candidate rather than fabricating a match.

**Do not commit the 244 MB scan into the GitHub repository.** This reference
was provided for source comparison; publication or redistribution of the
book's full scans is separate from using its information as a research source.

## Expanded pass — 12 November 2026

In one content-editing pass, **161** additional Arabic headwords from the
**seven PDF pages 7–13** (printed dictionary pages 3–9) were read visually
and given independently worded Arabic-only educational entries.

- PDF pages 7–10: 93 entries.
- PDF pages 11–13: 68 entries.
- Source-linked articles in total, including pages 5–6: **181**.
- Total editorial overlay articles, including earlier separate entries: **184**.
- The corpus loader merges by exact fully vocalized headword, keeping
  older stable IDs and existing book/chapter references.
- Arabic definitions, grammatical notes, synonyms where applicable, and
  original illustrative sentences are authored separately; they are not
  full transcriptions or reproduction of the publisher's examples.
- Empty antonym fields are intentional when no lexical opposite exists.
- All records include the scanned PDF page and corresponding printed page.

This is a **first editorial pass**, not a claim that 181 entries have passed
professional native-speaker proofreading. The audit checks structural
completeness and presence of diacritics, not correctness of every single
vowel or semantic nuance. Comparative adjectives and non-antonym semantic
pairs were checked again after the initial write.

The larger scan still needs systematic page-by-page work. Do not label
the unprocessed words or the whole dictionary as verified.

## Editorial acceptance criteria

1. Preserve existing word IDs, bookmarks, local study state and original entries.
2. For every checked lemma, record exact PDF and printed page numbers.
3. Compare visually with the scan and retain all Arabic vowel marks.
4. Label whether a relation is a context-specific synonym, an actual antonym
   or merely a semantically related contrast.
5. Store only Arabic explanations in the dictionary UI; no Russian translations.
6. Don't invent antonyms for verbs or concrete nouns with no direct lexical opposite.
7. Run `python3 tools/audit_reviewed_lexicon.py` and `flutter test`
   before using the new entries in a build.
