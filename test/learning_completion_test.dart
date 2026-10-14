import 'package:arabic_academy/core/academy_state.dart';
import 'package:arabic_academy/core/adaptive_review.dart';
import 'package:arabic_academy/core/grammar_guidance.dart';
import 'package:arabic_academy/core/practice_feedback.dart';
import 'package:arabic_academy/core/practice_generator.dart';
import 'package:arabic_academy/core/study_calendar.dart';
import 'package:arabic_academy/core/trace_feedback.dart';
import 'package:arabic_academy/features/learning/dialogue_journey_screen.dart';
import 'package:arabic_academy/features/learning/study_calendar_screen.dart';
import 'package:arabic_academy/features/learning/smart_reader_screen.dart';
import 'package:arabic_academy/features/learning/pronunciation_comparison_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _catalog = <String, dynamic>{
  'modules': [
    {'id': 'u1', 'title': 'Первый раздел'},
  ],
  'lessons': [
    {
      'id': 'l1', 'module_id': 'u1', 'title': 'Предметы класса',
      'vocabulary': [
        {'ar': 'كِتَابٌ', 'ru': 'Книга'},
        {'ar': 'قَلَمٌ', 'ru': 'Ручка'},
      ],
      'dialogue': [
        {'ar': 'سَلْمَى: هَذَا كِتَابٌ.', 'ru': 'Это книга.'},
        {'ar': 'مَرْيَمُ: أَيْنَ الْكِتَابُ؟', 'ru': 'Где книга?'},
        {'ar': 'سَلْمَى: فِي الْبَيْتِ.', 'ru': 'В доме.'},
        {'ar': 'مَرْيَمُ: أَنَا طَالِبَةٌ.', 'ru': 'Я ученица.'},
      ],
    },
    {
      'id': 'l2', 'module_id': 'u1', 'title': 'Другой диалог',
      'dialogue': [
        {'ar': 'سَلْمَى: أَنَا طَالِبَةٌ.', 'ru': 'Я ученица.'},
        {'ar': 'مَرْيَمُ: هَذَا قَلَمٌ.', 'ru': 'Это ручка.'},
      ],
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AcademyState> learning() async {
    SharedPreferences.setMockInitialValues({});
    final result = AcademyState(
      await SharedPreferences.getInstance(), _catalog,
    );
    await result.initialize();
    return result;
  }

  test('spaced repetition penalizes hesitant recall without erasing history',
      () async {
    final now = DateTime.utc(2026, 10, 15);
    var stable = <String, dynamic>{};
    var hesitant = <String, dynamic>{};
    for (var stage = 0; stage < 4; stage++) {
      stable = AdaptiveReview.update(stable, true, now,
        responseMillis: 1800, confidence: 5);
      hesitant = AdaptiveReview.update(hesitant, true, now,
        responseMillis: 18000, confidence: 2);
    }
    expect(stable['stage'], 4);
    expect(hesitant['stage'], 4);
    expect(stable['interval_days'], greaterThan(
      hesitant['interval_days'] as int));
    expect(AdaptiveReview.predictedRecall(stable,
      now.add(const Duration(days: 1))), inInclusiveRange(0, 1));
    final forgotten = AdaptiveReview.update(stable, false, now,
      responseMillis: 22000, confidence: 0);
    expect(forgotten['lapses'], 1);
    expect(forgotten['stage'], 0);
    expect(forgotten['retrieval_quality'], 'forgotten');
  });

  test('study calendar stays local, survives reload, never schedules past',
      () async {
    final state = await learning();
    addTearDown(state.dispose);
    final plan = StudyCalendarPlan.defaultPlan.copyWith(
      weekdays: {3}, hour: 18, minute: 25,
      notifyMinutesBefore: 60,
      notificationsEnabled: true,
    );
    await state.setSetting('study_calendar_v1', plan.toJson());
    final restored = AcademyState(state.prefs, _catalog);
    addTearDown(restored.dispose);
    final loaded = StudyCalendarPlan.fromState(restored);
    expect(loaded.weekdays, {3});
    expect(loaded.notificationsEnabled, true);
    final now = DateTime(2026, 10, 14, 10);
    final sessions = loaded.nextSessions(now: now, count: 3);
    expect(sessions, hasLength(3));
    expect(sessions.first.hour, 18);
    expect(sessions.first.minute, 25);
    expect(sessions.every((s) => s.weekday == 3), true);
    final notifications = loaded.nextNotifications(now: now);
    expect(notifications, isNotEmpty);
    expect(notifications.every((at) => at.isAfter(now)), true);
    expect(notifications.first, sessions.first.subtract(
        const Duration(hours: 1)));
  });

  test('grammar feedback uses only recognized Arabic editorial constructions',
      () {
    const q = PracticeQuestion(
      id: 'p1', lessonId: 'l1', lessonTitle: 'Предметы',
      mode: PracticeMode.sentence, prompt: 'Соберите фразу',
      answer: 'هَذَا كِتَابٌ.',
      reference: 'هَذَا كِتَابٌ.',
    );
    final hint = GrammarGuidance.relatedTo(q);
    expect(hint, isNotNull);
    expect(hint!.title, contains('Указательные'));
    final text = PracticeFeedback.explain(q, 'هَذِهِ كِتَابٌ',
      correct: false);
    expect(text, contains('Грамматическая справка'));
    expect(text, contains('هَذِهِ'));
    const unrelated = PracticeQuestion(
      id: 'u', lessonId: 'l1', lessonTitle: 'Урок',
      mode: PracticeMode.sentence, prompt: 'Собери',
      answer: 'كِتَابٌ جَدِيدٌ.',
    );
    expect(GrammarGuidance.relatedTo(unrelated), isNull);
  });

  testWidgets('Arabic letter tracing feedback remains a qualified hint',
      (tester) async {
    // Dart:ui toImage completes on the raster thread; with FakeAsync
    // it never resolves until runAsync releases the test clock.
    final output = await tester.runAsync(() => TraceEvaluator.evaluate(
      glyph: 'ب',
      strokes: [
        [const Offset(115, 140), const Offset(155, 140)],
        [const Offset(145, 156), const Offset(155, 175)],
      ],
      size: const Size(300, 285),
    ));
    expect(output, isNotNull);
    expect(output!.inkProximity, inInclusiveRange(0, 1));
    expect(output.templateCoverage, inInclusiveRange(0, 1));
    expect(output.message, isNotEmpty);
  });

  testWidgets('dialogue choices branch to correction and persist error',
      (tester) async {
    final state = await learning();
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(
      home: DialogueJourneyScreen(
        state: state,
        lesson: Map<String, dynamic>.from(
          _catalog['lessons']![0] as Map,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Как вы ответите?'), findsOneWidget);
    final wrong = find.textContaining('فِي الْبَيْتِ');
    await tester.ensureVisible(wrong.first);
    await tester.tap(wrong.first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dialogue-retry')), findsOneWidget);
    expect(state.attempts.last['status'], 'incorrect');
    await tester.ensureVisible(find.byKey(const ValueKey('dialogue-retry')));
    await tester.tap(find.byKey(const ValueKey('dialogue-retry')));
    await tester.pumpAndSettle();
    expect(find.text('Как вы ответите?'), findsOneWidget);
  });

  testWidgets('reader exposes full-dialog playback and audio import',
      (tester) async {
    final state = await learning();
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(
      home: SmartReaderScreen(
        state: state,
        lesson: Map<String, dynamic>.from(
          _catalog['lessons']![0] as Map,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reader-play-dialogue')), findsOneWidget);
    expect(find.byKey(const ValueKey('reader-import-audio-0')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('reader-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Записи носителя (необязательно)'));
    await tester.pumpAndSettle();
    expect(find.text('Запись для реплики 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('reader-word-0-0')), findsOneWidget);
  });

  testWidgets('pronunciation contains real dialogue and no invented score',
      (tester) async {
    final state = await learning();
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(
      home: PronunciationComparisonScreen(state: state),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Окончательную оценку'),
      findsOneWidget);
    expect(find.byKey(const ValueKey('pronunciation-record')),
      findsOneWidget);
    expect(find.byKey(const ValueKey('pronunciation-save')),
      findsNothing);
  });

  testWidgets('calendar supports offline weekday toggles without FCM',
      (tester) async {
    final state = await learning();
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(
      home: StudyCalendarScreen(state: state),
    ));
    await tester.pumpAndSettle();
    final tue = find.byKey(const ValueKey('study-weekday-2'));
    expect(tue, findsOneWidget);
    await tester.tap(tue);
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('study-calendar-save'));
    await tester.scrollUntilVisible(save, 200,
      scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(save.hitTestable());
    await tester.pumpAndSettle();
    expect(StudyCalendarPlan.fromState(state).weekdays.contains(2), false);
    expect(StudyCalendarPlan.fromState(state).notificationsEnabled, false);
  });
}
