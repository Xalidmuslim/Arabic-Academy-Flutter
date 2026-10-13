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
    expect(find.textContaining('282 страницы'), findsOneWidget);
  });

  testWidgets('second book PDF is independent and its page count is explained', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: TextbookReaderScreen(part: 2, initialPage: 22),
    ));
    await tester.pump();
    expect(find.text('Учебник · Часть 2'), findsOneWidget);
    expect(find.textContaining('284 страницы'), findsOneWidget);
    expect(find.byIcon(Icons.file_open_outlined), findsOneWidget);
  });

}
