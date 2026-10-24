import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Chapter one contains 62 unique, ordered, Arabic-only lemma entries', () async {
    final root = jsonDecode(
      await File('assets/data/entries.json').readAsString(),
    ) as Map<String, dynamic>;
    final entries = (root['entries'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final chapter = entries.where((e) =>
        (e['source_group'] == 'book1_chapter1_secondary')).toList();
    expect(chapter.length, 62);
    expect(chapter.map((e) =>
        (e['book_reference'] as Map<String, dynamic>)['index']).toSet().length, 62);
    for (final entry in chapter) {
      for (final field in ['arabic', 'meaning_ar']) {
        final value = entry[field] as String;
        expect(value, isNotEmpty);
        expect(RegExp(r'[а-яА-ЯёЁ]').hasMatch(value), isFalse);
      }
      for (final field in [
        'synonyms', 'antonyms', 'grammar', 'collocations', 'examples_ar',
        'additional_meanings_ar'
      ]) {
        expect(entry[field], isA<List<dynamic>>());
      }
      expect((entry['grammar'] as List).isNotEmpty, true);
      expect((entry['collocations'] as List).isNotEmpty, true);
      expect((entry['examples_ar'] as List).isNotEmpty, true);
    }
    final indexed = chapter.map((e) =>
        (e['book_reference'] as Map<String, dynamic>)['index'] as int).toList()..sort();
    expect(indexed, List<int>.generate(62, (i) => i + 1));
  });
}
