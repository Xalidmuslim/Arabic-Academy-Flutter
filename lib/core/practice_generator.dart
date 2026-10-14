import 'academy_state.dart';
import 'vocabulary_practice.dart';
import '../features/exercises/arabic_normalization.dart';

/// A practice question has provenance in a real catalog lesson. Exercises are
/// deterministic so that mistakes can be revisited after restarting the app.
enum PracticeMode { quiz, illustrations, sentence, missingWord, dictation, dialogue, exam, mistakes }

class PracticeQuestion {
  const PracticeQuestion({
    required this.id,
    required this.lessonId,
    required this.lessonTitle,
    required this.mode,
    required this.prompt,
    required this.answer,
    this.reference = '',
    this.options = const [],
    this.tokens = const [],
    this.word = '',
    this.translation = '',
  });
  final String id;
  final String lessonId;
  final String lessonTitle;
  final PracticeMode mode;
  final String prompt;
  final String answer;
  final String reference;
  final List<String> options;
  final List<String> tokens;
  final String word;
  final String translation;

  bool get usesChoices => options.length >= 2;
  bool get usesOrder => mode == PracticeMode.sentence;
  bool get usesSpeech => mode == PracticeMode.dictation;
}

abstract final class PracticeGenerator {
  static String _text(dynamic item) => item is String ? item.trim() : '';

