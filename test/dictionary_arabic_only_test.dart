import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bayna_dictionary/core/dictionary_data.dart';
import 'package:bayna_dictionary/ui/dictionary_shell.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Legacy Russian metadata is ignored without changing Arabic corpus', () {
    final words = decodeWords('{"entries":[{"id":"book-1",'
      '"arabic":"كِتَابٌ","meaning_ar":"مَجْمُوعَةٌ مِنَ الصَّفَحَاتِ",'
      '"meaning_ru":"книга"}]}');
    expect(words.single.id, 'book-1');
    expect(words.single.arabic, 'كِتَابٌ');
    expect(words.single.meaning, 'مَجْمُوعَةٌ مِنَ الصَّفَحَاتِ');
  });

  testWidgets('Arabic-only reader and search never show Russian glosses',
      (tester) async {
    const item = Word('book-1', 'كِتَابٌ', 'مَجْمُوعَةٌ مِنَ الصَّفَحَاتِ',
        [], [], [], [], [], '', [], bookNumber: 1, chapterNumber: 1);
    await tester.pumpWidget(const DictionaryApp(previewWords: [item]));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('all-words-tile')));
    await tester.pumpAndSettle();
    expect(find.text('книга'), findsNothing);
    await tester.tap(find.byType(WordTile).first);
    await tester.pumpAndSettle();
    expect(find.text('Перевод на русский'), findsNothing);
    expect(find.text('Значения слова'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Поиск').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('arabic-search')), 'книга');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(WordTile), findsNothing);
    await tester.enterText(find.byKey(const Key('arabic-search')), 'كتاب');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(WordTile), findsOneWidget);
  });
}
