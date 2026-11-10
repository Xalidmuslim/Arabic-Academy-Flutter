import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bayna_dictionary/core/dictionary_data.dart';
import 'package:bayna_dictionary/ui/dictionary_shell.dart';
import 'package:bayna_dictionary/ui/review_screen.dart';

const entry = Word('w1', 'رَحْمَةٌ', 'مَعْنَى الرَّحْمَةِ',
    ['مَعْنَى آخَرَ'], ['رَأْفَةٌ'], [], [], [], '', [],
    bookNumber: 1, chapterNumber: 1);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({
    'dictionary_animations_enabled_v1': true,
  }));

  test('Dictionary theme has no motion and no ripple irrespective of old preference', () {
    final theme = dictionaryTheme(false);
    expect(theme.splashFactory, NoSplash.splashFactory);
    expect(theme.pageTransitionsTheme.builders[TargetPlatform.android],
        isA<NoMotionPageTransitionsBuilder>());
    expect(theme.pageTransitionsTheme.builders[TargetPlatform.iOS],
        isA<NoMotionPageTransitionsBuilder>());
  });

  testWidgets('Primary tabs have zero-duration selection and no developer overlay',
      (tester) async {
    await tester.pumpWidget(const DictionaryApp(previewWords: [entry]));
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar))
        .animationDuration, Duration.zero);
    await tester.tap(find.byTooltip('Настройки шрифта'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('animation-toggle')), findsNothing);
    expect(find.byKey(const Key('frame-diagnostics-toggle')), findsNothing);
    expect(find.text('Инструменты разработчика'), findsNothing);
    expect(find.byKey(const Key('arabic-font-slider')), findsOneWidget);
    expect(find.text('Резервное копирование'), findsWidgets);
  });

  testWidgets('Reader opens sections instantly, preserving Arabic vowels',
      (tester) async {
    await tester.pumpWidget(const DictionaryApp(previewWords: [entry]));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('all-words-tile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(WordTile).first);
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.text('مَعْنَى الرَّحْمَةِ'), findsWidgets);
    expect(find.text('رَأْفَةٌ'), findsNothing);
    await tester.tap(find.text('Синонимы'));
    await tester.pump();
    expect(find.text('رَأْفَةٌ'), findsWidgets);
    expect(find.text('رَحْمَةٌ'), findsWidgets);
  });

  testWidgets('Recall answer swaps directly without animated widgets',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ReviewScreen(words: [entry], fontSize: 23),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(AnimatedSwitcher), findsNothing);
    await tester.tap(find.text('Показать ответ'));
    await tester.pump();
    expect(find.text('مَعْنَى الرَّحْمَةِ'), findsOneWidget);
    expect(find.byType(AnimatedSwitcher), findsNothing);
  });
}
