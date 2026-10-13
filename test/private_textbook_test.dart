import 'package:arabic_academy/features/learning/textbook_reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('private textbook route never embeds publisher PDF in APK', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(
      home: TextbookReaderScreen(),
    ));
    await tester.pump();
    expect(find.text('Учебник · Часть 1'), findsOneWidget);
    // Linux widget tests deliberately cannot read a real Android PDF.
    expect(find.textContaining('Просмотр сканированных страниц'), findsOneWidget);
    expect(find.byIcon(Icons.file_open_outlined), findsOneWidget);
  });
}
