import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../core/academy_state.dart';

/// Optional user-imported, real-speaker audio, private to this device.
/// Packaged APK has NO claimed human narration or scanned textbooks.
/// Recording rights, speaker quality and editorial review are the owner's
/// responsibility; arbitrary network URLs are never fetched.
class LessonAudioLibrary {
  LessonAudioLibrary(this.state) : _player = AudioPlayer();

  final AcademyState state;
  final AudioPlayer _player;
  bool _disposed = false;

  static String key(String lessonId, int line) =>
      'local_human_voice:${Uri.encodeComponent(lessonId)}:$line';

  String? localPath(String lessonId, int line) {
    final raw = state.settings[key(lessonId, line)];
    return raw is String && raw.isNotEmpty ? raw : null;
  }

  Future<bool> hasSample(String lessonId, int line) async {
    final path = localPath(lessonId, line);
    return path != null && await File(path).exists();
  }

  Future<bool> importFor(String lessonId, int line) async {
    if (_disposed) throw StateError('Аудиоплеер закрыт.');
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
      withData: false,
    );
    if (picked == null || picked.files.isEmpty) return false;
    final selected = picked.files.single;
    if (selected.size <= 0 || selected.size > 20 * 1024 * 1024) {
      throw const FormatException('Аудиофайл должен быть не больше 20 МБ.');
    }
    final extension = (selected.extension ?? '').toLowerCase();
    if (!{'mp3', 'm4a', 'wav', 'aac', 'ogg', 'opus'}.contains(extension)) {
      throw const FormatException('Выберите MP3, M4A, WAV, AAC или OGG.');
    }
    final sourcePath = selected.path;
    if (sourcePath == null) {
      throw StateError('Невозможно прочитать выбранный файл.');
    }
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw StateError('Выбранная запись больше недоступна.');
    }

    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/bayna_user_audio');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    // No external filenames are reused: prevent traversal and accidental
    // overwrites from malicious file-provider names.
    final target = File('${directory.path}/clip_'
        '${DateTime.now().microsecondsSinceEpoch}.$extension');
    await source.copy(target.path);
    final previous = localPath(lessonId, line);
    try {
      await state.setSetting(key(lessonId, line), target.path);
    } catch (_) {
      if (await target.exists()) await target.delete();
      rethrow;
    }
    if (previous != null && previous != target.path) {
      // Only delete files from our own private directory.
      if (previous.startsWith('${directory.path}/')) {
        try {
          final old = File(previous);
          if (await old.exists()) await old.delete();
        } catch (_) {
          // Settings are already committed; an orphan can be cleaned later.
        }
      }
    }
    return true;
  }

  Future<void> play(String lessonId, int line, {
    double speed = 1,
  }) async {
    if (_disposed) throw StateError('Аудиоплеер закрыт.');
    final path = localPath(lessonId, line);
    if (path == null || !await File(path).exists()) {
      throw StateError('Не найдено локальное аудио этой реплики.');
    }
    await _player.stop();
    await _player.setFilePath(path);
    await _player.setSpeed(speed.clamp(0.7, 1.25));
    await _player.play();
  }

  Future<void> stop() => _player.stop();

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _player.dispose();
  }
}
