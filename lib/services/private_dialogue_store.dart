import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'dialogue_ocr_region.dart';

/// Text brought in by the owner of a local PDF. Never bundled, published,
/// uploaded, or inserted in the academy's synced lesson catalog.
class SavedOriginalDialogue {
  const SavedOriginalDialogue({
    required this.pageIndex,
    required this.text,
    required this.verified,
    required this.source,
  });

  final int pageIndex;
  final String text;
  final bool verified;
  final String source;

  Map<String, dynamic> toJson() => {
    'version': 1,
    'page_index': pageIndex,
    'text': text,
    'verified': verified,
    'source': source,
  };

  static SavedOriginalDialogue? fromJson(Object? value) {
    if (value is! Map ||
        value['version'] != 1 ||
        value['page_index'] is! int ||
        value['text'] is! String ||
        value['verified'] is! bool ||
        (value['source'] != 'manual' &&
            value['source'] != 'pdf_text' &&
            value['source'] != 'ocr_arabic')) {
      return null;
    }
    final page = value['page_index'] as int;
    if (page < 0 || page > 10000) return null;
    final content = value['text'] as String;
    if (content.length > 100000) return null;
    return SavedOriginalDialogue(
      pageIndex: page,
      text: content,
      verified: value['verified'] as bool,
      source: value['source'] as String,
    );
  }
}

class PdfTextExtraction {
  const PdfTextExtraction(this.status, this.text);

  /// ok, ocr (unverified Arabic scan), empty, unsupported, missing.
  final String status;
  final String text;
}

abstract class OriginalDialogueStore {
  Future<bool> hasImportedPdf(int part);
  Future<SavedOriginalDialogue?> load(int part, String lessonId);
  Future<void> save(int part, String lessonId, SavedOriginalDialogue record);
  Future<void> clearPart(int part);
  Future<PdfTextExtraction> extractText(int part, int pageIndex);
  Future<PdfTextExtraction> recognizeScan(int part, int pageIndex);

  /// Local thumbnail of the same full PDF page the OCR region refers to.
  Future<PrivatePdfPagePreview?> previewPage(int part, int pageIndex);

  /// Tesseract processes ONLY the selected coordinates, not the whole page.
  Future<PdfTextExtraction> recognizeRegion(
    int part,
    int pageIndex,
    DialogueOcrRegion region,
  );
}

class OnDeviceDialogueStore implements OriginalDialogueStore {
  const OnDeviceDialogueStore();

  static const _native = MethodChannel('bayna.private_pdf');
  static final _safeId = RegExp(r'^[a-z0-9][a-z0-9_-]{0,79}$');

  static void _check(int part, [String? lessonId]) {
    if (part != 1 && part != 2) throw ArgumentError.value(part, 'part');
    if (lessonId != null && !_safeId.hasMatch(lessonId)) {
      throw ArgumentError.value(lessonId, 'lessonId');
    }
  }

  Future<Directory> _pdfDirectory() async {
    final root = await getApplicationSupportDirectory();
    return Directory('${root.path}/private_textbooks');
  }

  Future<Directory> _dialogueDirectory(int part) async {
    _check(part);
    return Directory('${(await _pdfDirectory()).path}/local_dialogues/part_$part');
  }

  Future<File> _recordFile(int part, String lessonId) async {
    _check(part, lessonId);
    return File('${(await _dialogueDirectory(part)).path}/$lessonId.json');
  }

  @override
  Future<bool> hasImportedPdf(int part) async {
    _check(part);
    final book = File(
      '${(await _pdfDirectory()).path}/student_book_1_part_$part.pdf',
    );
    return book.exists();
  }

  @override
  Future<SavedOriginalDialogue?> load(int part, String lessonId) async {
    final file = await _recordFile(part, lessonId);
    if (!await file.exists()) return null;
    final content = await file.readAsString();
    return SavedOriginalDialogue.fromJson(jsonDecode(content));
  }

