import 'dart:convert';

import 'dictionary_data.dart';

/// Editorial additions are stored separately from the original corpus.
/// An entry is shown only when its normalized headword is unambiguous.
class ReviewedFact {
  const ReviewedFact({required this.arabic});

  final String arabic;

  factory ReviewedFact.fromJson(Map<String, dynamic> json) {
    final arabic = (json['ar'] as String? ?? '').trim();
    if (json.containsKey('ru') ||
        arabic.isEmpty ||
        !RegExp(r'[\u0621-\u064A]').hasMatch(arabic) ||
        RegExp(r'[\u0400-\u04FF]').hasMatch(arabic)) {
      throw const FormatException(
          'Reviewed facts must contain Arabic only, without Russian fields');
    }
    return ReviewedFact(arabic: arabic);
  }
}

class ReviewedArticle {
  const ReviewedArticle({
    required this.arabic,
    required this.definition,
    required this.grammar,
    required this.synonyms,
    required this.contrasts,
    required this.examples,
    required this.important,
    required this.sourceUrls,
  });

  final String arabic;
  final List<ReviewedFact> definition;
  final List<ReviewedFact> grammar;
  final List<ReviewedFact> synonyms;
  final List<ReviewedFact> contrasts;
  final List<ReviewedFact> examples;
  final List<ReviewedFact> important;
  final List<String> sourceUrls;

  factory ReviewedArticle.fromJson(Map<String, dynamic> json) {
    List<ReviewedFact> facts(String field) =>
        (json[field] as List<dynamic>? ?? const [])
            .map((value) => ReviewedFact.fromJson(
                Map<String, dynamic>.from(value as Map)))
            .toList(growable: false);

    final arabic = (json['arabic'] as String? ?? '').trim();
    final sources = (json['source_urls'] as List<dynamic>? ?? const [])
        .cast<String>();
    if (json.containsKey('translation_ru') || arabic.isEmpty ||
        sources.isEmpty || sources.any((s) => !s.startsWith('https://'))) {
      throw const FormatException('Reviewed article requires Arabic headword and HTTPS sources');
    }
    final definition = facts('definition');
    final grammar = facts('grammar');
    final examples = facts('examples');
    final important = facts('important');
    if (definition.isEmpty || grammar.isEmpty || examples.isEmpty ||
        important.isEmpty) {
      throw const FormatException('Reviewed article is missing essential explanations');
    }
    return ReviewedArticle(
      arabic: arabic,
      definition: definition,
      grammar: grammar,
      synonyms: facts('synonyms'),
      contrasts: facts('contrasts'),
      examples: examples,
      important: important,
      sourceUrls: sources,
    );
  }
}

/// Normalize only the order of combining marks in a fully vocalized word.
/// Do NOT strip harakat or fold hamza/alef: those operations erase important
/// lexical distinctions, e.g. أَبْطَالٌ versus إِبْطَالٌ.
///
/// This canonical mark key is for equality checks, not for display.
String canonicalVocalizedHeadword(String input) {
  return input.replaceAllMapped(
    RegExp(r'[\u064B-\u065F\u0670]+'),
    (match) {
      final marks = match.group(0)!.runes.toList()..sort();
      return String.fromCharCodes(marks);
    },
  );
}

/// Reject duplicate fully vocalized headwords, including equivalent mark
/// orderings, while allowing genuinely distinct vowel patterns and hamzas.
Map<String, ReviewedArticle> decodeReviewedArticles(String jsonText) {
  final root = jsonDecode(jsonText) as Map<String, dynamic>;
  if (root['schema_version'] != 2) {
    throw const FormatException('Unsupported reviewed lexicon schema');
  }
  final articles = <String, ReviewedArticle>{};
  for (final value in root['entries'] as List<dynamic>) {
    final article = ReviewedArticle.fromJson(
        Map<String, dynamic>.from(value as Map));
    final key = canonicalVocalizedHeadword(article.arabic);
    if (articles.containsKey(key)) {
      throw FormatException('Ambiguous reviewed headword: ${article.arabic}');
    }
    articles[key] = article;
  }
  return articles;
}

/// Match fully vocalized articles by existing stable IDs. Homographs with
/// different vowels are distinct; ambiguous duplicate mark order is excluded.
Map<String, ReviewedArticle> matchReviewedArticles(
    Iterable<Word> words, Map<String, ReviewedArticle> reviewed) {
  final corpus = words.toList(growable: false);
  final counts = <String, int>{};
  for (final word in corpus) {
    final key = canonicalVocalizedHeadword(word.arabic);
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return {
    for (final word in corpus)
      if (counts[canonicalVocalizedHeadword(word.arabic)] == 1 &&
          reviewed.containsKey(canonicalVocalizedHeadword(word.arabic)))
        word.id: reviewed[canonicalVocalizedHeadword(word.arabic)]!,
  };
}
