import 'dart:convert';
import 'dart:io';

import 'package:bayna_dictionary/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter loader merges source-verified entries without losing original stable IDs or photography', () async {
    final manifest = jsonDecode(
      await File('assets/data/corpus_manifest.json').readAsString(),
    ) as Map<String, dynamic>;
    final paths = (manifest['files'] as List<dynamic>).cast<String>();
    expect(paths, hasLength(82));
    expect(paths, contains('assets/data/entries_editorial_photography_20261101.json'));

    final texts = await Future.wait(paths.map((path) => File(path).readAsString()));
    final merged = decodeAndMergeCorpora(texts);
    const scanFile = 'assets/data/entries_bayna_scan_verified_20261112.json';
    final beforeSource = decodeAndMergeCorpora([
      for (var i = 0; i < paths.length; i++)
        if (paths[i] != scanFile) texts[i],
    ]);
    expect(beforeSource, hasLength(7138));
    final originalByHeadword = {for (final w in beforeSource) w.arabic: w};
    final expectedNew = (jsonDecode(await File(scanFile).readAsString())
            as Map<String, dynamic>)['entries'] as List<dynamic>;
    final newHeadwords = expectedNew
        .cast<Map<String, dynamic>>()
        .map((e) => e['arabic'] as String)
        .where((lemma) => !originalByHeadword.containsKey(lemma))
        .toSet();
    expect(merged, hasLength(7125 + newHeadwords.length));
    final afterByHeadword = {for (final word in merged) word.arabic: word};
    for (final original in beforeSource) {
      expect(afterByHeadword[original.arabic]?.id, original.id,
          reason: 'Original stable word ID must remain: ${original.arabic}');
    }

    final scanSource = jsonDecode(
      await File('assets/data/entries_bayna_scan_verified_20261112.json').readAsString(),
    ) as Map<String, dynamic>;
    final sourceEntries = (scanSource['entries'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(paths, contains('assets/data/entries_bayna_scan_verified_20261112.json'));
    expect(sourceEntries.length, greaterThanOrEqualTo(571));
    expect(sourceEntries.map((e) => e['id']).toSet(), hasLength(sourceEntries.length));
    expect(sourceEntries.map((e) => e['arabic']).toSet(), hasLength(sourceEntries.length));
    final sourceByWord = {for (final entry in sourceEntries) entry['arabic']: entry};
    expect(sourceByWord, contains('أُسْقُفٌ'));
    expect(sourceByWord, contains('أَسْقُفٌ'));
    expect(sourceByWord, contains('أَرْسُغٌ'));
    expect(sourceByWord, contains('أَسْرَى'));
    expect(sourceByWord, isNot(contains('أَسْرَىٰ')));
    expect((sourceByWord['أَسْرَى']!['additional_meanings_ar'] as List).length,
        greaterThanOrEqualTo(1));
    final mergedById = {for (final entry in merged) entry.id: entry};
    for (final source in sourceEntries) {
      final original = originalByHeadword[source['arabic']];
      final entry = original == null
          ? mergedById[source['id']]
          : afterByHeadword[source['arabic']];
      expect(entry, isNotNull, reason: 'Source-verified lemma missing: ${source['arabic']}');
      expect(entry!.arabic, source['arabic']);
      if (original == null) {
        expect(entry.id, source['id']);
        expect(entry.meaning, source['meaning_ar']);
        expect(entry.examples, source['examples_ar']);
        expect(entry.bookReferences, isEmpty);
      } else {
        expect(entry.id, original.id);
      }
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
