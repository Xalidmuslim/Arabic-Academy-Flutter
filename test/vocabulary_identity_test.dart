import 'package:arabic_academy/core/vocabulary_key.dart';
import 'package:arabic_academy/features/teacher/content_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Deleting or reordering teacher words does not move existing review/bookmark IDs',
    () {
      final draft = LessonContentDraft({
        'id': 'legacy',
        'vocabulary': [
          {'ar': 'كِتَابٌ', 'ru': 'Книга'},
          {'ar': 'قَلَمٌ', 'ru': 'Ручка', 'custom': 'kept'},
        ],
      });
      final words = draft.items['vocabulary']!;
      final before = vocabularyKey('legacy', 1, words[1]);
      expect(before, 'word:legacy:1');
      words.removeAt(0);
      expect(vocabularyKey('legacy', 0, words.single), before);
      expect(words.single['custom'], 'kept');
    },
  );
}
