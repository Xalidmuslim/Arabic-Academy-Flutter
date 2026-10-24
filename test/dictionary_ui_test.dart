import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bayna_dictionary/main.dart';
import 'package:bayna_dictionary/ui/dictionary_shell.dart';

Word word(String id) => Word(id, 'كِتَابٌ $id', 'صَفَحَاتٌ نَقْرَؤُهَا',
    const [], const [], const ['اِسْمٌ'], const [], const [], '', const []);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Persistent bottom navigation includes all four destinations',
      (tester) async {
    await tester.pumpWidget(DictionaryApp(previewWords: [word('1')]));
    await tester.pumpAndSettle();
    expect(find.text('Словарь'), findsWidgets);
    expect(find.text('Избранное'), findsWidgets);
    expect(find.text('Закладки'), findsWidgets);
    expect(find.text('Настройки'), findsWidgets);
  });

  testWidgets('Search and scroll persist after reading and returning',
      (tester) async {
    await tester.pumpWidget(DictionaryApp(
      previewWords: [for (var i = 0; i < 45; i++) word('$i')]));
    await tester.pumpAndSettle();
    final scrollingList = find.byKey(const Key('dictionary-scroll-list'));
    expect(scrollingList, findsOneWidget);
    await tester.drag(scrollingList, const Offset(0, -900));
    await tester.pumpAndSettle();
    final controllerBefore = tester.widget<CustomScrollView>(scrollingList)
        .controller!;
    final offsetBefore = controllerBefore.offset;
    expect(offsetBefore, greaterThan(0));
    await tester.tap(find.byType(WordTile).first);
    await tester.pumpAndSettle();
    expect(find.text('Значения слова'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    final controllerAfter = tester.widget<CustomScrollView>(scrollingList)
        .controller!;
    expect(controllerAfter.offset, closeTo(offsetBefore, 1));
  });

  testWidgets('Home system back does not close dictionary', (tester) async {
    await tester.pumpWidget(DictionaryApp(previewWords: [word('1')]));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('АРАБО-АРАБСКИЙ СЛОВАРЬ'), findsOneWidget);
  });

  testWidgets('Reading settings are persisted', (tester) async {
    await tester.pumpWidget(DictionaryApp(previewWords: [word('1')]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Настройки').last);
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsOneWidget);
    await tester.tap(find.text('Тёмная'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('dictionary_theme_v2'), 'dark');
  });
  testWidgets('Family chapter filter shows only its entries', (tester) async {
    final first = Word('only1', 'تَحِيَّةٌ', 'كَلِمَةٌ لِلسَّلَامِ',
        const [], const [], const ['اِسْمٌ'], const [], const [], '',
        const [], bookNumber: 1, chapterNumber: 1, chapterOrder: 1);
    final second = Word('only2', 'وَالِدٌ', 'أَبٌ لِطِفْلٍ',
        const [], const [], const ['اِسْمٌ'], const [], const [], '',
        const [], bookNumber: 1, chapterNumber: 2, chapterOrder: 1);
    await tester.pumpWidget(DictionaryApp(previewWords: [first, second]));
    await tester.pumpAndSettle();
    expect(find.byType(WordTile), findsNWidgets(2));
    await tester.tap(find.text('Книга 1 · Тема 2').first);
    await tester.pumpAndSettle();
    expect(find.byType(WordTile), findsOneWidget);
    expect(find.text('وَالِدٌ'), findsWidgets);
  });

}
