import 'package:arabic_academy/core/academy_state.dart';
import 'package:arabic_academy/features/learning/progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('progress lesson list is built lazily for a long course',
      (tester) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final state = AcademyState(await SharedPreferences.getInstance(), {
      'modules': <dynamic>[],
      'lessons': <dynamic>[
        for (var i = 0; i < 140; i++)
          <String, dynamic>{
            'id': 'progress-lesson-$i',
            'title': 'Урок $i',
            'vocabulary': <dynamic>[],
            'dialogue': <dynamic>[],
          },
      ],
    });
    addTearDown(state.dispose);
    await state.initialize();

    await tester.pumpWidget(MaterialApp(
      home: LearnerProgressScreen(state: state),
    ));
    await tester.pumpAndSettle();

    final lazy = tester.widgetList<SliverList>(find.byType(SliverList))
        .where((sliver) => sliver.delegate is SliverChildBuilderDelegate);
    expect(lazy, isNotEmpty,
      reason: 'Progress must not instantiate 140 three-dimensional cards upfront');
    expect(find.text('Урок 139'), findsNothing);
    expect(find.text('Базовый уровень 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
