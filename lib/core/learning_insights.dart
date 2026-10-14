import 'academy_state.dart';
import 'vocabulary_practice.dart';
import 'adaptive_review.dart';

class SkillProgress {
  const SkillProgress({
    required this.id, required this.name,
    required this.correct, required this.total,
  });
  final String id;
  final String name;
  final int correct;
  final int total;
  double? get accuracy => total == 0 ? null : correct / total;
  int get percent => ((accuracy ?? 0) * 100).round();
}

/// The app never invents mastery from page views. Missing assessment evidence
/// is reported as "не проверено", not as 0% knowledge.
abstract final class LearningInsights {
  static const skillLabels = <String, String>{
    'words': 'Словарь',
    'grammar': 'Грамматика',
    'listening': 'Аудирование',
    'reading': 'Чтение',
    'writing': 'Письмо',
    'dialogue': 'Диалог',
    'pronunciation': 'Произношение',
  };

  static String? classify(Map<String, dynamic> attempt) {
    final id = attempt['exercise_id']?.toString() ?? '';
    if (id.startsWith('practice:')) {
      if (id.startsWith('practice:quiz:') ||
          id.startsWith('practice:illustrations:')) {
        return 'words';
      }
      if (id.startsWith('practice:missingWord:') ||
          id.startsWith('practice:sentence:')) {
        return 'grammar';
      }
      if (id.startsWith('practice:dictation:')) return 'listening';
      if (id.startsWith('practice:dialogue:')) return 'dialogue';
      if (id.startsWith('practice:exam:')) return null;
    }
    if (id.startsWith('handwriting:')) return 'writing';
    if (id.startsWith('pronunciation:')) return 'pronunciation';
    if (id.startsWith('reader:')) return 'reading';
    if (id.startsWith('voice:')) return 'listening';
    return null;
  }

  static List<SkillProgress> skills(AcademyState state) {
    final totals = <String, int>{};
    final corrects = <String, int>{};
    for (final item in state.attempts) {
      final skill = classify(item);
      if (skill == null) continue;
      if (item['status'] != 'correct' && item['status'] != 'incorrect') {
        continue;
      }
      totals[skill] = (totals[skill] ?? 0) + 1;
      if (item['status'] == 'correct') {
        corrects[skill] = (corrects[skill] ?? 0) + 1;
      }
    }
    return [
      for (final entry in skillLabels.entries)
        SkillProgress(
          id: entry.key, name: entry.value,
          correct: corrects[entry.key] ?? 0,
          total: totals[entry.key] ?? 0,
        ),
    ];
  }

  static String? weakestSkill(AcademyState state) {
    final measured = skills(state).where((skill) => skill.total >= 2)
        .toList()
      ..sort((a, b) => a.percent.compareTo(b.percent));
    return measured.isEmpty ? null : measured.first.id;
  }

  static int reviewGoal(AcademyState state) {
    final attempts = state.attempts
        .where((row) => row['status'] == 'correct' ||
            row['status'] == 'incorrect').toList();
    if (attempts.length < 8) return 8;
    final recent = attempts.reversed.take(20).toList();
    final correct = recent.where((row) => row['status'] == 'correct').length;
    final accuracy = correct / recent.length;
    return accuracy < .6 ? 5 : accuracy < .8 ? 8 : 12;
  }

  static int totalMasteredWords(AcademyState state) =>
      state.reviews.values.where((entry) =>
          entry is Map && AdaptiveReview.mastery(entry) >= .7).length;

  static Map<String, int> lessonMistakes(AcademyState state) {
    final latest = <String, Map<String, dynamic>>{};
    for (final attempt in state.attempts) {
      final id = attempt['exercise_id']?.toString() ?? '';
      if (id.isEmpty || id.startsWith('practice:exam:')) continue;
      latest[id] = attempt;
    }
    final counts = <String, int>{};
    for (final attempt in latest.values) {
      if (attempt['status'] != 'incorrect') continue;
      final lesson = attempt['lesson_id']?.toString() ?? '';
      if (lesson.isNotEmpty) counts[lesson] = (counts[lesson] ?? 0) + 1;
    }
    return counts;
  }

  static DailyLearningPlan dailyPlan(AcademyState state, {DateTime? now}) {
    final when = now ?? DateTime.now();
    final review = VocabularyPractice.plan(
      state, now: when, newLimit: reviewGoal(state),
    );
    final weak = weakestSkill(state);
    final incomplete = state.allLessons.where((lesson) =>
        !state.completed.contains(lesson['id'])).toList();
    final today = DateTime(when.year, when.month, when.day);
    final practicedToday = state.attempts.where((row) {
      final at = DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal();
      return at != null &&
          at.year == today.year &&
          at.month == today.month &&
          at.day == today.day;
    }).length;
    return DailyLearningPlan(
      due: review.due,
      newWordLimit: reviewGoal(state),
      recommendedLessonId: incomplete.isEmpty
          ? null : incomplete.first['id']?.toString(),
      weakSkill: weak,
      completedQuestionsToday: practicedToday,
    );
  }
}

class DailyLearningPlan {
  const DailyLearningPlan({
    required this.due, required this.newWordLimit,
    required this.recommendedLessonId,
    required this.weakSkill, required this.completedQuestionsToday,
  });
  final int due;
  final int newWordLimit;
  final String? recommendedLessonId;
  final String? weakSkill;
  final int completedQuestionsToday;
}
