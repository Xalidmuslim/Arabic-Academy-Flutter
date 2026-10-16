import 'package:flutter/material.dart'
    show Offset, CustomScrollView;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arabic_academy/main.dart';
import 'package:arabic_academy/ui/neumorphic_components.dart';

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
        const Offset(0, -260),
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
}
