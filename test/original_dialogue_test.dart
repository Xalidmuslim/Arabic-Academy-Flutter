import 'package:arabic_academy/features/learning/original_dialogue_screen.dart';
import 'package:arabic_academy/services/private_dialogue_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryOriginalDialogueStore implements OriginalDialogueStore {
  MemoryOriginalDialogueStore({this.pdfPresent = true, this.extracted = '', this.scanned = ''});
  bool pdfPresent;
  String extracted;
  String scanned;
  int ocrCalls = 0;
  final Map<String, SavedOriginalDialogue> records = {};
  String _key(int part, String lessonId) => '$part/$lessonId';

  @override
  Future<bool> hasImportedPdf(int part) async => pdfPresent;

  @override
  Future<SavedOriginalDialogue?> load(int part, String lessonId) async =>
      records[_key(part, lessonId)];

  @override
  Future<void> save(int part, String lessonId,
      SavedOriginalDialogue record) async {
    records[_key(part, lessonId)] = record;
  }

  @override
  Future<void> clearPart(int part) async {
    records.removeWhere((key, _) => key.startsWith('$part/'));
  }

  @override
  Future<PdfTextExtraction> extractText(int part, int pageIndex) async =>
      PdfTextExtraction(extracted.isEmpty ? 'empty' : 'ok', extracted);

  @override
  Future<PdfTextExtraction> recognizeScan(int part, int pageIndex) async {
    ocrCalls++;
    return PdfTextExtraction(scanned.isEmpty ? 'empty' : 'ocr', scanned);
  }
}

void main() {
  const lesson = <String, dynamic>{
    'id': 'book1-u1-d1',
    'title': 'Диалог 1. Знакомство в учебном центре',
    'pdf_part': 1,
    'pdf_page': 23,
    // The editor's dialogue does NOT become the alleged original.
    'dialogue': [
      {'ar': 'هذا نص من إعدادنا', 'ru': 'Авторский текст'}
    ],
  };

  test('saved personal transcription requires a review flag', () {
    const record = SavedOriginalDialogue(
      pageIndex: 27,
      text: 'السَّلَامُ عَلَيْكُمْ',
      verified: false,
      source: 'pdf_text',
    );
    expect(SavedOriginalDialogue.fromJson(record.toJson())!.verified, false);
    expect(SavedOriginalDialogue.fromJson(record.toJson())!.pageIndex, 27);
    expect(SavedOriginalDialogue.fromJson({'version': 1}), isNull);
    expect(SavedOriginalDialogue.fromJson({
      ...record.toJson(), 'source': 'publisher_official',
    }), isNull);
  });

  testWidgets('missing personal PDF never substitutes editorial dialogue',
      (tester) async {
    final store = MemoryOriginalDialogueStore(pdfPresent: false);
    await tester.pumpWidget(MaterialApp(
      home: OriginalDialogueScreen(lesson: lesson, store: store),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Оригинальный диалог'), findsOneWidget);
    expect(find.text('Импортировать личный PDF'), findsOneWidget);
    expect(find.text('Авторский текст'), findsNothing);
    expect(find.text('هذا نص من إعدادنا'), findsNothing);
  });

  testWidgets('owner-verified local text is displayed as independent lines',
      (tester) async {
    final store = MemoryOriginalDialogueStore();
    store.records['1/book1-u1-d1'] = const SavedOriginalDialogue(
      pageIndex: 29,
      text: 'السَّلَامُ عَلَيْكُمْ\nوَعَلَيْكُمُ السَّلَامُ',
      verified: true,
      source: 'manual',
    );
    await tester.pumpWidget(MaterialApp(
      home: OriginalDialogueScreen(lesson: lesson, store: store),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Страница 30'), findsOneWidget);
    expect(find.textContaining('Проверено вами по PDF'), findsOneWidget);
    expect(find.text('السَّلَامُ عَلَيْكُمْ'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('وَعَلَيْكُمُ السَّلَامُ'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('وَعَلَيْكُمُ السَّلَامُ'), findsOneWidget);
    expect(find.text('هذا نص من إعدادنا'), findsNothing);
  });

  testWidgets('extracted text is unverified until user reviews and saves',
      (tester) async {
    final store = MemoryOriginalDialogueStore(
      extracted: 'النَّصُ مِنَ الْكِتَابِ',
    );
    await tester.pumpWidget(MaterialApp(
      home: OriginalDialogueScreen(lesson: lesson, store: store),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
        const ValueKey('original-dialogue-extract')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('original-dialogue-editor')),
        findsOneWidget);
    expect(find.textContaining('Текстовый слой найден'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('original-dialogue-verified')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    final verify = tester.widget<SwitchListTile>(
        find.byKey(const ValueKey('original-dialogue-verified')));
    expect(verify.value, false);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('original-dialogue-save')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(
        const ValueKey('original-dialogue-save')));
    await tester.pumpAndSettle();
    final saved = store.records['1/book1-u1-d1'];
    expect(saved, isNotNull);
    expect(saved!.verified, isFalse);
    expect(saved.source, 'pdf_text');
    expect(store.ocrCalls, 0);
    expect(saved.pageIndex, 23);
  });

  testWidgets('unreadable scan reports OCR and supports manual corrections',
      (tester) async {
    final store = MemoryOriginalDialogueStore(extracted: '');
    await tester.pumpWidget(MaterialApp(
      home: OriginalDialogueScreen(lesson: lesson, store: store),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
        const ValueKey('original-dialogue-extract')));
    await tester.pumpAndSettle();
    expect(find.textContaining('OCR не смог прочитать'), findsOneWidget);
    expect(store.ocrCalls, 1);
    expect(find.byKey(const ValueKey('original-dialogue-editor')),
        findsOneWidget);
  });
  testWidgets('Arabic OCR extracts scanned page and keeps lines unverified',
      (tester) async {
    final store = MemoryOriginalDialogueStore(
      extracted: '',
      scanned: 'السَّلَامُ عَلَيْكُمْ\nوَعَلَيْكُمُ السَّلَامُ',
    );
    await tester.pumpWidget(MaterialApp(
      home: OriginalDialogueScreen(lesson: lesson, store: store),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
        const ValueKey('original-dialogue-extract')));
    await tester.pumpAndSettle();
    expect(store.ocrCalls, 1);
    expect(find.textContaining('Арабский текст распознан со скана'),
        findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('original-dialogue-save')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(
        const ValueKey('original-dialogue-save')));
    await tester.pumpAndSettle();
    final saved = store.records['1/book1-u1-d1'];
    expect(saved, isNotNull);
    expect(saved!.source, 'ocr_arabic');
    expect(saved.verified, isFalse);
    expect(saved.text, contains('السَّلَامُ'));
  });

  testWidgets('force OCR overrides a searchable text layer', (tester) async {
    final store = MemoryOriginalDialogueStore(
      extracted: 'السَّلَامُ',
      scanned: 'وَعَلَيْكُمُ السَّلَامُ',
    );
    await tester.pumpWidget(MaterialApp(
      home: OriginalDialogueScreen(lesson: lesson, store: store),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
        const ValueKey('original-dialogue-force-ocr')));
    await tester.pumpAndSettle();
    expect(store.ocrCalls, 1);
    final editor = tester.widget<TextField>(
      find.byKey(const ValueKey('original-dialogue-editor')),
    );
    expect(editor.controller!.text, contains('وَعَلَيْكُمُ'));
  });


}
