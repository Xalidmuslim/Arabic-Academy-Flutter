import 'arabic_normalization.dart';
import 'exercise.dart';
import 'exercise_result.dart';

typedef ExerciseGrader =
    ExerciseResult Function(Exercise exercise, dynamic answer);

/// Extend a private registry with overrides; the default evaluator is unchanged.
class ExerciseEvaluator {
  ExerciseEvaluator({Map<ExerciseKind, ExerciseGrader> registry = const {}})
    : registry = Map.unmodifiable({..._builtIns, ...registry});

  final Map<ExerciseKind, ExerciseGrader> registry;
  static final _default = ExerciseEvaluator();

  static ExerciseResult evaluate(Exercise exercise, dynamic answer) =>
      _default.grade(exercise, answer);

  ExerciseResult grade(Exercise exercise, dynamic answer) =>
      (registry[exercise.kind] ?? _manual)(exercise, answer);

  static final Map<ExerciseKind, ExerciseGrader> _builtIns = {
    for (final kind in [
      ExerciseKind.singleChoice,
      ExerciseKind.listeningChoice,
      ExerciseKind.imageChoice,
      ExerciseKind.readingComprehension,
    ])
      kind: _choice,
    ExerciseKind.multipleChoice: _multiple,
    ExerciseKind.trueFalse: _boolean,
    ExerciseKind.quiz: _composite,
    ExerciseKind.exam: _composite,
    for (final kind in [
      ExerciseKind.matching,
      ExerciseKind.listeningMatching,
      ExerciseKind.imageMatching,
      ExerciseKind.categorization,
    ])
      kind: _mapping,
    for (final kind in [
      ExerciseKind.wordOrder,
      ExerciseKind.sentenceOrder,
      ExerciseKind.fillBlanks,
      ExerciseKind.table,
      ExerciseKind.conjugation,
    ])
      kind: _structured,
    for (final kind in [
      ExerciseKind.fillBlank,
      ExerciseKind.shortAnswer,
      ExerciseKind.translation,
      ExerciseKind.dictation,
      ExerciseKind.errorCorrection,
      ExerciseKind.diacritics,
    ])
      kind: _text,
    for (final kind in [
      ExerciseKind.dialogue,
      ExerciseKind.writing,
      ExerciseKind.speaking,
      ExerciseKind.pronunciation,
      ExerciseKind.unknown,
    ])
      kind: _manual,
  };

  static ExerciseResult _result(Exercise exercise, bool correct) =>
      ExerciseResult(
        status: correct ? ExerciseStatus.correct : ExerciseStatus.incorrect,
        points: correct ? exercise.config.points : 0,
        explanation: exercise.explanation,
        score: correct ? 1 : 0,
        passThreshold: exercise.config.passThreshold,
        maxPoints: exercise.config.points,
      );

  static ExerciseResult _manual(Exercise exercise, dynamic answer) =>
      ExerciseResult(
        status: ExerciseStatus.needsReview,
        points: 0,
        explanation: exercise.explanation,
        passThreshold: exercise.config.passThreshold,
      );

  static ExerciseResult _composite(Exercise exercise, dynamic answer) =>
      _compositeAtDepth(exercise, answer, 0);

  static ExerciseResult _compositeAtDepth(
    Exercise exercise,
    dynamic answer,
    int depth,
  ) {
    final questions = exercise.data['questions'];
    if (depth > 8 ||
        questions is! List ||
        questions.isEmpty ||
        questions.length > 100 ||
        questions.any((x) => x is! Map)) {
      return _manual(exercise, answer);
    }
    final children = questions
        .map((x) => Exercise.fromJson(Map<String, dynamic>.from(x as Map)))
        .toList();
    final ids = children.map((x) => x.id).toSet();
    if (ids.length != children.length || ids.contains('')) {
      return _manual(exercise, answer);
    }
    if (answer is! Map || answer.keys.any((x) => !ids.contains(x))) {
      return _result(exercise, false);
    }
    var earned = 0;
    var possible = 0;
    var pending = false;
    for (final child in children) {
      final result =
          child.kind == ExerciseKind.quiz || child.kind == ExerciseKind.exam
          ? _compositeAtDepth(child, answer[child.id], depth + 1)
          : evaluate(child, answer[child.id]);
      earned += result.points;
      possible += result.maxPoints ?? child.config.points;
      pending |= result.status == ExerciseStatus.needsReview;
    }
    if (pending || possible == 0) return _manual(exercise, answer);
    final score = earned / possible;
    final passed =
        earned > 0 &&
        score >= exercise.config.passThreshold &&
        answer.length == ids.length;
    return ExerciseResult(
      status: passed ? ExerciseStatus.correct : ExerciseStatus.incorrect,
      points: earned,
      score: score,
      passThreshold: exercise.config.passThreshold,
      maxPoints: possible,
      explanation:
          '${exercise.explanation ?? ''}\nРезультат: $earned/$possible.',
    );
  }

