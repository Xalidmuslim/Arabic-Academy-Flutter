import 'dart:convert';
import 'dart:io';

import 'package:bayna_dictionary/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter loader merges all 81 manifest chunks without losing original or source-verified entries', () async {
    final manifest = jsonDecode(
      await File('assets/data/corpus_manifest.json').readAsString(),
    ) as Map<String, dynamic>;
    final paths = (manifest['files'] as List<dynamic>).cast<String>();
    expect(paths, hasLength(81));
    expect(paths, contains('assets/data/entries_editorial_photography_20261101.json'));

    final texts = await Future.wait(paths.map((path) => File(path).readAsString()));
    final merged = decodeAndMergeCorpora(texts);
    expect(merged, hasLength(7129));

    final scanSource = jsonDecode(
      await File('assets/data/entries_bayna_scan_verified_20261112.json').readAsString(),
    ) as Map<String, dynamic>;
    final sourceEntries = (scanSource['entries'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(paths, contains('assets/data/entries_bayna_scan_verified_20261112.json'));
    expect(sourceEntries, hasLength(4));
    final mergedById = {for (final entry in merged) entry.id: entry};
    for (final source in sourceEntries) {
      final entry = mergedById[source['id']];
      expect(entry, isNotNull, reason: 'Source-verified lemma missing: ${source['arabic']}');
      expect(entry!.arabic, source['arabic']);
      expect(entry.meaning, source['meaning_ar']);
      expect(entry.examples, source['examples_ar']);
      expect(entry.bookReferences, isEmpty);
    }

    final extension = jsonDecode(
      await File('assets/data/entries_editorial_photography_20261101.json').readAsString(),
    ) as Map<String, dynamic>;
    final added = (extension['entries'] as List<dynamic>).cast<Map<String, dynamic>>();
    final byId = {for (final word in merged) word.id: word};
    expect(added, hasLength(20));
    for (final card in added) {
      final word = byId[card['id']];
      expect(word, isNotNull, reason: 'Missing new card: ${card['id']}');
      expect(word!.arabic, card['arabic']);
      expect(word.meaning, card['meaning_ar']);
      expect(word.collocations, card['collocations']);
      expect(word.examples, card['examples_ar']);
    }
  });

  test('Arabic search normalization exposes all three exposure entries', () async {
    final text = await File('assets/data/entries_editorial_photography_20261101.json').readAsString();
    final words = decodeWords(text);
    final hits = words
        .where((word) => normalizeArabic(word.arabic).contains(normalizeArabic('تَعْرِيضٌ')))
        .toList();
    expect(hits, hasLength(3));
    expect(hits.map((w) => normalizeArabic(w.arabic)).toSet(), containsAll([
      normalizeArabic('تَعْرِيضٌ زَائِدٌ'),
      normalizeArabic('تَعْرِيضٌ نَاقِصٌ'),
      normalizeArabic('تَعْرِيضٌ مُزْدَوَجٌ'),
    ]));
  });
}
