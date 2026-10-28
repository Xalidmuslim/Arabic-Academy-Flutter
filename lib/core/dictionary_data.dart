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
        // The source corpus retains later substantive definitions as senses.
        // Match that behavior in the Flutter app without changing the original ID.
        final incomingMeaning = entry['meaning_ar'] as String?;
        if (incomingMeaning != null &&
            incomingMeaning.length >= 14 &&
            incomingMeaning != earlier['meaning_ar']) {
          final meanings = List<dynamic>.of(
              earlier['additional_meanings_ar'] as List<dynamic>? ?? const []);
          if (!meanings.contains(incomingMeaning)) {
            meanings.add(incomingMeaning);
          }
          earlier['additional_meanings_ar'] = meanings;
        }
        for (final key in <String>[
          'synonyms', 'antonyms', 'grammar', 'collocations',
          'examples_ar', 'additional_meanings_ar',
        ]) {
          final current = earlier[key] as List<dynamic>?;
          final incoming = entry[key] as List<dynamic>?;
          if (incoming == null || incoming.isEmpty) continue;
          final merged = <dynamic>[...?current];
          for (final value in incoming) {
            if (!merged.contains(value)) merged.add(value);
          }
          earlier[key] = merged;
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

/// Use the earliest explicit book reference; modern source cards often have
/// book_references without the older singular book_reference field.
List<Word> sortWordsByBookOrder(Iterable<Word> words) {
  List<int> orderKey(Word word) {
    if (word.bookReferences.isNotEmpty) {
      final references = word.bookReferences.map((ref) => <int>[
        ref['book'] as int? ?? 999,
        ref['chapter'] as int? ?? 999,
        ref['index'] as int? ?? 999,
      ]).toList();
      references.sort((a, b) {
        for (var i = 0; i < 3; i++) {
          final diff = a[i].compareTo(b[i]);
          if (diff != 0) return diff;
        }
        return 0;
      });
      return references.first;
    }
    return [
      word.bookNumber ?? 999,
      word.chapterNumber ?? 999,
      word.chapterOrder ?? 999,
    ];
  }
  final result = words.toList();
  result.sort((a, b) {
    final left = orderKey(a);
    final right = orderKey(b);
    for (var i = 0; i < 3; i++) {
      final diff = left[i].compareTo(right[i]);
      if (diff != 0) return diff;
    }
    return a.arabic.compareTo(b.arabic);
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

/// Retain the original vowels while stripping Arabic clitics.
/// This resolves e.g. بِالْعِلْمِ to عِلْمٌ, not عَلَمٌ.
List<String> _vocalizedCandidateForms(String token) {
  final candidates = <String>[];
  final queue = <String>[token];
  final visited = <String>{};
  while (queue.isNotEmpty) {
    final form = queue.removeAt(0);
    if (form.isEmpty || !visited.add(form)) continue;
    candidates.add(form);

    // Only remove distinctly vowelized attached particles. Bare consonants
    // may be the first radical of the actual lemma.
    for (final prefix in const ['وَ', 'فَ', 'بِ', 'لِ', 'كَ']) {
      if (form.startsWith(prefix) && form.length > prefix.length + 1) {
        queue.add(form.substring(prefix.length));
      }
    }
    for (final article in const ['الْ', 'ال', 'لْ']) {
      if (form.startsWith(article) && form.length > article.length + 1) {
        queue.add(form.substring(article.length));
      }
    }
  }
  return candidates;
}

/// Prefer vowel-exact forms before the consonant-only fallback.
/// If the fallback is ambiguous, do not open the wrong Arabic homograph.
Word? findWordForToken(String token, Iterable<Word> words) {
  final clean = token.replaceAll(
    RegExp(r'^[\u060C\u061B\u061F«».,:؛!?()]+|[\u060C\u061B\u061F«».,:؛!?()]+$'),
    '',
  );
  final entries = words.toList(growable: false);
  for (final item in entries) {
    if (item.arabic == clean) return item;
  }

  // Case endings and attached vowels can differ from dictionary headwords.
  final hasVowels = clean.contains(RegExp(r'[\u064B-\u065F\u0670]'));
  if (hasVowels) {
    for (final candidate in _vocalizedCandidateForms(clean)) {
      final vocalizedStem = _withoutCaseEnding(candidate);
      for (final item in entries) {
        if (_withoutCaseEnding(item.arabic) == vocalizedStem) return item;
      }
    }
  }

  final lookup = <String, List<Word>>{};
  for (final item in entries) {
    lookup.putIfAbsent(normalizeArabic(item.arabic), () => []).add(item);
  }
  for (final candidate in _candidateForms(clean)) {
    final matching = lookup[candidate];
    if (matching == null || matching.isEmpty) continue;
    if (matching.length == 1) return matching.single;
    // Same unvocalized form can represent different parts of speech or senses.
    // Prefer no result over an arbitrary first result.
    return null;
  }
  return null;
}
