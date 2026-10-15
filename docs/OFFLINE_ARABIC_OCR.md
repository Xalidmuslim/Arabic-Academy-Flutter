# Local Arabic OCR for the personal Bayna Yadayk reader

## What the v21 scan mode does

The learner imports their own PDF into private Android app storage. The
**Original Dialogue** screen first tries the PDF text layer; when Arabic
text is absent (or on pre-Android-15 devices), it renders the selected PDF
page with Android PdfRenderer and uses on-device Tesseract 5 + the Arabic
LSTM model to return a transcription. The **force OCR** option uses the scan
even when the PDF already contains an embedded text layer.

No original book pages, OCR transcripts, or book recordings are bundled
with distributed app assets or sent to any network API. PDFs and saved
dialogue transcripts are excluded from Android device/cloud backup rules.

## Important limits

- OCR is not a trustworthy edition of the source: harakat, names, digits,
  word segmentation, reading order and punctuation can be wrong.
- The page can contain several kinds of exercises. The OCR process reads the
  *whole selected page*, not a guaranteed single original dialogue.
- The user must confirm the correct page, remove unrelated OCR lines,
  separate speakers, and validate diacritics before marking a dialogue verified.
- Recognized Arabic is not automatically translated or licensed for resale.
- Text remains on the same device; replacing the imported PDF clears old
  transcriptions only after explicit confirmation.
- Tested Flutter UI behavior does not replace physical-device accuracy testing
  on the actual book scans.

## Reproducible model provisioning

Run **before building an Android APK**:

```sh
bash scripts/prepare_arabic_ocr.sh
flutter build apk --release --split-per-abi
```

The script downloads only the open Arabic OCR **language model**, not book
content, from a pinned GitHub commit and verifies its Git blob SHA.
The model is copied from APK assets into private internal storage on first
use to satisfy the native Tesseract data-path API.

Source:
- https://github.com/tesseract-ocr/tessdata_fast
- pinned commit: `87416418657359cb625c412a48b6e1d6d41c29bd`
- pinned Arabic traineddata blob: `c8d129c67821c1592cac46836686b057ecc203dc`
- model size: 1,432,056 bytes
- license: Apache License 2.0
- Android library: https://github.com/adaptech-cz/Tesseract4Android version 4.9.0
- upstream library and its native dependencies carry their own notices.

Private, individually imported copyrighted books have **not** been included
in the source repository or APK.
