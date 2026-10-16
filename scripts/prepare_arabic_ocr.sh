#!/usr/bin/env bash
set -euo pipefail
# License: tessdata_best language models are Apache-2.0; only the model is bundled.
# The user's PDF and recognized publisher text never leave the phone.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$ROOT/android/app/src/main/assets/tessdata/ara.traineddata"
EXPECTED_GIT_BLOB_SHA="4b687c7d54c86cf6219aebe781b47284fd5d41f0"
SOURCE="https://raw.githubusercontent.com/tesseract-ocr/tessdata_best/e12c65a915945e4c28e237a9b52bc4a8f39a0cec/ara.traineddata"
mkdir -p "$(dirname "$TARGET")"
if [[ -s "$TARGET" ]] && [[ "$(git hash-object "$TARGET")" == "$EXPECTED_GIT_BLOB_SHA" ]]; then
  echo "Arabic OCR language model already present and verified."
  exit 0
fi
TEMP="$(mktemp)"
trap 'rm -f "$TEMP"' EXIT
curl --fail --location --silent --show-error --retry 4 --retry-all-errors --connect-timeout 20 --max-time 180 "$SOURCE" --output "$TEMP"
ACTUAL="$(git hash-object "$TEMP")"
if [[ "$ACTUAL" != "$EXPECTED_GIT_BLOB_SHA" ]]; then
  echo "Arabic OCR model checksum mismatch: $ACTUAL" >&2
  exit 1
fi
install -m 0644 "$TEMP" "$TARGET"
echo "Arabic OCR model installed and verified (12.6 MB)."
