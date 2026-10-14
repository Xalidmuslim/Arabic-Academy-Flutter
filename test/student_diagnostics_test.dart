import 'dart:convert';

import 'package:arabic_academy/core/academy_state.dart';
import 'package:arabic_academy/features/learning/handwriting_screen.dart';
import 'package:arabic_academy/features/teacher/demo_school_store.dart';
import 'package:arabic_academy/features/teacher/demo_school_screen.dart';
import 'package:arabic_academy/features/teacher/student_diagnostics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _catalog = <String, dynamic>{
  'modules': <dynamic>[],
  'lessons': [
    {
      'id': 'l1', 'title': 'Первый урок',
      'vocabulary': [
        {'ar': 'كِتَابٌ', 'ru': 'Книга'},
        {'ar': 'قَلَمٌ', 'ru': 'Ручка'},
      ],
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AcademyState> local() async {
    SharedPreferences.setMockInitialValues({});
    final state = AcademyState(
      await SharedPreferences.getInstance(), _catalog,
    );
    await state.initialize();
    return state;
  }

  test('lesson errors, vocabulary lapses and SRS remain isolated per pupil',
      () async {
    final learning = await local();
    addTearDown(learning.dispose);
    final school = DemoSchoolStore(learning.prefs);
    addTearDown(school.dispose);

    await learning.recordAttempt(
      lessonId: 'l1',
      exerciseId: 'practice:quiz:word:l1:0',
      answer: {
        'response': 'Не знаю',
        'expected': 'Книга',
        'feedback': 'Повторите كتاب',
      },
      status: 'incorrect', points: 0,
    );
    await learning.recordAttempt(
      lessonId: 'l1',
      exerciseId: 'practice:missingWord:l1:0',
      answer: {
        'response': 'خطأ',
        'expected': 'كتاب',
        'feedback': 'Сравните с образцом',
      },
      status: 'incorrect', points: 0,
    );
    await learning.reviewWord(
      'word:l1:0', false,
      now: DateTime.now().subtract(const Duration(days: 2)),
    );

    final first = StudentLearningReport.build(school, learning, 's1');
    final second = StudentLearningReport.build(school, learning, 's2');
    expect(first.skill('words').errors, 1);
    expect(first.skill('grammar').errors, 1);
    expect(first.wordDue, 1);
    expect(first.wordLapses, 1);
    expect(first.hardWords.first.translation, 'Книга');
    expect(first.errors.length, 2);
    expect(second.skill('words').attempts, 0);
    expect(second.wordDue, 0);
    expect(second.skill('pronunciation').teacherAverage, isNull);
    expect(second.sampleLessonScores, isNotEmpty); // Seeded demo data only
  });

  test('real automatic exercises and human pronunciation remain different',
      () async {
    final learning = await local();
    addTearDown(learning.dispose);
    final school = DemoSchoolStore(learning.prefs);
    addTearDown(school.dispose);

    await school.addSkillAssessment(
      studentId: 's2', skill: 'pronunciation',
      score: 62, note: 'Сокращает долгие гласные.',
      criteria: {
        'consonants': 81,
        'vowels': 43,
        'endings': 62,
        'fluency': 70,
      },
    );
    await school.addSkillAssessment(
      studentId: 's2', skill: 'pronunciation',
      score: 78, note: 'Стала лучше различать долгие звуки.',
      criteria: {'vowels': 73, 'fluency': 80},
    );
    var report = StudentLearningReport.build(school, learning, 's2');
    expect(report.skill('pronunciation').attempts, 0);
    expect(report.skill('pronunciation').teacherAverage, 70);
    expect(report.skill('pronunciation').pronunciationCriteria['vowels'], 58);
    expect(report.skill('pronunciation').pronunciationCriteria['consonants'], 81);
    expect(report.skill('pronunciation').notes.first,
        contains('Стала лучше'));
    expect(report.skill('grammar').teacherAverage, isNull);

    await school.createAssignment(
      groupId: 'g1', studentId: 's2',
      title: 'Упражнение на грамматику',
      instructions: 'Исправьте предложения.',
      skill: 'grammar',
    );
    final task = school.assignments.last;
    await school.submit(
      assignmentId: task['id'] as String,
      studentId: 's2',
      answer: 'الإجابة',
    );
    final response = school.submissionFor(
      task['id'] as String, 's2',
    )!;
    await school.grade(
      submissionId: response['id'] as String,
      score: 75,
      feedback: 'Ошибки в порядке слов.',
    );

    report = StudentLearningReport.build(school, learning, 's2');
    expect(report.skill('grammar').automaticAccuracy, isNull);
    expect(report.skill('grammar').teacherAverage, 75);
    expect(report.skill('pronunciation').teacherAverage, 70);
    expect(report.graded, greaterThanOrEqualTo(1));
    expect(report.recommendations, isNotEmpty);
  });

  test('v1 archives without new diagnostics keep old assignments and grades',
      () async {
    final learning = await local();
    addTearDown(learning.dispose);
    final original = DemoSchoolStore(learning.prefs);
    await original.createGroup('Новая группа');
    original.dispose();
    final raw = jsonDecode(
      learning.prefs.getString(DemoSchoolStore.storageKey)!,
    ) as Map<String, dynamic>;
    raw.remove('skill_assessments');
    await learning.prefs.setString(
      DemoSchoolStore.storageKey, jsonEncode(raw),
    );
    final restored = DemoSchoolStore(learning.prefs);
    addTearDown(restored.dispose);
    expect(restored.readOnly, false);
    expect(restored.groups.last['name'], 'Новая группа');
    expect(restored.submissionFor('a1', 's2')?['grade'], 90);
    expect(restored.skillAssessmentsFor('s2'), isEmpty);
    await restored.addSkillAssessment(
      studentId: 's2', skill: 'reading',
      score: 85, note: 'Читает правильно.',
    );
    expect(restored.skillAssessmentsFor('s2'), hasLength(1));
  });

  testWidgets('touch writing consumes vertical strokes instead of scrolling',
      (tester) async {
    final learning = await local();
    addTearDown(learning.dispose);
    await tester.pumpWidget(
      MaterialApp(home: HandwritingScreen(state: learning)),
    );
    await tester.pumpAndSettle();
    final canvas = find.byKey(const ValueKey('handwriting-canvas'));
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    final before = scrollable.position.pixels;
    await tester.drag(canvas, const Offset(0, -115));
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, closeTo(before, .5));
    final save = find.byKey(const ValueKey('handwriting-save'));
    // Leave the canvas to scroll; its own touch gestures are reserved for ink.
    await tester.dragFrom(
      const Offset(8, 490), const Offset(0, -290));
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(learning.attempts.last['exercise_id'], 'handwriting:ب');
    expect(learning.attempts.last['status'], 'needsReview');
  });

  testWidgets('teacher sees isolated pupil profile and stores manual rubric',
      (tester) async {
    final learning = await local();
    addTearDown(learning.dispose);
    final school = DemoSchoolStore(learning.prefs);
    addTearDown(school.dispose);
    await tester.pumpWidget(MaterialApp(
      home: DemoStudentDetails(
        school: school, learning: learning, studentId: 's2',
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Усвоение по навыкам'), findsOneWidget);
    expect(find.text('Запоминание слов'), findsWidgets);
    expect(find.text('Диаграмма навыков'), findsOneWidget);
    expect(find.text('Проверки по навыкам'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('student-manual-assessment')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ручная оценка навыка'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).first, '72',
    );
    await tester.enterText(
      find.byType(TextFormField).last, 'Есть трудности с хамзой',
    );
    await tester.tap(find.byKey(
        const ValueKey('save-student-skill-assessment')));
    await tester.pumpAndSettle();
    final report = StudentLearningReport.build(school, learning, 's2');
    expect(report.skill('pronunciation').teacherAverage, 72);
  });
}
