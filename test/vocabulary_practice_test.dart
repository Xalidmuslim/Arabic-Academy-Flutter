import 'package:arabic_academy/app.dart';
import 'package:arabic_academy/core/academy_state.dart';
import 'package:arabic_academy/core/vocabulary_practice.dart';
import 'package:arabic_academy/features/learning/vocabulary_practice_screen.dart';
import 'package:arabic_academy/ui/floating_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _catalog = <String, dynamic>{
  'modules': <dynamic>[],
  'lessons': [
    {'id': 'l1', 'title': 'Урок первый', 'vocabulary': [
      {'ar': 'كِتَابٌ', 'ru': 'Книга'},
      {'ar': 'قَلَمٌ', 'ru': 'Ручка'},
      {'ar': 'بَيْتٌ', 'ru': 'Дом'},
      {'ar': 'بَابٌ', 'ru': 'Дверь'},
    ]},
    {'id': 'l2', 'title': 'Урок второй', 'vocabulary': [
      {'ar': 'مَدْرَسَةٌ', 'ru': 'Школа'},
      {'ar': '', 'ru': 'Пусто'},
      {'ar': 'صَبَاحٌ', 'ru': ''},
    ]},
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('due reviewed vocabulary comes before capped new words', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = AcademyState(prefs, _catalog);
    addTearDown(state.dispose);
    await state.initialize();
    final now = DateTime.utc(2026, 10, 14, 9);
    await state.reviewWord('word:l1:0', true,
        now: now.subtract(const Duration(days: 3)));
    await state.reviewWord('word:l1:1', true, now: now);
    final plan = VocabularyPractice.plan(
      state, now: now, dueLimit: 1, newLimit: 2);
    expect(plan.totalEligible, 5);
    expect(plan.due, 1);
    expect(plan.newWords, 3);
    expect(plan.words.map((w) => w.id),
        ['word:l1:0', 'word:l1:2', 'word:l1:3']);
    final restored = AcademyState(prefs, _catalog);
    expect(restored.reviews['word:l1:0']['stage'], 1);
    restored.dispose();
  });

  test('Arabic written answers allow optional tashkeel but preserve letters',
      () {
    expect(VocabularyPractice.matchesArabic('كتاب', 'كِتَابٌ'), isTrue);
    expect(VocabularyPractice.matchesArabic('كِتَابٌ', 'كتاب'), isTrue);
    expect(VocabularyPractice.matchesArabic('ام', 'أُمٌّ'), isFalse);
    expect(VocabularyPractice.matchesArabic('بيت', 'بَيْتٌ'), isTrue);
    expect(VocabularyPractice.matchesArabic('باء', 'باب'), isFalse);
  });

  test('choices come from actual catalog and never contain duplicate answer',
      () async {
    SharedPreferences.setMockInitialValues({});
    final state = AcademyState(
      await SharedPreferences.getInstance(), _catalog);
    addTearDown(state.dispose);
    final words = VocabularyPractice.words(state);
    final choices = VocabularyPractice.options(
      correct: words.first, all: words,
      type: VocabularyChallenge.arabicToRussian);
    expect(choices, contains('Книга'));
    expect(choices.toSet(), hasLength(choices.length));
    expect(choices, hasLength(4));
    expect(VocabularyPractice.options(
      correct: words.first, all: words,
      type: VocabularyChallenge.russianToArabic), contains('كِتَابٌ'));
  });

  testWidgets('active retrieval requires checking then persists review',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AcademyState(
        await SharedPreferences.getInstance(), _catalog);
    addTearDown(state.dispose);
    await state.initialize();
    await tester.pumpWidget(MaterialApp(
      home: VocabularyPracticeScreen(state: state),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Вспомните перевод'), findsOneWidget);
    expect(find.text('Книга'), findsOneWidget);
    expect(find.byKey(const ValueKey('practice-next')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('practice-option-Книга')));
    await tester.pump();
    final check = find.byKey(const ValueKey('practice-check'));
    await tester.ensureVisible(check);
    await tester.pumpAndSettle();
    await tester.tap(check.hitTestable());
    await tester.pump();
    expect(find.text('Верно!'), findsOneWidget);
    final next = find.byKey(const ValueKey('practice-next'));
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    await tester.tap(next.hitTestable());
    await tester.pumpAndSettle();
    expect(state.reviews['word:l1:0']['stage'], 1);
    expect(find.text('Выберите арабское слово'), findsOneWidget);
  });

  testWidgets('floating navigation never obstructs modal settings or lessons',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'welcome_seen': true,
    });
    final state = AcademyState(
        await SharedPreferences.getInstance(), _catalog);
    addTearDown(state.dispose);
    await tester.pumpWidget(AcademyApp(state: state));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingStudyNavigation), findsOneWidget);
    expect(find.byKey(const ValueKey('demo-role-switch')), findsNothing);
    await tester.tap(find.byTooltip('Настройки'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingStudyNavigation), findsNothing);
    final advanced = find.byKey(const ValueKey('demo-tools'));
    await tester.ensureVisible(advanced);
    await tester.tap(advanced);
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Выбрать демо-кабинет'), findsOneWidget);
    final choose = find.byKey(const ValueKey('demo-role-in-settings'));
    await tester.ensureVisible(choose);
    await tester.pumpAndSettle();
    await tester.tap(choose.hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Выберите кабинет'), findsOneWidget);
    expect(find.byType(FloatingStudyNavigation), findsNothing);
    final teacher = find.text('Учительница').last;
    await tester.ensureVisible(teacher);
    await tester.tap(teacher);
    await tester.pumpAndSettle();
    expect(find.text('Кабинет учительницы'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('demo_role_teacher'), isTrue);
  });
}
