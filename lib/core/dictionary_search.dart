import 'dictionary_data.dart';

/// Rank exact headword/gloss matches ahead of prefixes and explanations.
/// Unlike a plain substring scan, a generic definition cannot push an
/// exact dictionary entry off the first results page.
List<Word> searchDictionary(Iterable<Word> words, String query,
    {int? book, int maxResults = 300}) {
  final needle = normalizeArabic(query.trim());
  if (needle.isEmpty) return const [];
  final scored = <({Word word, int rank, int index})>[];
  var index = 0;
  for (final word in words) {
    final current = index++;
    if (book != null && !word.isInBook(book)) continue;
    final arabic = normalizeArabic(word.arabic);
    final ru = word.russian.toLowerCase();
    final definition = normalizeArabic(word.meaning);
    final rank = arabic == needle || ru == needle ? 0
        : arabic.startsWith(needle) || ru.startsWith(needle) ? 1
        : arabic.contains(needle) || ru.contains(needle) ? 2
        : definition.contains(needle) ? 3 : -1;
    if (rank >= 0) scored.add((word: word, rank: rank, index: current));
  }
  scored.sort((a, b) {
    final byRank = a.rank.compareTo(b.rank);
    return byRank != 0 ? byRank : a.index.compareTo(b.index);
  });
  return scored.take(maxResults).map((hit) => hit.word).toList(growable: false);
}
