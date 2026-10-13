import 'dart:convert';

import 'package:arabic_academy/core/academy_state.dart';
import 'package:arabic_academy/features/learning/lesson_screen.dart';
import 'package:arabic_academy/features/learning/textbook_reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('eight chapters and 24 original dialogues use validated PDF pages', () async {
    final jsonText = await rootBundle.loadString(
      'assets/content/book1_original_dialogues.json',
    );
    final data = jsonDecode(jsonText) as Map<String, dynamic>;
    final units = (data['modules'] as List).cast<Map<String, dynamic>>();
    final lessons = (data['lessons'] as List).cast<Map<String, dynamic>>();
    expect(units.length, 8);
    expect(lessons.length, 24);
    const starts = <int>[23, 49, 77, 103, 131, 157, 185, 211];
    final ids = <String>{};
    for (var index = 0; index < lessons.length; index++) {
      final lesson = lessons[index];
      final chapter = index ~/ 3;
      final dialogue = index % 3;
      expect(lesson['module_id'], units[chapter]['id']);
      expect(lesson['lesson_order'], dialogue + 1);
      expect(lesson['pdf_page'], starts[chapter] + dialogue * 2);
      expect(lesson['source'], 'original_editorial');
      expect(lesson['pdf_reference_kind'], 'parallel_theme_reference_not_verbatim');
      expect(lesson['dialogue'], isNotEmpty);
      expect(lesson['vocabulary'], isNotEmpty);
      expect(lesson['correct'], inInclusiveRange(0, 2));
      expect(ids.add(lesson['id'] as String), isTrue);
    }
  });

  testWidgets('dialogue links to exact original PDF page', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final text = await rootBundle.loadString(
      'assets/content/book1_original_dialogues.json',
    );
    final catalog = jsonDecode(text) as Map<String, dynamic>;
    final state = AcademyState(prefs, catalog);
    final lesson = Map<String, dynamic>.from(
      (catalog['lessons'] as List).first as Map,
    );

    await tester.pumpWidget(
      MaterialApp(home: LessonScreen(
        state: state,
        lesson: lesson,
        initialTab: 2,
      )),
    );
    await tester.pump();
    final button = find.byKey(const ValueKey('open-original-pdf-page'));
    expect(button, findsOneWidget);
    expect(find.textContaining('страница 24'), findsOneWidget);
    await tester.ensureVisible(button);
    await tester.tap(button);
    // The PDF reader initializes platform services asynchronously. Navigation
    // must not wait for native PDF loading or an indefinitely active indicator.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(TextbookReaderScreen), findsOneWidget);
    expect(find.text('Учебник · Часть 1'), findsOneWidget);
  });
}
