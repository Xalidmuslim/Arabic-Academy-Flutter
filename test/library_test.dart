import 'dart:convert';
import 'dart:io';

import 'package:arabic_academy/core/academy_state.dart';
import 'package:arabic_academy/core/arabic.dart';
import 'package:arabic_academy/features/learning/library_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The write queue starts in setUp's real async zone. Let preference futures
// finish before waiting for Flutter animations in the fake widget-test clock.
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
}

const catalog = <String, dynamic>{
  'lessons': [
    {
      'id': 'l1',
      'title': 'Книги в классе',
      'title_ar': 'فِي الْفَصْلِ',
      'goal': 'Называть предметы',
      'vocabulary': [
        {
          'ar': 'كِتَابٌ',
          'ru': 'Книга',
          'root': 'ك ت ب',
          'forms': ['كُتُبٌ'],
          'example': {'ar': 'هَذَا كِتَابٌ.', 'ru': 'Это книга.'},
        },
        {'ar': 'قَلَمٌ', 'ru': 'Ручка'},
      ],
    },
    {
      'id': 'l2',
      'title': 'О себе',
      'vocabulary': [
        {'ar': 'أَنَا', 'ru': 'Я'},
      ],
    },
  ],
  'grammar_topics': [
    {
      'id': 'nominal',
      'title': 'Именное предложение',
      'theory': 'Сообщение о предмете.',
      'examples': [
        {'ar': 'الْبَيْتُ كَبِيرٌ.', 'ru': 'Дом большой.'},
      ],
      'table': {
        'columns': ['Арабский', 'Перевод'],
        'rows': [
          ['كِتَابٌ', 'Книга'],
        ],
      },
      'exercises': [
        {
          'id': 'g-nominal',
          'kind': 'singleChoice',
          'prompt': 'Выберите перевод',
          'options': ['Дом большой.', 'Книга новая.'],
          'correct': 0,
          'config': {'maxAttempts': 1, 'points': 3},
        },
        {
          'id': 'write-nominal',
          'kind': 'writing',
          'prompt': 'Свой пример',
          'correct': 'same',
          'config': {'points': 99},
        },
      ],
    },
  ],
};

