import 'package:arabic_academy/core/academy_state.dart';
import 'package:arabic_academy/features/learning/situations_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('dialogue catalog uses lazy sliver builder and preserves actions',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final state = AcademyState(
      await SharedPreferences.getInstance(),
      <String, dynamic>{
        'modules': <dynamic>[],
        'lessons': <dynamic>[
          for (var i = 0; i < 80; i++)
            <String, dynamic>{
              'id': 'dialogue-$i',
              'module_id': 'u3',
              'title': 'Диалог $i',
              'dialogue': [
                {'ar': 'السَّلَامُ عَلَيْكُمْ', 'ru': 'Мир вам'},
                {'ar': 'وَعَلَيْكُمُ السَّلَامُ', 'ru': 'И вам мир'},
              ],
              if (i == 0)
                'dialogue_illustration_asset':
                    'assets/artwork/lesson_generated/dialogue_u3_d3_furniture.webp',
              if (i == 0) 'dialogue_illustration_format': 'square',
              'pdf_page': 22,
            },
        ],
      },
    );
    addTearDown(state.dispose);
    await state.initialize();

    await tester.pumpWidget(MaterialApp(home: SituationsScreen(state: state)));
    await tester.pump();
    final list = tester.widget<ListView>(find.byType(ListView).first);
    expect(list.childrenDelegate, isA<SliverChildBuilderDelegate>(),
        reason: 'a full illustrated dialogue catalog must not create '
          'every card in the screen build method');
    expect(find.text('Диалог 0'), findsOneWidget);
    expect(find.text('Диалог 79'), findsNothing);
    expect(find.text('Авторский текст'), findsWidgets);
    expect(find.text('Авторская практика'), findsWidgets);
    expect(find.text('Оригинал · мой PDF'), findsWidgets);

    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty dialogue catalog still shows correct placeholder',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AcademyState(
      await SharedPreferences.getInstance(),
      {'modules': <dynamic>[], 'lessons': <dynamic>[]},
    );
    addTearDown(state.dispose);
    await state.initialize();
    await tester.pumpWidget(MaterialApp(home: SituationsScreen(state: state)));
    await tester.pumpAndSettle();
    expect(find.text('Диалоги не найдены'), findsOneWidget);
  });
}
