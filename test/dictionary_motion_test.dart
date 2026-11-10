import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bayna_dictionary/ui/dictionary_shell.dart';
import 'package:bayna_dictionary/ui/review_screen.dart';
import 'package:bayna_dictionary/core/dictionary_data.dart';

const testWord = Word('w1', 'كِتَابٌ', 'مَجْمُوعَةٌ مِنَ الصَّفَحَاتِ',
    [], [], [], [], [], '', []);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Page transitions and touch ripple are always disabled', () {
    final theme = dictionaryTheme(false);
    expect(theme.pageTransitionsTheme.builders[TargetPlatform.android],
        isA<NoMotionPageTransitionsBuilder>());
    expect(theme.pageTransitionsTheme.builders[TargetPlatform.iOS],
        isA<NoMotionPageTransitionsBuilder>());
    expect(theme.splashFactory, NoSplash.splashFactory);
  });

  testWidgets('No animation toggle or FPS overlay, but saved theme works',
      (tester) async {
    await tester.pumpWidget(const DictionaryApp(previewWords: [testWord]));
    await tester.pumpAndSettle();
    expect(find.text('книга'), findsNothing);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar))
        .animationDuration, Duration.zero);
    await tester.tap(find.byTooltip('Настройки шрифта'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('animation-toggle')), findsNothing);
    expect(find.byKey(const Key('frame-diagnostics-toggle')), findsNothing);
    final scroller = find.descendant(
      of: find.byKey(const Key('settings-list')),
      matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(
      find.text('Тёмная'), 160, scrollable: scroller);
    await tester.tap(find.text('Тёмная'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('dictionary_theme_v2'), 'dark');
    expect(find.text('книга'), findsNothing);
  });

  testWidgets('Offline recall reveals Arabic definition instantly',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ReviewScreen(words: [testWord], fontSize: 23),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(AnimatedSwitcher), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.tap(find.text('Показать ответ'));
    await tester.pump();
    expect(find.text('مَجْمُوعَةٌ مِنَ الصَّفَحَاتِ'), findsOneWidget);
    expect(find.text('книга'), findsNothing);
  });
}