void main() {
  late AcademyState state;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    state = AcademyState(await SharedPreferences.getInstance(), catalog);
    await state.initialize();
  });
  tearDown(() => state.dispose());

  Future<void> mount(WidgetTester tester, Widget screen) =>
      tester.pumpWidget(MaterialApp(home: screen));

  testWidgets(
    'dictionary search folds Arabic/Russian without changing vowels',
    (tester) async {
      expect(matchesSearch('كتاب', ['كِتَابٌ']), isTrue);
      await mount(tester, DictionaryScreen(state: state));
      await tester.enterText(
        find.byKey(const ValueKey('dictionary-search')),
        'كتاب',
      );
      await settle(tester);
      expect(find.text('كِتَابٌ'), findsOneWidget);
      expect(find.text('قَلَمٌ'), findsNothing);
      expect(state.allLessons.first['vocabulary'][0]['ar'], 'كِتَابٌ');
      await tester.enterText(
        find.byKey(const ValueKey('dictionary-search')),
        'КНИГА',
      );
      await settle(tester);
      expect(find.text('كِتَابٌ'), findsOneWidget);
      expect(find.text('قَلَمٌ'), findsNothing);
    },
  );

  testWidgets('lesson dictionary scope and known entry details are real', (
    tester,
  ) async {
    Map<String, dynamic>? opened;
    await mount(
      tester,
      DictionaryScreen(
        state: state,
        lessonId: 'l1',
        onOpenLesson: (_, lesson) => opened = lesson,
      ),
    );
    expect(find.text('أَنَا'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('word:l1:0')));
    await settle(tester);
    expect(find.text('ك ت ب'), findsOneWidget);
    expect(find.text('كُتُبٌ'), findsOneWidget);
    expect(find.text('هَذَا كِتَابٌ.'), findsOneWidget);
    expect(
      find.byTooltip('Синтез речи устройства — арабский голос'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Открыть урок'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Открыть урок'));
    expect(opened?['id'], 'l1');
  });

  testWidgets('bookmark and favorite filter persist across state restoration', (
    tester,
  ) async {
    await mount(tester, DictionaryScreen(state: state));
    await tester.tap(find.byKey(const ValueKey('bookmark-word:l1:0')));
    await settle(tester);
    expect(state.bookmarks, contains('word:l1:0'));
    await tester.tap(find.text('Избранное'));
    await settle(tester);
    expect(find.text('كِتَابٌ'), findsOneWidget);
    expect(find.text('قَلَمٌ'), findsNothing);
    final restored = AcademyState(state.prefs, catalog);
    expect(restored.bookmarks, contains('word:l1:0'));
    restored.dispose();
  });

  testWidgets('flashcards require revealing and persist spaced review', (
    tester,
  ) async {
    await mount(tester, DictionaryScreen(state: state, lessonId: 'l2'));
    await tester.tap(find.text('Карточки'));
    await settle(tester);
    expect(find.text('Я'), findsNothing);
    expect(find.text('Помню'), findsNothing);
    await tester.tap(find.text('Показать перевод'));
    await settle(tester);
    expect(find.text('Я'), findsOneWidget);
    await tester.tap(find.text('Помню'));
    await settle(tester);
    expect(find.text('Карточки завершены'), findsOneWidget);
    final review = state.reviews['word:l2:0'] as Map;
    expect(review['stage'], 1);
    expect(review['difficult'], isFalse);
    expect(
      DateTime.parse(review['due_at'] as String).isAfter(DateTime.now()),
      isTrue,
    );
    final restored = AcademyState(state.prefs, catalog);
    expect(restored.reviews['word:l2:0']['reviews'], 1);
    restored.dispose();
  });

  testWidgets('difficult and due filters follow stored reviews', (
    tester,
  ) async {
    await tester.runAsync(() => state.reviewWord('word:l1:0', false));
    await tester.runAsync(() => state.reviewWord('word:l1:1', true));
    await tester.runAsync(() => state.reviewWord('word:l2:0', true));
    await mount(tester, DictionaryScreen(state: state));
    await tester.tap(find.text('Трудные'));
    await settle(tester);
    expect(find.text('كِتَابٌ'), findsOneWidget);
    expect(find.text('قَلَمٌ'), findsNothing);
    await tester.tap(find.text('К повторению'));
    await settle(tester);
    expect(find.text('كِتَابٌ'), findsOneWidget);
    expect(find.text('أَنَا'), findsNothing);
  });

  testWidgets('global search opens lessons, words and grammar', (tester) async {
    Map<String, dynamic>? opened;
    await mount(
      tester,
      SearchScreen(state: state, onOpenLesson: (_, lesson) => opened = lesson),
    );
    expect(find.text('Поиск по библиотеке'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('library-search')),
      'Книги',
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('lesson:l1')));
    expect(opened?['id'], 'l1');
    await tester.enterText(
      find.byKey(const ValueKey('library-search')),
      'كتاب',
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('word:l1:0')));
    await settle(tester);
    expect(find.text('Корень'), findsOneWidget);
    await tester.pageBack();
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('library-search')),
      'Именное',
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('grammar:nominal')));
    await settle(tester);
    expect(find.text('Сообщение о предмете.'), findsOneWidget);
    expect(find.text('الْبَيْتُ كَبِيرٌ.'), findsOneWidget);
  });

  testWidgets('grammar exercise records the assigned ID and wrong points', (
    tester,
  ) async {
    await mount(tester, GrammarScreen(state: state));
    await tester.tap(find.byKey(const ValueKey('grammar:nominal')));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('exercise-g-nominal')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('exercise-g-nominal')));
    await settle(tester);
    await tester.tap(find.text('Книга новая.'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('exercise-submit')));
    await settle(tester);
    expect(state.attempts.single['lesson_id'], 'grammar:nominal');
    expect(state.attempts.single['exercise_id'], 'g-nominal');
    expect(state.attempts.single['status'], 'incorrect');
    expect(state.attempts.single['points'], 0);
    expect(state.completed, isEmpty);
    expect(state.drafts['grammar:nominal:g-nominal']['answer'], 1);
  });

  testWidgets(
    'grammar writing stays needsReview without awarding points or progress',
    (tester) async {
      await mount(tester, GrammarScreen(state: state));
      await tester.tap(find.byKey(const ValueKey('grammar:nominal')));
      await settle(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('exercise-write-nominal')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('exercise-write-nominal')));
      await settle(tester);
      await tester.enterText(find.byType(TextFormField), 'same');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('exercise-submit')));
      await settle(tester);
      expect(state.attempts.single['exercise_id'], 'write-nominal');
      expect(state.attempts.single['status'], 'needsReview');
      expect(state.attempts.single['points'], 0);
      expect(state.completed, isEmpty);
    },
  );

  testWidgets('bookmarks resolve and open all three real content types', (
    tester,
  ) async {
    await tester.runAsync(() => state.toggleBookmark('lesson:l1'));
    await tester.runAsync(() => state.toggleBookmark('word:l1:0'));
    await tester.runAsync(() => state.toggleBookmark('grammar:nominal'));
    Map<String, dynamic>? opened;
    await mount(
      tester,
      BookmarksScreen(
        state: state,
        onOpenLesson: (_, lesson) => opened = lesson,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('lesson:l1')));
    expect(opened?['id'], 'l1');
    await tester.tap(find.byKey(const ValueKey('word:l1:0')));
    await settle(tester);
    expect(find.text('ك ت ب'), findsOneWidget);
    await tester.pageBack();
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('grammar:nominal')));
    await settle(tester);
    expect(find.text('Сообщение о предмете.'), findsOneWidget);
  });

  testWidgets('empty search, dictionary and bookmark states are meaningful', (
    tester,
  ) async {
    final empty = AcademyState(state.prefs, const {
      'lessons': [],
      'grammar_topics': [],
    });
    await mount(tester, DictionaryScreen(state: empty));
    expect(find.text('Словарь пока пуст'), findsOneWidget);
    await mount(tester, GrammarScreen(state: empty));
    expect(find.text('Темы пока не добавлены'), findsOneWidget);
    await mount(
      tester,
      BookmarksScreen(state: empty, onOpenLesson: (_, __) {}),
    );
    expect(find.text('Нет закладок'), findsOneWidget);
    await mount(tester, SearchScreen(state: state, onOpenLesson: (_, __) {}));
    await tester.enterText(
      find.byKey(const ValueKey('library-search')),
      'несуществующее',
    );
    await settle(tester);
    expect(find.text('Ничего не найдено'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    empty.dispose();
  });

  testWidgets(
    'narrow doubled-text dictionary and grammar details do not overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Widget app(Widget screen) => MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: screen,
      );
      await tester.pumpWidget(app(DictionaryScreen(state: state)));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('word:l1:0')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('word:l1:0'))),
        alignment: 0.1,
      );
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('word:l1:0')).hitTestable());
      await settle(tester);
      expect(tester.takeException(), isNull);
      final arabic = tester.element(find.text('كِتَابٌ'));
      expect(Directionality.of(arabic), TextDirection.rtl);
      expect(
        find.byTooltip('Синтез речи устройства — арабский голос'),
        findsOneWidget,
      );
      await tester.pageBack();
      await settle(tester);
      await tester.pumpWidget(app(GrammarScreen(state: state)));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('grammar:nominal')));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Перевод'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('كِتَابٌ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'device synthesis receives original Arabic and reports unavailable voice',
    (tester) async {
      const channel = MethodChannel('flutter_tts');
      final calls = <MethodCall>[];
      var available = true;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return call.method == 'isLanguageAvailable' ? available : 1;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.runAsync(() => state.setSetting('audioSpeed', 0.7));
      await tester.runAsync(() => state.setSetting('arabicHeight', 2.2));
      await tester.runAsync(() => state.setSetting('arabicSize', 32.0));
      await mount(tester, DictionaryScreen(state: state, lessonId: 'l2'));
      await tester.tap(find.byKey(const ValueKey('word:l2:0')));
      await settle(tester);
      await tester.tap(
        find.byTooltip('Синтез речи устройства — арабский голос'),
      );
      await settle(tester);
      final spoken = calls.singleWhere((call) => call.method == 'speak');
      expect(
        spoken.arguments is Map
            ? (spoken.arguments as Map)['text']
            : spoken.arguments,
        'أَنَا',
      );
      expect(
        calls.singleWhere((call) => call.method == 'setSpeechRate').arguments,
        0.65, // Current device speech policy clamps speed to the 0.65 maximum.
      );
      final style = tester.widget<Text>(find.text('أَنَا')).style!;
      expect(style.fontSize, 32);
      expect(style.height, 2.2);
      available = false;
      calls.clear();
      await tester.tap(
        find.byTooltip('Синтез речи устройства — арабский голос'),
      );
      await settle(tester);
      expect(calls.any((call) => call.method == 'speak'), isFalse);
      expect(find.textContaining('Арабский голос не найден'), findsOneWidget);
    },
  );

  testWidgets(
    'failed persistence keeps the revealed flashcard and reports the failure',
    (tester) async {
      await tester.runAsync(
        () => state.prefs.setString('blocked-library', '{broken'),
      );
      final blocked = AcademyState(
        state.prefs,
        catalog,
        namespace: 'blocked-library',
      );
      await mount(tester, DictionaryScreen(state: blocked, lessonId: 'l2'));
      await tester.tap(find.text('Карточки'));
      await settle(tester);
      await tester.tap(find.text('Показать перевод'));
      await settle(tester);
      await tester.tap(find.text('Помню'));
      await settle(tester);
      expect(find.text('Карточки завершены'), findsNothing);
      expect(find.text('Я'), findsOneWidget);
      expect(find.textContaining('Повторение не сохранено'), findsOneWidget);
      expect(blocked.reviews, isEmpty);
      await tester.pumpWidget(const SizedBox());
      blocked.dispose();
    },
  );

  testWidgets('every grammar check persists exactly once across retries', (
    tester,
  ) async {
    final data = jsonDecode(jsonEncode(catalog)) as Map<String, dynamic>;
    data['grammar_topics'][0]['exercises'][0]['config']['maxAttempts'] = 3;
    state.dispose();
    state = AcademyState(state.prefs, data);
    await mount(tester, GrammarScreen(state: state));
    await tester.tap(find.byKey(const ValueKey('grammar:nominal')));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('exercise-g-nominal')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('exercise-g-nominal')));
    await settle(tester);
    await tester.tap(find.text('Книга новая.'));
    await tester.pump();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const ValueKey('exercise-submit')));
      await settle(tester);
      expect(state.attempts, hasLength(i + 1));
    }
    await tester.tap(find.text('Дом большой.'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('exercise-submit')));
    await settle(tester);
    expect(state.attempts.map((x) => x['status']), [
      'incorrect',
      'incorrect',
      'correct',
    ]);
    expect(state.attempts.map((x) => x['points']), [0, 0, 3]);
    expect(
      state.attempts.every((x) => x['exercise_id'] == 'g-nominal'),
      isTrue,
    );
    expect(state.completed, isEmpty);
    expect(find.text('Сохранено проверок: 3'), findsOneWidget);
  });

  testWidgets('missing bookmark content is preserved until explicit removal', (
    tester,
  ) async {
    await tester.runAsync(() => state.toggleBookmark('word:deleted:4'));
    await mount(
      tester,
      BookmarksScreen(state: state, onOpenLesson: (_, __) {}),
    );
    expect(find.text('Сохранённый материал недоступен'), findsOneWidget);
    expect(state.bookmarks, contains('word:deleted:4'));
    await tester.tap(find.text('Удалить закладку'));
    await settle(tester);
    expect(state.bookmarks, isEmpty);
    expect(find.text('Нет закладок'), findsOneWidget);
  });

  testWidgets('legacy raw lesson bookmark resolves and can be removed', (
    tester,
  ) async {
    await tester.runAsync(() => state.toggleBookmark('l1'));
    await mount(
      tester,
      BookmarksScreen(state: state, onOpenLesson: (_, __) {}),
    );
    expect(find.byKey(const ValueKey('lesson:l1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bookmark-lesson:l1')));
    await settle(tester);
    expect(state.bookmarks, isEmpty);
  });

  testWidgets(
    'all 22 actual grammar topics are browsable without asset loading',
    (tester) async {
      final grammar =
          jsonDecode(File('assets/content/grammar.json').readAsStringSync())
              as Map;
      final actual = AcademyState(state.prefs, {
        'lessons': [],
        'grammar_topics': grammar['topics'],
      });
      await mount(tester, GrammarScreen(state: actual));
      expect(find.text('Тем: 22'), findsOneWidget);
      final last = (grammar['topics'] as List).last as Map;
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('grammar:${last['id']}')),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(ValueKey('grammar:${last['id']}')));
      await settle(tester);
      expect(find.text(last['theory'] as String), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      actual.dispose();
    },
  );
}
