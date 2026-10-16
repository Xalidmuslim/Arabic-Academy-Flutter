import 'dart:convert';
import 'dart:typed_data';

import 'package:arabic_academy/features/learning/original_dialogue_screen.dart';
import 'package:arabic_academy/services/private_dialogue_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class VisualDialogueStore implements OriginalDialogueStore, DialogueArtworkStore {
  static final Uint8List tinyPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAYAAACp8Z5+'
    'AAAAFklEQVR4nGP88OzSfwYkwMSABggLAADwggOvWRDQ6AAAAABJRU5ErkJggg==',
  );

  bool present = true;
  bool panelFound = true;
  int detected = 2;
  int calls = 0;
  int renders = 0;
  int lastSlot = 0;
  final Map<String, SavedOriginalDialogue> records = {};

  @override
  Future<bool> hasImportedPdf(int part) async => present;

  @override
  Future<SavedOriginalDialogue?> load(int part, String lessonId) async =>
      records['$part/$lessonId'];

  @override
  Future<void> save(
    int part, String lessonId, SavedOriginalDialogue record,
  ) async {
    records['$part/$lessonId'] = record;
  }

  @override
  Future<void> clearPart(int part) async {
    records.removeWhere((key, _) => key.startsWith('$part/'));
  }

  @override
  Future<Uint8List> renderCrop(
    int part, int pageIndex, DialogueCrop crop,
  ) async {
    renders++;
    return tinyPng;
  }

  @override
  Future<DialogueOcrResult> recognizeDialogue(
    int part, int pageIndex, int dialogueSlot,
  ) async {
    calls++;
    lastSlot = dialogueSlot;
    return DialogueOcrResult(
      panelFound ? 'image' : 'empty',
      'نَصٌّ خَاطِئٌ مُخْتَرَعٌ', // ignored even if native sent legacy OCR
      pageIndex: pageIndex,
      autoSelected: panelFound,
      detectedBlocks: panelFound ? detected : 0,
      crop: panelFound
          ? const DialogueCrop(.52, .20, .94, .72)
          : null,
      imagePng: panelFound ? tinyPng : null,
      yellowDetected: panelFound,
    );
  }

  @override
  Future<PdfTextExtraction> extractText(
    int part, int pageIndex,
  ) async => const PdfTextExtraction('unsupported', '');

  @override
  Future<PdfTextExtraction> recognizeScan(
    int part, int pageIndex,
  ) async => const PdfTextExtraction('unsupported', '');
}

const lesson = <String, dynamic>{
  'id': 'book1-u1-d1',
  'title': 'Диалог 1. Знакомство',
  'pdf_part': 1,
  'pdf_page': 23,
  'lesson_order': 1,
};

