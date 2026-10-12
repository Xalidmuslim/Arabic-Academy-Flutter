import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:arabic_academy/features/exercises/exercises.dart';

Exercise exercise(
  String kind,
  dynamic correct, {
  Map<String, dynamic> extra = const {},
}) {
  return Exercise.fromJson({
    'id': 'test',
    'kind': kind,
    'prompt': 'اختر الإجابة',
    'correct': correct,
    ...extra,
  });
}

void main() {
  testWidgets(
    'Russian controls stay readable and LTR beside Arabic RTL options',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExerciseRunner(
              exercise: Exercise.fromJson({
                'id': 'mixed',
                'kind': 'singleChoice',
                'prompt': 'Какое слово — глагол?',
                'options': ['كَتَبَ', 'كِتَابٌ'],
                'correct': 0,
              }),
              onCompleted: (_, _) {},
            ),
          ),
        ),
      );
      final attempts = find.textContaining('Попытки:');
      expect(Directionality.of(tester.element(attempts)), TextDirection.ltr);
      expect(tester.widget<Text>(attempts).style?.fontFamily, 'Manrope');
      expect(
        tester.widget<Text>(find.text('Какое слово — глагол?')).textDirection,
        TextDirection.ltr,
      );
      expect(
        tester.widget<Text>(find.text('كَتَبَ')).textDirection,
        TextDirection.rtl,
      );
      expect(
        tester.widget<Text>(find.text('كَتَبَ')).style?.fontFamily,
        'NotoNaskhArabic',
      );
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'Mini quiz evaluates all questions and cannot pass missing or wrong answers',
    () {
      final quiz = Exercise.fromJson({
        'id': 'quiz',
        'kind': 'miniQuiz',
        'questions': [
          {
            'id': 'one',
            'kind': 'singleChoice',
            'prompt': 'Один',
            'options': ['A', 'B'],
            'correct': 0,
          },
          {
            'id': 'two',
            'kind': 'translation',
            'prompt': 'Два',
            'correct': 'كِتَابٌ',
          },
        ],
      });
      expect(
        ExerciseEvaluator.evaluate(quiz, {'one': 0, 'two': 'كِتَابٌ'}).passed,
        isTrue,
      );
      expect(
        ExerciseEvaluator.evaluate(quiz, {'one': 0, 'two': 'قَلَمٌ'}).passed,
        isFalse,
      );
      expect(ExerciseEvaluator.evaluate(quiz, {'one': 0}).passed, isFalse);
      expect(
        ExerciseEvaluator.evaluate(quiz, {
          'one': 0,
          'two': 'كِتَابٌ',
          'extra': 0,
        }).passed,
        isFalse,
      );
    },
  );
  test(
    'Final exam respects passing threshold and manual questions stay pending',
    () {
      final exam = Exercise.fromJson({
        'id': 'exam',
        'kind': 'finalExam',
        'config': {'passThreshold': 0.5},
        'questions': [
          {
            'id': 'one',
            'kind': 'singleChoice',
            'options': ['A', 'B'],
            'correct': 0,
          },
          {
            'id': 'two',
            'kind': 'singleChoice',
            'options': ['A', 'B'],
            'correct': 0,
          },
        ],
      });
      final result = ExerciseEvaluator.evaluate(exam, {'one': 0, 'two': 1});
      expect(result.passed, isTrue);
      expect(result.score, 0.5);
      final manual = Exercise.fromJson({
        'kind': 'finalExam',
        'questions': [
          {'id': 'one', 'kind': 'writing'},
        ],
      });
      expect(
        ExerciseEvaluator.evaluate(manual, {'one': 'Answer'}).status,
        ExerciseStatus.needsReview,
      );
    },
  );
  group('immutable JSON contract', () {
    test('legacy zero-based choice and unknown fields survive round trip', () {
      final source = <String, dynamic>{
        'id': 'l1',
        'question': 'Как тебя зовут?',
        'options': ['أَنَا', 'مَا اسْمُكِ؟'],
        'correct': 1,
        'extension': {
          'nested': [1, 2],
        },
      };
      final parsed = Exercise.fromJson(source);
      expect(parsed.kind, ExerciseKind.singleChoice);
      expect(parsed.prompt, source['question']);
      expect(parsed.toJson(), source);
      (source['options'] as List)[1] = 'changed';
      expect(parsed.options[1], 'مَا اسْمُكِ؟');
      expect(() => parsed.options.add('bad'), throwsUnsupportedError);
      final exported = parsed.toJson();
      ((exported['extension'] as Map)['nested'] as List).clear();
      expect((parsed.toJson()['extension'] as Map)['nested'], [1, 2]);
    });

    test('configuration and nested answer keys are immutable', () {
      final parsed = exercise(
        'matching',
        {'a': 'b'},
        extra: {
          'config': {
            'timeLimitSeconds': 30,
            'maxAttempts': 2,
            'randomizeOptions': true,
            'points': 8,
            'passThreshold': 0.75,
            'ignoreDiacritics': true,
          },
          'explanation': 'شرح',
        },
      );
      expect(parsed.config.timeLimitSeconds, 30);
      expect(parsed.config.maxAttempts, 2);
      expect(parsed.config.randomizeOptions, isTrue);
      expect(parsed.config.points, 8);
      expect(parsed.config.passThreshold, 0.75);
      expect(parsed.config.ignoreDiacritics, isTrue);
      expect(() => (parsed.correct as Map)['a'] = 'c', throwsUnsupportedError);
      expect(Exercise.fromJson(parsed.toJson()).toJson(), parsed.toJson());
    });

    test('unknown kinds are preserved, invalid configuration is rejected', () {
      final parsed = exercise('future_kind', 'answer');
      expect(parsed.kind, ExerciseKind.unknown);
      expect(parsed.toJson()['kind'], 'future_kind');
      expect(
        ExerciseKind.values.where((x) => x != ExerciseKind.unknown),
        hasLength(greaterThanOrEqualTo(25)),
      );
      for (final config in [
        {'maxAttempts': 0},
        {'timeLimitSeconds': -1},
        {'points': -2},
        {'passThreshold': 1.1},
        {'randomizeOptions': 'yes'},
      ]) {
        expect(
          () => exercise('shortAnswer', 'a', extra: {'config': config}),
          throwsFormatException,
        );
      }
    });
  });

  group('safe scoring', () {
    test('single choice accepts only a valid original integer index', () {
      final task = exercise(
        'single_choice',
        1,
        extra: {
          'options': ['wrong', 'right'],
          'points': 5,
          'explanation': 'why',
        },
      );
      final result = ExerciseEvaluator.evaluate(task, 1);
      expect(result.status, ExerciseStatus.correct);
      expect(result.points, 5);
      expect(result.passed, isTrue);
      expect(result.explanation, 'why');
      for (final answer in [0, -1, 2, 'right', '1', 1.0, true, null, [], {}]) {
        final wrong = ExerciseEvaluator.evaluate(task, answer);
        expect(wrong.status, ExerciseStatus.incorrect, reason: '$answer');
        expect(wrong.points, 0);
        expect(wrong.passed, isFalse);
      }
      expect(
        ExerciseEvaluator.evaluate(
          exercise(
            'singleChoice',
            3,
            extra: {
              'options': ['a'],
            },
          ),
          3,
        ).status,
        ExerciseStatus.needsReview,
      );
    });

    test('multiple choice requires exactly all keys without duplicates', () {
      final task = exercise(
        'multipleChoice',
        [0, 2],
        extra: {
          'options': ['a', 'b', 'c'],
        },
      );
      expect(
        ExerciseEvaluator.evaluate(task, [2, 0]).status,
        ExerciseStatus.correct,
      );
      for (final answer in [
        [],
        [0],
        [0, 1, 2],
        [0, 2, 2],
        ['0', '2'],
        null,
      ]) {
        expect(
          ExerciseEvaluator.evaluate(task, answer).status,
          ExerciseStatus.incorrect,
          reason: '$answer',
        );
      }
      expect(
        ExerciseEvaluator.evaluate(
          exercise(
            'multipleChoice',
            [],
            extra: {
              'options': ['a'],
            },
          ),
          [],
        ).status,
        ExerciseStatus.needsReview,
      );
    });

    test('booleans are not coerced from strings or numbers', () {
      final task = exercise('trueFalse', false);
      expect(
        ExerciseEvaluator.evaluate(task, false).status,
        ExerciseStatus.correct,
      );
      for (final answer in [true, 0, 'false', null]) {
        expect(
          ExerciseEvaluator.evaluate(task, answer).status,
          ExerciseStatus.incorrect,
        );
      }
    });

    test('matching requires complete nonempty maps with exact identities', () {
      final task = exercise('matching', {'a': 'one', 'b': 'two'});
      expect(
        ExerciseEvaluator.evaluate(task, {'b': 'two', 'a': 'one'}).status,
        ExerciseStatus.correct,
      );
      for (final answer in [
        {},
        {'a': 'one'},
        {'a': 'one', 'b': 'one'},
        {'a': 'one', 'b': 'two', 'c': 'three'},
        ['one', 'two'],
        null,
      ]) {
        expect(
          ExerciseEvaluator.evaluate(task, answer).status,
          ExerciseStatus.incorrect,
        );
      }
      expect(
        ExerciseEvaluator.evaluate(exercise('matching', {}), {}).status,
        ExerciseStatus.needsReview,
      );
    });

    test('ordered and nested answers check shape, order and every cell', () {
      final ordered = exercise('wordOrder', ['أنا', 'طالبة']);
      expect(
        ExerciseEvaluator.evaluate(ordered, ['أنا', 'طالبة']).status,
        ExerciseStatus.correct,
      );
      for (final answer in [
        [],
        ['طالبة', 'أنا'],
        'أنا طالبة',
        ['أنا'],
        [1, 2],
      ]) {
        expect(
          ExerciseEvaluator.evaluate(ordered, answer).status,
          ExerciseStatus.incorrect,
        );
      }
      final table = exercise('table', [
        ['أنا', 'أنت'],
        ['هو', 'هي'],
      ]);
      expect(
        ExerciseEvaluator.evaluate(table, [
          ['أنا', 'أنت'],
          ['هو', 'هي'],
        ]).status,
        ExerciseStatus.correct,
      );
      expect(
        ExerciseEvaluator.evaluate(table, [
          ['أنا', 'أنت'],
          [],
        ]).status,
        ExerciseStatus.incorrect,
      );
      for (final key in [
        [],
        [[]],
        [''],
        {'a': ''},
        null,
      ]) {
        expect(
          ExerciseEvaluator.evaluate(exercise('table', key), key).status,
          ExerciseStatus.needsReview,
        );
      }
    });

    test(
      'grading preserves hamza and ta marbuta, diacritics are configurable',
      () {
        final strict = exercise('shortAnswer', 'أُمّ');
        expect(
          ExerciseEvaluator.evaluate(strict, 'أُمّ').status,
          ExerciseStatus.correct,
        );
        expect(
          ExerciseEvaluator.evaluate(strict, 'أم').status,
          ExerciseStatus.incorrect,
        );
        final relaxed = exercise(
          'shortAnswer',
          'أُمّ',
          extra: {
            'config': {'ignoreDiacritics': true},
          },
        );
        expect(
          ExerciseEvaluator.evaluate(relaxed, 'أم').status,
          ExerciseStatus.correct,
        );
        expect(
          ExerciseEvaluator.evaluate(relaxed, 'ام').status,
          ExerciseStatus.incorrect,
        );
        expect(
          ExerciseEvaluator.evaluate(
            exercise('shortAnswer', 'مدرسة'),
            'مدرسه',
          ).status,
          ExerciseStatus.incorrect,
        );
        expect(
          ExerciseEvaluator.evaluate(relaxed, 'ا\u0654م').status,
          ExerciseStatus.correct,
          reason: 'decomposed hamza is still a hamza',
        );
        expect(
          ArabicNormalization.forSearch('أُمّ مدرسة'),
          ArabicNormalization.forSearch('ام مدرسه'),
        );
      },
    );

    test(
      'alternatives are explicit and malformed or absent keys need review',
      () {
        final task = Exercise.fromJson({
          'kind': 'translation',
          'acceptedAnswers': ['كتاب', 'الكتاب'],
        });
        expect(
          ExerciseEvaluator.evaluate(task, 'الكتاب').status,
          ExerciseStatus.correct,
        );
        expect(
          ExerciseEvaluator.evaluate(task, 'wrong').status,
          ExerciseStatus.incorrect,
        );
        for (final json in [
          {'kind': 'shortAnswer'},
          {'kind': 'shortAnswer', 'correct': ''},
          {'kind': 'shortAnswer', 'acceptedAnswers': []},
          {
            'kind': 'shortAnswer',
            'acceptedAnswers': ['ok', null],
          },
          {'kind': 'newKind', 'correct': 'ok'},
        ]) {
          expect(
            ExerciseEvaluator.evaluate(Exercise.fromJson(json), 'ok').status,
            ExerciseStatus.needsReview,
          );
        }
        expect(
          ExerciseEvaluator.evaluate(exercise('shortAnswer', '0'), 0).status,
          ExerciseStatus.incorrect,
        );
      },
    );

    test('manual and voice kinds never award automatic points', () {
      for (final kind in ['writing', 'speaking', 'pronunciation', 'dialogue']) {
        final task = exercise(kind, 'same', extra: {'points': 20});
        for (final answer in [
          'same',
          {'audioPath': 'voice.m4a'},
          '',
          null,
        ]) {
          final result = ExerciseEvaluator.evaluate(task, answer);
          expect(result.status, ExerciseStatus.needsReview);
          expect(result.points, 0);
          expect(result.passed, isFalse);
        }
      }
    });

    test(
      'kind registry can be extended without replacing built-in graders',
      () {
        final evaluator = ExerciseEvaluator(
          registry: {
            ExerciseKind.shortAnswer: (exercise, answer) =>
                const ExerciseResult(
                  status: ExerciseStatus.needsReview,
                  points: 0,
                  explanation: 'Teacher',
                ),
          },
        );
        expect(
          evaluator.grade(exercise('shortAnswer', 'a'), 'a').status,
          ExerciseStatus.needsReview,
        );
        expect(
          evaluator.grade(exercise('trueFalse', true), true).status,
          ExerciseStatus.correct,
        );
      },
    );

    test(
      'every automatic kind accepts its explicit key and rejects a wrong answer',
      () {
        final examples = <String, dynamic>{
          for (final kind in [
            'singleChoice',
            'listeningChoice',
            'imageChoice',
            'readingComprehension',
          ])
            kind: 1,
          'multipleChoice': [0, 1],
          'trueFalse': true,
          for (final kind in [
            'matching',
            'listeningMatching',
            'imageMatching',
            'categorization',
          ])
            kind: {'a': 'b'},
          for (final kind in ['wordOrder', 'sentenceOrder', 'fillBlanks'])
            kind: ['أنا', 'طالبة'],
          'table': [
            ['أنا', 'طالبة'],
          ],
          'conjugation': {'أنا': 'أكتب'},
          for (final kind in [
            'fillBlank',
            'shortAnswer',
            'translation',
            'dictation',
            'errorCorrection',
            'diacritics',
          ])
            kind: 'أُمّ',
        };
        for (final example in examples.entries) {
          final task = exercise(
            example.key,
            example.value,
            extra: {
              'options': ['a', 'b'],
            },
          );
          expect(
            ExerciseEvaluator.evaluate(task, example.value).status,
            ExerciseStatus.correct,
            reason: example.key,
          );
          expect(
            ExerciseEvaluator.evaluate(task, null).status,
            ExerciseStatus.incorrect,
            reason: example.key,
          );
        }
      },
    );

    test('word order requires a nonempty flat list of nonempty strings', () {
      for (final key in [
        'word',
        {'a': 'word'},
        [
          ['word'],
        ],
        [],
        [''],
      ]) {
        expect(
          ExerciseEvaluator.evaluate(exercise('wordOrder', key), key).status,
          ExerciseStatus.needsReview,
        );
      }
    });

    test('zero pass threshold never makes an incorrect answer pass', () {
      final task = exercise(
        'trueFalse',
        false,
        extra: {
          'config': {'passThreshold': 0, 'points': 0},
        },
      );
      expect(ExerciseEvaluator.evaluate(task, true).passed, isFalse);
      final correct = ExerciseEvaluator.evaluate(task, false);
      expect(correct.passed, isTrue);
      expect(correct.points, 0);
    });
  });

  Future<void> mount(
    WidgetTester tester,
    Exercise task, {
    dynamic initialAnswer,
    void Function(ExerciseResult, dynamic)? onCompleted,
    ValueChanged<dynamic>? onDraft,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExerciseRunner(
            exercise: task,
            initialAnswer: initialAnswer,
            onCompleted: onCompleted ?? (_, __) {},
            onDraft: onDraft,
          ),
        ),
      ),
    );
  }

  group('runner', () {
    testWidgets('randomization preserves source indexes and drafts', (
      tester,
    ) async {
      final task = exercise(
        'singleChoice',
        1,
        extra: {
          'options': ['wrong', 'right', 'other'],
          'config': {'randomizeOptions': true},
        },
      );
      dynamic draft;
      ExerciseResult? result;
      dynamic submitted;
      await mount(
        tester,
        task,
        onDraft: (value) => draft = value,
        onCompleted: (value, answer) {
          result = value;
          submitted = answer;
        },
      );
      final labels = tester
          .widgetList<RadioListTile<int>>(find.byType(RadioListTile<int>))
          .map((x) => x.value)
          .toList();
      await tester.tap(find.text('right'));
      await tester.pump();
      expect(draft, 1);
      expect(
        tester
            .widgetList<RadioListTile<int>>(find.byType(RadioListTile<int>))
            .map((x) => x.value)
            .toList(),
        labels,
      );
      await tester.tap(find.byKey(const ValueKey('exercise-submit')));
      await tester.pump();
      expect(result?.status, ExerciseStatus.correct);
      expect(submitted, 1);
      expect(task.options, ['wrong', 'right', 'other']);
    });

    testWidgets('attempt limit locks the runner and completion fires once', (
      tester,
    ) async {
      var completions = 0;
      await mount(
        tester,
        exercise(
          'singleChoice',
          1,
          extra: {
            'options': ['wrong', 'right'],
            'config': {'maxAttempts': 1},
          },
        ),
        onCompleted: (result, answer) {
          completions++;
          expect(result.status, ExerciseStatus.incorrect);
        },
      );
      await tester.tap(find.text('wrong'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('exercise-submit')));
      await tester.pump();
      expect(completions, 1);
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('exercise-submit')),
      );
      expect(button.onPressed, isNull);
      expect(
        tester
            .widgetList<RadioListTile<int>>(find.byType(RadioListTile<int>))
            .every((x) => x.enabled == false),
        isTrue,
      );
    });

    testWidgets(
      'time limit expires without awarding points for a saved answer',
      (tester) async {
        ExerciseResult? result;
        await mount(
          tester,
          exercise(
            'trueFalse',
            true,
            extra: {
              'config': {'timeLimitSeconds': 1},
            },
          ),
          initialAnswer: true,
          onCompleted: (value, answer) => result = value,
        );
        await tester.pump(const Duration(seconds: 2));
        expect(result?.status, ExerciseStatus.incorrect);
        expect(result?.points, 0);
      },
    );

    testWidgets('manual draft is restored and submitted for review', (
      tester,
    ) async {
      ExerciseResult? result;
      dynamic answer;
      dynamic draft;
      await mount(
        tester,
        exercise('writing', null),
        initialAnswer: 'saved',
        onDraft: (value) => draft = value,
        onCompleted: (value, submitted) {
          result = value;
          answer = submitted;
        },
      );
      expect(find.text('saved'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'new answer');
      expect(draft, 'new answer');
      await tester.tap(find.byKey(const ValueKey('exercise-submit')));
      await tester.pump();
      expect(answer, 'new answer');
      expect(result?.status, ExerciseStatus.needsReview);
      expect(result?.points, 0);
    });

    testWidgets(
      'checkboxes submit original indexes and draft cannot mutate state',
      (tester) async {
        ExerciseResult? result;
        dynamic submitted;
        await mount(
          tester,
          exercise(
            'multipleChoice',
            [0, 2],
            extra: {
              'options': ['one', 'two', 'three'],
            },
          ),
          onDraft: (value) => (value as List).clear(),
          onCompleted: (value, answer) {
            result = value;
            submitted = answer;
          },
        );
        await tester.tap(find.text('three'));
        await tester.pump();
        await tester.tap(find.text('one'));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('exercise-submit')));
        await tester.pump();
        expect(result?.status, ExerciseStatus.correct);
        expect(submitted, [0, 2]);
      },
    );

    testWidgets('word ordering keeps repeated words separately selectable', (
      tester,
    ) async {
      ExerciseResult? result;
      dynamic answer;
      await mount(
        tester,
        exercise(
          'wordOrder',
          ['أنا', 'أنا', 'طالبة'],
          extra: {
            'words': ['طالبة', 'أنا', 'أنا'],
          },
        ),
        onCompleted: (value, submitted) {
          result = value;
          answer = submitted;
        },
      );
      var words = find.widgetWithText(OutlinedButton, 'أنا');
      await tester.tap(words.first);
      await tester.pump();
      words = find.widgetWithText(OutlinedButton, 'أنا');
      await tester.tap(words.last);
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, 'طالبة'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('exercise-submit')));
      await tester.pump();
      expect(result?.status, ExerciseStatus.correct);
      expect(answer, ['أنا', 'أنا', 'طالبة']);
    });

    testWidgets('matching dropdowns require every source', (tester) async {
      ExerciseResult? result;
      dynamic answer;
      await mount(
        tester,
        exercise('matching', {'book': 'كتاب', 'pen': 'قلم'}),
        onCompleted: (value, submitted) {
          result = value;
          answer = submitted;
        },
      );
      for (final pair in {'book': 'كتاب', 'pen': 'قلم'}.entries) {
        await tester.tap(find.byKey(ValueKey('match-${pair.key}')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(pair.value).last);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const ValueKey('exercise-submit')));
      await tester.pump();
      expect(result?.status, ExerciseStatus.correct);
      expect(answer, {'book': 'كتاب', 'pen': 'قلم'});
    });

    testWidgets(
      'table edits retain other cells and submit the complete matrix',
      (tester) async {
        ExerciseResult? result;
        dynamic answer;
        await mount(
          tester,
          exercise('table', [
            ['أنا', 'هو'],
          ]),
          onCompleted: (value, submitted) {
            result = value;
            answer = submitted;
          },
        );
        await tester.enterText(find.byType(TextFormField).first, 'أنا');
        await tester.pump();
        await tester.enterText(find.byType(TextFormField).last, 'هو');
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('exercise-submit')));
        await tester.pump();
        expect(result?.status, ExerciseStatus.correct);
        expect(answer, [
          ['أنا', 'هو'],
        ]);
      },
    );

    testWidgets('voice attachment survives a note edit and stays needsReview', (
      tester,
    ) async {
      ExerciseResult? result;
      dynamic answer;
      await mount(
        tester,
        exercise('speaking', null),
        initialAnswer: {'audioPath': 'voice.m4a', 'note': 'draft'},
        onCompleted: (value, submitted) {
          result = value;
          answer = submitted;
        },
      );
      expect(find.text('draft'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'note');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('exercise-submit')));
      await tester.pump();
      expect(result?.status, ExerciseStatus.needsReview);
      expect(answer, {'audioPath': 'voice.m4a', 'note': 'note'});
    });

    testWidgets('voice attachment can be submitted without an optional note', (
      tester,
    ) async {
      ExerciseResult? result;
      await mount(
        tester,
        exercise('pronunciation', null),
        initialAnswer: {'audioPath': 'voice.m4a', 'note': ''},
        onCompleted: (value, answer) => result = value,
      );
      await tester.tap(find.byKey(const ValueKey('exercise-submit')));
      await tester.pump();
      expect(result?.status, ExerciseStatus.needsReview);
    });

    testWidgets('native choices inherit the Arabic font and theme color', (
      tester,
    ) async {
      await mount(
        tester,
        exercise(
          'singleChoice',
          0,
          extra: {
            'options': ['أَنَا'],
          },
        ),
      );
      final context = tester.element(find.text('أَنَا'));
      expect(DefaultTextStyle.of(context).style.fontFamily, 'NotoNaskhArabic');
      expect(
        DefaultTextStyle.of(context).style.height,
        greaterThanOrEqualTo(1.65),
      );
    });

    testWidgets(
      'wrong attempts can retry but equivalent parent rebuilds do not reset limits',
      (tester) async {
        var count = 0;
        final json = <String, dynamic>{
          'id': 'retry',
          'kind': 'singleChoice',
          'options': ['wrong', 'right'],
          'correct': 1,
          'config': {'maxAttempts': 2},
        };
        void completed(ExerciseResult result, dynamic answer) => count++;
        await mount(tester, Exercise.fromJson(json), onCompleted: completed);
        await tester.tap(find.text('wrong'));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('exercise-submit')));
        await tester.pump();
        expect(count, 0);
        await mount(tester, Exercise.fromJson(json), onCompleted: completed);
        await tester.tap(find.byKey(const ValueKey('exercise-submit')));
        await tester.pump();
        expect(count, 1);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('exercise-submit')),
              )
              .onPressed,
          isNull,
        );
      },
    );

    testWidgets('RTL controls fit a narrow screen with doubled text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: ExerciseRunner(
                exercise: exercise(
                  'singleChoice',
                  0,
                  extra: {
                    'options': ['أنا طالبة في مركز اللغة العربية', 'لا'],
                  },
                ),
                onCompleted: (_, __) {},
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<Text>(find.text('إرسال الإجابة')).style?.fontFamily,
        'NotoNaskhArabic',
      );
      expect(
        Directionality.of(
          tester.element(find.text('أنا طالبة في مركز اللغة العربية')),
        ),
        TextDirection.rtl,
      );
    });
  });
}
