import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Housing unit retains 52 independently ordered Arabic entries', () async {
    final source = jsonDecode(await File('assets/data/entries.json').readAsString())
        as Map<String, dynamic>;
    final entries = (source['entries'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final positions = <int, Map<String, dynamic>>{};
    for (final entry in entries) {
      final refs = (entry['book_references'] as List<dynamic>?) ??
          (entry['book_reference'] == null
              ? <dynamic>[] : <dynamic>[entry['book_reference']]);
      for (final raw in refs) {
        final ref = raw as Map<String, dynamic>;
        if (ref['book'] != 1 || ref['chapter'] != 3) continue;
        final index = ref['index'] as int;
        expect(positions.containsKey(index), isFalse,
          reason: 'Repeated third-unit position $index');
        expect(ref['official_end_glossary_checked'], isFalse);
        expect(ref['source_url'], 'https://www.isalkini.com/6840/');
        positions[index] = entry;
        for (final key in [
          'synonyms', 'antonyms', 'grammar', 'collocations',
          'examples_ar', 'additional_meanings_ar'
        ]) {
          expect(entry[key], isA<List<dynamic>>());
        }
        expect((entry['meaning_ar'] as String).isNotEmpty, isTrue);
        expect((entry['grammar'] as List).isNotEmpty, isTrue);
        expect((entry['examples_ar'] as List).isNotEmpty, isTrue);
        final lexical = [
          entry['arabic'], entry['meaning_ar'], entry['usage_note_ar'],
          ...(entry['synonyms'] as List<dynamic>),
          ...(entry['antonyms'] as List<dynamic>),
          ...(entry['grammar'] as List<dynamic>),
          ...(entry['collocations'] as List<dynamic>),
          ...(entry['examples_ar'] as List<dynamic>)
        ].join(' ');
        expect(RegExp(r'[А-Яа-яЁё]').hasMatch(lexical), isFalse);
      }
    }
    expect(positions.length, 52);
    expect(positions.keys.toList()..sort(), List<int>.generate(52, (i) => i + 1));
    // JSON is NFC-normalized: the dammatan precedes shadda in Unicode order.
    // The conventional displayed spelling remains exactly the same.
    expect(positions[1]!['arabic'], 'حَيٌّ');
    expect(positions[5]!['arabic'], 'شَقَّةٌ');
    expect(positions[12]!['arabic'], 'أَثَاثٌ');
  });

  test('Shared housing word is linked without duplication', () async {
    final data = jsonDecode(await File('assets/data/entries.json').readAsString())
        as Map<String, dynamic>;
    final entries = (data['entries'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final house = entries.where((e) => e['arabic'] == 'بَيْتٌ').toList();
    expect(house.length, 1);
    final refs = (house.single['book_references'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(refs.any((r) => r['chapter'] == 3), isTrue);
  });
}
