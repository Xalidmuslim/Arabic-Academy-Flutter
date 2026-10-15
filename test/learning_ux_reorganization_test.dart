import 'package:arabic_academy/app.dart';
import 'package:arabic_academy/core/academy_state.dart';
import 'package:arabic_academy/features/learning/lesson_screen.dart';
import 'package:arabic_academy/features/learning/practice_center_screen.dart';
import 'package:arabic_academy/features/learning/words_hub_screen.dart';
import 'package:arabic_academy/ui/floating_navigation.dart';
import 'package:arabic_academy/ui/dialogue_scene_illustration.dart';
import 'package:arabic_academy/ui/semantic_object_artwork.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const catalog = <String, dynamic>{
  'modules': <dynamic>[],
  'lessons': <Map<String, dynamic>>[
    {
      'id': 'l1', 'title': 'Слова и диалог',
      'vocabulary': [
        {'ar': 'كِتَابٌ', 'ru': 'Книга'},
        {'ar': 'قَلَمٌ', 'ru': 'Ручка'}
      ],
      'dialogue': [
        {'ar': 'السَّلَامُ عَلَيْكُمْ', 'ru': 'Мир вам'},
        {'ar': 'وَعَلَيْكُمُ السَّلَامُ', 'ru': 'И вам мир'}
      ]
    }
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AcademyState> makeState() async {
    SharedPreferences.setMockInitialValues({'welcome_seen': true});
    final state = AcademyState(await SharedPreferences.getInstance(), catalog);
    await state.initialize();
    addTearDown(state.dispose);
    return state;
  }

  testWidgets('learner navigation leads to Today, Textbook, Practice and Mine',
      (tester) async {
    final state = await makeState();
    await tester.pumpWidget(AcademyApp(state: state));
    await tester.pumpAndSettle();
    final nav = find.byType(FloatingStudyNavigation);
    expect(nav, findsOneWidget);
    for (final title in ['Сегодня', 'Учебник', 'Практика', 'Моё']) {
      expect(find.descendant(of: nav, matching: find.text(title)),
          findsOneWidget);
    }
    expect(find.descendant(of: nav, matching: find.text('Поиск')),
        findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home-practice-entry')), 230,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('home-practice-entry')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('study-tab-2')));
    await tester.pumpAndSettle();
    expect(find.text('Практика'), findsWidgets);
    expect(find.text('Слова'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('study-tab-3')));
    await tester.pumpAndSettle();
    expect(find.text('Ученица · локальное обучение'), findsOneWidget);
  });

  test('dialogue scene assets correspond only to known educational contexts', () {
    expect(DialogueSceneIllustration.sceneFor('В магазине'), 'shop');
    expect(DialogueSceneIllustration.sceneFor('Предметы класса'), 'classroom');
    expect(DialogueSceneIllustration.sceneFor('В доме'), 'home');
    expect(DialogueSceneIllustration.sceneFor('Случайная тема'), isNull);
  });

  testWidgets('recognized words show original illustrations', (tester) async {
    final state = await makeState();
    await tester.pumpWidget(MaterialApp(home: WordsHubScreen(state: state)));
    await tester.pumpAndSettle();
    expect(find.byType(SemanticObjectArtwork), findsWidgets);
  });

  testWidgets('word study, test and reviews live in a single entry', (tester) async {
    final state = await makeState();
    await tester.pumpWidget(MaterialApp(
      home: WordsHubScreen(state: state),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Изучаю'), findsOneWidget);
    expect(find.text('Проверяю'), findsOneWidget);
    expect(find.text('Повторяю'), findsOneWidget);
    expect(find.text('كِتَابٌ'), findsWidgets);
    expect(find.text('Книга'), findsWidgets);
  });

  testWidgets('lesson offers four comprehensible learning phases',
      (tester) async {
    final state = await makeState();
    await tester.pumpWidget(MaterialApp(
      home: LessonScreen(state: state, lesson: state.allLessons.first),
    ));
    await tester.pumpAndSettle();
    for (final stage in ['Диалог', 'Новые слова', 'Практикую', 'Закрепляю']) {
      expect(find.text(stage), findsOneWidget);
    }
    expect(find.text('Введение'), findsNothing);
    expect(find.text('Лексика'), findsNothing);
  });

  testWidgets('practice offers four skill groups, not eleven repeated rows',
      (tester) async {
    final state = await makeState();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PracticeCenterScreen(state: state)),
    ));
    await tester.pumpAndSettle();
    for (final group in ['Слова', 'Письмо и грамматика',
        'Слушаю и говорю', 'Проверяю']) {
      final target = find.text(group);
      await tester.scrollUntilVisible(target, 190,
        scrollable: find.byType(Scrollable).first);
      expect(target, findsOneWidget);
    }
  });
}
