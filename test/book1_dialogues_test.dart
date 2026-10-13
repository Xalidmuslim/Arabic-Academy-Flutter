import 'dart:convert';

import 'package:arabic_academy/features/learning/lesson_pdf_link.dart';
import 'package:arabic_academy/features/learning/textbook_reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('PDF button routes to the exact selected original page', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: OriginalTextbookLink(pageIndex: 23)),
    ));
    final button = find.byKey(const ValueKey('open-original-pdf-page'));
    expect(button, findsOneWidget);
    expect(find.textContaining('страница 24'), findsOneWidget);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final reader = find.byType(TextbookReaderScreen);
    expect(reader, findsOneWidget);
    expect(tester.widget<TextbookReaderScreen>(reader).initialPage, 23);
  });
}
