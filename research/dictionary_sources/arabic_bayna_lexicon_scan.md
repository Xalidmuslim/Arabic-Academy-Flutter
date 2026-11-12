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
