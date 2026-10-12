import 'package:arabic_academy/core/academy_state.dart';
import 'package:arabic_academy/features/learning/lesson_screen.dart';
import 'package:arabic_academy/ui/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const lesson = <String, dynamic>{
    'id': 'l1',
    'title': 'Приветствие',
    'title_ar': 'مَرْحَبًا',
    'goal': 'Представиться',
    'vocabulary': <dynamic>[],
    'dialogue': <dynamic>[],
    'grammar': 'Правило',
    'question': 'Выберите приветствие',
    'options': ['Правильно', 'Неверно'],
    'correct': 0,
    'homework': 'Напишите ответ',
  };
  Future<AcademyState> state() async {
    SharedPreferences.setMockInitialValues({});
    return AcademyState(await SharedPreferences.getInstance(), {
      'modules': [],
      'lessons': [lesson],
    });
  }

  testWidgets('Lesson exposes all six interactive learning stages', (
    tester,
  ) async {
    final data = await state();
    await tester.pumpWidget(
      MaterialApp(
        theme: DesignTokens.theme(),
        home: LessonScreen(state: data, lesson: lesson),
      ),
    );
    for (final name in [
      'Введение',
      'Лексика',
      'Диалог',
      'Грамматика',
      'Практика',
      'Проверка',
    ]) {
      expect(find.text(name), findsWidgets);
    }
    await tester.tap(find.text('Грамматика').first);
    await tester.pumpAndSettle();
    expect(find.text('Правило'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Wrong answer is saved and does not complete the lesson', (
    tester,
  ) async {
    final data = await state();
    await tester.pumpWidget(
      MaterialApp(
        theme: DesignTokens.theme(),
        home: LessonScreen(state: data, lesson: lesson, initialTab: 5),
      ),
    );
    await tester.tap(find.text('Неверно').first);
    await tester.pump();
    await tester.tap(find.text('Проверить').first);
    await tester.pumpAndSettle();
    expect(data.completed, isEmpty);
    expect(data.attempts, isNotEmpty);
    expect(data.attempts.first['status'], 'incorrect');
    expect(tester.takeException(), isNull);
  });
}
