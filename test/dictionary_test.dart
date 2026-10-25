import 'package:flutter_test/flutter_test.dart';
import 'package:bayna_dictionary/main.dart';

void main() {
  test('Arabic diacritics do not break word search', () {
    expect(normalizeArabic('بَيْتٌ'), normalizeArabic('بيت'));
    expect(normalizeArabic('أُسْرَةٌ'), normalizeArabic('اسرة'));
  });

  test('Arabic meanings decode with all seven data groups', () {
    const source = '{"entries":[{"id":"demo1","arabic":"بَيْتٌ",'
        '"meaning_ar":"مَبْنًى","synonyms":[],"antonyms":[],'
        '"grammar":[],"collocations":[],"examples_ar":[],'
        '"usage_note_ar":""}]}';
    final words = decodeWords(source);
    expect(words.length, 1);
    expect(words.first.arabic, 'بَيْتٌ');
    expect(words.first.meaning, 'مَبْنًى');
    expect(words.first.synonyms, isEmpty);
  });

  test('Separate Arabic definitions are parsed without losing senses', () {
    const source = '{"entries":[{"id":"1","arabic":"كَبِيرٌ",'
        '"meaning_ar":"عَظِيمُ الْحَجْمِ","additional_meanings_ar":["مُتَقَدِّمٌ فِي السِّنِّ"],'
        '"synonyms":[],"antonyms":[],"grammar":[],"collocations":[],'
        '"examples_ar":[],"usage_note_ar":""}]}';
    final parsed = decodeWords(source);
    expect(parsed.first.additionalMeanings.length, 1);
    expect(parsed.first.additionalMeanings.single, 'مُتَقَدِّمٌ فِي السِّنِّ');
  });

  test('Tapping a diacritized or definite noun opens its entry', () {
    const source = '{"entries":[{"id":"1","arabic":"بَيْتٌ",'
        '"meaning_ar":"مَبْنًى","synonyms":[],"antonyms":[],'
        '"grammar":[],"collocations":[],"examples_ar":[]}]}';
    final words = decodeWords(source);
    expect(findWordForToken('بَيْتٍ', words)?.id, '1');
    expect(findWordForToken('الْبَيْتِ،', words)?.id, '1');
    expect(findWordForToken('وَبَيْتٍ', words)?.id, '1');
    expect(findWordForToken('مَجْهُولٌ', words), isNull);
  });


  test('Chapter reference survives parsing and supports ordered browsing', () {
    const source = '{"entries":[{"id":"a","arabic":"تَحِيَّةٌ",'
        '"meaning_ar":"كَلِمَةٌ نَقُولُهَا","synonyms":[],"antonyms":[],'
        '"grammar":[],"collocations":[],"examples_ar":[],'
        '"book_reference":{"book":1,"chapter":1,"index":5}},'
        '{"id":"b","arabic":"اِسْمٌ","meaning_ar":"كَلِمَةٌ",'
        '"synonyms":[],"antonyms":[],"grammar":[],"collocations":[],'
        '"examples_ar":[],"book_reference":{"book":1,"chapter":1,"index":3}}]}';
    final words = decodeWords(source);
    expect(words.first.bookNumber, 1);
    expect(words.first.chapterNumber, 1);
    expect(words.first.chapterOrder, 5);
    expect(sortWordsByBookOrder(words).map((w) => w.id).toList(), ['b', 'a']);
  });

  test('Homographs with different vowel patterns stay separate', () {
    const source = '{"entries":['
      '{"id":"noun","arabic":"تَعَارُفٌ","meaning_ar":"مَعْرِفَةٌ",'
      '"synonyms":[],"antonyms":[],"grammar":["مَصْدَرٌ"],'
      '"collocations":[],"examples_ar":[]},'
      '{"id":"verb","arabic":"تَعَارَفَ","meaning_ar":"عَرَفَ",'
      '"synonyms":[],"antonyms":[],"grammar":["فِعْلٌ"],'
      '"collocations":[],"examples_ar":[]}]}';
    final words = decodeWords(source);
    expect(findWordForToken('تَعَارُفٍ', words)?.id, 'noun');
    expect(findWordForToken('تَعَارَفَ', words)?.id, 'verb');
  });
  test('A lemma may appear in both chapter 1 and chapter 2', () {
    const source = '{"entries":[{"id":"a","arabic":"أُسْرَةٌ",'
        '"meaning_ar":"مَجْمُوعَةٌ مِنَ الْأَقَارِبِ",'
        '"synonyms":[],"antonyms":[],"grammar":[],"collocations":[],'
        '"examples_ar":[],"book_reference":{"book":1,"chapter":1,"index":10},'
        '"book_references":[{"book":1,"chapter":1,"index":10},'
        '{"book":1,"chapter":2,"index":1}]}]}';
    final words = decodeWords(source);
    expect(words.single.isInChapter(1, 1), isTrue);
    expect(words.single.isInChapter(1, 2), isTrue);
    expect(words.single.chapterOrderFor(1, 2), 1);
    expect(filterWordsByChapter(words, 1, 2).length, 1);
  });

  test('Chapter two preserves lesson order independently', () {
    const source = '{"entries":['
      '{"id":"a","arabic":"جَدٌّ","meaning_ar":"أَبُ الْأَبِ",'
      '"synonyms":[],"antonyms":[],"grammar":[],"collocations":[],'
      '"examples_ar":[],"book_references":[{"book":1,"chapter":2,"index":9}]},'
      '{"id":"b","arabic":"جَدَّةٌ","meaning_ar":"أُمُّ الْأُمِّ",'
      '"synonyms":[],"antonyms":[],"grammar":[],"collocations":[],'
      '"examples_ar":[],"book_references":[{"book":1,"chapter":2,"index":3}]}]}';
    final words = decodeWords(source);
    expect(filterWordsByChapter(words, 1, 2).map((w) => w.id).toList(), ['b', 'a']);
  });

  test('Multiple data chunks merge the same vocalized lemma without losing chapter refs', () {
    const first = '{"entries":[{"id":"old","arabic":"عِلْمٌ",'
        '"meaning_ar":"مَعْرِفَةٌ مُفِيدَةٌ","synonyms":[],"antonyms":[],'
        '"grammar":["اِسْمٌ"],"collocations":[],"examples_ar":[],'
        '"book_references":[{"book":1,"chapter":7,"index":1}]}]}';
    const second = '{"entries":[{"id":"new","arabic":"عِلْمٌ",'
        '"meaning_ar":"مَعْرِفَةٌ","synonyms":[],"antonyms":[],'
        '"grammar":["اِسْمٌ"],"collocations":[],"examples_ar":[],'
        '"book_references":[{"book":2,"chapter":7,"index":3}]}]}';
    final words = decodeAndMergeCorpora([first, second]);
    expect(words.length, 1);
    expect(words.single.id, 'old');
    expect(words.single.meaning, 'مَعْرِفَةٌ مُفِيدَةٌ');
    expect(words.single.isInChapter(1, 7), true);
    expect(words.single.isInChapter(2, 7), true);
    expect(words.single.chapterOrderFor(2, 7), 3);
  });
  test('Later corpus updates append distinct senses without overwriting earlier ones', () {
    const first = '{"entries":[{"id":"original","arabic":"بَيْتٌ",'
        '"meaning_ar":"مَسْكَنٌ يَعِيشُ فِيهِ النَّاسُ.",'
        '"synonyms":[],"antonyms":[],"grammar":["اِسْمٌ"],'
        '"collocations":["بَيْتٌ جَمِيلٌ"],'
        '"examples_ar":["هَذَا بَيْتٌ وَاسِعٌ."],'
        '"additional_meanings_ar":["أَسْرَةٌ تَعِيشُ فِي الْمَنْزِلِ."]}]}';
    const supplement = '{"entries":[{"id":"supplement","arabic":"بَيْتٌ",'
        '"meaning_ar":"مَسْكَنٌ","synonyms":[],"antonyms":[],'
        '"grammar":["اِسْمٌ"],'
        '"collocations":["بَيْتٌ مِنَ الشِّعْرِ"],'
        '"examples_ar":["حَفِظْتُ بَيْتًا مِنَ الشِّعْرِ."],'
        '"additional_meanings_ar":["أَسْرَةٌ تَعِيشُ فِي الْمَنْزِلِ.",'
        '"جُمْلَةٌ شِعْرِيَّةٌ تَتَكَوَّنُ مِنْ شَطْرَيْنِ."],'
        '"usage_note_ar":"بَيْتُ الشِّعْرِ جَمْعُهُ أَبْيَاتٌ."}]}';
    final words = decodeAndMergeCorpora([first, supplement]);
    expect(words.single.id, 'original');
    expect(words.single.meaning, 'مَسْكَنٌ يَعِيشُ فِيهِ النَّاسُ.');
    expect(words.single.additionalMeanings.length, 2);
    expect(words.single.examples.length, 2);
    expect(words.single.collocations.length, 2);
    expect(words.single.grammar.length, 1);
    expect(words.single.usage, 'بَيْتُ الشِّعْرِ جَمْعُهُ أَبْيَاتٌ.');
  });

  test('Separate vowelled homographs remain distinct across corpus chunks', () {
    const first = '{"entries":[{"id":"noun","arabic":"وَلَدٌ",'
        '"meaning_ar":"صَبِيٌّ","synonyms":[],"antonyms":[],'
        '"grammar":["اِسْمٌ"],"collocations":[],"examples_ar":[]}]}';
    const second = '{"entries":[{"id":"verb","arabic":"وَلَدَ",'
        '"meaning_ar":"أَنْجَبَ","synonyms":[],"antonyms":[],'
        '"grammar":["فِعْلٌ"],"collocations":[],"examples_ar":[]}]}';
    expect(decodeAndMergeCorpora([first, second]).length, 2);
  });

}
