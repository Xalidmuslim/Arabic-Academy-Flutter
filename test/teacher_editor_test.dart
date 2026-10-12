import 'package:arabic_academy/core/academy_state.dart';
import 'package:arabic_academy/features/teacher/teacher_editor.dart';
import 'package:arabic_academy/ui/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Teacher content builder can create a dialogue, word and exercise without JSON',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final data = AcademyState(await SharedPreferences.getInstance(), {
        'modules': [],
        'lessons': [],
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: DesignTokens.theme(),
          home: TeacherEditor(state: data),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Содержание урока'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Содержание урока'), findsOneWidget);
      await tester.ensureVisible(find.text('Добавить реплику'));
      await tester.tap(find.text('Добавить реплику'));
      await tester.pumpAndSettle();
      expect(find.text('Арабский текст'), findsOneWidget);
      expect(find.text('Русский перевод'), findsOneWidget);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Добавить упражнение'));
      await tester.tap(find.text('Добавить упражнение'));
      await tester.pumpAndSettle();
      expect(find.text('Тип задания'), findsOneWidget);
      expect(find.text('Вопрос или инструкция'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
