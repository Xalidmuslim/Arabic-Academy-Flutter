import 'dart:convert';
import 'dart:io';

import 'package:bayna_dictionary/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter loader merges all 80 manifest chunks and preserves photography entries', () async {
    final manifest = jsonDecode(
      await File('assets/data/corpus_manifest.json').readAsString(),
    ) as Map<String, dynamic>;
    final paths = (manifest['files'] as List<dynamic>).cast<String>();
    expect(paths, hasLength(80));
    expect(paths, contains('assets/data/entries_editorial_photography_20261101.json'));

    final texts = await Future.wait(paths.map((path) => File(path).readAsString()));
    final merged = decodeAndMergeCorpora(texts);
    expect(merged, hasLength(7125));

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
