/// Search folding must never be used to decide whether an answer is correct.
abstract final class ArabicNormalization {
  static final _marks = RegExp(
    '[\u0610-\u061A\u064B-\u0652\u0656-\u065F\u0670\u06D6-\u06ED]',
  );

  static String forGrading(String value, {bool ignoreDiacritics = false}) {
    // Canonically equivalent spellings of hamza/madda stay distinct from alef.
    var text = value
        .replaceAll('ا\u0654', 'أ')
        .replaceAll('ا\u0655', 'إ')
        .replaceAll('ا\u0653', 'آ')
        .replaceAll('و\u0654', 'ؤ')
        .replaceAll('ي\u0654', 'ئ');
    if (ignoreDiacritics) text = text.replaceAll(_marks, '');
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String forSearch(String value) =>
      forGrading(value, ignoreDiacritics: true)
          .replaceAll(RegExp('[أإآٱ]'), 'ا')
          .replaceAll('ؤ', 'و')
          .replaceAll('ئ', 'ي')
          .replaceAll('ى', 'ي')
          .replaceAll('ة', 'ه')
          .replaceAll('ـ', '')
          .toLowerCase();
}