  @override
  Future<void> save(
      int part, String lessonId, SavedOriginalDialogue record) async {
    if (record.text.length > 100000 || record.pageIndex < 0) {
      throw const FormatException('Invalid local dialogue content');
    }
    final file = await _recordFile(part, lessonId);
    await file.parent.create(recursive: true);
    final staging = File('${file.path}.writing');
    try {
      await staging.writeAsString(jsonEncode(record.toJson()), flush: true);
      if (await file.exists()) await file.delete();
      await staging.rename(file.path);
    } finally {
      if (await staging.exists()) await staging.delete();
    }
  }

  @override
  Future<void> clearPart(int part) async {
    final folder = await _dialogueDirectory(part);
    if (await folder.exists()) {
      await folder.delete(recursive: true);
    }
  }

  @override
  Future<PdfTextExtraction> extractText(int part, int pageIndex) async {
    _check(part);
    if (pageIndex < 0) throw ArgumentError.value(pageIndex, 'pageIndex');
    if (!Platform.isAndroid) return const PdfTextExtraction('unsupported', '');
    final result = await _native.invokeMapMethod<String, dynamic>('extractText', {
      'part': part,
      'page': pageIndex,
    });
    final status = result?['status']?.toString() ?? 'empty';
    if (!const ['ok', 'empty', 'unsupported', 'missing'].contains(status)) {
      throw const FormatException('Unexpected PDF extraction status');
    }
    return PdfTextExtraction(status, result?['text']?.toString() ?? '');
  }
  @override
  Future<PdfTextExtraction> recognizeScan(int part, int pageIndex) async {
    _check(part);
    if (pageIndex < 0) throw ArgumentError.value(pageIndex, 'pageIndex');
    if (!Platform.isAndroid) return const PdfTextExtraction('unsupported', '');
    final result = await _native.invokeMapMethod<String, dynamic>('ocrArabicPage', {
      'part': part,
      'page': pageIndex,
    });
    final status = result?['status']?.toString() ?? 'empty';
    if (!const ['ocr', 'empty', 'missing'].contains(status)) {
      throw const FormatException('Unexpected scanned PDF OCR status');
    }
    return PdfTextExtraction(status, result?['text']?.toString() ?? '');
  }


  @override
  Future<PrivatePdfPagePreview?> previewPage(int part, int pageIndex) async {
    _check(part);
    if (pageIndex < 0) throw ArgumentError.value(pageIndex, 'pageIndex');
    if (!Platform.isAndroid) return null;
    final result = await _native.invokeMapMethod<String, dynamic>(
      'previewOcrPage',
      {'part': part, 'page': pageIndex, 'width': 1000},
    );
    if (result?['status'] == 'missing') return null;
    final bytes = result?['bytes'];
    final width = result?['width'];
    final height = result?['height'];
    if (bytes is! Uint8List || width is! int || height is! int) {
      throw const FormatException('Invalid PDF preview from Android');
    }
    final preview = PrivatePdfPagePreview(
      bytes: bytes, width: width, height: height,
    );
    if (!preview.valid) throw const FormatException('Empty PDF page preview');
    return preview;
  }

  @override
  Future<PdfTextExtraction> recognizeRegion(
    int part,
    int pageIndex,
    DialogueOcrRegion region,
  ) async {
    _check(part);
    if (pageIndex < 0) throw ArgumentError.value(pageIndex, 'pageIndex');
    final bounds = region.normalizedBounds;
    if (!Platform.isAndroid) return const PdfTextExtraction('unsupported', '');
    final result = await _native.invokeMapMethod<String, dynamic>(
      'ocrArabicRegion',
      {'part': part, 'page': pageIndex, 'region': bounds},
    );
    final status = result?['status']?.toString() ?? 'empty';
    if (!const ['ocr', 'empty', 'missing'].contains(status)) {
      throw const FormatException('Invalid cropped PDF OCR status');
    }
    return PdfTextExtraction(status, result?['text']?.toString() ?? '');
  }

}
