import 'package:flutter_test/flutter_test.dart';
import 'package:bayna_dictionary/core/dictionary_data.dart';
import 'package:bayna_dictionary/core/dictionary_search.dart';

void main() {
  const book = Word('book', 'كِتَابٌ', 'مَجْمُوعَةٌ مِنَ الصَّفَحَاتِ',
    [], [], [], [], [], '', [],
    russian: 'книга', bookNumber: 1, chapterNumber: 1);
  const meaning = Word('definition', 'مَكْتَبَةٌ', 'مَكَانٌ فِيهِ كِتَابٌ',
    [], [], [], [], [], '', [],
    russian: 'библиотека', bookNumber: 2, chapterNumber: 1);
  test('Exact Arabic headword outranks definition', () {
    final words = [meaning, book];
    expect(searchDictionary(words, 'كتاب').first.id, 'book');
    expect(searchDictionary(words, 'книга'), isEmpty);
    expect(searchDictionary(words, 'كِتَابٌ').first.id, 'book');
  });
  test('Filter by textbook volume and cap results', () {
    expect(searchDictionary([book, meaning], 'م', book: 2).map((w) => w.id),
      ['definition']);
    expect(searchDictionary([book, meaning], 'م', maxResults: 1).length, 1);
  });
}
