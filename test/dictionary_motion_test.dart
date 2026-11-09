import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bayna_dictionary/ui/dictionary_shell.dart';
import 'package:bayna_dictionary/ui/review_screen.dart';
import 'package:bayna_dictionary/core/dictionary_data.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Motion-free theme uses instant Android page transitions', () {
    final theme = dictionaryTheme(false, animationsEnabled: false);
    expect(theme.pageTransitionsTheme.builders[TargetPlatform.android],
        isA<NoMotionPageTransitionsBuilder>());
    expect(theme.splashFactory, NoSplash.splashFactory);
  });

  testWidgets('Animation toggle is persisted and keeps Arabic dictionary intact',
      (tester) async {
    const words = [
      Word('w1', 'كِتَابٌ', 'مَجْمُوعَةٌ مِنَ الصَّفَحَاتِ',
          [], [], [], [], [], '', [], russian: 'книга'),
    ];
    await tester.pumpWidget(const DictionaryApp(previewWords: words));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Настройки шрифта'));
    await tester.pumpAndSettle();
    final target = find.byKey(const Key('animation-toggle'));
    final scrollable = find.descendant(
      of: find.byKey(const Key('settings-list')),
      matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(target, 180, scrollable: scrollable);
    expect(tester.widget<SwitchListTile>(target).value, isTrue);
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(target).value, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('dictionary_animations_enabled_v1'), isFalse);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.widget<DictionaryNav>(find.byType(DictionaryNav))
        .animationsEnabled, isFalse);
    await tester.tap(find.byKey(const Key('all-words-tile')));
    await tester.pumpAndSettle();
    expect(find.text('كِتَابٌ'), findsWidgets);
    expect(find.text('книга'), findsNothing);
  });

  testWidgets('Recall mode only reveals the original Arabic definition',
      (tester) async {
    const words = [
      Word('w1', 'كِتَابٌ', 'مَجْمُوعَةٌ مِنَ الصَّفَحَاتِ',
          [], [], [], [], [], '', [], russian: 'книга'),
    ];
    await tester.pumpWidget(const MaterialApp(
      home: ReviewScreen(words: words, fontSize: 23, animationsEnabled: false),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Показать ответ'));
    await tester.pumpAndSettle();
    expect(find.text('مَجْمُوعَةٌ مِنَ الصَّفَحَاتِ'), findsOneWidget);
    expect(find.text('книга'), findsNothing);
    expect(tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher))
        .duration, Duration.zero);
  });
}
