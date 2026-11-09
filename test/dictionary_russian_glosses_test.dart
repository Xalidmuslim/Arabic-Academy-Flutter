import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bayna_dictionary/main.dart';
import 'package:bayna_dictionary/ui/dictionary_shell.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Corpus accepts the Russian gloss without changing Arabic meaning or ID', () {
    final result = decodeWords('{"entries":[{"id":"book-1",'
      '"arabic":"كِتَابٌ","meaning_ar":"مَجْمُوعَةٌ مِنَ الصَّفَحَاتِ",'
      '"meaning_ru":"книга"}]}');
    expect(result.single.id, 'book-1');
    expect(result.single.meaning, 'مَجْمُوعَةٌ مِنَ الصَّفَحَاتِ');
    expect(result.single.russian, 'книга');
  });

  test('Offline glossary restores Russian gloss to words without editing Arabic', () {
    const source = Word('book-1', 'كِتَابٌ', 'مَجْمُوعَةٌ مِنَ الصَّفَحَاتِ',
        [], [], [], [], [], '', []);
    final mapped = attachRussianGlosses([source], {'كتاب': 'книга'});
    expect(mapped.single.russian, 'книга');
    expect(mapped.single.id, source.id);
    expect(mapped.single.arabic, source.arabic);
    expect(mapped.single.meaning, source.meaning);
  });

  test('Arabic homographs cannot silently receive the wrong Russian meaning', () {
    const first = Word('flag', 'عَلَمٌ', 'رَايَةٌ', [], [], [], [], [], '', []);
    const second = Word('knowledge', 'عِلْمٌ', 'مَعْرِفَةٌ', [], [], [], [], [], '', []);
    final mapped = attachRussianGlosses([first, second], {'علم': 'знание'});
    expect(mapped.every((w) => w.russian.isEmpty), isTrue);
  });

  testWidgets('Dictionary remains Arabic-only even when source has a Russian gloss',
      (tester) async {
    const item = Word('book-1', 'كِتَابٌ', 'مَجْمُوعَةٌ مِنَ الصَّفَحَاتِ',
        [], [], [], [], [], '', [], russian: 'книга',
        bookNumber: 1, chapterNumber: 1);
    await tester.pumpWidget(const DictionaryApp(previewWords: [item]));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('all-words-tile')));
    await tester.pumpAndSettle();
    expect(find.text('книга'), findsNothing);
    expect(find.text('كِتَابٌ'), findsWidgets);
    await tester.tap(find.byType(WordTile).first);
    await tester.pumpAndSettle();
    expect(find.text('Перевод на русский'), findsNothing);
    expect(find.text('Значения слова'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Поиск').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('arabic-search')), 'книга');
    await tester.pumpAndSettle();
    expect(find.byType(WordTile), findsNothing);
    await tester.enterText(find.byKey(const Key('arabic-search')), 'كتاب');
    await tester.pumpAndSettle();
    expect(find.byType(WordTile), findsOneWidget);
  });

}