  static bool _validIndex(dynamic index, Exercise exercise) =>
      index is int && index >= 0 && index < exercise.options.length;

  static bool _validOptions(Exercise exercise) =>
      exercise.options.isNotEmpty &&
      exercise.options.every((option) => option.trim().isNotEmpty);

  static ExerciseResult _choice(Exercise exercise, dynamic answer) {
    if (!_validOptions(exercise) || !_validIndex(exercise.correct, exercise)) {
      return _manual(exercise, answer);
    }
    return _result(
      exercise,
      _validIndex(answer, exercise) && answer == exercise.correct,
    );
  }

  static bool _indices(dynamic value, Exercise exercise) =>
      value is List &&
      value.isNotEmpty &&
      value.every((item) => _validIndex(item, exercise)) &&
      value.toSet().length == value.length;

  static ExerciseResult _multiple(Exercise exercise, dynamic answer) {
    final key = exercise.correct;
    if (!_validOptions(exercise) || !_indices(key, exercise)) {
      return _manual(exercise, answer);
    }
    return _result(
      exercise,
      _indices(answer, exercise) &&
          (answer as List).length == (key as List).length &&
          answer.every((item) => key.contains(item)),
    );
  }

  static ExerciseResult _boolean(Exercise exercise, dynamic answer) {
    if (exercise.correct is! bool) return _manual(exercise, answer);
    return _result(exercise, answer is bool && answer == exercise.correct);
  }

  static ExerciseResult _mapping(Exercise exercise, dynamic answer) {
    final key = exercise.correct;
    if (key is! Map ||
        key.isEmpty ||
        key.keys.any((item) => item is! String || item.trim().isEmpty) ||
        key.values.any((item) => item is! String || item.trim().isEmpty)) {
      return _manual(exercise, answer);
    }
    // Matching values are identifiers, not prose. Do not normalize them.
    return _result(
      exercise,
      answer is Map &&
          answer.length == key.length &&
          key.keys.every(
            (item) =>
                answer.containsKey(item) &&
                answer[item] is String &&
                answer[item] == key[item],
          ),
    );
  }

  static String _normalize(Exercise exercise, String value) =>
      ArabicNormalization.forGrading(
        value,
        ignoreDiacritics: exercise.config.ignoreDiacritics,
      );

  static bool _validText(Exercise exercise, dynamic value) =>
      value is String && _normalize(exercise, value).isNotEmpty;

  static ExerciseResult _text(Exercise exercise, dynamic answer) {
    final alternatives = exercise.data['acceptedAnswers'];
    final List<dynamic> keys;
    if (exercise.data.containsKey('acceptedAnswers')) {
      if (alternatives is! List ||
          alternatives.isEmpty ||
          !alternatives.every((value) => _validText(exercise, value))) {
        return _manual(exercise, answer);
      }
      keys = alternatives;
    } else {
      if (!_validText(exercise, exercise.correct)) {
        return _manual(exercise, answer);
      }
      keys = [exercise.correct];
    }
    return _result(
      exercise,
      _validText(exercise, answer) &&
          keys.any(
            (key) =>
                _normalize(exercise, key as String) ==
                _normalize(exercise, answer as String),
          ),
    );
  }

  static bool _validStructure(Exercise exercise, dynamic value) {
    if (value is String) return _validText(exercise, value);
    if (value is List) {
      return value.isNotEmpty &&
          value.every((item) => _validStructure(exercise, item));
    }
    if (value is Map) {
      return value.isNotEmpty &&
          value.keys.every((key) => key is String && key.trim().isNotEmpty) &&
          value.values.every((item) => _validStructure(exercise, item));
    }
    return false;
  }

  static bool _equalStructure(Exercise exercise, dynamic key, dynamic answer) {
    if (key is String) {
      return answer is String &&
          _normalize(exercise, key) == _normalize(exercise, answer);
    }
    if (key is List) {
      return answer is List &&
          key.length == answer.length &&
          List.generate(key.length, (index) => index).every(
            (index) => _equalStructure(exercise, key[index], answer[index]),
          );
    }
    if (key is Map) {
      return answer is Map &&
          key.length == answer.length &&
          key.keys.every(
            (item) =>
                answer.containsKey(item) &&
                _equalStructure(exercise, key[item], answer[item]),
          );
    }
    return false;
  }

  static ExerciseResult _structured(Exercise exercise, dynamic answer) {
    if (exercise.kind == ExerciseKind.wordOrder ||
        exercise.kind == ExerciseKind.sentenceOrder) {
      final key = exercise.correct;
      if (key is! List ||
          key.isEmpty ||
          !key.every((item) => _validText(exercise, item))) {
        return _manual(exercise, answer);
      }
    }
    if (!_validStructure(exercise, exercise.correct)) {
      return _manual(exercise, answer);
    }
    return _result(
      exercise,
      _equalStructure(exercise, exercise.correct, answer),
    );
  }
}
