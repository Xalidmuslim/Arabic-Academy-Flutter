import 'package:arabic_academy/core/academy_state.dart';
import 'package:arabic_academy/features/learning/demo_showcase_screen.dart';
import 'package:arabic_academy/features/teacher/demo_school_store.dart';
import 'package:arabic_academy/features/teacher/teacher_word_card_studio_screen.dart';
import 'package:arabic_academy/services/backend_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('customer showcase offers local features without checkout', (
      tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final learning = AcademyState(prefs, {
      'modules': <dynamic>[], 'lessons': <dynamic>[],
    });
    await learning.initialize();
    final school = DemoSchoolStore(prefs);
    final backend = BackendService();
    addTearDown(learning.dispose);
    addTearDown(school.dispose);
    addTearDown(backend.dispose);

    await tester.pumpWidget(MaterialApp(home: DemoShowcaseScreen(
      learning: learning, school: school, backend: backend,
    )));
    expect(find.text('Демонстрация академии'), findsOneWidget);
    expect(find.byKey(const ValueKey('showcase-teacher-dashboard')), findsOneWidget);
    expect(find.byKey(const ValueKey('showcase-word-cards')), findsOneWidget);
  });

  testWidgets('teacher word card studio offers add and empty states', (
      tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final learning = AcademyState(prefs, {
      'modules': <dynamic>[], 'lessons': <dynamic>[],
    });
    await learning.initialize();
    addTearDown(learning.dispose);
    await tester.pumpWidget(MaterialApp(home:
      TeacherWordCardStudioScreen(state: learning)));
    expect(find.byKey(const ValueKey('word-card-add')), findsOneWidget);
    expect(find.text('Добавьте первое слово'), findsOneWidget);
  });
}