  static String normalize(String input) =>
      ArabicNormalization.forGrading(input, ignoreDiacritics: true)
          .replaceAll(RegExp(r'[.،؟!?؛:…]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

  static bool matchesArabic(String response, String expected) =>
      normalize(response) == normalize(expected);

  static String utterance(String input) {
    // Many editorial dialogues prefix each line with a speaking role.
    final colon = input.indexOf(':');
    return colon < 0 ? input.trim() : input.substring(colon + 1).trim();
  }

  static List<Map<String, dynamic>> _lessons(AcademyState state, String? lessonId) =>
      state.allLessons.where((lesson) => lessonId == null ||
          lesson['id'] == lessonId).toList();

  static List<PracticeQuestion> build(
    AcademyState state,
    PracticeMode mode, {
    String? lessonId,
    String? moduleId,
    int limit = 12,
  }) {
    if (limit <= 0) return [];
    if (mode == PracticeMode.exam) {
      final sequence = <PracticeQuestion>[];
      for (final kind in [
        PracticeMode.quiz,
        PracticeMode.sentence,
        PracticeMode.missingWord,
        PracticeMode.dialogue,
        PracticeMode.dictation,
      ]) {
        sequence.addAll(build(state, kind, lessonId: lessonId, moduleId: moduleId, limit: 5));
      }
      // Interleave question types instead of forcing a block of each kind.
      final grouped = <PracticeMode, List<PracticeQuestion>>{};
      for (final q in sequence) {
        grouped.putIfAbsent(q.mode, () => []).add(q);
      }
      final result = <PracticeQuestion>[];
      while (grouped.values.any((items) => items.isNotEmpty) &&
          result.length < limit) {
        for (final kind in grouped.keys) {
          final items = grouped[kind]!;
          if (items.isNotEmpty && result.length < limit) {
            result.add(items.removeAt(0));
          }
        }
      }
      return result;
    }

    if (mode == PracticeMode.mistakes) {
      final failed = state.attempts
          .where((row) => row['status'] == 'incorrect')
          .map((row) => row['exercise_id']?.toString() ?? '')
          .where((id) => id.startsWith('practice:'))
          .toSet();
      if (failed.isEmpty) return [];
      final source = <PracticeQuestion>[];
      for (final kind in [
        PracticeMode.quiz,
        PracticeMode.illustrations,
        PracticeMode.sentence,
        PracticeMode.missingWord,
        PracticeMode.dictation,
        PracticeMode.dialogue,
      ]) {
        source.addAll(build(state, kind, lessonId: lessonId, moduleId: moduleId, limit: 300));
      }
      return source.where((q) => failed.contains(q.id)).take(limit).toList();
    }

    final catalog = _lessons(state, lessonId)
        .where((lesson) => moduleId == null || lesson['module_id'] == moduleId)
        .toList();
    final results = <PracticeQuestion>[];
    if (mode == PracticeMode.quiz || mode == PracticeMode.illustrations) {
      final allowedIds = catalog.map((lesson) => lesson['id']).toSet();
      final words = VocabularyPractice.words(state, lessonId: lessonId)
          .where((word) => allowedIds.contains(word.lessonId)).toList();
      final terms = words.where((word) =>
          mode != PracticeMode.illustrations ||
          IllustratedTerm.hasIllustration(word.ar)).toList();
      for (final term in terms) {
        final illustration = mode == PracticeMode.illustrations;
        final candidate = VocabularyPractice.options(
          correct: term,
          all: illustration ? terms : words,
          type: illustration
              ? VocabularyChallenge.russianToArabic
              : VocabularyChallenge.arabicToRussian,
        );
        if (candidate.length < 2) continue;
        results.add(PracticeQuestion(
          id: 'practice:${mode.name}:${term.id}',
          lessonId: term.lessonId,
          lessonTitle: term.lessonTitle,
          mode: mode,
          prompt: illustration
              ? 'Узнайте предмет по иллюстрации'
              : 'Выберите перевод арабского слова',
          word: term.ar,
          answer: illustration ? term.ar : term.ru,
          translation: term.ru,
          reference: term.ar,
          options: candidate,
        ));
        if (results.length >= limit) break;
      }
      return results;
    }

    for (final lesson in catalog) {
      final lessonIdValue = _text(lesson['id']);
      if (lessonIdValue.isEmpty) continue;
      final name = _text(lesson['title']);
      final lines = lesson['dialogue'];
      if (lines is! List) continue;
      final utterances = <({int index, String ar, String ru})>[];
      for (var i = 0; i < lines.length; i++) {
        final row = lines[i];
        if (row is! Map) continue;
        final ar = utterance(_text(row['ar']));
        final ru = utterance(_text(row['ru']));
        if (ar.isNotEmpty && ru.isNotEmpty) {
          utterances.add((index: i, ar: ar, ru: ru));
        }
      }
      for (var j = 0; j < utterances.length; j++) {
        final row = utterances[j];
        final tokens = row.ar.split(RegExp(r'\s+'))
            .where((s) => s.trim().isNotEmpty).toList();
        final id = 'practice:${mode.name}:$lessonIdValue:${row.index}';
        if (mode == PracticeMode.sentence && tokens.length >= 3 &&
            tokens.length <= 14) {
          results.add(PracticeQuestion(
            id: id, lessonId: lessonIdValue, lessonTitle: name,
            mode: mode, prompt: 'Соберите исходную фразу по её переводу',
            answer: row.ar, translation: row.ru,
            tokens: tokens, reference: row.ar,
          ));
        } else if (mode == PracticeMode.missingWord &&
            tokens.length >= 3 && tokens.length <= 18) {
          final hiddenIndex = tokens.length ~/ 2;
          final missing = tokens[hiddenIndex];
          if (normalize(missing).isEmpty) continue;
          final visible = [...tokens]..[hiddenIndex] = '_____';
          results.add(PracticeQuestion(
            id: id, lessonId: lessonIdValue, lessonTitle: name,
            mode: mode, prompt: 'Вставьте пропущенное арабское слово',
            answer: missing, reference: visible.join(' '),
            translation: row.ru, word: row.ar,
          ));
        } else if (mode == PracticeMode.dictation &&
            row.ar.length <= 180) {
          results.add(PracticeQuestion(
            id: id, lessonId: lessonIdValue, lessonTitle: name,
            mode: mode, prompt: 'Прослушайте и напишите арабскую фразу',
            answer: row.ar, reference: row.ar, translation: row.ru,
          ));
        } else if (mode == PracticeMode.dialogue &&
            j + 1 < utterances.length && j < 10) {
          final answer = utterances[j + 1].ar;
          final options = <String>[answer];
          for (final entry in utterances) {
            if (entry.ar != answer &&
                entry.ar != row.ar && !options.contains(entry.ar)) {
              options.add(entry.ar);
              if (options.length == 4) break;
            }
          }
          if (options.length < 2) continue;
          final shift = row.index % options.length;
          final rotated = [...options.skip(shift), ...options.take(shift)];
          results.add(PracticeQuestion(
            id: id, lessonId: lessonIdValue, lessonTitle: name,
            mode: mode, prompt: 'Выберите следующую реплику из диалога',
            answer: answer, options: rotated,
            reference: row.ar, translation: row.ru,
          ));
        }
        if (results.length >= limit) return results;
      }
    }
    return results;
  }
}

/// Illustrations are explicitly mapped by meaning. Unknown terms never show
/// an unrelated illustration. This is a limited semantic picture dictionary.
abstract final class IllustratedTerm {
  static const Map<String, String> concepts = {
    'كتاب': 'book', 'قلم': 'pen', 'باب': 'door', 'بيت': 'house',
    'مدرسة': 'school', 'حقيبة': 'bag', 'سيارة': 'car',
    'شجرة': 'tree', 'مسجد': 'mosque', 'سوق': 'market',
    'ساعة': 'clock', 'ماء': 'water', 'خبز': 'bread',
    'تفاح': 'apple', 'تفاحة': 'apple', 'شمس': 'sun',
    'قمر': 'moon', 'طائرة': 'plane', 'قط': 'cat', 'قطة': 'cat',
    'كرسي': 'chair', 'هاتف': 'phone', 'حاسوب': 'computer',
    'مفتاح': 'key', 'نافذة': 'window', 'زهرة': 'flower',
    'سمكة': 'fish', 'طعام': 'food', 'قميص': 'shirt',
    'بقرة': 'cow', 'حصان': 'horse', 'طبيب': 'doctor',
    'مستشفى': 'hospital', 'كوب': 'cup', 'مطبخ': 'kitchen',
  };
  static String? concept(String arabic) {
    final folded = ArabicNormalization.forGrading(
        arabic, ignoreDiacritics: true).replaceAll('ـ', '').trim();
    return concepts[folded];
  }
  static bool hasIllustration(String arabic) => concept(arabic) != null;
}
