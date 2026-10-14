import '../features/exercises/arabic_normalization.dart';
import 'practice_generator.dart';

/// Small editorially checked explanations of specific constructions.
/// These are *related study hints*, never an automated syntactic diagnosis.
/// Full grammar review still requires a verified rule/exercise pairing.
class GrammarHint {
  const GrammarHint(this.title, this.rule, this.example);
  final String title;
  final String rule;
  final String example;
}

abstract final class GrammarGuidance {
  static final List<({List<String> tokens, GrammarHint hint})> _rules = [
    (
      tokens: ['هَذَا', 'هَذِهِ'],
      hint: const GrammarHint('Указательные местоимения',
        'هَذَا обычно относится к существительному мужского рода, '
        'а هَذِهِ — женского. Сопоставьте род существительного '
        'и выбранное указательное слово.',
        'هَذَا كِتَابٌ / هَذِهِ حَقِيبَةٌ'),
    ),
    (
      tokens: ['أَنْتَ', 'أَنْتِ'],
      hint: const GrammarHint('Личные местоимения',
        'При обращении к одному мужчине используется أَنْتَ, '
        'к одной женщине — أَنْتِ. В письме огласовки '
        'могут определять различие.',
        'أَنْتَ / أَنْتِ'),
    ),
    (
      tokens: ['أَيْنَ'],
      hint: const GrammarHint('Вопрос о месте',
        'أَيْنَ используется в вопросах «где?». '
        'Обратите внимание на порядок слов в ответе.',
        'أَيْنَ الْكِتَابُ؟'),
    ),
    (
      tokens: ['بِكَمْ', 'كَمْ'],
      hint: const GrammarHint('Вопрос о количестве или цене',
        'Кَمْ спрашивает о количестве; بِكَمْ — о цене. '
        'В ответах может указываться число и денежная единица.',
        'بِكَمْ هَذَا الْكِتَابُ؟'),
    ),
    (
      tokens: ['فِي', 'مِنْ', 'إِلَى', 'عَلَى'],
      hint: const GrammarHint('Предлоги',
        'Предлоги связывают слова: فِي — «в», مِنْ — «из/от», '
        'إِلَى — «к/в (направление)», عَلَى — «на». '
        'Важен смысл всей фразы, не только отдельное слово.',
        'الْكِتَابُ فِي الْبَيْتِ.'),
    ),
    (
      tokens: ['أَنَا', 'هُوَ', 'هِيَ'],
      hint: const GrammarHint('Именное предложение',
        'В простом именном предложении настоящего времени '
        'отдельный глагол «быть» обычно не требуется. '
        'Проверьте, кто назван и что о нём сказано.',
        'أَنَا طَالِبَةٌ.'),
    ),
  ];

  static GrammarHint? relatedTo(PracticeQuestion question) {
    if (question.mode != PracticeMode.sentence &&
        question.mode != PracticeMode.missingWord &&
        question.mode != PracticeMode.dialogue &&
        question.mode != PracticeMode.dictation) {
      return null;
    }
    final source = [
      question.reference, question.answer, question.word,
    ].join(' ');
    final stripped = ArabicNormalization.forGrading(
      source, ignoreDiacritics: true,
    ).split(RegExp(r'[^\u0621-\u064A]+')).where((s) => s.isNotEmpty).toSet();
    for (final item in _rules) {
      if (item.tokens.any((token) => stripped.contains(
          ArabicNormalization.forGrading(
            token, ignoreDiacritics: true)))) {
        return item.hint;
      }
    }
    return null;
  }
}
