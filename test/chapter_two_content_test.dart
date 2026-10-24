import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Family chapter has 36 ordered independently indexed entries', () async {
    final db = jsonDecode(await File('assets/data/entries.json').readAsString())
        as Map<String, dynamic>;
    final rows = (db['entries'] as List<dynamic>).cast<Map<String, dynamic>>();
    final grouped = <int, Map<String, dynamic>>{};
    for (final entry in rows) {
      final refs = (entry['book_references'] as List<dynamic>?) ??
          (entry['book_reference'] == null
            ? <dynamic>[] : <dynamic>[entry['book_reference']]);
      for (final raw in refs) {
        final ref = raw as Map<String, dynamic>;
        if (ref['book'] != 1 || ref['chapter'] != 2) continue;
        final index = ref['index'] as int;
        expect(grouped.containsKey(index), false, reason: 'Duplicate index $index');
        grouped[index] = entry;
        expect(ref['official_end_glossary_checked'], false);
        expect(ref['source_url'], 'https://www.isalkini.com/6837/');
      }
    }
    expect(grouped.length, 36);
    expect(grouped.keys.toList()..sort(), List.generate(36, (i) => i + 1));
    for (final entry in grouped.values) {
      expect((entry['meaning_ar'] as String).isNotEmpty, isTrue);
      expect(RegExp(r'[А-Яа-яЁё]').hasMatch(entry['meaning_ar'] as String), isFalse);
      for (final key in ['synonyms', 'antonyms', 'grammar',
                         'collocations', 'examples_ar', 'additional_meanings_ar']) {
        expect(entry[key], isA<List<dynamic>>());
      }
      expect((entry['grammar'] as List).isNotEmpty, isTrue);
      expect((entry['examples_ar'] as List).isNotEmpty, isTrue);
    }
    expect((grouped[24]!['arabic'] as String), 'وَلَدٌ');
    expect((grouped[33]!['arabic'] as String), 'وَلَدَ');
  });

  test('Shared first chapter words retain original provenance', () async {
    final root = jsonDecode(await File('assets/data/entries.json').readAsString())
        as Map<String, dynamic>;
    final entries = (root['entries'] as List<dynamic>).cast<Map<String, dynamic>>();
    final shared = entries.firstWhere((e) => e['arabic'] == 'صُورَةٌ');
    final refs = (shared['book_references'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(refs.any((r) => r['chapter'] == 1), true);
    expect(refs.any((r) => r['chapter'] == 2), true);
  });
}
