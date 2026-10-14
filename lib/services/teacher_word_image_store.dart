import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Copies a teacher-selected picture into app-owned local storage.
/// No network upload, no remote publication, and no arbitrary file paths.
abstract final class TeacherWordImageStore {
  static const maxBytes = 2 * 1024 * 1024;

  static String extension(Uint8List bytes) {
    if (bytes.length > maxBytes) {
      throw const FormatException('Изображение больше 2 МБ. Уменьшите его.');
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4e &&
        bytes[3] == 0x47 && bytes[4] == 0x0d && bytes[5] == 0x0a &&
        bytes[6] == 0x1a && bytes[7] == 0x0a) {
      return 'png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff) {
      return 'jpg';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'webp';
    }
    throw const FormatException(
      'Поддерживаются только настоящие изображения JPG, PNG и WebP.',
    );
  }

  static Future<String> save(Uint8List image) async {
    final ext = extension(image);
    final root = await getApplicationSupportDirectory();
    final directory = Directory(root.path + '/teacher_word_cards');
    await directory.create(recursive: true);
    final name = DateTime.now().microsecondsSinceEpoch.toString() +
        '_' + Random.secure().nextInt(1 << 30).toString() + '.' + ext;
    final saved = File(directory.path + '/' + name);
    await saved.writeAsBytes(image, flush: true);
    return saved.path;
  }
}
