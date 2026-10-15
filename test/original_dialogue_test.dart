import 'dart:convert';
import 'dart:typed_data';

import 'package:arabic_academy/features/learning/dialogue_region_picker_screen.dart';
import 'package:arabic_academy/features/learning/original_dialogue_screen.dart';
import 'package:arabic_academy/services/dialogue_ocr_region.dart';
import 'package:arabic_academy/services/private_dialogue_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryOriginalDialogueStore implements OriginalDialogueStore {
  MemoryOriginalDialogueStore({
    this.pdfPresent = true,
    this.scanned = '',
    this.secondScan,
  });

  bool pdfPresent;
  String scanned;
  String? secondScan;
  int ocrCalls = 0;
  int wholePageCalls = 0;
  int previewCalls = 0;
  DialogueOcrRegion? lastCrop;
  final Map<String, SavedOriginalDialogue> records = {};

  String _key(int part, String lessonId) => '$part/$lessonId';

  @override
  Future<bool> hasImportedPdf(int part) async => pdfPresent;

  @override
  Future<SavedOriginalDialogue?> load(int part, String lessonId) async =>
      records[_key(part, lessonId)];

  @override
  Future<void> save(
      int part, String lessonId, SavedOriginalDialogue record) async {
    records[_key(part, lessonId)] = record;
  }

  @override
  Future<void> clearPart(int part) async =>
      records.removeWhere((key, _) => key.startsWith('$part/'));

  @override
  Future<PdfTextExtraction> extractText(int part, int pageIndex) async {
    wholePageCalls++;
    return const PdfTextExtraction('empty', '');
  }

  @override
  Future<PdfTextExtraction> recognizeScan(int part, int pageIndex) async {
    wholePageCalls++;
    return PdfTextExtraction('ocr', scanned);
  }

  @override
  Future<PrivatePdfPagePreview?> previewPage(int part, int pageIndex) async {
    previewCalls++;
    if (!pdfPresent) return null;
    // Valid, transparent 1x1 PNG: UI tests do not ship or display a
    // copyrighted original PDF page.
    return PrivatePdfPagePreview(
      bytes: Uint8List.fromList(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9YlCnWQAAAAASUVORK5CYII=',
      )),
      width: 1,
      height: 1,
    );
  }

  @override
  Future<PdfTextExtraction> recognizeRegion(
    int part, int pageIndex, DialogueOcrRegion region,
  ) async {
    ocrCalls++;
    lastCrop = region;
    final value = ocrCalls > 1 ? (secondScan ?? scanned) : scanned;
    return PdfTextExtraction(value.isEmpty ? 'empty' : 'ocr', value);
  }
}

const lesson = <String, dynamic>{
  'id': 'book1-u1-d1',
  'title': 'Диалог 1. Знакомство в учебном центре',
  'pdf_part': 1,
  'pdf_page': 23,
  'dialogue': [
    {'ar': 'هذا نص من إعدادنا', 'ru': 'Авторский текст'}
  ],
};

Future<void> openCrop(WidgetTester tester) async {
  final extract = find.byKey(const ValueKey('original-dialogue-extract'));
  await tester.ensureVisible(extract);
  await tester.tap(extract);
  await tester.pumpAndSettle();
  expect(find.byType(DialogueRegionPickerScreen), findsOneWidget);
  expect(find.text('Выберите текст диалога'), findsOneWidget);
  expect(find.byKey(const ValueKey('ocr-crop-page-preview')), findsOneWidget);
}

