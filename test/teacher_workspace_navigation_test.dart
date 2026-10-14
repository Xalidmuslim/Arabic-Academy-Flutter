import 'package:arabic_academy/app.dart';
import 'package:arabic_academy/core/academy_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('teacher demo uses its own floating navigation and no student lessons', (tester) async {
    SharedPreferences.setMockInitialValues({
      'welcome_seen': true,
      'demo_role_teacher': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final state = AcademyState(prefs, const {
      'modules': <dynamic>[], 'lessons': <dynamic>[],
    });
    addTearDown(state.dispose);
    await tester.pumpWidget(AcademyApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('Кабинет учительницы'), findsWidgets);
    final nav = find.byKey(const ValueKey('floating-study-navigation'));
    expect(nav, findsOneWidget);
    expect(find.descendant(of: nav, matching: find.text('Группы')), findsOneWidget);
    expect(find.descendant(of: nav, matching: find.text('Работы')), findsOneWidget);
    expect(find.descendant(of: nav, matching: find.text('Меню')), findsOneWidget);
    expect(find.descendant(of: nav, matching: find.text('Уроки')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('study-tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('Группа А · Начальный'), findsWidgets);
    expect(find.text('Карточки слов'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('study-tab-2')));
    await tester.pumpAndSettle();
    expect(find.text('Работы учениц'), findsOneWidget);
    expect(find.textContaining('Знакомство на арабском'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('study-tab-3')));
    await tester.pumpAndSettle();
    expect(find.text('Инструменты учительницы'), findsOneWidget);
    expect(find.text('Карточки слов'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('teacher-settings-entry')), 220,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Настройки'), findsWidgets);
    expect(find.text('Уроки'), findsNothing);
  });

  testWidgets('student navigation remains unchanged when not in teacher role',
      (tester) async {
    SharedPreferences.setMockInitialValues({'welcome_seen': true});
    final prefs = await SharedPreferences.getInstance();
    final state = AcademyState(prefs, const {
      'modules': <dynamic>[], 'lessons': <dynamic>[],
    });
    addTearDown(state.dispose);
    await tester.pumpWidget(AcademyApp(state: state));
    await tester.pumpAndSettle();

    final nav = find.byKey(const ValueKey('floating-study-navigation'));
    expect(find.descendant(of: nav, matching: find.text('Уроки')), findsOneWidget);
    expect(find.descendant(of: nav, matching: find.text('Меню')), findsNothing);
  });
}
