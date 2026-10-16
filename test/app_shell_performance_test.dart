import 'package:arabic_academy/app.dart';
import 'package:arabic_academy/core/academy_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AcademyState> state() async {
    SharedPreferences.setMockInitialValues({
      'welcome_seen': true,
    });
    final model = AcademyState(
      await SharedPreferences.getInstance(),
      <String, dynamic>{
        'modules': <dynamic>[],
        'lessons': <dynamic>[],
      },
    );
    await model.initialize();
    return model;
  }

  testWidgets('saving learning progress does not rebuild MaterialApp',
      (tester) async {
    final model = await state();
    addTearDown(model.dispose);
    await tester.pumpWidget(AcademyApp(state: model));
    await tester.pumpAndSettle();

    final material = find.byType(MaterialApp);
    final before = tester.widget<MaterialApp>(material);
    final lessonList = model.allLessons;
    expect(identical(lessonList, model.allLessons), isTrue);

    await model.visitLesson('lesson-15');
    await tester.pumpAndSettle();
    expect(identical(before, tester.widget<MaterialApp>(material)), isTrue,
        reason: 'progress updates should repaint relevant leaf widgets only');
    expect(model.lastLessonId, 'lesson-15');
    expect(identical(lessonList, model.allLessons), isFalse,
        reason: 'persisted lesson edits must invalidate cached catalog view');

    await model.setSetting('appearance', 'dark');
    await tester.pumpAndSettle();
    expect(tester.widget<MaterialApp>(material).themeMode, ThemeMode.dark);
    expect(identical(before, tester.widget<MaterialApp>(material)), isFalse);
  });

  testWidgets('switching between student tabs retains root navigation',
      (tester) async {
    final model = await state();
    addTearDown(model.dispose);
    await tester.pumpWidget(AcademyApp(state: model));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('study-tab-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('study-tab-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('study-tab-0')));
    await tester.pumpAndSettle();
    expect(find.text('Арабский каждый день'), findsOneWidget);
    expect(model.lastLessonId, isNull);
  });
}
