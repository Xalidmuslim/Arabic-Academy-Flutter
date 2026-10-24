import 'dart:convert';

class Word {
  const Word(this.id, this.arabic, this.meaning, this.synonyms, this.antonyms,
      this.grammar, this.collocations, this.examples, this.usage, this.additionalMeanings,
      {this.bookNumber, this.chapterNumber, this.chapterOrder});
  final String id, arabic, meaning, usage;
  final List<String> synonyms, antonyms, grammar, collocations, examples, additionalMeanings;
  final int? bookNumber, chapterNumber, chapterOrder;

  factory Word.fromJson(Map<String, dynamic> json) {
    List<String> strings(String key) =>
        ((json[key] as List<dynamic>?) ?? const []).cast<String>();
    return Word(
      json['id'] as String,
      json['arabic'] as String,
      json['meaning_ar'] as String,
      strings('synonyms'),
      strings('antonyms'),
      strings('grammar'),
      strings('collocations'),
      strings('examples_ar'),
      (json['usage_note_ar'] as String?) ?? '',
      strings('additional_meanings_ar'),
      bookNumber: (json['book_reference'] as Map<String, dynamic>?)?['book'] as int?,
      chapterNumber: (json['book_reference'] as Map<String, dynamic>?)?['chapter'] as int?,
      chapterOrder: (json['book_reference'] as Map<String, dynamic>?)?['index'] as int?,
    );
  }
}

List<Word> decodeWords(String jsonText) {
  final object = jsonDecode(jsonText) as Map<String, dynamic>;
  return (object['entries'] as List<dynamic>)
      .map((dynamic item) => Word.fromJson(item as Map<String, dynamic>))
      .toList();
}

List<Word> sortWordsByBookOrder(Iterable<Word> words) {
  final result = words.toList();
  result.sort((a, b) {
    final aBook = a.bookNumber ?? 999;
    final bBook = b.bookNumber ?? 999;
    final first = aBook.compareTo(bBook);
    if (first != 0) return first;
    final chapter = (a.chapterNumber ?? 999).compareTo(b.chapterNumber ?? 999);
    if (chapter != 0) return chapter;
    return (a.chapterOrder ?? 999).compareTo(b.chapterOrder ?? 999);
  });
  return result;
}

String normalizeArabic(String text) {
  return text.toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]'), '')
      .replaceAll(RegExp(r'[إأٱآ]'), 'ا')
      .replaceAll('ى', 'ي').trim();
}


/// Candidates preserve exact matches, then try common clitics and the article.
List<String> _candidateForms(String token) {
  final normalized = normalizeArabic(token)
      .replaceAll(RegExp(r'^[^ء-ي]+|[^ء-ي]+$'), '');
  if (normalized.isEmpty) return const [];
  final candidates = <String>[normalized];
  if (normalized.length > 2 &&
      (normalized.startsWith('و') || normalized.startsWith('ف'))) {
    candidates.add(normalized.substring(1));
  }
  for (final item in List<String>.of(candidates)) {
    if (item.length > 3 && item.startsWith('ال')) {
      candidates.add(item.substring(2));
    }
    if (item.length > 3 &&
        (item.startsWith('ب') || item.startsWith('ل') ||
         item.startsWith('ك'))) {
      final stem = item.substring(1);
      candidates.add(stem);
      if (stem.length > 3 && stem.startsWith('ال')) {
        candidates.add(stem.substring(2));
      }
    }
  }
  return candidates.toSet().toList();
}

String _withoutCaseEnding(String text) {
  return text.replaceAll(RegExp(r'[\u064B-\u0652]+$'), '');
}

/// Keep vocalized noun and verb homographs as distinct dictionary entries.
Word? findWordForToken(String token, Iterable<Word> words) {
  final clean = token.replaceAll(
    RegExp(r'^[\u060C\u061B\u061F«».,:؛!?()]+|[\u060C\u061B\u061F«».,:؛!?()]+$'),
    '',
  );
  final entries = words.toList(growable: false);
  for (final item in entries) {
    if (item.arabic == clean) return item;
  }
  final vocalized = _withoutCaseEnding(clean);
  if (vocalized.contains(RegExp(r'[\u064B-\u0652]'))) {
    for (final item in entries) {
      if (_withoutCaseEnding(item.arabic) == vocalized) return item;
    }
  }
  final lookup = <String, Word>{};
  for (final item in entries) {
    lookup.putIfAbsent(normalizeArabic(item.arabic), () => item);
  }
  for (final candidate in _candidateForms(clean)) {
    final matching = lookup[candidate];
    if (matching != null) return matching;
  }
  return null;
}

