import 'package:bayna_dictionary/core/dictionary_data.dart';
import 'package:bayna_dictionary/ui/dictionary_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Book navigation uses explicit chapter references without duplicates', () {
    const source = '{"entries":['
        '{"id":"a","arabic":"بَيْتٌ","meaning_ar":"مَنْزِلٌ",'
        '"book_references":[{"book":1,"chapter":1,"index":1},'
        '{"book":1,"chapter":2,"index":2}]},'
        '{"id":"b","arabic":"أُسْرَةٌ","meaning_ar":"أَهْلٌ",'
        '"book_reference":{"book":1,"chapter":2,"index":1}},'
        '{"id":"c","arabic":"سَفَرٌ","meaning_ar":"رِحْلَةٌ",'
        '"book_references":[{"book":2,"chapter":1,"index":1}]},'
        '{"id":"d","arabic":"عِلْمٌ","meaning_ar":"مَعْرِفَةٌ"}]}';
    final index = bookChapterCounts(decodeWords(source));
    expect(index.keys.toList()..sort(), [1, 2]);
    expect(index[1]?[1], 1);
    expect(index[1]?[2], 2);
    expect(index[2]?[1], 1);
    expect(index.values.expand((chapters) => chapters.values).reduce((a, b) => a + b), 4);
  });

  testWidgets('Bottom navigation shows search without removing saved access', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: DictionaryNav(tab: 0, onTap: (_) {}),
      ),
    ));
    expect(find.text('Поиск'), findsOneWidget);
    expect(find.text('Избранное'), findsNothing);
    expect(find.text('Закладки'), findsOneWidget);
  });

  testWidgets('Book opens chapters, chapter opens words, back returns to chapters', (tester) async {
    SharedPreferences.setMockInitialValues({});
    const source = '{"entries":['
        '{"id":"a","arabic":"بَيْتٌ","meaning_ar":"مَنْزِلٌ",'
        '"book_reference":{"book":1,"chapter":1,"index":1}},'
        '{"id":"b","arabic":"سَفَرٌ","meaning_ar":"رِحْلَةٌ"}]}';
    await tester.pumpWidget(DictionaryApp(previewWords: decodeWords(source)));
    await tester.pumpAndSettle();
    expect(find.text('Том 1'), findsOneWidget);
    await tester.tap(find.text('Том 1'));
    await tester.pumpAndSettle();
    expect(find.text('Тема 1'), findsOneWidget);
    await tester.tap(find.text('Тема 1'));
    await tester.pumpAndSettle();
    expect(find.text('بَيْتٌ'), findsOneWidget);
    await tester.tap(find.byTooltip('К темам'));
    await tester.pumpAndSettle();
    expect(find.text('Тема 1'), findsOneWidget);
  });

  testWidgets('Search looks across the entire corpus, including words without book references',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    const source = '{"entries":['
        '{"id":"a","arabic":"بَيْتٌ","meaning_ar":"مَنْزِلٌ",'
        '"book_reference":{"book":1,"chapter":1,"index":1}},'
        '{"id":"b","arabic":"سَفَرٌ","meaning_ar":"رِحْلَةٌ"}]}';
    await tester.pumpWidget(DictionaryApp(previewWords: decodeWords(source)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Поиск'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('arabic-search')), 'سفر');
    await tester.pumpAndSettle();
    expect(find.text('سَفَرٌ'), findsOneWidget);
  });
}
