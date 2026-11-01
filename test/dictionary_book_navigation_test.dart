import 'package:bayna_dictionary/main.dart';
import 'package:bayna_dictionary/ui/dictionary_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Word lessonWord(String id, int book, int chapter) => Word(
  id, 'كَلِمَةٌ $id', 'مَعْنًى', const [], const [], const ['اِسْمٌ'],
  const [], const [], '', const [],
  bookReferences: [
    {'book': book, 'chapter': chapter, 'index': 1},
  ],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Volume and chapter index includes every available reference exactly once', () {
    final words = [
      lessonWord('a', 1, 2),
      lessonWord('b', 3, 4),
      Word('shared', 'بَيْتٌ', 'مَسْكَنٌ', const [], const [], const [],
          const [], const [], '', const [], bookReferences: const [
        {'book': 1, 'chapter': 1, 'index': 3},
        {'book': 3, 'chapter': 4, 'index': 7},
      ]),
      Word('unlinked', 'شَمْسٌ', 'نَجْمٌ', const [], const [], const [],
          const [], const [], '', const []),
    ];
    expect(availableBookChapters(words), {
      1: [1, 2],
      3: [4],
    });
  });

  testWidgets('Select volume then topic, switch volumes without stale filter',
      (tester) async {
    await tester.pumpWidget(DictionaryApp(previewWords: [
      lessonWord('a', 1, 1),
      lessonWord('b', 1, 2),
      lessonWord('c', 2, 1),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('book-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Том 2').last);
    await tester.pumpAndSettle();
    expect(find.byType(WordTile), findsOneWidget);
    expect(find.text('Кَلِمَةٌ c'), findsOneWidget);

    await tester.tap(find.byKey(const Key('book-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Том 1').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chapter-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Тема 2').last);
    await tester.pumpAndSettle();
    expect(find.byType(WordTile), findsOneWidget);
    expect(find.text('Кَلِمَةٌ b'), findsOneWidget);
  });
}
