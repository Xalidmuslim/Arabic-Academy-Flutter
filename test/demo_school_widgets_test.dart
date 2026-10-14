import 'package:arabic_academy/app.dart';
import 'package:arabic_academy/core/academy_state.dart';
import 'package:arabic_academy/features/teacher/demo_school_store.dart';
import 'package:arabic_academy/features/teacher/demo_student_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('demo role selector opens teacher groups and personal assignment', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'welcome_seen': true,
      'demo_role_teacher': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final state = AcademyState(prefs, const {
      'modules': <dynamic>[],
      'lessons': <dynamic>[],
    });
    addTearDown(state.dispose);
    await tester.pumpWidget(AcademyApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('Кабинет учительницы'), findsOneWidget);
    final group = find.text('Группа А · Начальный').first;
    await tester.ensureVisible(group);
    await tester.tap(group);
    await tester.pumpAndSettle();
    expect(find.text('Амина'), findsOneWidget);
    await tester.tap(find.text('Амина').first);
    await tester.pumpAndSettle();
    final assign = find.text('Назначить индивидуальное задание');
    await tester.ensureVisible(assign);
    await tester.tap(assign);
    await tester.pumpAndSettle();
    expect(find.text('Новое домашнее задание'), findsOneWidget);
  });

  testWidgets('learner submits demo homework and sees sent status', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final school = DemoSchoolStore(prefs);
    final state = AcademyState(prefs, const {
      'modules': <dynamic>[],
      'lessons': <dynamic>[],
    });
    addTearDown(school.dispose);
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(
      home: DemoStudentSchoolScreen(school: school, learning: state),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Знакомство на арабском'), findsOneWidget);
    await tester.tap(find.text('Выполнить и отправить'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last,
        'اِسْمِي أَمِينَةُ. أَنَا طَالِبَةٌ.');
    await tester.tap(find.text('Отправить'));
    await tester.pumpAndSettle();
    expect(school.submissionFor('a1', 's1')?['status'], 'submitted');
    expect(find.text('Отправлено · ожидает проверки'), findsOneWidget);
  });
}
