import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arabic_academy/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Student dashboard is available without a paid account in demo', (
    tester,
  ) async {
    // FakeAsync repeatedly drains Timer.run while a route animation is active.
    // The real scheduler defers Priority.idle tasks to a later event-loop turn;
    // a fake clock cannot reach that next frame if the idle task keeps retrying.
    // Let queued work run in these navigation tests; the preloader's own tests
    // separately verify production deferral and scroll pausing.
    final schedulingBefore = tester.binding.schedulingStrategy;
    tester.binding.schedulingStrategy =
        ({required priority, required scheduler}) => true;
    addTearDown(() => tester.binding.schedulingStrategy = schedulingBefore);
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
    await tester.pumpWidget(AcademyApp(state: state));
    expect(find.text('Начать обучение'), findsOneWidget);
    await tester.tap(find.text('Начать обучение'));
    await tester.pumpAndSettle();
    expect(find.text('Арабский каждый день'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-switch-role')), findsOneWidget);
    expect(find.byIcon(Icons.switch_account_outlined), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
