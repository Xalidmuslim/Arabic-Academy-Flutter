#!/usr/bin/env bash
# Development certificate is public test material, never a store release identity.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mode="${BAYNA_SIGNING_MODE:-development}"
while (( $# )); do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;
    --mode) mode="$2"; shift 2 ;;
    *) echo 'Usage: prepare_signing.sh [--repo DIR] [--mode development|owner]' >&2; exit 2 ;;
  esac
done
[[ "$mode" == development || "$mode" == owner ]] || { echo 'Invalid signing mode' >&2; exit 2; }
cd "$repo"
command -v keytool >/dev/null || { echo 'Java 17/21 keytool is required' >&2; exit 1; }
git check-ignore -q -- build/signing/debug.keystore || { echo 'Signing output must be Git-ignored' >&2; exit 1; }
umask 077
mkdir -p build/signing
if [[ ! -f build/signing/debug.keystore ]]; then
  keytool -genkeypair -keystore build/signing/debug.keystore -storetype JKS \
    -storepass android -keypass android -alias androiddebugkey -keyalg RSA \
    -keysize 2048 -validity 10000 -dname 'CN=Android Debug,O=Android,C=US' -noprompt >/dev/null 2>&1
fi
keytool -list -keystore build/signing/debug.keystore -storepass android \
  -alias androiddebugkey >/dev/null 2>&1 || { echo 'Existing development keystore is invalid; it was not replaced' >&2; exit 1; }
if [[ "$mode" == owner && ! -f android/key.properties ]]; then
  python3 - "$repo" <<'PY'
import base64
import os
from pathlib import Path
import sys

names = ['ANDROID_KEYSTORE_BASE64', 'ANDROID_KEYSTORE_PASSWORD', 'ANDROID_KEY_ALIAS', 'ANDROID_KEY_PASSWORD']
if any(not os.environ.get(name) for name in names):
    raise SystemExit('Owner signing requires android/key.properties or environment names: ' + ', '.join(names))
try:
    data = base64.b64decode(os.environ[names[0]], validate=True)
except (ValueError, TypeError):
    raise SystemExit('ANDROID_KEYSTORE_BASE64 is not valid base64') from None
if not data or len(data) > 1024 * 1024:
    raise SystemExit('Owner keystore must be nonempty and at most 1 MiB')
root = Path(sys.argv[1]).resolve()
keystore = root / 'build/signing/owner.keystore'
if keystore.exists():
    raise SystemExit('Existing owner keystore was preserved; provide its matching key.properties')
def properties(value):
    # Java Properties.load uses Latin-1 with Unicode escapes. Escape whitespace,
    # separators, backslashes, and non-ASCII without logging secret values.
    return ''.join('\\u%04x' % ord(c) if ord(c) > 126 or ord(c) < 32 else '\\' + c
                   if c in '\\ =:#!' else c for c in value)
values = {'storeFile': str(keystore), 'storePassword': os.environ[names[1]],
          'keyAlias': os.environ[names[2]], 'keyPassword': os.environ[names[3]]}
text = '\n'.join(key + '=' + properties(value) for key, value in values.items()) + '\n'
# All inputs are validated first; exclusive creation preserves owner files.
with keystore.open('xb') as target:
    target.write(data)
try:
    with (root / 'android/key.properties').open('x', encoding='ascii') as target:
        target.write(text)
except BaseException:
    keystore.unlink()
    raise
PY
fi
if [[ "$mode" == owner ]]; then
  [[ -f android/key.properties ]] || { echo 'Owner key.properties is required' >&2; exit 1; }
  git check-ignore -q -- android/key.properties || { echo 'Owner signing properties must be Git-ignored' >&2; exit 1; }
fi
if [[ "$mode" == development ]]; then
  fingerprint="$(keytool -J-Duser.language=en -list -v -keystore build/signing/debug.keystore \
    -storepass android -alias androiddebugkey 2>/dev/null | sed -n 's/^[[:space:]]*SHA256: //p' | tr -d ':[:space:]' | tr 'A-F' 'a-f')"
elif [[ -f build/signing/owner.keystore && -n "${ANDROID_KEYSTORE_PASSWORD:-}" && -n "${ANDROID_KEY_ALIAS:-}" ]]; then
  fingerprint="$(keytool -J-Duser.language=en -list -v -keystore build/signing/owner.keystore \
    -storepass:env ANDROID_KEYSTORE_PASSWORD -alias "$ANDROID_KEY_ALIAS" 2>/dev/null | sed -n 's/^[[:space:]]*SHA256: //p' | tr -d ':[:space:]' | tr 'A-F' 'a-f')"
else
  fingerprint="${ANDROID_SIGNER_SHA256:-}"
fi
if [[ -n "$fingerprint" ]]; then
  [[ "$fingerprint" =~ ^[0-9a-f]{64}$ ]] || { echo 'Could not verify the selected signing certificate fingerprint' >&2; exit 1; }
  printf '%s\n' "$fingerprint" > build/signing/certificate.sha256
else
  rm -f build/signing/certificate.sha256
fi
printf '%s\n' "$mode" > build/signing/mode.txt
printf 'Signing mode: %s. Development key: build/signing/debug.keystore.\n' "$mode"
