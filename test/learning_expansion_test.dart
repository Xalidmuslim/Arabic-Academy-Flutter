import 'package:arabic_academy/app.dart';
import 'package:arabic_academy/core/academy_state.dart';
import 'package:arabic_academy/core/learning_insights.dart';
import 'package:arabic_academy/core/practice_feedback.dart';
import 'package:arabic_academy/core/practice_generator.dart';
import 'package:arabic_academy/features/learning/handwriting_screen.dart';
import 'package:arabic_academy/features/learning/situations_screen.dart';
import 'package:arabic_academy/features/learning/smart_reader_screen.dart';
import 'package:arabic_academy/features/teacher/demo_school_store.dart';
import 'package:arabic_academy/ui/floating_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _catalog = <String, dynamic>{
  'modules': [{'id': 'm1', 'title': 'Раздел первый'}],
  'lessons': [{
    'id': 'l1', 'module_id': 'm1', 'title': 'Диалог',
    'vocabulary': [
      {'ar':'كِتَابٌ', 'ru':'Книга'},
      {'ar':'بَابٌ', 'ru':'Дверь'},
      {'ar':'بَيْتٌ', 'ru':'Дом'},
      {'ar':'قَلَمٌ', 'ru':'Ручка'},
    ],
    'dialogue': [
      {'ar':'عَلِيّ: هَذَا كِتَابٌ.', 'ru':'Это книга.'},
      {'ar':'حَسَن: أَيْنَ الْكِتَابُ؟', 'ru':'Где книга?'},
      {'ar':'عَلِيّ: فِي الْبَيْتِ.', 'ru':'В доме.'},
    ],
  }],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AcademyState> learning() async {
    SharedPreferences.setMockInitialValues({'welcome_seen': true});
    final state = AcademyState(await SharedPreferences.getInstance(), _catalog);
    await state.initialize();
    return state;
  }

  test('knowledge map has no fabricated scores for untested skills', () async {
    final state = await learning();
    addTearDown(state.dispose);
    final original = LearningInsights.skills(state);
    expect(original, hasLength(7));
    expect(original.every((skill) => skill.accuracy == null), isTrue);
    expect(LearningInsights.weakestSkill(state), isNull);
    await state.recordAttempt(
      lessonId:'l1', exerciseId:'practice:dictation:l1:0',
      answer:{'response':'خطأ','expected':'هَذَا كِتَابٌ.'},
      status:'incorrect', points:0);
    await state.recordAttempt(
      lessonId:'l1', exerciseId:'practice:dictation:l1:0',
      answer:{'response':'هذا كتاب','expected':'هَذَا كِتَابٌ.'},
      status:'correct', points:1);
    expect(LearningInsights.skills(state)
        .firstWhere((skill)=>skill.id=='listening').percent, 50);
    expect(LearningInsights.weakestSkill(state), 'listening');
    expect(LearningInsights.dailyPlan(state).newWordLimit, 8);
  });

  test('answer feedback cites actual lesson reference, no speculative grammar',
      () async {
    final state = await learning();
    addTearDown(state.dispose);
    final q = PracticeGenerator.build(state, PracticeMode.dialogue).first;
    final message = PracticeFeedback.explain(q, 'неправильно', correct:false);
    expect(message, contains(q.answer));
    expect(message, contains(q.reference));
    expect(PracticeFeedback.explain(
        q, '', correct:false, revealed:true), contains('показан'));
  });

  test('voice prompts, audio answers and voice reviews stay in local demo store',
      () async {
    final state = await learning();
    addTearDown(state.dispose);
    final school = DemoSchoolStore(state.prefs);
    addTearDown(school.dispose);
    await school.createAssignment(
      title:'Голосовое чтение', instructions:'Прочитать слова',
      groupId:'g1', studentId:'s1',
      audioPath:'/private/voice_teacher.m4a',
    );
    final assignment = school.assignments.last;
    expect(assignment['audio_path'], '/private/voice_teacher.m4a');
    final taskId = assignment['id'] as String;
    await school.submit(
      assignmentId:taskId,studentId:'s1',answer:'',
      audioPath:'/private/voice_student.m4a',
    );
    expect(school.submissionFor(taskId,'s1')!['audio_path'],
        '/private/voice_student.m4a');
    final submissionId=school.submissionFor(taskId,'s1')!['id'] as String;
    await school.grade(submissionId:submissionId,score:85,
      feedback:'Обратите внимание на долгие гласные',
      feedbackAudioPath:'/private/voice_review.m4a',
    );
    expect(school.submissionFor(taskId,'s1')!['feedback_audio_path'],
        '/private/voice_review.m4a');
    expect(school.homeworkFor('s4').any((x)=>x['id']==taskId), isFalse);
    expect(DemoSchoolStore(state.prefs)
      .submissionFor(taskId,'s1')!['grade'],85);
  });

  testWidgets('practice is on home and floating bar persists in pushed page',
      (tester) async {
    final state = await learning();
    addTearDown(state.dispose);
    await tester.pumpWidget(AcademyApp(state:state));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingStudyNavigation), findsOneWidget);
    final entry=find.byKey(const ValueKey('home-practice-entry'));
    await tester.scrollUntilVisible(entry, 280,
      scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.text('Практика'), findsWidgets);
    expect(find.byType(FloatingStudyNavigation), findsOneWidget);
    final nav=find.byKey(const ValueKey('floating-study-navigation'));
    expect(tester.getTopLeft(nav).dy, greaterThan(150));
    await tester.tap(find.byKey(const ValueKey('study-tab-3')));
    await tester.pumpAndSettle();
    expect(find.text('Ученица · локальное обучение'), findsOneWidget);
  });

  testWidgets('reader can select a known word, dialog hides floating nav',
      (tester) async {
    final state = await learning();
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(home: SmartReaderScreen(
        state:state, lesson:Map<String,dynamic>.from(_catalog['lessons']![0] as Map)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Умное чтение'), findsOneWidget);
    final words=find.textContaining('كِتَابٌ');
    expect(words, findsWidgets);
    await tester.tap(words.first);
    await tester.pumpAndSettle();
    expect(find.text('Книга'), findsOneWidget);
  });

  testWidgets('handwriting captures traces without claiming automatic grade',
      (tester) async {
    final state = await learning();
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(
      home: HandwritingScreen(state:state),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('не оценивает'), findsOneWidget);
    final canvas=find.byKey(const ValueKey('handwriting-canvas'));
    await tester.drag(canvas, const Offset(110, 0));
    await tester.pump();
    // Scroll from the outside gutter: strokes inside the ink canvas
    // intentionally capture all drags and no longer move the page.
    await tester.dragFrom(
      const Offset(8, 480), const Offset(0, -290));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('handwriting-save')));
    await tester.pumpAndSettle();
    expect(state.attempts.last['status'],'needsReview');
    expect(state.attempts.last['exercise_id'],'handwriting:ب');
  });

  testWidgets('situations list catalog dialogues and opens lesson reader',
      (tester) async {
    final state=await learning();
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(
      home:SituationsScreen(state:state),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Диалог'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Авторский текст').first,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Авторский текст').first);
    await tester.pumpAndSettle();
    expect(find.text('Умное чтение'), findsOneWidget);
  });
}
