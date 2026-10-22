import 'academy_state.dart';
import 'vocabulary_practice.dart';
import '../features/exercises/arabic_normalization.dart';

/// A practice question has provenance in a real catalog lesson. Exercises are
/// deterministic so that mistakes can be revisited after restarting the app.
enum PracticeMode { quiz, illustrations, sentence, missingWord, dictation, dialogue, exam, mistakes, reverseQuiz, listen, recall, matching, restoreDialogue, intensive, findError }

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
    this.pairs = const [],
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
  final List<({String ar, String ru})> pairs;

  bool get usesChoices => options.length >= 2;
  bool get usesOrder => mode == PracticeMode.sentence ||
      mode == PracticeMode.restoreDialogue;
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
    if (mode == PracticeMode.intensive) {
      // Mix genuine authored learning material across several different
      // retrieval formats. Never synthesize arbitrary incorrect Arabic.
      final types = <PracticeMode>[
        PracticeMode.matching,
        PracticeMode.quiz,
        PracticeMode.reverseQuiz,
        PracticeMode.listen,
        PracticeMode.recall,
        PracticeMode.illustrations,
        PracticeMode.sentence,
        PracticeMode.missingWord,
        PracticeMode.findError,
        PracticeMode.dialogue,
        PracticeMode.restoreDialogue,
        PracticeMode.dictation,
      ];
      final grouped = <PracticeMode, List<PracticeQuestion>>{
        for (final type in types)
          type: build(state, type, lessonId: lessonId,
              moduleId: moduleId, limit: 80),
      };
      // Review history rotates the starting point between sessions without
      // changing the stable question ID or its source.
      final offset = state.attempts.length;
      for (final items in grouped.values) {
        if (items.length > 1) {
          final first = offset % items.length;
          final rotated = [...items.skip(first), ...items.take(first)];
          items..clear()..addAll(rotated);
        }
      }
      final questions = <PracticeQuestion>[];
      final seen = <String>{};
      while (questions.length < limit && grouped.values.any(
          (items) => items.isNotEmpty)) {
        for (final type in types) {
          final items = grouped[type]!;
          if (items.isEmpty || questions.length >= limit) continue;
          final next = items.removeAt(0);
          if (seen.add(next.id)) questions.add(next);
        }
      }
      return questions;
    }

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
      // A corrected exercise stops being a current mistake. Historical
      // attempts remain visible in progress reports, without an endless
      // error queue for questions the learner can now answer.
      final latest = <String, String>{};
      for (final attempt in state.attempts) {
        final id = attempt['exercise_id']?.toString() ?? '';
        if (!id.startsWith('practice:') ||
            id.startsWith('practice:exam:')) {
          continue;
        }
        latest[id] = attempt['status']?.toString() ?? '';
      }
      final failed = latest.entries
          .where((entry) => entry.value == 'incorrect')
          .map((entry) => entry.key).toSet();
      if (failed.isEmpty) return [];
      final source = <PracticeQuestion>[];
      for (final kind in [
        PracticeMode.quiz,
        PracticeMode.illustrations,
        PracticeMode.sentence,
        PracticeMode.missingWord,
        PracticeMode.dictation,
        PracticeMode.dialogue,
        PracticeMode.reverseQuiz,
        PracticeMode.listen,
        PracticeMode.recall,
        PracticeMode.matching,
        PracticeMode.restoreDialogue,
        PracticeMode.findError,
      ]) {
        source.addAll(build(state, kind, lessonId: lessonId, moduleId: moduleId, limit: 300));
      }
      return source.where((q) => failed.contains(q.id)).take(limit).toList();
    }

    final catalog = _lessons(state, lessonId)
        .where((lesson) => moduleId == null || lesson['module_id'] == moduleId)
        .toList();
    final results = <PracticeQuestion>[];

    if (mode == PracticeMode.matching) {
      for (final lesson in catalog) {
        final id = _text(lesson['id']);
        if (id.isEmpty) continue;
        final source = VocabularyPractice.words(state, lessonId: id);
        final selected = <VocabularyPracticeWord>[];
        final arabic = <String>{};
        final russian = <String>{};
        for (final word in source) {
          if (arabic.add(word.ar) && russian.add(word.ru)) {
            selected.add(word);
          }
        }
        // Three or four independently verified pairs per round.
        for (var start = 0; start + 3 <= selected.length; start += 4) {
          final group = selected.skip(start).take(4).toList();
          if (group.length < 3) break;
          results.add(PracticeQuestion(
            id: 'practice:matching:$id:$start',
            lessonId: id, lessonTitle: _text(lesson['title']),
            mode: mode,
            prompt: 'Соедините арабские слова с переводами',
            answer: 'all-matched',
            pairs: [
              for (final word in group) (ar: word.ar, ru: word.ru),
            ],
          ));
          if (results.length >= limit) return results;
        }
      }
      return results;
    }

    if (mode == PracticeMode.quiz ||
        mode == PracticeMode.illustrations ||
        mode == PracticeMode.reverseQuiz ||
        mode == PracticeMode.listen ||
        mode == PracticeMode.recall) {
      final allowedIds = catalog.map((lesson) => lesson['id']).toSet();
      final words = VocabularyPractice.words(state, lessonId: lessonId)
          .where((word) => allowedIds.contains(word.lessonId)).toList();
      final terms = words.where((word) =>
          mode != PracticeMode.illustrations ||
          IllustratedTerm.hasIllustration(word.ar)).toList();
      for (final term in terms) {
        final illustration = mode == PracticeMode.illustrations;
        final arabicAnswer = illustration ||
            mode == PracticeMode.reverseQuiz;
        final typed = mode == PracticeMode.recall;
        final candidate = typed ? <String>[] : VocabularyPractice.options(
          correct: term,
          all: illustration ? terms : words,
          type: arabicAnswer ? VocabularyChallenge.russianToArabic
              : VocabularyChallenge.arabicToRussian,
        );
        if (!typed && candidate.length < 2) continue;
        results.add(PracticeQuestion(
          id: 'practice:${mode.name}:${term.id}',
          lessonId: term.lessonId,
          lessonTitle: term.lessonTitle,
          mode: mode,
          prompt: switch (mode) {
            PracticeMode.illustrations => 'Узнайте предмет по иллюстрации',
            PracticeMode.reverseQuiz => 'Найдите арабское слово',
            PracticeMode.listen => 'Послушайте и выберите перевод',
            PracticeMode.recall => 'Напишите слово по-арабски без подсказок',
            _ => 'Выберите перевод арабского слова',
          },
          word: term.ar,
          answer: arabicAnswer || typed ? term.ar : term.ru,
          translation: term.ru,
          reference: mode == PracticeMode.reverseQuiz ||
              mode == PracticeMode.recall ? term.ru : term.ar,
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
      if (mode == PracticeMode.restoreDialogue &&
          utterances.length >= 3) {
        for (var start = 0; start + 3 <= utterances.length; start += 4) {
          final lines = utterances.skip(start).take(4).toList();
          final tokens = lines.map((line) => line.ar).toList();
          results.add(PracticeQuestion(
            id: 'practice:restoreDialogue:$lessonIdValue:$start',
            lessonId: lessonIdValue,
            lessonTitle: name,
            mode: mode,
            prompt: 'Восстановите порядок реплик диалога',
            answer: tokens.join('\n'),
            reference: '', tokens: tokens,
          ));
          if (results.length >= limit) return results;
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
        } else if (mode == PracticeMode.findError &&
            tokens.length >= 3 && tokens.length <= 12) {
          // Deliberately replace exactly one word in an existing utterance.
          // Both the original and the distractor are real course vocabulary;
          // no invented Arabic sentence is presented as the source text.
          final sourceWords = VocabularyPractice.words(state,
              lessonId: lessonIdValue);
          final normalizedTokens = tokens.map(normalize).toSet();
          String? replacement;
          var changedIndex = -1;
          for (var i = 0; i < tokens.length; i++) {
            if (normalize(tokens[i]).isEmpty) continue;
            for (final vocab in sourceWords) {
              if (vocab.ar.trim().contains(' ')) continue;
              if (!normalizedTokens.contains(normalize(vocab.ar))) {
                replacement = vocab.ar;
                changedIndex = i;
                break;
              }
            }
            if (replacement != null) break;
          }
          if (replacement == null || changedIndex < 0) continue;
          final altered = [...tokens]..[changedIndex] = replacement;
          final seen = <String>{};
          final candidates = <String>[
            for (final token in altered)
              if (seen.add(normalize(token))) token,
          ];
          if (candidates.length < 2) continue;
          results.add(PracticeQuestion(
            id: id,
            lessonId: lessonIdValue,
            lessonTitle: name,
            mode: mode,
            prompt: 'Найдите слово, заменённое в исходном диалоге',
            answer: replacement,
            word: tokens[changedIndex],
            reference: altered.join(' '),
            translation: row.ru,
            options: candidates,
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
    'قمر': 'moon', 'طائرة': 'plane',
    'كرسي': 'chair', 'هاتف': 'phone', 'حاسوب': 'computer',
    'مفتاح': 'key', 'نافذة': 'window', 'زهرة': 'flower',
    'سمكة': 'fish', 'طعام': 'food', 'قميص': 'shirt',
    'طبيب': 'doctor',
    'مستشفى': 'hospital', 'كوب': 'cup',
  };
  static String? concept(String arabic) {
    final folded = ArabicNormalization.forGrading(
        arabic, ignoreDiacritics: true).replaceAll('ـ', '').trim();
    return concepts[folded];
  }
  static bool hasIllustration(String arabic) => concept(arabic) != null;
}