Future<void> confirmCrop(WidgetTester tester) async {
  final confirm = find.byKey(const ValueKey('ocr-crop-confirm'));
  await tester.scrollUntilVisible(
    confirm,
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(confirm);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('crop presets cover only the right-hand dialogue column', () {
    const top = DialogueOcrRegion.upperDialogue;
    const bottom = DialogueOcrRegion.lowerDialogue;
    expect(top.valid, isTrue);
    expect(bottom.valid, isTrue);
    expect(top.left, greaterThan(0.50));
    expect(bottom.left, greaterThan(0.50));
    expect(top.bottom, lessThan(bottom.top));
    expect(top.normalizedBounds, [0.57, 0.20, 0.97, 0.54]);
  });

  test('manual crop handles reversed drags and bounds', () {
    final selected = DialogueOcrRegion.fromDrag(
      0.94, 0.89, 0.58, 0.20,
    );
    expect(selected.valid, isTrue);
    expect(selected.left, 0.58);
    expect(selected.bottom, 0.89);
    final clipped = DialogueOcrRegion.fromDrag(
      -8, -2, 4, 3,
    );
    expect(clipped.normalizedBounds, [0, 0, 1, 1]);
    expect(() => const DialogueOcrRegion(
        left: .7, top: .5, right: .7, bottom: .5,
      ).normalizedBounds, throwsFormatException);
  });

  test('local transcript remains unverified until source review', () {
    const record = SavedOriginalDialogue(
      pageIndex: 27,
      text: 'السَّلَامُ عَلَيْكُمْ',
      verified: false,
      source: 'ocr_arabic',
    );
    expect(SavedOriginalDialogue.fromJson(record.toJson())!.verified, false);
    expect(SavedOriginalDialogue.fromJson(record.toJson())!.source, 'ocr_arabic');
    expect(SavedOriginalDialogue.fromJson({'version': 1}), isNull);
  });

  testWidgets('missing local book never substitutes editorial dialogue',
      (tester) async {
    final store = MemoryOriginalDialogueStore(pdfPresent: false);
    await tester.pumpWidget(MaterialApp(
      home: OriginalDialogueScreen(lesson: lesson, store: store),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Импортировать личный PDF'), findsOneWidget);
    expect(find.text('هذا نص من إعدادنا'), findsNothing);
  });

  testWidgets('saved personal Arabic lines are rendered independently',
      (tester) async {
    final store = MemoryOriginalDialogueStore();
    store.records['1/book1-u1-d1'] = const SavedOriginalDialogue(
      pageIndex: 29,
      text: 'السَّلَامُ عَلَيْكُمْ" + "\\n" + "وَعَلَيْكُمُ السَّلَامُ',
      verified: true,
      source: 'manual',
    );
    await tester.pumpWidget(MaterialApp(
      home: OriginalDialogueScreen(lesson: lesson, store: store),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Страница 30'), findsOneWidget);
    expect(find.text('السَّلَامُ عَلَيْكُمْ'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('وَعَلَيْكُمُ السَّلَامُ'),
      175,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('وَعَلَيْكُمُ السَّلَامُ'), findsOneWidget);
  });

  testWidgets('OCR sees only confirmed upper dialogue region',
      (tester) async {
    final store = MemoryOriginalDialogueStore(
      scanned: 'السَّلَامُ عَلَيْكُمْ',
    );
    await tester.pumpWidget(MaterialApp(
      home: OriginalDialogueScreen(lesson: lesson, store: store),
    ));
    await tester.pumpAndSettle();

    await openCrop(tester);
    await confirmCrop(tester);
    expect(store.previewCalls, 1);
    expect(store.wholePageCalls, 0);
    expect(store.ocrCalls, 1);
    expect(store.lastCrop, same(DialogueOcrRegion.upperDialogue));
    expect(find.textContaining('Распознан только выбранный фрагмент'),
        findsOneWidget);

    final save = find.byKey(const ValueKey('original-dialogue-save'));
    await tester.scrollUntilVisible(
      save, 220, scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(save);
    await tester.pumpAndSettle();
    final stored = store.records['1/book1-u1-d1'];
    expect(stored?.text, 'السَّلَامُ عَلَيْكُمْ');
    expect(stored?.verified, isFalse);
    expect(stored?.source, 'ocr_arabic');
  });

  testWidgets('lower dialogue preset never includes the first text area',
      (tester) async {
    final store = MemoryOriginalDialogueStore(
      scanned: 'وَعَلَيْكُمُ السَّلَامُ',
    );
    await tester.pumpWidget(MaterialApp(
      home: OriginalDialogueScreen(lesson: lesson, store: store),
    ));
    await tester.pumpAndSettle();
    await openCrop(tester);
    await tester.tap(find.byKey(const ValueKey('ocr-crop-lower')));
    await confirmCrop(tester);
    expect(store.lastCrop, same(DialogueOcrRegion.lowerDialogue));
    expect(store.wholePageCalls, 0);
  });

  testWidgets('two regions may be combined without replacing first dialogue',
      (tester) async {
    final store = MemoryOriginalDialogueStore(
      scanned: 'السَّلَامُ عَلَيْكُمْ',
      secondScan: 'وَعَلَيْكُمُ السَّلَامُ',
    );
    await tester.pumpWidget(MaterialApp(
      home: OriginalDialogueScreen(lesson: lesson, store: store),
    ));
    await tester.pumpAndSettle();
    await openCrop(tester);
    await confirmCrop(tester);

    await openCrop(tester);
    await tester.tap(find.byKey(const ValueKey('ocr-crop-lower')));
    await confirmCrop(tester);
    expect(find.text('Добавить распознанные реплики?'), findsOneWidget);
    await tester.tap(find.text('Добавить'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(
        find.byKey(const ValueKey('original-dialogue-editor')));
    expect(field.controller!.text, contains('السَّلَامُ عَلَيْكُمْ'));
    expect(field.controller!.text, contains('وَعَلَيْكُمُ السَّلَامُ'));
    expect(store.ocrCalls, 2);
  });

  testWidgets('OCR failure leaves existing text untouched',
      (tester) async {
    final store = MemoryOriginalDialogueStore(scanned: '');
    await tester.pumpWidget(MaterialApp(
      home: OriginalDialogueScreen(lesson: lesson, store: store),
    ));
    await tester.pumpAndSettle();
    await openCrop(tester);
    await confirmCrop(tester);
    expect(find.textContaining('Выделенный фрагмент не удалось прочитать'),
        findsOneWidget);
    expect(store.wholePageCalls, 0);
    expect(store.ocrCalls, 1);
  });
}
