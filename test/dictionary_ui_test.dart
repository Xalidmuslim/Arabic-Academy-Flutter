import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bayna_dictionary/main.dart';
import 'package:bayna_dictionary/ui/dictionary_shell.dart';

Word word(String id) => Word(id, 'كِتَابٌ $id', 'صَفَحَاتٌ نَقْرَؤُهَا',
    const [], const [], const ['اِسْمٌ'], const [], const [], '', const []);

Future<void> scrollToSetting(WidgetTester tester, Finder target) async {
  final settingsScrollable = find.descendant(
    of: find.byKey(const Key('settings-list')),
    matching: find.byType(Scrollable)).first;
  await tester.scrollUntilVisible(target, 200, scrollable: settingsScrollable);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Persistent bottom navigation includes three primary destinations',
      (tester) async {
    await tester.pumpWidget(DictionaryApp(previewWords: [word('1')]));
    await tester.pumpAndSettle();
    expect(find.text('Словарь'), findsWidgets);
    expect(find.text('Поиск'), findsWidgets);
    expect(find.text('Сохранённое'), findsWidgets);
    expect(find.byTooltip('Настройки шрифта'), findsOneWidget);
  });

  testWidgets('Search and scroll persist after reading and returning',
      (tester) async {
    await tester.pumpWidget(DictionaryApp(
      previewWords: [for (var i = 0; i < 45; i++) word('$i')]));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('all-words-tile')));
    await tester.pumpAndSettle();
    final scrollingList = find.byKey(const Key('dictionary-scroll-list'));
    expect(scrollingList, findsOneWidget);
    await tester.drag(scrollingList, const Offset(0, -900));
    await tester.pumpAndSettle();
    final controllerBefore = tester.widget<CustomScrollView>(scrollingList)
        .controller!;
    final offsetBefore = controllerBefore.offset;
    expect(offsetBefore, greaterThan(0));
    // Cache prebuilds offscreen tiles. Tap a visible, hit-testable one.
    await tester.tap(find.byType(WordTile).hitTestable().first);
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
    await tester.tap(find.byTooltip('Настройки шрифта'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('arabic-font-slider')), findsOneWidget);
    expect(find.byKey(const Key('russian-font-slider')), findsNothing);
    await scrollToSetting(tester, find.text('Тёмная'));
    await tester.tap(find.text('Тёмная'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('dictionary_theme_v2'), 'dark');
  });
  testWidgets('Family topic opens only its words', (tester) async {
    final first = Word('only1', 'تَحِيَّةٌ', 'كَلِمَةٌ لِلسَّلَامِ',
        const [], const [], const ['اِسْمٌ'], const [], const [], '',
        const [], bookNumber: 1, chapterNumber: 1, chapterOrder: 1);
    final second = Word('only2', 'وَالِدٌ', 'أَبٌ لِطِفْلٍ',
        const [], const [], const ['اِسْمٌ'], const [], const [], '',
        const [], bookNumber: 1, chapterNumber: 2, chapterOrder: 1);
    await tester.pumpWidget(DictionaryApp(previewWords: [first, second]));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('volume-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chapter-1-2')));
    await tester.pumpAndSettle();
    expect(find.byType(WordTile), findsOneWidget);
    expect(find.text('وَالِدٌ'), findsWidgets);
  });

  testWidgets('Housing topic opens only its words', (tester) async {
    final family = Word('family', 'وَالِدٌ', 'أَبٌ',
      const [], const [], const ['اِسْمٌ'], const [], const [], '',
      const [], bookNumber: 1, chapterNumber: 2, chapterOrder: 1);
    final housing = Word('housing', 'شَقَّةٌ', 'جُزْءٌ مِنْ مَبْنًى',
      const [], const [], const ['اِسْمٌ'], const [], const [], '',
      const [], bookNumber: 1, chapterNumber: 3, chapterOrder: 5);
    await tester.pumpWidget(DictionaryApp(previewWords: [family, housing]));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('volume-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chapter-1-3')));
    await tester.pumpAndSettle();
    expect(find.byType(WordTile), findsOneWidget);
    expect(find.text('شَقَّةٌ'), findsWidgets);
  });

  testWidgets('A modern chapter-reference-only word displays its chapter tag',
      (tester) async {
    final modern = Word('modern', 'كِتَابٌ', 'مَجْمُوعَةٌ مِنَ الصَّفَحَاتِ',
      const [], const [], const ['اِسْمٌ'], const [], const [], '', const [],
      bookReferences: const [
        {'book': 1, 'chapter': 3, 'index': 7},
      ]);
    await tester.pumpWidget(DictionaryApp(previewWords: [modern]));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('all-words-tile')));
    await tester.pumpAndSettle();
    expect(find.text('كِتَابٌ'), findsWidgets);
    expect(find.descendant(
      of: find.byType(WordTile),
      matching: find.text('Том 1 · Тема 3'),
    ), findsOneWidget);
  });

  testWidgets('Volume and topic cards fit narrow phones', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final entry = Word('compact', 'كِتَابٌ', 'مَعْنًى',
        const [], const [], const [], const [], const [], '', const [],
        bookNumber: 1, chapterNumber: 1);
    await tester.pumpWidget(DictionaryApp(previewWords: [entry]));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('volume-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('volume-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chapter-1-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic meaning is right aligned and has room for three lines',
      (tester) async {
    const explanation =
        'مُعَامَلَةٌ تَجْمَعُ بَيْنَ الْإِحْسَانِ وَالتَّعَاوُنِ وَالتَّرَاحُمِ '
        'وَتَتَضَمَّنُ مَعَانِيَ مُتَعَدِّدَةً فِي الْحَيَاةِ الْيَوْمِيَّةِ.';
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final item = Word('description', 'رَحْمَةٌ', explanation,
        const [], const [], const [], const [], const [], '', const []);
    await tester.pumpWidget(DictionaryApp(previewWords: [item]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('all-words-tile')));
    await tester.pumpAndSettle();
    final meaning = tester.widget<Text>(find.descendant(
      of: find.byType(WordTile),
      matching: find.text(explanation),
    ));
    expect(meaning.maxLines, 3);
    expect(meaning.textDirection, TextDirection.rtl);
    expect(meaning.textAlign, TextAlign.right);
    expect(tester.takeException(), isNull);
  });


  testWidgets('Large dictionary lazily builds only nearby tiles',
      (tester) async {
    await tester.pumpWidget(DictionaryApp(
      previewWords: [for (var i = 0; i < 1200; i++) word('$i')]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('all-words-tile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dictionary-scroll-list')), findsOneWidget);
    expect(find.byType(WordTile).evaluate().length, lessThan(30));
  });


  testWidgets('No performance overlay or debug render switching; Arabic vowels remain',
      (tester) async {
    const entry = Word(
      'original', 'رَحْمَةٌ', 'خَيْرٌ وَرَحْمَةٌ',
      [], [], [], [], [], '', [], bookNumber: 1, chapterNumber: 1,
    );
    await tester.pumpWidget(const DictionaryApp(previewWords: [entry]));
    await tester.pumpAndSettle();
    expect(find.textContaining('Экран:'), findsNothing);
    await tester.tap(find.byKey(const Key('all-words-tile')));
    await tester.pumpAndSettle();
    expect(find.text('رَحْمَةٌ'), findsWidgets);
    await tester.tap(find.byTooltip('Настройки шрифта'));
    await tester.pumpAndSettle();
    expect(find.text('Инструменты разработчика'), findsNothing);
    expect(find.byKey(const Key('render-mode-no-vowels')), findsNothing);
    expect(find.byKey(const Key('frame-diagnostics-toggle')), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(WordTile).first);
    await tester.pumpAndSettle();
    expect(find.text('رَحْمَةٌ'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

}
