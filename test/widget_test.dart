import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arabic_academy/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Student dashboard is available without a paid account in demo', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = AcademyState(prefs, <String, dynamic>{
      'modules': <dynamic>[],
      'lessons': <dynamic>[
        <String, dynamic>{
          'id': 'demo',
          'title': 'Проверка',
          'title_ar': 'تَجْرِبَةٌ',
          'goal': 'Тест',
          'dialogue': <dynamic>[],
          'vocabulary': <dynamic>[],
          'grammar': 'Тест',
          'question': 'Тест?',
          'options': <dynamic>['А', 'Б'],
          'correct': 0,
          'homework': 'Тест',
        },
      ],
    });
    await tester.pumpWidget(AcademyApp(state: state));
    expect(find.text('Начать обучение'), findsOneWidget);
    await tester.tap(find.text('Начать обучение'));
    await tester.pumpAndSettle();
    expect(find.text('Арабский каждый день'), findsOneWidget);
    expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);
  });
}
