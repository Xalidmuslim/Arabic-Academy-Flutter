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
}
