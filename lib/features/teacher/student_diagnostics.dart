import '../../core/academy_state.dart';
import '../../core/learning_insights.dart';
import '../../core/vocabulary_practice.dart';
import 'demo_school_store.dart';

/// Teacher-facing read model. A demo pupil is NEVER assumed to own the
/// device-wide AcademyState. Only s1 uses that learning data in the local
/// single-device demonstration; other demo pupils have isolated grades/rubrics.
class StudentSkillDiagnostic {
  const StudentSkillDiagnostic({
    required this.id,
    required this.title,
    required this.attempts,
    required this.correct,
    required this.errors,
    required this.pendingManual,
    required this.teacherScores,
    required this.notes,
    required this.pronunciationCriteria,
  });

  final String id;
  final String title;
  final int attempts;
  final int correct;
  final int errors;
  final int pendingManual;
  final List<int> teacherScores;
  final List<String> notes;
  final Map<String, double> pronunciationCriteria;

  double? get automaticAccuracy =>
      attempts == 0 ? null : correct / attempts;
  double? get teacherAverage => teacherScores.isEmpty
      ? null
      : teacherScores.reduce((a, b) => a + b) / teacherScores.length;
  bool get hasEvidence => attempts > 0 || teacherScores.isNotEmpty ||
      pendingManual > 0;

  /// Deliberately no made-up "mastery" score for untested areas.
  String get status {
    if (automaticAccuracy == null && teacherAverage == null) {
      return pendingManual > 0 ? 'Ожидает ручной проверки' : 'Нет проверки';
    }
    final value = automaticAccuracy ?? (teacherAverage! / 100);
    if (value < .6) return 'Нужна помощь';
    if (value < .8) return 'Закрепляется';
    return 'Хороший результат';
  }
}

class StudentWordDiagnostic {
  const StudentWordDiagnostic({
    required this.arabic,
    required this.translation,
    required this.stage,
    required this.lapses,
    required this.due,
  });
  final String arabic;
  final String translation;
  final int stage;
  final int lapses;
  final bool due;
}

class StudentErrorDiagnostic {
  const StudentErrorDiagnostic({
    required this.skill,
    required this.lesson,
    required this.response,
    required this.expected,
    required this.explanation,
    required this.count,
  });
  final String skill;
  final String lesson;
  final String response;
  final String expected;
  final String explanation;
  final int count;
}

class StudentLearningReport {
  StudentLearningReport._({
    required this.studentId,
    required this.localLearningAvailable,
    required this.skills,
    required this.lessonCount,
    required this.sampleLessonScores,
    required this.assigned,
    required this.submitted,
    required this.graded,
    required this.revision,
    required this.gradedHomeworkAverage,
    required this.wordReviewed,
    required this.wordMastered,
    required this.wordDue,
    required this.wordDifficult,
    required this.wordLapses,
    required this.hardWords,
    required this.errors,
    required this.totalAttemptCount,
    required this.daysStudied,
    required this.recentAttemptCount,
    required this.lastActivity,
    required this.recommendations,
  });

  final String studentId;
  final bool localLearningAvailable;
  final List<StudentSkillDiagnostic> skills;
  final int lessonCount;
  final List<Map<String, dynamic>> sampleLessonScores;
  final int assigned;
  final int submitted;
  final int graded;
  final int revision;
  final double? gradedHomeworkAverage;
  final int wordReviewed;
  final int wordMastered;
  final int wordDue;
  final int wordDifficult;
  final int wordLapses;
  final List<StudentWordDiagnostic> hardWords;
  final List<StudentErrorDiagnostic> errors;
  final int totalAttemptCount;
  final int daysStudied;
  final int recentAttemptCount;
  final DateTime? lastActivity;
  final List<String> recommendations;

  static const pronunciationCriteriaLabels = <String, String>{
    'consonants': 'Согласные и махрадж',
    'vowels': 'Долгие/краткие гласные',
    'endings': 'Огласовки и окончания',
    'fluency': 'Плавность речи',
  };

  static const skillNames = <String, String>{
    'words': 'Запоминание слов',
    'grammar': 'Грамматика',
    'listening': 'Аудирование',
    'reading': 'Чтение',
    'writing': 'Письмо',
    'dialogue': 'Диалоги',
    'pronunciation': 'Произношение',
  };

  StudentSkillDiagnostic skill(String id) =>
      skills.firstWhere((x) => x.id == id);

