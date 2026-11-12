import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bayna_dictionary/core/dictionary_data.dart';
import 'package:bayna_dictionary/core/lexical_relations.dart';
import 'package:bayna_dictionary/ui/dictionary_shell.dart';

const fixture = '''
{
  "schema_version": 1,
  "pairs": [
    {
      "kind": "antonym",
      "left": "صَادِقٌ",
      "right": "كَاذِبٌ",
      "evidence_file": "assets/data/entries_adjectives_character_20261025.json"
    },
    {
      "kind": "synonym",
      "left": "مُخْتَصَرٌ",
      "right": "مُوجَزٌ",
      "evidence_file": "assets/data/entries_adjectives_cognition_20261025.json"
    }
  ]
}
''';

Word sample(String id, String arabic, {
    List<String> synonyms = const [], List<String> antonyms = const []}) =>
    Word(id, arabic, 'تَعْرِيفٌ مُوجَزٌ', synonyms, antonyms,
      const ['صِفَةٌ'], const [], const [], '', const []);

void main() {
  test('Relations attach in both directions without rewriting original IDs', () {
    final words = <Word>[
      sample('truth', 'صَادِقٌ'),
      sample('lie', 'كَاذِبٌ'),
      sample('brief', 'مُخْتَصَرٌ'),
      sample('concise', 'مُوجَزٌ'),
    ];
    final compiled = matchLexicalRelations(words, decodeLexicalRelations(fixture));
    expect(compiled['truth']!.antonyms, ['كَاذِبٌ']);
    expect(compiled['lie']!.antonyms, ['صَادِقٌ']);
    expect(compiled['brief']!.synonyms, ['مُوجَزٌ']);
    expect(compiled['concise']!.synonyms, ['مُخْتَصَرٌ']);
    expect(words.first.id, 'truth');
    expect(words.first.antonyms, isEmpty);
  });

  test('Exact vocalization prevents homograph and missing-word false matches', () {
    final words = <Word>[
      sample('knowledge', 'صُدْقٌ'),
      sample('liar', 'كَاذِبٌ'),
    ];
    expect(matchLexicalRelations(words, decodeLexicalRelations(fixture)), isEmpty);
  });

  test('Bad relation data is rejected, including Russian and duplicate pairs', () {
    expect(() => decodeLexicalRelations(fixture.replaceFirst(
      '"kind": "antonym"', '"kind": "Russian перевод"')), throwsFormatException);
    expect(() => decodeLexicalRelations(fixture.replaceFirst(
      '"left": "صَادِقٌ"', '"left": "كَاذِبٌ"')), throwsFormatException);
    expect(() => decodeLexicalRelations(fixture.replaceFirst(
      '"schema_version": 1', '"schema_version": 7')), throwsFormatException);
  });

  testWidgets('Reader shows added Arabic relations and keeps existing article',
      (tester) async {
    final item = sample('truth', 'صَادِقٌ',
      synonyms: ['صَرِيحٌ']);
    final relations = matchLexicalRelations(
      [item, sample('lie', 'كَاذِبٌ')],
      decodeLexicalRelations(fixture),
    )['truth'];
    await tester.pumpWidget(MaterialApp(home: WordReader(
      word: item, relations: relations, font: 23,
      favorite: false, bookmarked: false,
      onFavorite: () async {}, onBookmark: () async {},
      onSpeak: () {}, onCopy: () {}, onArabicTap: (_) {},
    )));
    await tester.pump();
    expect(find.text('Значения слова'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Антонимы'), 150,
      scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Антонимы'));
    await tester.pump();
    expect(find.text('كَاذِبٌ'), findsWidgets);
    expect(item.synonyms, ['صَرِيحٌ']);
  });
}
