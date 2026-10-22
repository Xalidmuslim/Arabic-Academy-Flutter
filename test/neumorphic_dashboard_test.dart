import 'package:flutter/material.dart'
    show Color, Offset, CustomScrollView, ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arabic_academy/main.dart';
import 'package:arabic_academy/ui/neumorphic_components.dart';
import 'package:arabic_academy/ui/home_quick_action.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Learner dashboard retains four current neumorphic shortcuts '
    'and opens the textbook and practice tabs',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'welcome_seen': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final state = AcademyState(prefs, <String, dynamic>{
        'modules': <dynamic>[
          <String, dynamic>{
            'id': 'u1',
            'title_ru': 'Первый раздел',
            'title_ar': 'الدَّرْسُ الْأَوَّلُ',
            'access_default': 'free',
          },
        ],
        'lessons': <dynamic>[
          <String, dynamic>{
            'id': 'demo',
            'title': 'Приветствие и имя',
            'title_ar': 'التَّحِيَّةُ وَالاسْمُ',
            'goal': 'Поздороваться',
            'dialogue': <dynamic>[],
            'vocabulary': <dynamic>[],
            'grammar': '',
            'question': 'Тест?',
            'options': <dynamic>['А', 'Б'],
            'correct': 0,
            'homework': '',
          },
        ],
      });
      addTearDown(state.dispose);

      await tester.pumpWidget(AcademyApp(state: state));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -440),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NeumorphicFeatureTile), findsNWidgets(4));
      expect(find.text('Слова в образах'), findsOneWidget);
      expect(find.text('Диалоги'), findsOneWidget);
      expect(find.text('Арабское письмо'), findsOneWidget);
      expect(find.text('Проверить себя'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('study-tab-1')));
      await tester.pumpAndSettle();
      expect(find.byType(UnitScreen), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('study-tab-2')));
      await tester.pumpAndSettle();
      expect(find.text('Практика'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('study-tab-0')));
      await tester.pumpAndSettle();
      expect(find.text('Арабский каждый день'), findsOneWidget);
    },
  );

  testWidgets('Course progress reflects saved completion, not mock scores', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'welcome_seen': true,
      'completed': <String>['demo'],
    });
    final prefs = await SharedPreferences.getInstance();
    final state = AcademyState(prefs, <String, dynamic>{
      'modules': <dynamic>[],
      'lessons': <dynamic>[
        <String, dynamic>{'id': 'demo', 'title': 'Приветствие и имя'},
      ],
    });
    addTearDown(state.dispose);
    await tester.pumpWidget(AcademyApp(state: state));
    await tester.pumpAndSettle();
    // Progress hero is at the beginning of Today's list. The previous test
    // dragged it offscreen before checking its contents.
    expect(find.text('Пройдено 1 из 1 уроков'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('study-tab-3')));
    await tester.pumpAndSettle();
    expect(find.text('Ученица · локальное обучение'), findsOneWidget);
  });
  testWidgets('Two quick actions use sage frames and separate transparent 3D icons',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'welcome_seen': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final state = AcademyState(prefs, <String, dynamic>{
      'modules': <dynamic>[],
      'lessons': <dynamic>[
        <String, dynamic>{'id': 'demo', 'title': 'Приветствие'},
      ],
    });
    addTearDown(state.dispose);
    await tester.pumpWidget(AcademyApp(state: state));
    await tester.pumpAndSettle();

    expect(find.byType(HomeQuickActionTile), findsNWidgets(2));
    expect(find.byKey(const ValueKey('home-review-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-next-card')), findsOneWidget);
    final review = tester.widget<HomeQuickActionTile>(
      find.byKey(const ValueKey('home-review-card')),
    );
    final next = tester.widget<HomeQuickActionTile>(
      find.byKey(const ValueKey('home-next-card')),
    );
    expect(review.image, 'assets/artwork/home_quick/review.webp');
    expect(next.image, 'assets/artwork/home_quick/next.webp');
    expect(HomeQuickActionTile.sageBorder, const Color(0xFFC7D7C1));
    expect(find.text('Мой учебный путь'), findsNothing);
    expect(find.byKey(const ValueKey('home-continue-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-next-lesson')), findsOneWidget);
  });

}
