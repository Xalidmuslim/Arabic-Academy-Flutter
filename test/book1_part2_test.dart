import 'dart:convert';

import 'package:arabic_academy/core/academy_state.dart';
import 'package:arabic_academy/features/learning/course_screen.dart';
import 'package:arabic_academy/features/learning/lesson_screen.dart';
import 'package:arabic_academy/features/learning/textbook_reader_screen.dart';
import 'package:arabic_academy/features/learning/original_dialogue_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('eight additional Book 1 Part 2 units contain 72 usable editorial lessons', () async {
    final content = await rootBundle.loadString('assets/content/book1_part2_editorial.json');
    final book = jsonDecode(content) as Map<String, dynamic>;
    final units = (book['modules'] as List).cast<Map<String, dynamic>>();
    final lessons = (book['lessons'] as List).cast<Map<String, dynamic>>();
    expect(units, hasLength(8));
    expect(lessons, hasLength(72));
    const starts = [22, 48, 76, 102, 130, 156, 184, 210];
    final ids = <String>{};
    for (var i = 0; i < units.length; i++) {
      final unit = units[i];
      expect(unit['id'], 'u${i + 9}');
      expect(unit['pdf_page'], starts[i]);
      expect(unit['pdf_part'], 2);
      final selected = lessons.where((l) => l['module_id'] == unit['id']).toList();
      expect(selected, hasLength(9));
      for (var j = 0; j < selected.length; j++) {
        final lesson = selected[j];
        expect(lesson['lesson_order'], j + 1);
        expect(lesson['pdf_part'], 2);
        expect(lesson['source'], 'original_editorial');
        expect(lesson['pdf_reference_kind'], 'parallel_theme_reference_not_verbatim');
        expect(lesson['dialogue'], isNotEmpty);
        expect(lesson['vocabulary'], isNotEmpty);
        expect(lesson['pdf_page'], inInclusiveRange(starts[i] + 1, 283));
        expect(lesson['correct'], inInclusiveRange(0, 2));
        expect(ids.add(lesson['id'] as String), isTrue);
      }
    }
  });

  testWidgets('Book 1 Part 2 lesson opens corresponding imported PDF', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final text = await tester.runAsync(
      () => rootBundle.loadString('assets/content/book1_part2_editorial.json'),
    );
    final book = jsonDecode(text!) as Map<String, dynamic>;
    final state = AcademyState(prefs, book);
    addTearDown(state.dispose);
    final lesson = Map<String, dynamic>.from((book['lessons'] as List).first as Map);
    await tester.pumpWidget(MaterialApp(
      home: LessonScreen(state: state, lesson: lesson, initialTab: 2),
    ));
    await tester.pump();
    final link = find.byKey(const ValueKey('open-original-dialogue'));
    expect(link, findsOneWidget);
    expect(find.byKey(const ValueKey('open-original-pdf-page')), findsNothing);
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(OriginalDialogueScreen), findsOneWidget);
    expect(tester.widget<OriginalDialogueScreen>(
      find.byType(OriginalDialogueScreen)).lesson['pdf_part'], 2);
  });

  testWidgets('course catalog lists both separately imported private PDFs', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final state = AcademyState(await SharedPreferences.getInstance(),
      <String, dynamic>{'modules': <dynamic>[], 'lessons': <dynamic>[]});
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(home: UnitScreen(state: state)));
    expect(find.byKey(const ValueKey('private-pdf-textbook-entry-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('private-pdf-textbook-entry-2')), findsOneWidget);
  });
}
