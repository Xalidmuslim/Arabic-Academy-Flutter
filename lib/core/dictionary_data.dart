import 'dart:convert';

class Word {
  const Word(this.id, this.arabic, this.meaning, this.synonyms, this.antonyms,
      this.grammar, this.collocations, this.examples, this.usage, this.additionalMeanings,
      {this.bookNumber, this.chapterNumber, this.chapterOrder,
      this.bookReferences = const []});
  final String id, arabic, meaning, usage;
  final List<String> synonyms, antonyms, grammar, collocations, examples, additionalMeanings;
  final int? bookNumber, chapterNumber, chapterOrder;
  final List<Map<String, dynamic>> bookReferences;

  bool isInChapter(int book, int chapter) {
    if (bookReferences.isNotEmpty) {
      return bookReferences.any((ref) =>
          ref['book'] == book && ref['chapter'] == chapter);
    }
    return bookNumber == book && chapterNumber == chapter;
  }

  int? chapterOrderFor(int book, int chapter) {
    for (final ref in bookReferences) {
      if (ref['book'] == book && ref['chapter'] == chapter) {
        return ref['index'] as int?;
      }
    }
    return isInChapter(book, chapter) ? chapterOrder : null;
  }


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
      bookReferences: (json['book_references'] as List<dynamic>? ?? const [])
        .map((ref) => Map<String, dynamic>.from(ref as Map)).toList(),
    );
  }
}

List<Word> decodeWords(String jsonText) {
  final object = jsonDecode(jsonText) as Map<String, dynamic>;
  return (object['entries'] as List<dynamic>)
      .map((dynamic item) => Word.fromJson(item as Map<String, dynamic>))
      .toList();
}

/// Load separate UTF-8 lexicon chunks, merging repeated headwords safely.
/// Existing IDs and earlier definitions take precedence so saved favorites survive.
/// Fully vocalized noun/verb homographs remain distinct.
List<Word> decodeAndMergeCorpora(List<String> jsonTexts) {
  final combined = <Map<String, dynamic>>[];
  final byHeadword = <String, Map<String, dynamic>>{};
  List<Map<String, dynamic>> references(Map<String, dynamic> entry) {
    final refs = entry['book_references'] as List<dynamic>?;
    if (refs != null) {
      return refs.map((r) => Map<String, dynamic>.from(r as Map)).toList();
    }
    final ref = entry['book_reference'];
    return ref == null ? [] : [Map<String, dynamic>.from(ref as Map)];
  }
  for (final text in jsonTexts) {
    final decoded = jsonDecode(text) as Map<String, dynamic>;
    for (final raw in decoded['entries'] as List<dynamic>) {
      final entry = Map<String, dynamic>.from(raw as Map);
      final headword = entry['arabic'] as String;
      final earlier = byHeadword[headword];
      if (earlier == null) {
        byHeadword[headword] = entry;
        combined.add(entry);
      } else {
        final refs = references(earlier);
        for (final ref in references(entry)) {
          if (!refs.any((r) =>
              r['book'] == ref['book'] &&
              r['chapter'] == ref['chapter'])) {
            refs.add(ref);
          }
        }
        earlier['book_references'] = refs;
        for (final key in <String>[
          'synonyms', 'antonyms', 'grammar', 'collocations',
          'examples_ar', 'additional_meanings_ar',
        ]) {
          final current = earlier[key] as List<dynamic>?;
          if ((current == null || current.isEmpty) &&
              entry[key] is List && (entry[key] as List).isNotEmpty) {
            earlier[key] = entry[key];
          }
        }
        if ((earlier['usage_note_ar'] as String? ?? '').isEmpty &&
            (entry['usage_note_ar'] as String? ?? '').isNotEmpty) {
          earlier['usage_note_ar'] = entry['usage_note_ar'];
        }
      }
    }
  }
  return combined.map(Word.fromJson).toList();
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

List<Word> filterWordsByChapter(
    Iterable<Word> words, int book, int chapter) {
  final result = words.where((w) => w.isInChapter(book, chapter)).toList();
  result.sort((a, b) =>
    (a.chapterOrderFor(book, chapter) ?? 999).compareTo(
      b.chapterOrderFor(book, chapter) ?? 999));
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

