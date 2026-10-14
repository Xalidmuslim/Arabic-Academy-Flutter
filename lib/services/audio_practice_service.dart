import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'integration_config.dart';

/// A recording stays in the app's temporary directory and is deleted on exit.
class AudioPracticeService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer player = AudioPlayer();
  final ValueNotifier<String?> playbackError = ValueNotifier(null);
  Future<void> _operations = Future.value();
  Future<void>? _closing;

  Future<void> _serialize(Future<void> Function() action) {
    final result = _operations.then((_) => action());
    _operations = result.catchError((Object _) {});
    return result;
  }

  String? _path;
  bool _recording = false;
  bool _disposed = false;
  bool get isRecording => _recording;
  bool get hasRecording => _path != null && !_recording;
  Stream<Amplitude> get amplitude =>
      _recorder.onAmplitudeChanged(const Duration(milliseconds: 200));

  Future<void> start({required bool consent}) => _serialize(() async {
    IntegrationValidation.consent(consent);
    if (_disposed || _closing != null || _recording) {
      throw const IntegrationException('Запись уже идёт или экран закрыт.');
    }
    if (kIsWeb) {
      throw const IntegrationException(
        'Локальная запись доступна в мобильном приложении.',
      );
    }
    if (!await _recorder.hasPermission()) {
      throw const IntegrationException(
        'Разрешите доступ к микрофону в настройках устройства.',
      );
    }
    if (_disposed || _closing != null) return;
    await _delete();
    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/oral_${DateTime.now().microsecondsSinceEpoch}.m4a';
    _path = path;
    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );
      _recording = true;
    } catch (_) {
      await _delete();
      rethrow;
    }
  });

  Future<void> stop() => _serialize(() async {
    if (!_recording || _disposed) return;
    final result = await _recorder.stop();
    _recording = false;
    if (result != null) _path = result;
  });

  Future<void> play() => _serialize(() async {
    final path = _path;
    if (!hasRecording || path == null || _disposed) {
      throw const IntegrationException('Сначала запишите и остановите голос.');
    }
    await player.setFilePath(path);
    // play() resolves only after playback finishes; do not block the UI on it.
    playbackError.value = null;
    unawaited(
      player.play().catchError((Object _) {
        if (!_disposed && _closing == null) {
          playbackError.value =
              'Не удалось воспроизвести запись. Повторите или запишите заново.';
        }
      }),
    );
  });

  /// Keep a locally recorded homework message in app-private documents.
  /// The caller explicitly requests this; temporary rehearsal audio remains
  /// short-lived and gets removed when leaving the recorder.
  Future<String> preserveForHomework() async {
    final path = _path;
    if (_disposed || _recording || path == null) {
      throw const IntegrationException('Сначала остановите запись.');
    }
    final source = File(path);
    if (!await source.exists() ||
        await source.length() > 10 * 1024 * 1024) {
      throw const IntegrationException(
        'Запись отсутствует или превышает 10 МБ.',
      );
    }
    final root = await getApplicationDocumentsDirectory();
    final folder = Directory('${root.path}/bayna_voice_homework');
    if (!await folder.exists()) await folder.create(recursive: true);
    final saved = File('${folder.path}/voice_'
        '${DateTime.now().microsecondsSinceEpoch}.m4a');
    await source.copy(saved.path);
    return saved.path;
  }

  Future<Uint8List> readForTranscription({required bool consent}) async {
    IntegrationValidation.consent(consent);
    if (!hasRecording) {
      throw const IntegrationException('Сначала остановите запись.');
    }
    final file = File(_path!);
    if (await file.length() > 10 * 1024 * 1024) {
      throw const IntegrationException(
        'Для распознавания запись должна быть не больше 10 МБ.',
      );
    }
    return file.readAsBytes();
  }

  Future<void> delete() => _serialize(_delete);

  Future<void> _delete() async {
    try {
      if (_recording) await _recorder.stop();
    } finally {
      _recording = false;
      try {
        await player.stop();
      } finally {
        final path = _path;
        if (path != null) {
          final file = File(path);
          if (await file.exists()) await file.delete();
          _path = null;
        }
      }
    }
  }

  Future<void> dispose() => _closing ??= _serialize(() async {
    try {
      await _delete();
    } finally {
      _disposed = true;
      try {
        await _recorder.dispose();
      } finally {
        await player.dispose();
        playbackError.dispose();
      }
    }
  });
}
