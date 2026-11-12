import 'dart:convert';

import 'dictionary_data.dart';

/// A curated relationship between two exactly vocalized dictionary headwords.
/// Relationships are not represented as literal extracts from a published book.
class LexicalPair {
  const LexicalPair({
    required this.kind,
    required this.left,
    required this.right,
    required this.evidenceFile,
  });

  final String kind;
  final String left;
  final String right;
  final String evidenceFile;
}

class LexicalRelations {
  const LexicalRelations({required this.synonyms, required this.antonyms});

  final List<String> synonyms;
  final List<String> antonyms;
}

/// Reject Russian, malformed entries, identical headwords and duplicate pairs.
/// A pair with no exact match in the loaded corpus is ignored by the matcher.
List<LexicalPair> decodeLexicalRelations(String source) {
  final root = jsonDecode(source) as Map<String, dynamic>;
  if (root['schema_version'] != 1) {
    throw const FormatException('Unsupported lexical relations schema');
  }
  final result = <LexicalPair>[];
  final seen = <String>{};
  final diacritics = RegExp(r'[\u064B-\u065F\u0670]');
  final arabic = RegExp(r'[\u0621-\u064A]');
  final russian = RegExp(r'[\u0400-\u04FF]');

  for (final raw in root['pairs'] as List<dynamic>) {
    final record = Map<String, dynamic>.from(raw as Map);
    final kind = record['kind'] as String? ?? '';
    final left = record['left'] as String? ?? '';
    final right = record['right'] as String? ?? '';
    final evidence = record['evidence_file'] as String? ?? '';
    if ((kind != 'synonym' && kind != 'antonym') ||
        left.isEmpty || right.isEmpty ||
        !arabic.hasMatch(left) || !arabic.hasMatch(right) ||
        !diacritics.hasMatch(left) || !diacritics.hasMatch(right) ||
        russian.hasMatch(left) || russian.hasMatch(right) ||
        normalizeArabic(left) == normalizeArabic(right) ||
        !evidence.startsWith('assets/data/') || !evidence.endsWith('.json') ||
        record.containsKey('ru') || record.containsKey('translation_ru')) {
      throw FormatException('Invalid lexical relationship: $left / $right');
    }
    final ordered = [left, right]..sort();
    final key = '$kind|${ordered[0]}|${ordered[1]}';
    if (!seen.add(key)) {
      throw FormatException('Repeated relationship: $key');
    }
    result.add(LexicalPair(
      kind: kind, left: left, right: right, evidenceFile: evidence));
  }
  return result;
}

/// Merge only verified, exact vocalized headwords. Unlike bare-letter matching
/// this does not connect عَلَمٌ (flag) to عِلْمٌ (knowledge). Original corpus
/// entries and stable IDs remain unchanged.
Map<String, LexicalRelations> matchLexicalRelations(
    Iterable<Word> words, Iterable<LexicalPair> pairs) {
  final byHeadword = <String, Word>{};
  final duplicate = <String>{};
  for (final word in words) {
    if (byHeadword.containsKey(word.arabic)) duplicate.add(word.arabic);
    byHeadword[word.arabic] = word;
  }
  for (final key in duplicate) {
    byHeadword.remove(key);
  }

  final synonyms = <String, Set<String>>{};
  final antonyms = <String, Set<String>>{};
  for (final pair in pairs) {
    final left = byHeadword[pair.left];
    final right = byHeadword[pair.right];
    if (left == null || right == null) continue;
    final target = pair.kind == 'synonym' ? synonyms : antonyms;
    target.putIfAbsent(left.id, () => <String>{}).add(right.arabic);
    target.putIfAbsent(right.id, () => <String>{}).add(left.arabic);
  }

  return {
    for (final id in {...synonyms.keys, ...antonyms.keys})
      id: LexicalRelations(
        synonyms: List<String>.unmodifiable(synonyms[id] ?? const {}),
        antonyms: List<String>.unmodifiable(antonyms[id] ?? const {}),
      ),
  };
}
