import 'practice_generator.dart';

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
        PracticeMode.sentence =>
          'Порядок слов совпадает с исходным предложением.',
        PracticeMode.dialogue =>
          'Выбрана реплика из исходного учебного диалога.',
        _ => 'Ответ совпадает с проверенным эталоном упражнения.',
      };
    }
    switch (question.mode) {
      case PracticeMode.sentence:
        return 'Обратите внимание на порядок слов. '
            'В учебнике: ${question.answer}. '
            'Ваша последовательность: $submitted';
      case PracticeMode.dictation:
        return 'Сравните услышанную фразу с учебным эталоном. '
            'Запись: $submitted. Образец: ${question.answer}. '
            'Огласовки можно пропускать, буквы и хамза имеют значение.';
      case PracticeMode.missingWord:
        return 'В контексте «${question.reference}» '
            'пропущено слово «${question.answer}». '
            'Сопоставьте его с русским переводом: '
            '${question.translation}.';
      case PracticeMode.quiz:
      case PracticeMode.illustrations:
        return 'Для «${question.word}» в словаре урока '
            'указан ответ «${question.answer}». '
            'Повторите слово и его значение.';
      case PracticeMode.dialogue:
        return 'В исходном диалоге после «${question.reference}» '
            'следует реплика «${question.answer}». '
            'Прослушайте последовательность снова.';
      case PracticeMode.exam:
      case PracticeMode.mistakes:
        return 'Ответ отличается от учебного эталона: ${question.answer}.';
    }
  }
}
