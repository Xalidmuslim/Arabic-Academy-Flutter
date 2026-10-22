import 'dialogue_vocab_gloss_a.dart';
import 'dialogue_vocab_gloss_b.dart';
import 'dialogue_vocab_gloss_c.dart';

/// Expand existing authored vocabulary with individually glossed words that
/// actually occur in the Arabic dialogues. Original entries and their review
/// keys are retained verbatim; dialogue words receive stable, named IDs.
///
/// The glossary is audited against all 111 bundled lessons. Unknown words in
/// future user-authored dialogues are skipped rather than mistranslated.
abstract final class DialogueVocabulary {
  static final Map<String, String> _glosses = {
    ...dialogueGlossA,
    ...dialogueGlossB,
    ...dialogueGlossC,
  };

  static final _speaker = RegExp(r'^[^:：\n]{0,36}[:：]\s*');
  static final _split = RegExp(r'[\s،؛.!?؟«»()"”„…:]+');
  static final _marks = RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]');
  static final _alif = RegExp(r'[إأٱآ]');
  static final _nonArabic = RegExp(r'[^ء-ي]');

  static String normalize(String value) => value
      .replaceAll(_marks, '')
      .replaceAll(_alif, 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll(_nonArabic, '');

  static Iterable<String> dialogueWords(String source) sync* {
    final utterance = source.replaceFirst(_speaker, '');
    for (final raw in utterance.split(_split)) {
      if (normalize(raw).isNotEmpty) yield raw;
    }
  }

  static String? meaning(String arabic) {
    final key = normalize(arabic);
    // A preposition (عَلَى) and the proper name Ali (عَلِيّ) otherwise
    // collapse to the same normalized spelling.
    if (key == 'علي') {
      return arabic.contains('ى') ? 'на; над' : 'Али';
    }
    return _glosses[key];
  }

  static Map<String, dynamic> expand(Map<String, dynamic> lesson) {
    final original = lesson['vocabulary'];
    final source = original is List ? original : const <dynamic>[];
    final result = <dynamic>[...source];
    final known = <String>{};
    for (final word in source) {
      if (word is Map && (word['ar'] is String) &&
          (word['ru'] is String) &&
          (word['ru'] as String).trim().isNotEmpty) {
        known.add(normalize(word['ar'] as String));
      }
    }
    final dialogue = lesson['dialogue'];
    if (dialogue is List) {
      for (final line in dialogue) {
        if (line is! Map || line['ar'] is! String) continue;
        for (final arabic in dialogueWords(line['ar'] as String)) {
          final key = normalize(arabic);
          if (key.isEmpty || known.contains(key)) continue;
          final russian = meaning(arabic);
          if (russian == null || russian.trim().isEmpty) continue;
          known.add(key);
          result.add(<String, dynamic>{
            'id': 'dialogue-$key',
            'ar': arabic,
            'ru': russian,
            'source': 'dialogue',
          });
        }
      }
    }
    return {...lesson, 'vocabulary': result};
  }
}
