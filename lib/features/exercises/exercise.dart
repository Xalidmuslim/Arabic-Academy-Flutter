import 'dart:math';

/// The local exercise taxonomy. Unknown wire names remain in [Exercise.data].
enum ExerciseKind {
  singleChoice,
  multipleChoice,
  trueFalse,
  matching,
  wordOrder,
  sentenceOrder,
  fillBlank,
  fillBlanks,
  table,
  shortAnswer,
  translation,
  dictation,
  listeningChoice,
  listeningMatching,
  readingComprehension,
  imageChoice,
  imageMatching,
  categorization,
  errorCorrection,
  diacritics,
  conjugation,
  dialogue,
  writing,
  speaking,
  pronunciation,
  quiz,
  exam,
  unknown;

  static ExerciseKind parse(dynamic value) {
    if (value is! String) return ExerciseKind.unknown;
    final name = value.replaceAll(RegExp(r'[_\-\s]'), '').toLowerCase();
    for (final kind in values) {
      if (kind.name.toLowerCase() == name) return kind;
    }
    return const {
          'choice': ExerciseKind.singleChoice,
          'mcq': ExerciseKind.singleChoice,
          'manual': ExerciseKind.writing,
          'voice': ExerciseKind.speaking,
          'fillintheblank': ExerciseKind.fillBlank,
          'grammaticalform': ExerciseKind.singleChoice,
          'gendernumber': ExerciseKind.singleChoice,
          'pronounpractice': ExerciseKind.singleChoice,
          'endingchoice': ExerciseKind.singleChoice,
          'audioquestion': ExerciseKind.listeningChoice,
          'oralrepetition': ExerciseKind.pronunciation,
          'voicerecording': ExerciseKind.speaking,
          'conversation': ExerciseKind.dialogue,
          'homework': ExerciseKind.writing,
          'miniquiz': ExerciseKind.quiz,
          'finalexam': ExerciseKind.exam,
        }[name] ??
        ExerciseKind.unknown;
  }
}

/// Immutable, deeply copied JSON. Unknown editorial fields are preserved.
class Exercise {
  Exercise._(this.data, this.kind, this.config);

  factory Exercise.fromJson(Map<String, dynamic> json) {
    final data = freezeExerciseValue(json) as Map<String, dynamic>;
    final legacyChoice =
        !data.containsKey('kind') &&
        !data.containsKey('type') &&
        data['options'] is List &&
        data['correct'] is int;
    return Exercise._(
      data,
      legacyChoice
          ? ExerciseKind.singleChoice
          : ExerciseKind.parse(data['kind'] ?? data['type']),
      ExerciseConfig.fromJson(data),
    );
  }

  final Map<String, dynamic> data;
  final ExerciseKind kind;
  final ExerciseConfig config;

  String get id => data['id'] is String ? data['id'] as String : '';
  String get prompt {
    final value = data['prompt'] ?? data['question'];
    return value is String ? value : '';
  }

  dynamic get correct => data['correct'];
  String? get explanation {
    final value = data['explanation'] ?? config.explanation;
    return value is String ? value : null;
  }

  List<String> get options {
    final value = data['options'];
    if (value is! List || value.any((item) => item is! String)) return const [];
    return List<String>.unmodifiable(value.cast<String>());
  }

  Map<String, dynamic> toJson() =>
      copyExerciseValue(data) as Map<String, dynamic>;
}

/// Config may be nested under `config` or use the same names at the top level.
/// Scores are all-or-nothing; [passThreshold] is a fraction from 0 through 1.
class ExerciseConfig {
  const ExerciseConfig({
    this.timeLimitSeconds,
    this.maxAttempts = 3,
    this.randomizeOptions = false,
    this.points = 1,
    this.passThreshold = 1,
    this.ignoreDiacritics = false,
    this.explanation,
  });

  factory ExerciseConfig.fromJson(Map<String, dynamic> data) {
    final nested = data['config'];
    if (nested != null && nested is! Map) {
      throw const FormatException('Exercise config must be an object.');
    }
    dynamic read(String key) =>
        nested is Map && nested.containsKey(key) ? nested[key] : data[key];

    int integer(String key, int fallback, {int minimum = 0}) {
      final value = read(key);
      if (value == null) return fallback;
      if (value is! int || value < minimum) {
        throw FormatException('$key must be an integer >= $minimum.');
      }
      return value;
    }

    bool boolean(String key) {
      final value = read(key);
      if (value == null) return false;
      if (value is! bool) throw FormatException('$key must be a boolean.');
      return value;
    }

    final threshold = read('passThreshold') ?? 1;
    if (threshold is! num ||
        !threshold.isFinite ||
        threshold < 0 ||
        threshold > 1) {
      throw const FormatException('passThreshold must be between 0 and 1.');
    }
    final explanation = read('explanation');
    if (explanation != null && explanation is! String) {
      throw const FormatException('explanation must be a string.');
    }
    return ExerciseConfig(
      timeLimitSeconds: read('timeLimitSeconds') == null
          ? null
          : integer('timeLimitSeconds', 1, minimum: 1),
      maxAttempts: integer('maxAttempts', 3, minimum: 1),
      randomizeOptions: boolean('randomizeOptions'),
      points: integer('points', 1),
      passThreshold: threshold.toDouble(),
      ignoreDiacritics: boolean('ignoreDiacritics'),
      explanation: explanation as String?,
    );
  }

  final int? timeLimitSeconds;
  final int maxAttempts;
  final bool randomizeOptions;
  final int points;
  final double passThreshold;
  final bool ignoreDiacritics;
  final String? explanation;
}

/// Also used to detach callback answers from the runner's mutable state.
dynamic freezeExerciseValue(dynamic value) {
  if (value is Map) {
    if (value.keys.any((key) => key is! String)) {
      throw const FormatException('JSON object keys must be strings.');
    }
    return Map<String, dynamic>.unmodifiable(
      value.map(
        (key, item) => MapEntry(key as String, freezeExerciseValue(item)),
      ),
    );
  }
  if (value is List) {
    return List<dynamic>.unmodifiable(value.map(freezeExerciseValue));
  }
  if (value == null ||
      value is String ||
      value is bool ||
      (value is num && value.isFinite)) {
    return value;
  }
  throw const FormatException('Exercise values must be JSON compatible.');
}

dynamic copyExerciseValue(dynamic value) {
  if (value is Map) {
    return value.map(
      (key, item) => MapEntry(key as String, copyExerciseValue(item)),
    );
  }
  if (value is List) return value.map(copyExerciseValue).toList();
  return value;
}

/// Stable shuffle seed, independent of Dart's process-specific string hash.
Random exerciseRandom(Exercise exercise) {
  var seed = 17;
  for (final unit in '${exercise.id}:${exercise.prompt}'.codeUnits) {
    seed = (seed * 31 + unit) & 0x7fffffff;
  }
  return Random(seed);
}
