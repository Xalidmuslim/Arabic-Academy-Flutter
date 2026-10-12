import 'package:flutter/material.dart'
    show Offset, CustomScrollView, Scrollable, BackButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arabic_academy/main.dart';
import 'package:arabic_academy/ui/neumorphic_components.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Learner dashboard shows four neumorphic shortcuts and opens lessons',
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

      await tester.pumpWidget(AcademyApp(state: state));
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -260),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NeumorphicFeatureTile), findsNWidgets(4));
      expect(find.text('Уроки'), findsWidgets);
      expect(find.text('Словарь'), findsOneWidget);
      expect(find.text('Грамматика'), findsOneWidget);
      expect(find.text('Мой прогресс'), findsOneWidget);

      final lessonsLabel = find.descendant(
        of: find.widgetWithText(NeumorphicFeatureTile, 'Уроки'),
        matching: find.text('Уроки'),
      );
      await tester.ensureVisible(lessonsLabel);
      await tester.pumpAndSettle();
      await tester.tap(lessonsLabel);
      await tester.pumpAndSettle();
      expect(find.byType(UnitScreen), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Базовый уровень 1'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Базовый уровень 1'), findsWidgets);
      final progressCard = find.widgetWithText(
        NeumorphicFeatureTile,
        'Мой прогресс',
      );
      // Scroll the lazy dashboard until the progress shortcut is reachable.
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, 240),
      );
      await tester.pumpAndSettle();
      final progressLabel = find.descendant(
        of: progressCard,
        matching: find.text('Мой прогресс'),
      );
      await tester.ensureVisible(progressLabel);
      await tester.pumpAndSettle();
      await tester.tap(progressLabel);
      await tester.pumpAndSettle();
      expect(find.byType(LearnerProgressScreen), findsOneWidget);
    },
  );

  testWidgets('Course progress displays real completion, not mock statistics', (
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
    await tester.pumpWidget(AcademyApp(state: state));
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -650),
    );
    await tester.pumpAndSettle();
    expect(find.text('Пройдено 1 из 1 уроков'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });
}
