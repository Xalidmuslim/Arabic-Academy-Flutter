import 'package:bayna_dictionary/main.dart';
import 'package:bayna_dictionary/ui/dictionary_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Word referenceWord(String id, int book, int chapter) => Word(
  id, 'كَلِمَةٌ $id', 'مَعْنًى $id', const [], const [], const ['اِسْمٌ'],
  const [], const [], '', const [], bookReferences: [
    {'book': book, 'chapter': chapter, 'index': 1},
  ],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Bottom bar has dedicated search and combined saved words', (tester) async {
    await tester.pumpWidget(DictionaryApp(previewWords: [referenceWord('a', 1, 1)]));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.text('Поиск'), findsOneWidget);
    expect(find.text('Закладки'), findsOneWidget);
    await tester.tap(find.text('Поиск').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('arabic-search')), findsOneWidget);
    await tester.tap(find.text('Закладки').last);
    await tester.pumpAndSettle();
    expect(find.text('Избранное'), findsOneWidget);
  });

  testWidgets('Volumes and topics open without replacing the offline corpus', (tester) async {
    await tester.pumpWidget(DictionaryApp(previewWords: [
      referenceWord('family', 1, 2),
      referenceWord('housing', 1, 3),
      referenceWord('advanced', 2, 1),
    ]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('volume-list')), findsOneWidget);
    await tester.tap(find.byKey(const Key('volume-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chapter-list')), findsOneWidget);
    await tester.tap(find.byKey(const Key('chapter-1-3')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dictionary-scroll-list')), findsOneWidget);
    expect(find.text('كَلِمَةٌ housing'), findsOneWidget);
    expect(find.text('كَلِمَةٌ family'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chapter-list')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('volume-list')), findsOneWidget);
  });

  testWidgets('Search results find a vocalized word without switching book', (tester) async {
    await tester.pumpWidget(DictionaryApp(previewWords: [
      referenceWord('first', 1, 1),
      referenceWord('second', 2, 1),
    ]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Поиск').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('arabic-search')), 'second');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search-results-list')), findsOneWidget);
    expect(find.text('كَلِمَةٌ second'), findsOneWidget);
    expect(find.text('كَلِمَةٌ first'), findsNothing);
  });

  testWidgets('Existing favorites and bookmarks remain accessible', (tester) async {
    SharedPreferences.setMockInitialValues({
      'dictionary_favorites': <String>['favorite'],
      'dictionary_bookmarks_v2': <String>['bookmark'],
    });
    await tester.pumpWidget(DictionaryApp(previewWords: [
      referenceWord('favorite', 1, 1), referenceWord('bookmark', 1, 1),
    ]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Закладки').last);
    await tester.pumpAndSettle();
    expect(find.text('كَلِمَةٌ bookmark'), findsOneWidget);
    await tester.tap(find.text('Избранное').last);
    await tester.pumpAndSettle();
    expect(find.text('كَلِمَةٌ favorite'), findsOneWidget);
  });
}
