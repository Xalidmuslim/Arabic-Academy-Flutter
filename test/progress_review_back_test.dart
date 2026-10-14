import 'package:arabic_academy/core/academy_state.dart';
import 'package:arabic_academy/features/learning/lesson_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Back from progress mistake review returns to progress, not dialogue',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AcademyState(
      await SharedPreferences.getInstance(),
      <String, dynamic>{
        'modules': <dynamic>[],
        'lessons': <Map<String, dynamic>>[
          {
            'id': 'l1', 'title': 'Диалог 1',
            'dialogue': <Map<String, String>>[
              {'ar': 'السَّلَامُ عَلَيْكُمْ', 'ru': 'Мир вам'},
            ],
            'vocabulary': <Map<String, String>>[],
          },
        ],
      },
    );
    await state.initialize();
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) => Scaffold(
        body: Center(child: FilledButton(
          onPressed: () => Navigator.push<void>(context,
            MaterialPageRoute(builder: (_) => LessonScreen(
              state: state,
              lesson: state.allLessons.first,
              initialTab: 4,
              returnToProgressOnBack: true,
            ))),
          child: const Text('Мой прогресс'),
        )),
      )),
    ));
    await tester.tap(find.text('Мой прогресс'));
    await tester.pumpAndSettle();
    expect(find.text('Диалог 1'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Мой прогресс'), findsOneWidget);
    expect(find.text('Диалог 1'), findsNothing);
  });
}