  static StudentLearningReport build(
    DemoSchoolStore school,
    AcademyState learning,
    String studentId, {
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    // Only the first DEMO profile is associated with persisted device work.
    final local = studentId == 's1';
    final attempts = local ? learning.attempts : <Map<String, dynamic>>[];
    final reviews = local ? learning.reviews : <String, dynamic>{};
    final assigned = school.homeworkFor(studentId);
    final submissions = <Map<String, dynamic>>[];
    for (final assignment in assigned) {
      final submission = school.submissionFor(
        assignment['id'] as String, studentId,
      );
      if (submission != null) submissions.add(submission);
    }
    final done = submissions.where((x) => x['status'] == 'graded' &&
        x['grade'] is num).toList();
    final revision = submissions
        .where((x) => x['status'] == 'revision_requested').length;
    final teacherAssessments = school.skillAssessmentsFor(studentId);
    final skillList = <StudentSkillDiagnostic>[];
    final mistakes = <StudentErrorDiagnostic>[];
    final lastPerExercise = <String, Map<String, dynamic>>{};
    final historicalErrors = <String, int>{};

    for (final attempt in attempts) {
      final id = attempt['exercise_id']?.toString() ?? '';
      if (id.isEmpty || id.startsWith('practice:exam:')) continue;
      lastPerExercise[id] = attempt;
      if (attempt['status'] == 'incorrect') {
        historicalErrors[id] = (historicalErrors[id] ?? 0) + 1;
      }
    }

    final sampleScores = school.studentResults(studentId);
    final seenDays = <String>{};
    var recentAttempts = 0;
    DateTime? mostRecent;
    void observe(dynamic raw) {
      final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
      if (date == null) return;
      if (mostRecent == null || date.isAfter(mostRecent!)) {
        mostRecent = date;
      }
    }

    for (final attempt in attempts) {
      final date = DateTime.tryParse(
        attempt['created_at']?.toString() ?? '',
      )?.toLocal();
      if (date == null) continue;
      seenDays.add('${date.year}-${date.month}-${date.day}');
      if (!date.isBefore(at.subtract(const Duration(days: 7)))) {
        recentAttempts++;
      }
      observe(date.toIso8601String());
    }
    for (final submission in submissions) {
      observe(submission['updated_at']);
    }
    for (final review in reviews.values) {
      if (review is Map) observe(review['last_review']);
    }
    for (final assessment in teacherAssessments) {
      observe(assessment['at']);
    }

    for (final category in skillNames.entries) {
      var correct = 0;
      var errors = 0;
      var pending = 0;
      final scores = <int>[];
      final notes = <String>[];
      final criteria = <String, List<int>>{};
      for (final attempt in attempts) {
        if (LearningInsights.classify(attempt) != category.key) continue;
        if (attempt['status'] == 'correct') correct++;
        if (attempt['status'] == 'incorrect') errors++;
        if (attempt['status'] == 'needsReview') pending++;
      }
      for (final item in teacherAssessments) {
        if (item['skill'] != category.key) continue;
        final score = item['score'];
        if (score is num) scores.add(score.round());
        final rubric = item['criteria'];
        if (category.key == 'pronunciation' && rubric is Map) {
          for (final entry in rubric.entries) {
            if (pronunciationCriteriaLabels.containsKey(entry.key) &&
                entry.value is num) {
              criteria.putIfAbsent(entry.key as String, () => <int>[])
                  .add((entry.value as num).round());
            }
          }
        }
        final note = item['note']?.toString() ?? '';
        if (note.trim().isNotEmpty) notes.add(note);
      }
      for (final submission in submissions) {
        if (submission['status'] != 'graded' &&
            submission['status'] != 'revision_requested') {
          continue;
        }
        final assignments = assigned.where(
          (row) => row['id'] == submission['assignment_id'],
        );
        if (assignments.isEmpty ||
            assignments.first['skill'] != category.key) {
          continue;
        }
        if (submission['grade'] is num) {
          scores.add((submission['grade'] as num).round());
        }
        final note = submission['feedback']?.toString() ?? '';
        if (note.trim().isNotEmpty) notes.add(note);
      }

      skillList.add(StudentSkillDiagnostic(
        id: category.key,
        title: category.value,
        attempts: correct + errors,
        correct: correct,
        errors: errors,
        pendingManual: pending,
        teacherScores: scores,
        notes: notes.take(3).toList(),
        pronunciationCriteria: {
          for (final entry in criteria.entries)
            if (entry.value.isNotEmpty)
              entry.key: entry.value.reduce((a, b) => a + b) /
                  entry.value.length,
        },
      ));
    }

    final lessonNames = <String, String>{
      for (final item in learning.allLessons)
        if (item['id'] is String)
          item['id'] as String: item['title']?.toString() ?? '',
    };
    for (final row in lastPerExercise.entries) {
      final attempt = row.value;
      if (attempt['status'] != 'incorrect') continue;
      final kind = LearningInsights.classify(attempt) ?? 'general';
      final payload = attempt['answer'];
      final details = payload is Map ? payload : <String, dynamic>{};
      final lessonId = attempt['lesson_id']?.toString() ?? '';
      mistakes.add(StudentErrorDiagnostic(
        skill: skillNames[kind] ?? 'Упражнения',
        lesson: lessonNames[lessonId] ?? lessonId,
        response: details['response']?.toString() ??
            (payload is String ? payload : ''),
        expected: details['expected']?.toString() ?? '',
        explanation: details['feedback']?.toString() ?? '',
        count: historicalErrors[row.key] ?? 1,
      ));
    }
    mistakes.sort((a, b) => b.count.compareTo(a.count));

    final wordList = <StudentWordDiagnostic>[];
    final terms = <String, VocabularyPracticeWord>{
      if (local)
        for (final word in VocabularyPractice.words(learning))
          word.id: word,
    };
    var wordMastered = 0;
    var wordDue = 0;
    var wordDifficult = 0;
    var wordLapses = 0;
    for (final entry in reviews.entries) {
      if (entry.value is! Map) continue;
      final review = entry.value as Map;
      final stage = (review['stage'] as int? ?? 0).clamp(0, 5);
      final lapses = review['lapses'] as int? ?? 0;
      final isDue = VocabularyPractice.isDue(review, at);
      final difficult = review['difficult'] == true || lapses > 0;
      if (stage >= 2) wordMastered++;
      if (isDue) wordDue++;
      if (difficult) wordDifficult++;
      wordLapses += lapses;
      if (difficult || isDue) {
        final word = terms[entry.key];
        wordList.add(StudentWordDiagnostic(
          arabic: word?.ar ?? 'Слово из прошлого урока',
          translation: word?.ru ?? 'Нет в текущем каталоге',
          stage: stage,
          lapses: lapses,
          due: isDue,
        ));
      }
    }
    wordList.sort((a, b) {
      final diff = b.lapses.compareTo(a.lapses);
      return diff == 0 ? a.stage.compareTo(b.stage) : diff;
    });

    final recommendations = <String>[];
    if (reviews.isEmpty && attempts.isEmpty) {
      recommendations.add('Начните с короткой проверки слов и грамматики, '
          'чтобы собрать первые измеримые результаты.');
    }
    if (wordDue > 0 || wordLapses > 0) {
      recommendations.add('Дайте повторить $wordDue слов по расписанию; '
          'повторных забываний: $wordLapses. Проверьте трудные слова '
          'через аудио и самостоятельное воспроизведение.');
    }
    final weak = skillList.where(
      (skill) => skill.attempts >= 2 &&
          (skill.automaticAccuracy ?? 1) < .7,
    );
    for (final skill in weak.take(2)) {
      recommendations.add('Зона внимания: ${skill.title.toLowerCase()} — '
          '${skill.correct} верно из ${skill.attempts}. '
          'Назначьте короткое адресное упражнение.');
    }
    final pronunciation = skillList.firstWhere(
      (entry) => entry.id == 'pronunciation',
    );
    if (pronunciation.teacherScores.isEmpty) {
      recommendations.add('Произношение не оценено: '
          'попросите записать голос и проверьте вручную.');
    } else if ((pronunciation.teacherAverage ?? 100) < 70) {
      recommendations.add('Произношение нуждается в повторной '
          'ручной проверке с образцом арабской речи.');
    }
    if (revision > 0) {
      recommendations.add('Проверьте $revision работ, возвращённых '
          'на исправление.');
    }
    if (recommendations.isEmpty) {
      recommendations.add('Продолжайте практику разных навыков и '
          'возвращайтесь к повторениям по расписанию.');
    }

    final gradeMean = done.isEmpty ? null :
        done.fold<int>(0, (sum, item) =>
          sum + (item['grade'] as num).round()) / done.length;
    return StudentLearningReport._(
      studentId: studentId,
      localLearningAvailable: local,
      skills: skillList,
      lessonCount: local ? learning.completed.length : 0,
      sampleLessonScores: sampleScores,
      assigned: assigned.length,
      submitted: submissions.length,
      graded: done.length,
      revision: revision,
      gradedHomeworkAverage: gradeMean,
      wordReviewed: reviews.values.whereType<Map>().length,
      wordMastered: wordMastered,
      wordDue: wordDue,
      wordDifficult: wordDifficult,
      wordLapses: wordLapses,
      hardWords: wordList.take(10).toList(),
      errors: mistakes.take(12).toList(),
      totalAttemptCount: attempts.length,
      daysStudied: seenDays.length,
      recentAttemptCount: recentAttempts,
      lastActivity: mostRecent,
      recommendations: recommendations,
    );
  }
}
