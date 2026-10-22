import 'practice_generator.dart';
import 'grammar_guidance.dart';

/// Evidence-based hints only. Without a verified grammar rule linked to the
/// exercise, the app does not invent an explanation of Arabic morphology.
abstract final class PracticeFeedback {
  static String explain(
    PracticeQuestion question,
    String submitted, {
    required bool correct,
    bool revealed = false,
  }) {
    if (revealed) {
      return 'Ответ был показан. Попробуйте восстановить его по памяти '
          'в следующий раз.';
    }
    if (correct) {
      return switch (question.mode) {
        PracticeMode.dictation =>
          'Фраза записана верно. Сравните огласовки с образцом.',
        PracticeMode.sentence ||
        PracticeMode.restoreDialogue =>
          'Порядок совпадает с исходным учебным текстом.',
        PracticeMode.dialogue =>
          'Выбрана реплика из исходного учебного диалога.',
        _ => 'Ответ совпадает с проверенным эталоном упражнения.',
      };
    }
    final related = GrammarGuidance.relatedTo(question);
    final hint = related == null ? '' :
        '\nГрамматическая справка — ${related.title}: '
        '${related.rule}\nПример: ${related.example}';
    switch (question.mode) {
      case PracticeMode.sentence:
      case PracticeMode.restoreDialogue:
        return 'Обратите внимание на порядок слов. '
            'В учебнике: ${question.answer}. '
            'Ваша последовательность: $submitted$hint';
      case PracticeMode.dictation:
        return 'Сравните услышанную фразу с учебным эталоном. '
            'Запись: $submitted. Образец: ${question.answer}. '
            'Огласовки можно пропускать, буквы и хамза имеют значение.$hint';
      case PracticeMode.missingWord:
        return 'В контексте «${question.reference}» '
            'пропущено слово «${question.answer}». '
            'Сопоставьте его с русским переводом: '
            '${question.translation}.$hint';
      case PracticeMode.quiz:
      case PracticeMode.illustrations:
      case PracticeMode.reverseQuiz:
      case PracticeMode.listen:
      case PracticeMode.recall:
        return 'Для «${question.word}» в словаре урока '
            'указан ответ «${question.answer}». '
            'Повторите слово и его значение.';
      case PracticeMode.findError:
        return 'Подменённое слово: «${question.answer}». '
            'В оригинальной реплике стояло «${question.word}». '
            'Сравните фразу с исходным диалогом.';
      case PracticeMode.dialogue:
        return 'В исходном диалоге после «${question.reference}» '
            'следует реплика «${question.answer}». '
            'Прослушайте последовательность снова.$hint';
      case PracticeMode.matching:
        return 'Проверьте соответствие каждого арабского слова '
            'и его русского значения.';
      case PracticeMode.exam:
      case PracticeMode.mistakes:
      case PracticeMode.intensive:
        return 'Ответ отличается от учебного эталона: ${question.answer}.';
    }
  }
}