Future<void> scrollTo(
  WidgetTester tester,
  Finder target, {
  double step = 150,
}) async {
  await tester.scrollUntilVisible(
    target, step, scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  test('visual-only records are backward compatible and preserve PDF crop',
      () {
    const crop = DialogueCrop(.51, .24, .95, .74);
    expect(crop.isValid, true);
    const saved = SavedOriginalDialogue(
      pageIndex: 25,
      text: '',
      verified: false,
      source: 'manual',
      crop: crop,
    );
    final restored = SavedOriginalDialogue.fromJson(saved.toJson());
    expect(restored?.crop?.left, .51);
    expect(restored?.text, '');
    // Older records remain readable without altering their contents.
    final old = SavedOriginalDialogue.fromJson({
      ...saved.toJson(),
      'text': 'قديمة من OCR',
      'source': 'ocr_arabic',
    });
    expect(old?.text, 'قديمة من OCR');
  });

  testWidgets('missing PDF cannot silently show editorial dialogue',
      (tester) async {
    final store = VisualDialogueStore()..present = false;
    await tester.pumpWidget(MaterialApp(
      home: OriginalDialogueScreen(lesson: lesson, store: store),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Импортировать личный PDF'), findsOneWidget);
    expect(find.textContaining('распознавания и изменения'), findsOneWidget);
    expect(find.byKey(const ValueKey('original-dialogue-pdf-fragment')),
        findsNothing);
  });

  testWidgets('selecting a source panel never shows received OCR text',
      (tester) async {
    final store = VisualDialogueStore();
    await tester.pumpWidget(MaterialApp(
      home: OriginalDialogueScreen(lesson: lesson, store: store),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('original-dialogue-extract')));
    await tester.pumpAndSettle();
    expect(store.calls, 1);
    expect(store.lastSlot, 1);
    expect(find.byKey(const ValueKey('original-dialogue-pdf-fragment')),
        findsOneWidget);
    expect(find.textContaining('نَصٌّ خَاطِئٌ'), findsNothing);
    expect(find.text('Текст диалога'), findsNothing);
    expect(find.byKey(const ValueKey('original-dialogue-editor')),
        findsNothing);
    expect(find.text('Найти снова'), findsOneWidget);
  });

  testWidgets('dialogue A and B retain independent visual source drafts',
      (tester) async {
    final store = VisualDialogueStore();
    await tester.pumpWidget(MaterialApp(
      home: OriginalDialogueScreen(lesson: lesson, store: store),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('original-dialogue-extract')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('original-dialogue-selector')));
    await tester.tap(find.text('Диалог Б (ب)'));
    await tester.pumpAndSettle();
    expect(store.lastSlot, 2);
    expect(store.calls, 2);
    expect(find.byKey(const ValueKey('original-dialogue-pdf-fragment')),
        findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('original-dialogue-selector')));
    await tester.tap(find.text('Диалог А (أ)'));
    await tester.pumpAndSettle();
    expect(store.calls, 2); // In-memory source crop restored, no OCR.
  });

  testWidgets('saved image has empty transcription and separate part slot',
      (tester) async {
    final store = VisualDialogueStore();
    await tester.pumpWidget(MaterialApp(
      home: OriginalDialogueScreen(lesson: lesson, store: store),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Диалог Б (ب)'));
    await tester.pumpAndSettle();
    await scrollTo(tester,
        find.byKey(const ValueKey('original-dialogue-save')), step: 180);
    await tester.tap(find.byKey(const ValueKey('original-dialogue-save')));
    await tester.pumpAndSettle();
    final saved = store.records['1/book1-u1-d1_dialogue_2'];
    expect(saved, isNotNull);
    expect(saved!.text, '');
    expect(saved.source, 'manual');
    expect(saved.verified, false);
    expect(saved.crop, isNotNull);
    expect(store.records.containsKey('1/book1-u1-d1'), isFalse);
  });

  testWidgets('legacy OCR transcription stays stored but is not displayed',
      (tester) async {
    final store = VisualDialogueStore();
    store.records['1/book1-u1-d1'] = const SavedOriginalDialogue(
      pageIndex: 24,
      text: 'خطأ OCR', verified: false, source: 'ocr_arabic',
      crop: DialogueCrop(.5, .2, .94, .7),
    );
    await tester.pumpWidget(MaterialApp(
      home: OriginalDialogueScreen(lesson: lesson, store: store),
    ));
    await tester.pumpAndSettle();
    expect(store.records['1/book1-u1-d1']!.text, 'خطأ OCR');
    expect(find.textContaining('خطأ OCR'), findsNothing);
    expect(find.byKey(const ValueKey('original-dialogue-pdf-fragment')),
        findsOneWidget);
    expect(store.renders, 1);
  });

  testWidgets('missing yellow region can be selected by hand',
      (tester) async {
    final store = VisualDialogueStore()..panelFound = false;
    await tester.pumpWidget(MaterialApp(
      home: OriginalDialogueScreen(lesson: lesson, store: store),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('original-dialogue-extract')));
    await tester.pumpAndSettle();
    expect(find.textContaining('не определена'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('original-dialogue-crop-edit')));
    await tester.pumpAndSettle();
    await scrollTo(tester,
        find.byKey(const ValueKey('original-dialogue-crop-apply')), step: 140);
    await tester.tap(find.byKey(const ValueKey('original-dialogue-crop-apply')));
    await tester.pumpAndSettle();
    expect(store.renders, 1);
    await scrollTo(tester,
        find.byKey(const ValueKey('original-dialogue-save')), step: 130);
    await tester.tap(find.byKey(const ValueKey('original-dialogue-save')));
    await tester.pumpAndSettle();
    expect(store.records['1/book1-u1-d1']?.crop?.isValid, true);
  });

  testWidgets('image zoom offers reliable controls and reset', (tester) async {
    final store = VisualDialogueStore();
    await tester.pumpWidget(MaterialApp(
      home: OriginalDialogueScreen(lesson: lesson, store: store),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('original-dialogue-extract')));
    await tester.pumpAndSettle();
    final viewer = find.byKey(const ValueKey('original-dialogue-pdf-zoom'));
    await scrollTo(tester, viewer, step: 140);
    await tester.tap(find.byKey(const ValueKey('original-pdf-zoom-in')));
    await tester.pumpAndSettle();
    expect(tester.widget<InteractiveViewer>(viewer)
      .transformationController!.value.getMaxScaleOnAxis(), greaterThan(1.5));
    await tester.tap(find.byKey(const ValueKey('original-pdf-zoom-reset')));
    await tester.pumpAndSettle();
    expect(tester.widget<InteractiveViewer>(viewer)
      .transformationController!.value.getMaxScaleOnAxis(), closeTo(1, .02));
  });

  testWidgets('lesson preview shows only saved original PDF crop',
      (tester) async {
    final store = VisualDialogueStore();
    store.records['1/book1-u1-d1'] = const SavedOriginalDialogue(
      pageIndex: 23, text: '', verified: false, source: 'manual',
      crop: DialogueCrop(.52, .2, .94, .72),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OriginalDialoguePdfPreview(lesson: lesson, store: store),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lesson-original-pdf-fragment')),
        findsOneWidget);
    expect(find.text('Диалог из оригинального PDF'), findsOneWidget);
    expect(store.renders, 1);
  });
}
