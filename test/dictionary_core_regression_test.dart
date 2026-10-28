import 'package:flutter_test/flutter_test.dart';
import 'package:bayna_dictionary/main.dart';

Word sample(String id, String arabic, {List<Map<String, dynamic>> references = const []}) =>
    Word(id, arabic, 'تَعْرِيفٌ لِلْكَلِمَةِ', const [], const [],
        const ['اِسْمٌ'], const [], const [], '', const [],
        bookReferences: references);

void main() {
  test('Corpus merge retains a substantive later primary definition as a second sense', () {
    const old = '{"entries":[{"id":"old","arabic":"بَيْتٌ",'
        '"meaning_ar":"مَسْكَنٌ يَعِيشُ فِيهِ النَّاسُ وَأُسَرُهُمْ.",'
        '"grammar":["اِسْمٌ"],"collocations":[],"examples_ar":[],'
        '"synonyms":[],"antonyms":[],"additional_meanings_ar":[]}]}';
    const recent = '{"entries":[{"id":"new","arabic":"بَيْتٌ",'
        '"meaning_ar":"وَحْدَةٌ مِنَ الشِّعْرِ تَتَكَوَّنُ مِنْ شَطْرَيْنِ.",'
        '"grammar":["اِسْمٌ"],"collocations":[],"examples_ar":[],'
        '"synonyms":[],"antonyms":[],"additional_meanings_ar":[]}]}';

    final result = decodeAndMergeCorpora([old, recent]);
    expect(result, hasLength(1));
    expect(result.single.id, 'old');
    expect(result.single.meaning, 'مَسْكَنٌ يَعِيشُ فِيهِ النَّاسُ وَأُسَرُهُمْ.');
    expect(result.single.additionalMeanings,
        contains('وَحْدَةٌ مِنَ الشِّعْرِ تَتَكَوَّنُ مِنْ شَطْرَيْنِ.'));
  });

  test('Duplicate primary meaning is not copied into secondary senses', () {
    const source = '{"entries":[{"id":"a","arabic":"كِتَابٌ",'
        '"meaning_ar":"مَجْمُوعَةٌ مِنَ الْأَوْرَاقِ الْمَكْتُوبَةِ.",'
        '"grammar":[],"collocations":[],"examples_ar":[],'
        '"synonyms":[],"antonyms":[],"additional_meanings_ar":[]}]}';
    final result = decodeAndMergeCorpora([source, source]);
    expect(result, hasLength(1));
    expect(result.single.additionalMeanings, isEmpty);
  });

  test('Tapping fully vocalized attached definite noun picks the right homograph', () {
    final corpus = [
      sample('flag', 'عَلَمٌ'),
      sample('knowledge', 'عِلْمٌ'),
    ];
    expect(findWordForToken('بِالْعِلْمِ', corpus)?.id, 'knowledge');
    expect(findWordForToken('وَالْعَلَمِ،', corpus)?.id, 'flag');
    expect(findWordForToken('عِلْمٍ', corpus)?.id, 'knowledge');
  });

  test('Ambiguous bare consonantal word does not silently choose wrong homograph', () {
    final corpus = [sample('flag', 'عَلَمٌ'), sample('knowledge', 'عِلْمٌ')];
    expect(findWordForToken('علم', corpus), isNull);
  });

  test('Chapter ordering considers modern multi-book references', () {
    final corpus = [
      sample('second', 'قَلَمٌ', references: [
        {'book': 1, 'chapter': 3, 'index': 5}
      ]),
      sample('first', 'بَيْتٌ', references: [
        {'book': 1, 'chapter': 1, 'index': 2}
      ]),
      sample('third', 'كِتَابٌ', references: [
        {'book': 2, 'chapter': 1, 'index': 1}
      ]),
    ];
    expect(sortWordsByBookOrder(corpus).map((w) => w.id).toList(),
        ['first', 'second', 'third']);
  });
}
