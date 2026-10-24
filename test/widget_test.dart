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
    addTearDown(state.dispose);
    debugPrint('welcome test: mount');
    await tester.pumpWidget(AcademyApp(state: state));
    expect(find.text('Начать обучение'), findsOneWidget);
    debugPrint('welcome test: tap start');
    await tester.tap(find.text('Начать обучение'));
    debugPrint('welcome test: settle');
    await tester.pumpAndSettle();
    debugPrint('welcome test: verify dashboard');
    expect(find.text('Арабский каждый день'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-switch-role')), findsOneWidget);
    expect(find.byIcon(Icons.switch_account_outlined), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
