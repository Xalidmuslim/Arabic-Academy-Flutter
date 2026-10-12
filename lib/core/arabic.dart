/// Only for searching. Never mutate the original teaching text or use this
/// permissive spelling normalization to award an exercise score.
String normalizeSearch(String value) => value
    .toLowerCase()
    .replaceAll(
      RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u0640]'),
      '',
    )
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

bool matchesSearch(String query, Iterable<String> values) {
  final normalized = normalizeSearch(query);
  return normalized.isEmpty ||
      values.any((text) => normalizeSearch(text).contains(normalized));
}
