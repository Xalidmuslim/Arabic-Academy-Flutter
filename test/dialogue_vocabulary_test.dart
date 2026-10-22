import 'dart:convert';

import 'package:arabic_academy/core/academy_state.dart';
import 'package:arabic_academy/core/dialogue_vocabulary.dart';
import 'package:arabic_academy/core/vocabulary_practice.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dialogue word translations preserve saved review IDs and avoid duplicates',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final state = AcademyState(
      await SharedPreferences.getInstance(),
      <String, dynamic>{
        'modules': <dynamic>[],
        'lessons': <dynamic>[
          <String, dynamic>{
            'id': 'dialog-1',
            'title': 'Приветствие',
            'vocabulary': <dynamic>[
              {'ar': 'كِتَابٌ', 'ru': 'Книга'},
            ],
            'dialogue': <dynamic>[
              {'ar': 'مَرْيَمُ: هَلْ هَذَا كِتَابٌ؟',
               'ru': 'Марьям: Это книга?'},
              {'ar': 'عُمَرُ: نَعَمْ، هَذَا كِتَابٌ.',
               'ru': 'Умар: Да, это книга.'},
            ],
          },
        ],
      },
    );
    addTearDown(state.dispose);
    final words = VocabularyPractice.words(state);
    expect(words.where((w) => w.id == 'word:dialog-1:0'), hasLength(1));
    expect(words.where((w) =>
        DialogueVocabulary.normalize(w.ar) == 'كتاب'), hasLength(1));
    expect(words.where((w) =>
        DialogueVocabulary.normalize(w.ar) == 'هل'), hasLength(1));
    expect(words.where((w) =>
        DialogueVocabulary.normalize(w.ar) == 'هذا'), hasLength(1));
    expect(words.any((w) => w.ar.endsWith(':')), isFalse);
    expect(words.every((w) => w.ru.isNotEmpty), isTrue);

    await state.reviewWord('word:dialog-1:0', true);
    expect(state.reviews['word:dialog-1:0'], isNotNull);
    expect(VocabularyPractice.plan(state, newLimit: 30).totalEligible,
        words.length);
  });

  test('every word from all bundled dialogues is individually translated',
      () async {
    final all = <Map<String, dynamic>>[];
    for (final file in [
      'assets/content/level1.json',
      'assets/content/original_lessons.json',
      'assets/content/book1_original_dialogues.json',
      'assets/content/book1_part2_editorial.json',
    ]) {
      final catalog = jsonDecode(await rootBundle.loadString(file)) as Map;
      for (final item in catalog['lessons'] as List) {
        all.add(Map<String, dynamic>.from(item as Map));
      }
    }
    expect(all, hasLength(111));
    var dialogueCount = 0;
    var added = 0;
    for (final lesson in all) {
      final expanded = DialogueVocabulary.expand(lesson);
      final words = (expanded['vocabulary'] as List).cast<Map>();
      added += words.length - (lesson['vocabulary'] as List).length;
      final known = <String>{
        for (final item in words)
          DialogueVocabulary.normalize(item['ar'] as String),
      };
      for (final line in (lesson['dialogue'] as List)) {
        dialogueCount++;
        for (final token in DialogueVocabulary.dialogueWords(
            (line as Map)['ar'] as String)) {
          expect(known.contains(DialogueVocabulary.normalize(token)), isTrue,
              reason: 'Missing translation in ${lesson['id']}: $token');
        }
      }
    }
    expect(dialogueCount, greaterThan(400));
    expect(added, greaterThan(400));
  });
}
