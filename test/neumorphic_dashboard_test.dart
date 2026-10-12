import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arabic_academy/main.dart';
import 'package:arabic_academy/ui/neumorphic_components.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Learner dashboard shows four neumorphic shortcuts and opens lessons',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'welcome_seen': true});
    final prefs = await SharedPreferences.getInstance();
    final state = AcademyState(prefs, <String, dynamic>{
      'modules': <dynamic>[
        <String, dynamic>{
          'id': 'u1', 'title_ru': 'Первый раздел',
          'title_ar': 'الدَّرْسُ الْأَوَّلُ', 'access_default': 'free',
        },
      ],
      'lessons': <dynamic>[
        <String, dynamic>{
          'id': 'demo', 'title': 'Приветствие и имя',
          'title_ar': 'التَّحِيَّةُ وَالاسْمُ',
          'goal': 'Поздороваться', 'dialogue': <dynamic>[],
          'vocabulary': <dynamic>[], 'grammar': '',
          'question': 'Тест?', 'options': <dynamic>['А', 'Б'],
          'correct': 0, 'homework': '',
        },
      ],
    });

    await tester.pumpWidget(AcademyApp(state: state));
    expect(find.byType(NeumorphicFeatureTile), findsNWidgets(4));
    expect(find.text('Уроки'), findsWidgets);
    expect(find.text('Словарь'), findsOneWidget);
    expect(find.text('Базовый уровень 1'), findsWidgets);

    await tester.tap(find.widgetWithText(NeumorphicFeatureTile, 'Уроки'));
    await tester.pumpAndSettle();
    expect(find.byType(UnitScreen), findsOneWidget);
  });

  testWidgets('Course progress displays real completion, not mock statistics',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'welcome_seen': true, 'completed': <String>['demo'],
    });
    final prefs = await SharedPreferences.getInstance();
    final state = AcademyState(prefs, <String, dynamic>{
      'modules': <dynamic>[],
      'lessons': <dynamic>[
        <String, dynamic>{'id': 'demo', 'title': 'Приветствие и имя'},
      ],
    });
    await tester.pumpWidget(AcademyApp(state: state));
    expect(find.text('1 из 1'), findsWidgets);
    expect(find.text('100%'), findsOneWidget);
  });
}
