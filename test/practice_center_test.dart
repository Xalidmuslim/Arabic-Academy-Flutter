import 'package:arabic_academy/app.dart';
import 'package:arabic_academy/core/adaptive_review.dart';
import 'package:arabic_academy/core/academy_state.dart';
import 'package:arabic_academy/core/practice_generator.dart';
import 'package:arabic_academy/features/learning/practice_center_screen.dart';
import 'package:arabic_academy/features/learning/lesson_screen.dart';
import 'package:arabic_academy/ui/floating_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const catalog = <String, dynamic>{
  'modules': [
    {'id': 'u1', 'title': 'Первый раздел'},
    {'id': 'u2', 'title': 'Второй раздел'},
  ],
  'lessons': [
    {
      'id': 'l1', 'title': 'В классе', 'module_id': 'u1',
      'vocabulary': [
        {'ar': 'كِتَابٌ', 'ru': 'Книга'},
        {'ar': 'قَلَمٌ', 'ru': 'Ручка'},
        {'ar': 'بَابٌ', 'ru': 'Дверь'},
        {'ar': 'بَيْتٌ', 'ru': 'Дом'},
      ],
      'dialogue': [
        {'ar': 'سَلْمَى: هَذَا كِتَابٌ جَدِيدٌ.', 'ru': 'Сальма: Это новая книга.'},
        {'ar': 'مَرْيَمُ: أَيْنَ هَذَا الْكِتَابُ؟', 'ru': 'Марьям: Где эта книга?'},
        {'ar': 'سَلْمَى: فِي الْبَيْتِ كِتَابٌ.', 'ru': 'Сальма: Дома есть книга.'},
        {'ar': 'مَرْيَمُ: هَذَا بَابٌ جَدِيدٌ.', 'ru': 'Марьям: Это новая дверь.'},
      ],
    },
    {
      'id': 'l2', 'title': 'Приветствие', 'module_id': 'u2',
      'vocabulary': [{'ar': 'مَرْحَبًا', 'ru': 'Здравствуйте'}],
      'dialogue': [
        {'ar': 'خَدِيجَة: السَّلَامُ عَلَيْكُمْ.', 'ru': 'Хадиджа: Мир вам.'},
        {'ar': 'آمِنَة: وَعَلَيْكُمُ السَّلَامُ.', 'ru': 'Амина: И вам мир.'},
      ],
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AcademyState> state() async {
    SharedPreferences.setMockInitialValues({'welcome_seen': true});
    final result = AcademyState(await SharedPreferences.getInstance(), catalog);
    await result.initialize();
    return result;
  }

  test('SRS becomes adaptive after lapses while keeping the first day', () {
    final now = DateTime.utc(2026, 10, 14);
    final first = AdaptiveReview.update({}, true, now);
    expect(first['stage'], 1);
    expect(first['interval_days'], 1);
    final missed = AdaptiveReview.update(first, false, now);
    expect(missed['stage'], 0);
    expect(missed['lapses'], 1);
    expect(DateTime.parse(missed['due_at'] as String), now);
    final recovered = AdaptiveReview.update(missed, true, now);
    expect(recovered['successes'], 2);
    expect(AdaptiveReview.mastery(recovered), greaterThan(0));
  });

  test('practice questions are grounded in catalog and exam scoped to module', () async {
    final model = await state();
    addTearDown(model.dispose);
    final words = PracticeGenerator.build(model, PracticeMode.quiz);
    final images = PracticeGenerator.build(model, PracticeMode.illustrations);
    final phrases = PracticeGenerator.build(model, PracticeMode.sentence);
    final cloze = PracticeGenerator.build(model, PracticeMode.missingWord);
    final audio = PracticeGenerator.build(model, PracticeMode.dictation);
    final dialogue = PracticeGenerator.build(model, PracticeMode.dialogue);
    final exam = PracticeGenerator.build(model, PracticeMode.exam,
        moduleId: 'u1');
    expect(words, isNotEmpty);
    expect(images, isNotEmpty);
    expect(phrases, isNotEmpty);
    expect(cloze, isNotEmpty);
    expect(audio, isNotEmpty);
    expect(dialogue, isNotEmpty);
    expect(exam, isNotEmpty);
    expect(exam.every((q) => q.lessonId == 'l1'), isTrue);
    expect(phrases.first.answer, 'هَذَا كِتَابٌ جَدِيدٌ.');
    expect(dialogue.first.reference, 'هَذَا كِتَابٌ جَدِيدٌ.');
    expect(images.first.options, contains(images.first.answer));
    expect(PracticeGenerator.matchesArabic('هذا كتاب جديد', phrases.first.answer),
        isTrue);
    expect(PracticeGenerator.matchesArabic('هدا كتاب جديد', phrases.first.answer),
        isFalse);
    expect(IllustratedTerm.hasIllustration('كِتَابٌ'), isTrue);
    expect(IllustratedTerm.hasIllustration('غَيْرُ مَعْرُوفٍ'), isFalse);
  });

  test('wrong practice answers appear in personal error center and persist', () async {
    final model = await state();
    addTearDown(model.dispose);
    final question = PracticeGenerator.build(model, PracticeMode.quiz).first;
    await model.recordAttempt(lessonId: question.lessonId,
      exerciseId: question.id, answer: 'Не знаю',
      status: 'incorrect', points: 0);
    final mistakes = PracticeGenerator.build(model, PracticeMode.mistakes);
    expect(mistakes.map((q) => q.id), contains(question.id));
    expect(model.attempts.last['status'], 'incorrect');
    final restored = AcademyState(model.prefs, catalog);
    expect(PracticeGenerator.build(restored, PracticeMode.mistakes),
        isNotEmpty);
    restored.dispose();
    await model.recordAttempt(lessonId: question.lessonId,
      exerciseId: question.id, answer: question.answer,
      status: 'correct', points: 1);
    expect(PracticeGenerator.build(model, PracticeMode.mistakes), isEmpty);
  });

  testWidgets('learner practice records wrong answer, shows correct and navigates',
      (tester) async {
    final model = await state();
    addTearDown(model.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PracticeCenterScreen(state: model)),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('practice-mode-quiz')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Викторина'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('practice-answer-0')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('practice-submit-answer')));
    await tester.tap(find.byKey(const ValueKey('practice-submit-answer')));
    await tester.pumpAndSettle();
    expect(model.attempts, hasLength(1));
    expect(find.byKey(const ValueKey('practice-next-question')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picture dictionary uses known illustrations and precise search',
      (tester) async {
    final model = await state();
    addTearDown(model.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PracticeCenterScreen(state: model)),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Словарь с рисунками'));
    await tester.pumpAndSettle();
    expect(find.text('Слова в рисунках'), findsOneWidget);
    expect(find.text('Книга'), findsWidgets);
    await tester.enterText(
      find.byKey(const ValueKey('illustrated-dictionary-search')), 'дверь');
    await tester.pumpAndSettle();
    expect(find.text('Дверь'), findsOneWidget);
    expect(find.text('Книга'), findsNothing);
  });

  testWidgets('Android back returns to previous main tab and then home', (tester) async {
    final model = await state();
    addTearDown(model.dispose);
    await tester.pumpWidget(AcademyApp(state: model));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('study-tab-3')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('study-tab-2')));
    await tester.pump();
    expect(find.text('Практика'), findsWidgets);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Ученица · локальное обучение'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Арабский каждый день'), findsOneWidget);
    expect(find.byType(FloatingStudyNavigation), findsOneWidget);
  });

  testWidgets('Android back inside lesson moves to prior stage before closing', (tester) async {
    final model = await state();
    addTearDown(model.dispose);
    await tester.pumpWidget(MaterialApp(home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
              builder: (_) => LessonScreen(state: model,
                lesson: Map<String, dynamic>.from(
                  catalog['lessons']![0] as Map)),
            )),
            child: const Text('Open lesson'),
          ),
        ),
      ),
    )));
    await tester.tap(find.text('Open lesson'));
    await tester.pumpAndSettle();
    expect(find.text('Введение'), findsWidgets);
    await tester.tap(find.text('Начать урок'));
    await tester.pumpAndSettle();
    expect(find.text('Новые слова'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Цель обучения'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Open lesson'), findsOneWidget);
  });
}
