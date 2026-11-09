import 'dart:convert';

/// Portable offline backup. No corpus text or personal identifiers are exported.
class DictionaryBackup {
  const DictionaryBackup({
    required this.favorites,
    required this.bookmarks,
    required this.recentWords,
    required this.searchHistory,
  });

  final List<String> favorites;
  final List<String> bookmarks;
  final List<String> recentWords;
  final List<String> searchHistory;

  String toJsonText() => const JsonEncoder.withIndent('  ').convert({
    'format': 'bayna_dictionary_backup',
    'version': 1,
    'favorites': favorites,
    'bookmarks': bookmarks,
    'recent_words': recentWords,
    'search_history': searchHistory,
  });

  static DictionaryBackup fromJsonText(String text) {
    if (text.length > 1000000) {
      throw const FormatException('Резервная копия слишком большая');
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != 'bayna_dictionary_backup' ||
        decoded['version'] != 1) {
      throw const FormatException('Неизвестный формат резервной копии');
    }
    List<String> read(String field) {
      final value = decoded[field];
      if (value is! List || value.length > 20000 ||
          value.any((item) => item is! String)) {
        throw FormatException('Некорректное поле: $field');
      }
      return value.cast<String>().toSet().toList(growable: false);
    }

    return DictionaryBackup(
      favorites: read('favorites'),
      bookmarks: read('bookmarks'),
      recentWords: read('recent_words'),
      searchHistory: read('search_history'),
    );
  }
}
