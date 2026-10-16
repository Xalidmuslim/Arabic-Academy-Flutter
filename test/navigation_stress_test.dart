import 'package:arabic_academy/app.dart';
import 'package:arabic_academy/core/academy_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('20 repeated home/textbook/practice/profile transitions '
      'preserve user progress and installed navigation', (tester) async {
    SharedPreferences.setMockInitialValues({'welcome_seen': true});
    final state = AcademyState(
      await SharedPreferences.getInstance(),
      <String, dynamic>{
        'modules': <dynamic>[],
        'lessons': <dynamic>[],
      },
    );
    addTearDown(state.dispose);
    await state.initialize();
    await state.visitLesson('saved-lesson');

    await tester.pumpWidget(AcademyApp(state: state));
    await tester.pumpAndSettle();

    for (var cycle = 0; cycle < 20; cycle++) {
      final target = 1 + cycle % 3;
      await tester.tap(find.byKey(ValueKey('study-tab-$target')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('study-tab-0')));
      await tester.pumpAndSettle();
      expect(find.text('Арабский каждый день'), findsOneWidget);
    }
    expect(state.lastLessonId, 'saved-lesson');
    expect(find.byKey(const ValueKey('floating-study-navigation')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
