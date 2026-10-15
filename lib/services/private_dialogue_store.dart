import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Normalized coordinates of a reader-owned PDF fragment, not an APK asset.
class DialogueCrop {
  const DialogueCrop(this.left, this.top, this.right, this.bottom);

  final double left, top, right, bottom;

  bool get isValid =>
      [left, top, right, bottom].every((v) => v.isFinite && v >= 0 && v <= 1) &&
      right - left >= 0.08 && bottom - top >= 0.06;

  List<double> toJson() => [left, top, right, bottom];

  static DialogueCrop? fromJson(Object? value) {
    if (value is! List || value.length != 4 || value.any((v) => v is! num)) {
      return null;
    }
    final values = value.cast<num>().map((v) => v.toDouble()).toList();
    final crop = DialogueCrop(values[0], values[1], values[2], values[3]);
    return crop.isValid ? crop : null;
  }
}

/// Text brought in by the owner of a local PDF. Never bundled, published,
/// uploaded, or inserted in the academy's synced lesson catalog.
class SavedOriginalDialogue {
  const SavedOriginalDialogue({
    required this.pageIndex,
    required this.text,
    required this.verified,
    required this.source,
    this.crop,
  });

  final int pageIndex;
  final String text;
  final bool verified;
  final String source;
  final DialogueCrop? crop;

  Map<String, dynamic> toJson() => {
    'version': 1,
    'page_index': pageIndex,
    'text': text,
    'verified': verified,
    'source': source,
    if (crop != null) 'crop': crop!.toJson(),
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
    if (value.containsKey('crop') && DialogueCrop.fromJson(value['crop']) == null) {
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
      crop: DialogueCrop.fromJson(value['crop']),
    );
  }
}

class PdfTextExtraction {
  const PdfTextExtraction(this.status, this.text);

  /// ok, ocr (unverified Arabic scan), empty, unsupported, missing.
  final String status;
  final String text;
}

/// A selected block of dialogue; it is NOT authoritative until user verified.
class DialogueOcrResult extends PdfTextExtraction {
  const DialogueOcrResult(
    super.status,
    super.text, {
    required this.pageIndex,
    required this.autoSelected,
    required this.detectedBlocks,
    this.crop,
    this.imagePng,
  });

  final int pageIndex;
  final bool autoSelected;
  final int detectedBlocks;
  final DialogueCrop? crop;
  final Uint8List? imagePng;
}

/// Optional visual feature keeps existing test stores and lesson data compatible.
abstract class DialogueArtworkStore {
  Future<Uint8List> renderCrop(int part, int pageIndex, DialogueCrop crop);
}

abstract class OriginalDialogueStore {
  Future<bool> hasImportedPdf(int part);
  Future<SavedOriginalDialogue?> load(int part, String lessonId);
  Future<void> save(int part, String lessonId, SavedOriginalDialogue record);
  Future<void> clearPart(int part);
  Future<PdfTextExtraction> extractText(int part, int pageIndex);
  Future<PdfTextExtraction> recognizeScan(int part, int pageIndex);
  Future<DialogueOcrResult> recognizeDialogue(
    int part, int pageIndex, int dialogueSlot,
  );
}

class OnDeviceDialogueStore implements OriginalDialogueStore, DialogueArtworkStore {
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
  Future<Uint8List> renderCrop(int part, int pageIndex, DialogueCrop crop) async {
    _check(part);
    if (pageIndex < 0 || pageIndex > 10000 || !crop.isValid) {
      throw const FormatException('Invalid PDF dialogue crop');
    }
    if (!Platform.isAndroid) throw UnsupportedError('Android only');
    final png = await _native.invokeMethod<Uint8List>('renderDialogueCrop', {
      'part': part,
      'page': pageIndex,
      'crop': crop.toJson(),
    });
    if (png == null || png.isEmpty) {
      throw const FormatException('Empty PDF fragment');
    }
    return png;
  }

  @override
  Future<DialogueOcrResult> recognizeDialogue(
    int part, int pageIndex, int dialogueSlot,
  ) async {
    _check(part);
    if (pageIndex < 0 || pageIndex > 10000) {
      throw ArgumentError.value(pageIndex, 'pageIndex');
    }
    if (dialogueSlot != 1 && dialogueSlot != 2) {
      throw ArgumentError.value(dialogueSlot, 'dialogueSlot');
    }
    if (!Platform.isAndroid) {
      return DialogueOcrResult('unsupported', '',
          pageIndex: pageIndex, autoSelected: false, detectedBlocks: 0);
    }
    final result = await _native.invokeMapMethod<String, dynamic>(
      'ocrArabicDialogue', {
        'part': part,
        'page': pageIndex,
        'dialogueSlot': dialogueSlot,
      },
    );
    final status = result?['status']?.toString() ?? 'empty';
    if (!const ['ocr', 'empty', 'missing'].contains(status)) {
      throw const FormatException('Unknown automatic dialogue OCR status');
    }
    final actualPage = result?['page_index'];
    if (actualPage is! int || actualPage < 0 || actualPage > 10000) {
      throw const FormatException('Invalid dialogue source page');
    }
    final groupCount = result?['detected_blocks'];
    if (groupCount != null && (groupCount is! int || groupCount < 0)) {
      throw const FormatException('Invalid dialogue section count');
    }
    return DialogueOcrResult(
      status,
      result?['text']?.toString() ?? '',
      pageIndex: actualPage,
      autoSelected: result?['auto_selected'] == true,
      detectedBlocks: groupCount is int ? groupCount : 0,
      crop: DialogueCrop.fromJson(result?['crop']),
      imagePng: result?['image_png'] is Uint8List
          ? result!['image_png'] as Uint8List
          : null,
    );
  }

}
