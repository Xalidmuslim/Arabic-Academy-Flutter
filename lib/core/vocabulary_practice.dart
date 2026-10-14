import 'academy_state.dart';
import 'vocabulary_key.dart';
import '../features/exercises/arabic_normalization.dart';

/// Words come exclusively from the user's available lesson catalog.
/// We never synthesize translations or infer missing Arabic editorial text.
class VocabularyPracticeWord {
  const VocabularyPracticeWord({
    required this.id,
    required this.ar,
    required this.ru,
    required this.lessonId,
    required this.lessonTitle,
  });
  final String id;
  final String ar;
  final String ru;
  final String lessonId;
  final String lessonTitle;
}

enum VocabularyChallenge {
  arabicToRussian,
  russianToArabic,
  listening,
  writeArabic,
}

class VocabularyPracticePlan {
  const VocabularyPracticePlan({
    required this.words,
    required this.due,
    required this.newWords,
    required this.totalEligible,
  });

  final List<VocabularyPracticeWord> words;
  final int due;
  final int newWords;
  final int totalEligible;
}

abstract final class VocabularyPractice {
  static List<VocabularyPracticeWord> words(AcademyState state,
      {String? lessonId}) {
    final result = <VocabularyPracticeWord>[];
    for (final lesson in state.allLessons) {
      final id = lesson['id'];
      if (id is! String || id.isEmpty ||
          (lessonId != null && id != lessonId)) continue;
      final vocabulary = lesson['vocabulary'];
      if (vocabulary is! List) continue;
      for (var i = 0; i < vocabulary.length; i++) {
        final word = vocabulary[i];
        if (word is! Map) continue;
        final ar = (word['ar'] as String? ?? '').trim();
        final ru = (word['ru'] as String? ?? '').trim();
        if (ar.isEmpty || ru.isEmpty) {
        continue;
      }
        result.add(VocabularyPracticeWord(
          id: vocabularyKey(id, i, word),
          ar: ar,
          ru: ru,
          lessonId: id,
          lessonTitle: lesson['title']?.toString() ?? '',
        ));
      }
    }
    return result;
  }

  static bool isDue(Map<dynamic, dynamic> review, DateTime now) {
    final due = DateTime.tryParse(review['due_at']?.toString() ?? '');
    // Broken or missing scheduling metadata must not strand a studied word.
    return due == null || !due.isAfter(now);
  }

  static VocabularyPracticePlan plan(AcademyState state, {
    String? lessonId,
    DateTime? now,
    int newLimit = 8,
    int dueLimit = 20,
  }) {
    final current = now ?? DateTime.now();
    final eligible = words(state, lessonId: lessonId);
    final reviews = state.reviews;
    final due = <VocabularyPracticeWord>[];
    final fresh = <VocabularyPracticeWord>[];
    for (final word in eligible) {
      final metadata = reviews[word.id];
      if (metadata is Map) {
        if (isDue(metadata, current)) due.add(word);
      } else {
        fresh.add(word);
      }
    }
    // Missed sessions are prioritized and never silently treated as learned.
    due.sort((a, b) {
      final left = (reviews[a.id] as Map)['due_at']?.toString() ?? '';
      final right = (reviews[b.id] as Map)['due_at']?.toString() ?? '';
      return left.compareTo(right);
    });
    final dueBatch = due.take(dueLimit).toList();
    final newBatch = fresh.take(newLimit).toList();
    return VocabularyPracticePlan(
      words: [...dueBatch, ...newBatch],
      due: due.length,
      newWords: fresh.length,
      totalEligible: eligible.length,
    );
  }

  /// Accent marks may be omitted, but hamza, alif and taa marbuta remain
  /// significant. Search normalization must never be used for grading.
  static bool matchesArabic(String submitted, String expected) {
    return ArabicNormalization.forGrading(
          submitted, ignoreDiacritics: true) ==
        ArabicNormalization.forGrading(
          expected, ignoreDiacritics: true);
  }

  static VocabularyChallenge challengeAt(int index) => switch (index % 4) {
    0 => VocabularyChallenge.arabicToRussian,
    1 => VocabularyChallenge.russianToArabic,
    2 => VocabularyChallenge.writeArabic,
    _ => VocabularyChallenge.listening,
  };

  static List<String> options({
    required VocabularyPracticeWord correct,
    required List<VocabularyPracticeWord> all,
    required VocabularyChallenge type,
  }) {
    final arabic = type == VocabularyChallenge.russianToArabic;
    String value(VocabularyPracticeWord word) =>
        arabic ? word.ar : word.ru;
    final answer = value(correct);
    final distractors = <String>[];
    final seen = <String>{answer.toLowerCase()};
    for (final item in all) {
      if (item.id == correct.id) continue;
      final candidate = value(item);
      if (seen.add(candidate.toLowerCase())) {
        distractors.add(candidate);
        if (distractors.length == 3) break;
      }
    }
    final result = [answer, ...distractors];
    // Deterministic rotation avoids always placing the correct answer first,
    // while remaining stable between rebuilds.
    if (result.length > 1) {
      final offset = (correct.id.codeUnits.fold<int>(
          0, (sum, n) => sum + n) + type.index) % result.length;
      return [...result.skip(offset), ...result.take(offset)];
    }
    return result;
  }
}
