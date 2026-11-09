import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bayna_dictionary/ui/dictionary_shell.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Main navigation has three destinations and settings are a route',
      (tester) async {
    await tester.pumpWidget(const DictionaryApp(previewWords: []));
    await tester.pumpAndSettle();
    expect(find.text('Словарь'), findsOneWidget);
    expect(find.text('Поиск'), findsOneWidget);
    expect(find.text('Сохранённое'), findsOneWidget);
    await tester.tap(find.byTooltip('Настройки шрифта'));
    await tester.pumpAndSettle();
    expect(find.text('Русский шрифт'), findsOneWidget);
    final settingsScroll = find.descendant(
      of: find.byKey(const Key('settings-list')),
      matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(
      find.text('Резервное копирование'), 250, scrollable: settingsScroll);
    await tester.pumpAndSettle();
    expect(find.text('Резервное копирование'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Инструменты разработчика'), 250,
      scrollable: settingsScroll);
    await tester.pumpAndSettle();
    expect(find.text('Инструменты разработчика'), findsOneWidget);
    expect(find.byKey(const Key('frame-diagnostics-toggle')), findsNothing);
    await tester.tap(find.text('Инструменты разработчика'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('frame-diagnostics-toggle')), 250,
      scrollable: settingsScroll);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('frame-diagnostics-toggle')), findsOneWidget);
  });
}
