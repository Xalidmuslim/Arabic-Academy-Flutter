import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;

import 'package:flutter/services.dart';

/// Local content must be available without a network or an account.
/// Each asset is associated with a semantic name to prevent accidental
/// substitution of the book index for the grammar index during startup.
Future<Map<String, dynamic>> loadBundledAcademyCatalog() async {
  const sources = <String, String>{
    'level': 'assets/content/level1.json',
    'original': 'assets/content/original_lessons.json',
    'book': 'assets/content/book1_original_dialogues.json',
    'book2': 'assets/content/book1_part2_editorial.json',
    'grammar': 'assets/content/grammar.json',
  };

  // Fetch assets concurrently and parse/merge in ONE worker isolate.
  // Flutter can keep animating its first loading frame without five separate
  // JSON parsing/merging passes contending with UI frame scheduling.
  final assets = await Future.wait(
    sources.entries.map((source) async {
      final bytes = await rootBundle.load(source.value);
      return MapEntry(source.key, Uint8List.sublistView(bytes));
    }),
  );
  return compute<Map<String, Uint8List>, Map<String, dynamic>>(
    _decodeAndMergeCatalog,
    Map<String, Uint8List>.fromEntries(assets),
    debugLabel: 'bayna-catalog-background-decode',
  );
}

/// Runs on a Dart worker isolate on Android. No BuildContext, platform
/// channels or Flutter bindings can be accessed from this function.
Map<String, dynamic> _decodeAndMergeCatalog(
  Map<String, Uint8List> assets,
) {
  final documents = <String, Map<String, dynamic>>{};
  for (final entry in assets.entries) {
    final decoded = jsonDecode(utf8.decode(entry.value));
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Invalid bundled catalog: ${entry.key}');
    }
    documents[entry.key] = decoded;
  }
  final catalog = Map<String, dynamic>.from(documents['level']!);
  final original = documents['original']!;
  final book = documents['book']!;
  final book2 = documents['book2']!;
  final grammar = documents['grammar']!;

  List<dynamic> requireList(Map<String, dynamic> data, String key, String source) {
    final list = data[key];
    if (list is! List) {
      throw FormatException('Invalid $key in bundled asset $source');
    }
    return list;
  }

  final modules = requireList(book, 'modules', 'book');
  final dialogues = requireList(book, 'lessons', 'book');
  final secondPartUnits = requireList(book2, 'modules', 'book2');
  final secondPartLessons = requireList(book2, 'lessons', 'book2');
  final supplements = requireList(catalog, 'lessons', 'level');
  final originalLessons = requireList(original, 'lessons', 'original');
  final grammarTopics = requireList(grammar, 'topics', 'grammar');

  // Independent editorial dialogues in Book 1 order. Existing micro-lessons
  // remain supplementary, never passed off as publisher textbook content.
  catalog['modules'] = [...modules, ...secondPartUnits];
  catalog['lessons'] = [
    ...dialogues,
    ...secondPartLessons,
    for (final item in supplements)
      {...item as Map, 'module_id': 'u1', 'source': 'original_editorial',
        'supplementary': true},
    for (final item in originalLessons)
      {...item as Map, 'supplementary': true},
  ];
  catalog['grammar_topics'] = grammarTopics;
  return catalog;
}
