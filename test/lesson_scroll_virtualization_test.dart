import 'package:arabic_academy/core/academy_state.dart';
import 'package:arabic_academy/features/learning/lesson_screen.dart';
import 'package:arabic_academy/ui/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Long lesson vocabulary creates only visible word cards',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final lesson = <String, dynamic>{
      'id': 'scroll-lesson',
      'title': 'Словарь',
      'vocabulary': List<dynamic>.generate(
        250,
        (i) => <String, String>{'ar': 'كَلِمَةٌ', 'ru': 'Слово $i'},
      ),
      'dialogue': <dynamic>[],
    };
    final state = AcademyState(
      await SharedPreferences.getInstance(),
      {'modules': <dynamic>[], 'lessons': <dynamic>[lesson]},
    );
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: DesignTokens.theme(),
      home: LessonScreen(state: state, lesson: lesson, initialTab: 1),
    ));
    await tester.pumpAndSettle();
    final lazyList = tester.widgetList<SliverList>(
      find.byType(SliverList),
    ).where((list) => list.delegate is SliverChildBuilderDelegate);
    expect(lazyList, isNotEmpty,
        reason: 'All 250 vocabulary cards must not be built eagerly');
    expect(find.text('Слово 0'), findsOneWidget);
    expect(find.text('Слово 249'), findsNothing);
    // Natural drag must remain valid with virtualized content.
    await tester.drag(find.byType(CustomScrollView).first,
        const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
