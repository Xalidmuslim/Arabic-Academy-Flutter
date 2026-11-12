import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bayna_dictionary/core/dictionary_data.dart';
import 'package:bayna_dictionary/core/reviewed_lexicon.dart';
import 'package:bayna_dictionary/ui/dictionary_shell.dart';

const fixture = '''
{
  "schema_version": 2,
  "entries": [{
    "arabic": "تَحِيَّةٌ",    "definition": [{"ar":"سَلَامٌ عِنْدَ اللِّقَاءِ."}],
    "grammar": [{"ar":"اِسْمٌ مُؤَنَّثٌ."}],
    "synonyms": [{"ar":"سَلَامٌ"}],
    "contrasts": [{"ar":"وَدَاعٌ"}],
    "examples": [{"ar":"رَدَّ الرَّجُلُ التَّحِيَّةَ."}],
    "important": [{"ar":"حَيَّا — يُحَيِّي."}],
    "source_urls": ["https://www.arabicacademy.gov.eg/"]
  }]
}
''';

Word sample(String id, String arabic) => Word(id, arabic,
  'كَلِمَةٌ تُقَالُ عِنْدَ اللِّقَاءِ', const [], const [],
  const ['اِسْمٌ'], const [], const [], '', const []);

void main() {
  test('Reviewed articles retain original corpus IDs and skip bare homographs', () {
    final articles = decodeReviewedArticles(fixture);
    final corpus = [sample('original', 'تَحِيَّةٌ'), sample('other', 'كِتَابٌ')];
    final attached = matchReviewedArticles(corpus, articles);
    expect(attached.keys, contains('original'));
    expect(attached['original']!.definition.single.arabic, 'سَلَامٌ عِنْدَ اللِّقَاءِ.');
    expect(attached.keys, isNot(contains('other')));
    expect(corpus.first.id, 'original');
    expect(corpus.first.meaning, 'كَلِمَةٌ تُقَالُ عِنْدَ اللِّقَاءِ');
  });

  test('Reviewed cards reject Russian translations and comments', () {
    final root = jsonDecode(fixture) as Map<String, dynamic>;
    final item = (root['entries'] as List<dynamic>).single as Map<String, dynamic>;
    item['translation_ru'] = 'приветствие';
    expect(() => decodeReviewedArticles(jsonEncode(root)), throwsFormatException);
    item.remove('translation_ru');
    final definition = (item['definition'] as List<dynamic>).first as Map<String, dynamic>;
    definition['ru'] = 'Перевод';
    expect(() => decodeReviewedArticles(jsonEncode(root)), throwsFormatException);
  });

  test('Ambiguous unvowelled forms are never enriched by guessed sense', () {
    final articles = decodeReviewedArticles(fixture);
    final attached = matchReviewedArticles([
      sample('a', 'تَحِيَّةٌ'),
      sample('b', 'تَحِيَّةٌ'),
    ], articles);
    expect(attached, isEmpty);
  });

  test('Duplicate reviewed headwords are rejected', () {
    final root = jsonDecode(fixture) as Map<String, dynamic>;
    final items = root['entries'] as List<dynamic>;
    items.add(Map<String, dynamic>.from(items.first as Map));
    expect(() => decodeReviewedArticles(jsonEncode(root)), throwsFormatException);
  });

  test('Missing evidence and grammar cause a failed editorial import', () {
    final root = jsonDecode(fixture) as Map<String, dynamic>;
    final article = (root['entries'] as List<dynamic>).first as Map<String, dynamic>;
    article['source_urls'] = <String>[];
    expect(() => decodeReviewedArticles(jsonEncode(root)), throwsFormatException);
    article['source_urls'] = ['https://www.arabicacademy.gov.eg/'];
    article['grammar'] = <dynamic>[];
    expect(() => decodeReviewedArticles(jsonEncode(root)), throwsFormatException);
  });

  testWidgets('Reviewed word shows Arabic-only explanations without deleting legacy word data',
      (tester) async {
    final article = decodeReviewedArticles(fixture).values.single;
    await tester.pumpWidget(MaterialApp(home: WordReader(
      word: sample('greeting', 'تَحِيَّةٌ'),
      reviewed: article, font: 23,
      favorite: false, bookmarked: false,
      onFavorite: () async {}, onBookmark: () async {},
      onSpeak: () {}, onCopy: () {}, onArabicTap: (_) {},
    )));
    await tester.pump();
    expect(find.textContaining('Перевод:'), findsNothing);
    expect(find.text('سَلَامٌ عِنْدَ اللِّقَاءِ.'), findsWidgets);
    expect(find.text('Приветствие при встрече.'), findsNothing);
    expect(find.text('Разъяснение значения'), findsOneWidget);
    expect(find.text('Грамматический разбор'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Противоположные слова'), 160,
      scrollable: find.byType(Scrollable).first);
    expect(find.text('Противоположные слова'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Важно знать'), 160,
      scrollable: find.byType(Scrollable).first);
    expect(find.text('Важно знать'), findsOneWidget);
  });
}
