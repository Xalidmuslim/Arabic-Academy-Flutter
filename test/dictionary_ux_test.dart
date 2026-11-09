import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bayna_dictionary/main.dart';

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
    expect(find.text('Резервное копирование'), findsOneWidget);
    expect(find.text('Инструменты разработчика'), findsOneWidget);
    expect(find.byKey(const Key('frame-diagnostics-toggle')), findsNothing);
    await tester.tap(find.text('Инструменты разработчика'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('frame-diagnostics-toggle')), findsOneWidget);
  });
}
