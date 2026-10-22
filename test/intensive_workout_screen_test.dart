import 'package:arabic_academy/core/academy_state.dart';
import 'package:arabic_academy/core/practice_generator.dart';
import 'package:arabic_academy/features/learning/practice_center_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Intensive matching accepts actual pairs and records one attempt',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AcademyState(
      await SharedPreferences.getInstance(),
      <String, dynamic>{
        'modules': <dynamic>[],
        'lessons': <dynamic>[
          {
            'id': 'study',
            'title': 'Учебные слова',
            'vocabulary': [
              {'ar': 'كِتَابٌ', 'ru': 'Книга'},
              {'ar': 'قَلَمٌ', 'ru': 'Ручка'},
              {'ar': 'بَيْتٌ', 'ru': 'Дом'},
              {'ar': 'بَابٌ', 'ru': 'Дверь'},
            ],
            'dialogue': [
              {'ar': 'عُمَرُ: هَذَا كِتَابٌ جَدِيدٌ.',
               'ru': 'Это новая книга.'},
              {'ar': 'حَامِدٌ: هَذَا قَلَمٌ جَمِيلٌ.',
               'ru': 'Это красивая ручка.'},
              {'ar': 'عُمَرُ: هَلْ هَذَا بَيْتٌ كَبِيرٌ؟',
               'ru': 'Это большой дом?'},
            ],
          },
        ],
      },
    );
    addTearDown(state.dispose);
    await state.initialize();
    await tester.pumpWidget(MaterialApp(
      home: PracticeSessionScreen(
        state: state, mode: PracticeMode.intensive, lessonId: 'study'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Соедините арабские слова с переводами'), findsOneWidget);

    for (var i = 0; i < 4; i++) {
      final arabic = find.byKey(ValueKey('intensive-arabic-$i'));
      await tester.ensureVisible(arabic);
      await tester.tap(arabic);
      final russian = find.byKey(ValueKey('intensive-translation-$i'));
      await tester.ensureVisible(russian);
      await tester.tap(russian);
      await tester.pump();
    }
    final check = find.byKey(const ValueKey('practice-submit-answer'));
    await tester.ensureVisible(check);
    await tester.tap(check);
    await tester.pumpAndSettle();
    expect(find.text('Верно! Результат сохранён.'), findsOneWidget);
    expect(state.attempts.where(
      (a) => a['exercise_id'] == 'practice:matching:study:0'), hasLength(1));
    final next = find.byKey(const ValueKey('practice-next-question'));
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.textContaining('Вопрос 2 из'), findsOneWidget);
  });
}
