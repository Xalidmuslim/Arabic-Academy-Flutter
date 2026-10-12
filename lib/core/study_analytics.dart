import 'academy_state.dart';

class StudyAnalytics {
  StudyAnalytics(this.state);
  final AcademyState state;
  int get totalLessons => state.allLessons.length;
  int get completedLessons =>
      state.allLessons.where((x) => state.completed.contains(x['id'])).length;
  double get progress =>
      totalLessons == 0 ? 0 : completedLessons / totalLessons;
  int get automaticAttempts => state.attempts
      .where((x) => ['correct', 'incorrect'].contains(x['status']))
      .length;
  int get correctAttempts =>
      state.attempts.where((x) => x['status'] == 'correct').length;
  double? get accuracy =>
      automaticAttempts == 0 ? null : correctAttempts / automaticAttempts;
  int get studySeconds => state.studySessions.fold(
    0,
    (sum, item) => sum + (item['seconds'] as int? ?? 0),
  );
  int get learnedWords => state.reviews.values
      .where((x) => x is Map && (x['stage'] as int? ?? 0) >= 2)
      .length;
  int get difficultWords => state.reviews.values
      .where((x) => x is Map && x['difficult'] == true)
      .length;
  Set<String> get activeDays => {
    for (final item in [...state.studySessions, ...state.attempts])
      if (DateTime.tryParse(item['created_at'] as String? ?? '') != null)
        dayKey(DateTime.parse(item['created_at'] as String).toLocal()),
  };
  static String dayKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  int streak({DateTime? now}) {
    final today = now ?? DateTime.now();
    var date = DateTime(today.year, today.month, today.day);
    final days = activeDays;
    if (!days.contains(dayKey(date))) {
      date = date.subtract(const Duration(days: 1));
    }
    var count = 0;
    while (days.contains(dayKey(date))) {
      count++;
      date = date.subtract(const Duration(days: 1));
    }
    return count;
  }

  List<Map<String, dynamic>> get mistakes => state.attempts
      .where((x) => x['status'] == 'incorrect')
      .toList()
      .reversed
      .toList();
}
