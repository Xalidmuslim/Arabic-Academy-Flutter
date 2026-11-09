#!/usr/bin/env python3
"""Count verified Russian-gloss coverage without inventing translations."""
import json
import pathlib
import re
from collections import defaultdict

root = pathlib.Path(__file__).resolve().parents[1]
manifest = json.loads((root / 'assets/data/corpus_manifest.json').read_text())
glosses = json.loads((root / 'assets/data/ru_glosses.json').read_text())
unique = {}
for filename in manifest['files']:
    entries = json.loads((root / filename).read_text())['entries']
    for entry in entries:
        unique.setdefault(entry['arabic'], entry)
def normalize(word):
    word = re.sub(r'[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]', '', word)
    return word.translate(str.maketrans({'إ':'ا','أ':'ا','ٱ':'ا','آ':'ا','ى':'ي'})).lower().strip()
forms = defaultdict(set)
for arabic in unique:
    forms[normalize(arabic)].add(arabic)
covered = 0
missing = []
for arabic, item in unique.items():
    norm = normalize(arabic)
    value = item.get('meaning_ru') or glosses.get(arabic)
    if not value and len(forms[norm]) == 1:
        value = glosses.get(norm)
    if value:
        covered += 1
    else:
        missing.append({'arabic': arabic, 'id': item['id']})
report = {
    'unique_lexical_entries': len(unique),
    'russian_glosses_present': covered,
    'russian_glosses_missing': len(missing),
    'coverage_percent': round(covered * 100 / max(1, len(unique)), 2),
    'missing_examples': missing[:40],
}
print(json.dumps(report, ensure_ascii=False, indent=2))
(root / 'translation-coverage.json').write_text(
    json.dumps(report, ensure_ascii=False, indent=2) + '\n')
