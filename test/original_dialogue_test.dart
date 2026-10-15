import 'dart:convert';
import 'dart:typed_data';

import 'package:arabic_academy/features/learning/original_dialogue_screen.dart';
import 'package:arabic_academy/services/private_dialogue_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryOriginalDialogueStore
    implements OriginalDialogueStore, DialogueArtworkStore {
  static final Uint8List tinyPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAYAAACp8Z5+'
    'AAAAFklEQVR4nGP88OzSfwYkwMSABggLAADwggOvWRDQ6AAAAABJRU5ErkJggg==',
  );
  int cropRenders = 0;
  DialogueCrop? lastCrop;

  @override
  Future<Uint8List> renderCrop(int part, int pageIndex, DialogueCrop crop) async {
    cropRenders++;
    lastCrop = crop;
    return tinyPng;
  }
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
  Future<DialogueOcrResult> recognizeDialogue(
    int part, int pageIndex, int dialogueSlot,
  ) async {
    ocrCalls++;
    return DialogueOcrResult(
      scanned.isEmpty ? 'empty' : 'ocr',
      scanned,
      pageIndex: dialogueSlot == 2 && pageIndex >= 2
          ? pageIndex - 2
          : pageIndex,
      autoSelected: scanned.isNotEmpty,
      detectedBlocks: scanned.isNotEmpty ? (dialogueSlot == 2 ? 2 : 1) : 0,
      crop: scanned.isNotEmpty
          ? const DialogueCrop(0.08, 0.23, 0.92, 0.72)
          : null,
      imagePng: scanned.isNotEmpty ? tinyPng : null,
    );
  }

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
      scanned: 'النَّصُ مِنَ الْكِتَابِ',
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
    expect(find.textContaining('Область диалога найдена автоматически'), findsOneWidget);
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
    expect(saved.source, 'ocr_arabic');
    expect(store.ocrCalls, 1);
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
    expect(find.textContaining('Не удалось надёжно определить область'), findsOneWidget);
    expect(store.ocrCalls, 1);
    expect(find.byKey(const ValueKey('original-dialogue-editor')),
        findsNothing);
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
    expect(find.textContaining('Область диалога найдена автоматически'),
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

  testWidgets('auto OCR isolates a conversation without manual crop', (tester) async {
    final store = MemoryOriginalDialogueStore(
      extracted: 'السَّلَامُ',
      scanned: 'وَعَلَيْكُمُ السَّلَامُ',
    );
    await tester.pumpWidget(MaterialApp(
      home: OriginalDialogueScreen(lesson: lesson, store: store),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
        const ValueKey('original-dialogue-extract')));
    await tester.pumpAndSettle();
    expect(store.ocrCalls, 1);
    final editor = tester.widget<TextField>(
      find.byKey(const ValueKey('original-dialogue-editor')),
    );
    expect(editor.controller!.text, contains('وَعَلَيْكُمُ'));
  });


  testWidgets('second dialogue may be auto-located on earlier shared page',
      (tester) async {
    final store = MemoryOriginalDialogueStore(
      scanned: 'خولة: السَّلَامُ عَلَيْكُمْ',
    );
    final d2 = <String, dynamic>{
      ...lesson,
      'id': 'book1-u1-d2',
      'lesson_order': 2,
      'pdf_page': 25,
    };
    await tester.pumpWidget(MaterialApp(
      home: OriginalDialogueScreen(lesson: d2, store: store),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
        const ValueKey('original-dialogue-extract')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Страница 24'), findsOneWidget);
    expect(find.textContaining('блоков на странице: 2'), findsOneWidget);
  });


  test('crop persistence rejects malformed geometry and keeps legacy records', () {
    const crop = DialogueCrop(0.06, 0.20, 0.92, 0.74);
    expect(DialogueCrop.fromJson(crop.toJson())!.right, closeTo(0.92, .001));
    expect(DialogueCrop.fromJson([0.8, 0.2, 0.2, 0.7]), isNull);
    expect(DialogueCrop.fromJson([0.1, -0.1, 0.9, 0.9]), isNull);
    expect(DialogueCrop.fromJson([0.1, 0.2, double.nan, 0.8]), isNull);
    const record = SavedOriginalDialogue(
      pageIndex: 12, text: 'السَّلَامُ', verified: false,
      source: 'ocr_arabic', crop: crop,
    );
    expect(SavedOriginalDialogue.fromJson(record.toJson())!.crop!.top, .20);
    final legacy = <String, dynamic>{...record.toJson()}..remove('crop');
    expect(SavedOriginalDialogue.fromJson(legacy)!.crop, isNull);
    expect(SavedOriginalDialogue.fromJson({
      ...record.toJson(), 'crop': [0.4, 0.8, 0.2, 0.9],
    }), isNull);
  });

  testWidgets('private visual PDF fragment supports crop adjustment and save',
      (tester) async {
    final store = MemoryOriginalDialogueStore(scanned: 'السَّلَامُ عَلَيْكُمْ');
    await tester.pumpWidget(MaterialApp(
      home: OriginalDialogueScreen(lesson: lesson, store: store),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('original-dialogue-extract')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('original-dialogue-pdf-fragment')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('original-dialogue-pdf-zoom')),
        findsOneWidget);

    await tester.ensureVisible(
        find.byKey(const ValueKey('original-dialogue-crop-edit')));
    await tester.tap(find.byKey(const ValueKey('original-dialogue-crop-edit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('original-dialogue-crop-horizontal')),
        findsOneWidget);
    await tester.ensureVisible(
        find.byKey(const ValueKey('original-dialogue-crop-apply')));
    await tester.tap(find.byKey(const ValueKey('original-dialogue-crop-apply')));
    await tester.pumpAndSettle();
    expect(store.cropRenders, 1);

    await tester.ensureVisible(
        find.byKey(const ValueKey('original-dialogue-save')));
    await tester.tap(find.byKey(const ValueKey('original-dialogue-save')));
    await tester.pumpAndSettle();
    expect(store.records['1/book1-u1-d1']!.crop, isNotNull);
    expect(store.records['1/book1-u1-d1']!.verified, false);
  });

  testWidgets('saved image can be re-rendered without re-running OCR',
      (tester) async {
    final store = MemoryOriginalDialogueStore();
    store.records['1/book1-u1-d1'] = const SavedOriginalDialogue(
      pageIndex: 23, text: 'السَّلَامُ', verified: true,
      source: 'manual', crop: DialogueCrop(0.08, 0.23, 0.92, 0.72),
    );
    await tester.pumpWidget(MaterialApp(
      home: OriginalDialogueScreen(lesson: lesson, store: store),
    ));
    await tester.pumpAndSettle();
    expect(store.cropRenders, 1);
    expect(store.ocrCalls, 0);
    expect(find.byKey(const ValueKey('original-dialogue-pdf-fragment')),
        findsOneWidget);
  });

}
