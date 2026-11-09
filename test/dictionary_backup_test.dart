import 'package:flutter_test/flutter_test.dart';
import 'package:bayna_dictionary/core/dictionary_backup.dart';

void main() {
  test('Versioned backup round trips saved words and history', () {
    const original = DictionaryBackup(
      favorites: ['word-1', 'word-2'],
      bookmarks: ['word-2'],
      recentWords: ['word-1'],
      searchHistory: ['книга', 'بيت'],
    );
    final decoded = DictionaryBackup.fromJsonText(original.toJsonText());
    expect(decoded.favorites, ['word-1', 'word-2']);
    expect(decoded.bookmarks, ['word-2']);
    expect(decoded.recentWords, ['word-1']);
    expect(decoded.searchHistory, ['книга', 'بيت']);
  });

  test('Backup rejects foreign schema and damaged saved field types', () {
    expect(
      () => DictionaryBackup.fromJsonText('{"favorites":[]}'),
      throwsFormatException,
    );
    expect(
      () => DictionaryBackup.fromJsonText(
        '{"format":"bayna_dictionary_backup","version":1,'
        '"favorites":[1],"bookmarks":[],"recent_words":[],'
        '"search_history":[]}'),
      throwsFormatException,
    );
  });
}
