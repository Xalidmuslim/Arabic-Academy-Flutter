#!/usr/bin/env bash
# Actual Flutter tester PNGs, never Android/device screenshots.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo"
if [[ -f /workspace/academy-env.sh ]]; then source /workspace/academy-env.sh; fi
if [[ "${1:-}" == -- ]]; then shift; fi
for arg in "$@"; do
  [[ "$arg" != --no-test-assets* ]] || { echo 'Real bundled assets are required; --no-test-assets is prohibited.' >&2; exit 2; }
done
flutter_version="$(flutter --version --machine | python3 -c 'import json,sys; print(json.load(sys.stdin)["frameworkVersion"])')"
[[ "$flutter_version" == 3.35.7 ]] || { echo 'Visual acceptance requires Flutter 3.35.7' >&2; exit 1; }
export VISUAL_ACCEPTANCE_DIR
VISUAL_ACCEPTANCE_DIR="$(python3 - <<'PY'
from datetime import datetime, timezone
from pathlib import Path
import uuid
folder = Path('docs/screenshots/flutter-tester') / (datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ-') + uuid.uuid4().hex[:6])
folder.mkdir(parents=True, exist_ok=False)
print(folder.resolve())
PY
)"
printf 'Flutter widget tester renders (NOT Android/device screenshots): %s\n' "$VISUAL_ACCEPTANCE_DIR"
python3 - "$VISUAL_ACCEPTANCE_DIR" <<'PY'
import hashlib, json
from pathlib import Path
import sys
root = Path.cwd()
paths = [*root.glob('lib/**/*.dart'), *root.glob('assets/content/*.json'),
         *root.glob('assets/artwork/*'), *root.glob('assets/fonts/*'),
         root / 'test/visual_acceptance_test.dart', root / 'pubspec.yaml', root / 'pubspec.lock']
hashes = {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
          for p in sorted(paths) if p.is_file()}
(Path(sys.argv[1]) / 'source-before.json').write_text(json.dumps(hashes, indent=2) + '\n')
PY
set +e
flutter test --no-pub --concurrency=1 --reporter expanded test/visual_acceptance_test.dart "$@" 2>&1 | tee "$VISUAL_ACCEPTANCE_DIR/flutter-test.log"
statuses=("${PIPESTATUS[@]}")
set -e
python3 - "$VISUAL_ACCEPTANCE_DIR" "${statuses[0]}" "$@" <<'PY'
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import sys

output = Path(sys.argv[1])
exit_code = int(sys.argv[2])
arguments = sys.argv[3:]
run = json.loads((output / 'run.json').read_text()) if (output / 'run.json').exists() else {}
cases = []
for file in sorted(output.glob('*.json')):
    data = json.loads(file.read_text())
    if 'profile' in data: cases.append(data)
images = []
for file in sorted(output.glob('*.png')):
    data = file.read_bytes()
    if data[:8] != b'\x89PNG\r\n\x1a\n' or data[12:16] != b'IHDR':
        raise SystemExit('Engine screenshot is not a valid PNG: ' + file.name)
    width, height = struct.unpack('>II', data[16:24])
    images.append({'file': file.name, 'width': width, 'height': height,
                   'sha256': hashlib.sha256(data).hexdigest()})
root = Path.cwd()
source_paths = [*root.glob('lib/**/*.dart'), *root.glob('assets/content/*.json'),
                *root.glob('assets/artwork/*'), *root.glob('assets/fonts/*'),
                root / 'test/visual_acceptance_test.dart', root / 'pubspec.yaml', root / 'pubspec.lock']
after_hashes = {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                 for p in sorted(source_paths) if p.is_file()}
source_hashes = json.loads((output / 'source-before.json').read_text())
changed_sources = [name for name in sorted(set(source_hashes) | set(after_hashes))
                   if source_hashes.get(name) != after_hashes.get(name)]
head = subprocess.run(['git', 'rev-parse', 'HEAD'], capture_output=True, text=True, check=True).stdout.strip()
passed = [case for case in cases if case.get('status') == 'passed']
failed = [case for case in cases if case.get('status') != 'passed']
complete = len(cases) == run.get('expected_cases') and len(passed) == len(cases) and not changed_sources
summary = {'renderer': 'Flutter widget tester engine; NOT Android/device screenshots',
           'visual_review': 'pending PNG inspection; layout success alone is not visual approval',
           'flutter_version': '3.35.7', 'git_head': head, 'working_tree_source_sha256': source_hashes,
           'source_hashes_stable_during_run': not changed_sources, 'changed_source_paths': changed_sources,
           'flutter_exit_code': exit_code, 'additional_test_arguments': arguments,
           'complete_matrix_passed': complete and exit_code == 0,
           'cases_passed': len(passed), 'cases_failed': len(failed),
           'expected_cases': run.get('expected_cases', 0), 'case_reports': [p.name for p in output.glob('*.json')],
           'screenshots': images}
(output / 'summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n')
relative = output.relative_to(root)
Path('docs/screenshots/flutter-tester/latest.json').write_text(json.dumps(
    {'run': str(relative), 'summary': str(relative / 'summary.json'),
     'complete_matrix_passed': summary['complete_matrix_passed'],
     'visual_review': 'pending'}, indent=2) + '\n')
print(f'Visual reports: {relative}; {len(passed)} passed, {len(failed)} failed, {len(images)} tester PNGs.')
for case in failed:
    print(f"FAILED: {case['profile']} {case['screen']} ({len(case.get('errors', []))} diagnostics)")
if changed_sources:
    raise SystemExit('Capture source changed during this run; regenerate after coordination: ' + ', '.join(changed_sources))
PY
[[ "${statuses[1]}" == 0 ]] || { echo 'Capture log could not be written' >&2; exit 1; }
exit "${statuses[0]}"
