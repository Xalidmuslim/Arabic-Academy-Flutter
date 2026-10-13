import 'dart:convert';

import 'package:flutter/services.dart';

/// Local content must be available without a network or an account.
/// Each asset is associated with a semantic name to prevent accidental
/// substitution of the book index for the grammar index during startup.
Future<Map<String, dynamic>> loadBundledAcademyCatalog() async {
  const sources = <String, String>{
    'level': 'assets/content/level1.json',
    'original': 'assets/content/original_lessons.json',
    'book': 'assets/content/book1_original_dialogues.json',
    'grammar': 'assets/content/grammar.json',
  };

  final entries = await Future.wait(
    sources.entries.map((source) async {
      final decoded = jsonDecode(await rootBundle.loadString(source.value));
      if (decoded is! Map<String, dynamic>) {
        throw FormatException('Invalid bundled catalog: ${source.value}');
      }
      return MapEntry(source.key, decoded);
    }),
  );
  final documents = Map<String, Map<String, dynamic>>.fromEntries(entries);
  final catalog = Map<String, dynamic>.from(documents['level']!);
  final original = documents['original']!;
  final book = documents['book']!;
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
  final supplements = requireList(catalog, 'lessons', 'level');
  final originalLessons = requireList(original, 'lessons', 'original');
  final grammarTopics = requireList(grammar, 'topics', 'grammar');

  // Independent editorial dialogues in Book 1 order. Existing micro-lessons
  // remain supplementary, never passed off as publisher textbook content.
  catalog['modules'] = modules;
  catalog['lessons'] = [
    ...dialogues,
    for (final item in supplements)
      {...item as Map, 'module_id': 'u1', 'source': 'original_editorial',
        'supplementary': true},
    for (final item in originalLessons)
      {...item as Map, 'supplementary': true},
  ];
  catalog['grammar_topics'] = grammarTopics;
  return catalog;
}
