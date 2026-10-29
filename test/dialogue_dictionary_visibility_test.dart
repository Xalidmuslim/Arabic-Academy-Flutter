import 'package:arabic_academy/core/academy_state.dart';
import 'package:arabic_academy/features/learning/library_screens.dart';
import 'package:arabic_academy/features/learning/words_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AcademyState> makeState() async {
    SharedPreferences.setMockInitialValues({});
    final state = AcademyState(await SharedPreferences.getInstance(), {
      'modules': <dynamic>[],
      'lessons': <dynamic>[
        {
          'id': 'greeting',
          'title': 'Приветствие',
          'vocabulary': <dynamic>[
            {'ar': 'كِتَابٌ', 'ru': 'книга'},
            {'ar': 'قَلَمٌ', 'ru': 'ручка'},
          ],
          'dialogue': <dynamic>[
            {'ar': 'مَرْيَمُ: هَلْ هَذَا كِتَابٌ؟', 'ru': 'Это книга?'},
          ],
        },
      ],
    });
    await state.initialize();
    return state;
  }

  testWidgets('dialogue filter shows both original and expanded words, not unrelated terms',
      (tester) async {
    final state = await makeState();
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(home: DictionaryScreen(state: state)));
    expect(find.text('Из диалогов'), findsOneWidget);
    await tester.tap(find.text('Из диалогов'));
    await tester.pumpAndSettle();
    expect(find.text('كِتَابٌ'), findsOneWidget);
    expect(find.text('هَلْ'), findsOneWidget);
    expect(find.text('هَذَا'), findsOneWidget);
    expect(find.text('قَلَمٌ'), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('dictionary-search')), 'هذا');
    await tester.pumpAndSettle();
    expect(find.text('هَذَا'), findsOneWidget);
    expect(find.text('كِتَابٌ'), findsNothing);
  });

  testWidgets('words hub opens the complete dialogue dictionary without diagnostics',
      (tester) async {
    final state = await makeState();
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(home: WordsHubScreen(state: state)));
    await tester.tap(find.byKey(const ValueKey('words-dialogue-dictionary')));
    await tester.pumpAndSettle();
    expect(find.text('Словарь'), findsOneWidget);
    expect(find.text('Из диалогов'), findsOneWidget);
    expect(find.text('هَلْ'), findsOneWidget);
    expect(find.text('قَلَمٌ'), findsNothing);
    expect(find.textContaining('Гц'), findsNothing);
    expect(find.byTooltip('GPU-тест'), findsNothing);
  });
}
