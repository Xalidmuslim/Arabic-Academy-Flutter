enum ExerciseStatus { correct, incorrect, needsReview }

class ExerciseResult {
  const ExerciseResult({
    required this.status,
    required this.points,
    this.explanation,
    this.score = 0,
    this.passThreshold = 1,
    this.maxPoints,
  });

  final ExerciseStatus status;
  final int points;
  final String? explanation;
  final double score;
  final double passThreshold;
  final int? maxPoints;

  bool get passed => status == ExerciseStatus.correct && score >= passThreshold;
}
