import 'package:arabic_academy/core/academy_state.dart';
import 'package:arabic_academy/core/practice_generator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _catalog = <String, dynamic>{
  'modules': <dynamic>[],
  'lessons': <dynamic>[
    {
      'id': 'study-1',
      'title': 'Знакомство',
      'vocabulary': [
        {'ar': 'كِتَابٌ', 'ru': 'книга'},
        {'ar': 'قَلَمٌ', 'ru': 'ручка'},
        {'ar': 'بَيْتٌ', 'ru': 'дом'},
        {'ar': 'بَابٌ', 'ru': 'дверь'},
        {'ar': 'مَاءٌ', 'ru': 'вода'},
        {'ar': 'سَلَامٌ', 'ru': 'мир'},
      ],
      'dialogue': [
        {'ar': 'عُمَرُ: هَذَا كِتَابٌ جَدِيدٌ.', 'ru': 'Это новая книга.'},
        {'ar': 'حَامِدٌ: هَذَا قَلَمٌ جَمِيلٌ.', 'ru': 'Это красивая ручка.'},
        {'ar': 'عُمَرُ: هَلْ هَذَا بَيْتٌ كَبِيرٌ؟', 'ru': 'Это большой дом?'},
        {'ar': 'حَامِدٌ: نَعَمْ، هَذَا بَيْتٌ كَبِيرٌ.', 'ru': 'Да, это большой дом.'},
      ],
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Intensive session mixes multiple grounded exercise mechanics',
      () async {
    SharedPreferences.setMockInitialValues({});
    final state = AcademyState(await SharedPreferences.getInstance(), _catalog);
    addTearDown(state.dispose);
    final questions = PracticeGenerator.build(
      state, PracticeMode.intensive, limit: 36, lessonId: 'study-1',
    );
    final modes = questions.map((q) => q.mode).toSet();
    expect(questions.length, greaterThanOrEqualTo(12));
    expect(modes, contains(PracticeMode.matching));
    expect(modes, contains(PracticeMode.quiz));
    expect(modes, contains(PracticeMode.reverseQuiz));
    expect(modes, contains(PracticeMode.listen));
    expect(modes, contains(PracticeMode.recall));
    expect(modes, contains(PracticeMode.sentence));
    expect(modes, contains(PracticeMode.missingWord));
    expect(modes, contains(PracticeMode.dictation));
    expect(modes, contains(PracticeMode.dialogue));
    expect(modes, contains(PracticeMode.restoreDialogue));
    expect(questions.every((q) => q.lessonId == 'study-1'), isTrue);
    expect(questions.map((q) => q.id).toSet(), hasLength(questions.length));
  });

  test('Find-error mode replaces exactly one word from a real dialogue',
      () async {
    SharedPreferences.setMockInitialValues({});
    final state = AcademyState(await SharedPreferences.getInstance(), _catalog);
    addTearDown(state.dispose);
    final questions = PracticeGenerator.build(
      state, PracticeMode.findError, lessonId: 'study-1');
    expect(questions, isNotEmpty);
    final q = questions.first;
    expect(q.options, contains(q.answer));
    expect(q.word, isNotEmpty);
    expect(q.word, isNot(equals(q.answer)));
    expect(q.reference, contains(q.answer));
    expect(q.reference, isNot(contains(q.word)));
    expect(q.options, hasLength(q.options.toSet().length));
    expect(q.lessonId, 'study-1');
    expect(PracticeGenerator.build(state, PracticeMode.intensive,
      lessonId: 'study-1', limit: 36).map((item) => item.mode),
      contains(PracticeMode.findError));
  });

  test('Matching uses real unique pairs, with no fabricated translations',
      () async {
    SharedPreferences.setMockInitialValues({});
    final state = AcademyState(await SharedPreferences.getInstance(), _catalog);
    addTearDown(state.dispose);
    final cards = PracticeGenerator.build(
      state, PracticeMode.matching, lessonId: 'study-1',
    );
    expect(cards, isNotEmpty);
    final first = cards.first;
    expect(first.pairs.length, greaterThanOrEqualTo(3));
    expect(first.pairs.map((p) => p.ar).toSet(), hasLength(first.pairs.length));
    expect(first.pairs.map((p) => p.ru).toSet(), hasLength(first.pairs.length));
    final authored = (_catalog['lessons'] as List).first['vocabulary'] as List;
    for (final pair in first.pairs) {
      expect(authored.any((w) => w['ar'] == pair.ar &&
          w['ru'] == pair.ru), isTrue);
    }
  });

  test('Dialogue restoration uses actual sequential conversation lines',
      () async {
    SharedPreferences.setMockInitialValues({});
    final state = AcademyState(await SharedPreferences.getInstance(), _catalog);
    addTearDown(state.dispose);
    final items = PracticeGenerator.build(
      state, PracticeMode.restoreDialogue, lessonId: 'study-1',
    );
    expect(items, isNotEmpty);
    expect(items.first.tokens.length, greaterThanOrEqualTo(3));
    expect(items.first.usesOrder, isTrue);
    expect(items.first.answer, items.first.tokens.join('\n'));
  });

  test('Audio task speaks Arabic but checks its real Russian meaning',
      () async {
    SharedPreferences.setMockInitialValues({});
    final state = AcademyState(await SharedPreferences.getInstance(), _catalog);
    addTearDown(state.dispose);
    final question = PracticeGenerator.build(
      state, PracticeMode.listen, lessonId: 'study-1',
    ).first;
    expect(question.word, 'كِتَابٌ');
    expect(question.answer, 'книга');
    expect(question.options, contains(question.answer));
  });
}
