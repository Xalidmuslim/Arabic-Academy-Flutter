import 'dart:typed_data' show BytesBuilder;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'backend_service.dart';

enum UploadStage {
  selected,
  uploading,
  uploaded,
  authorizing,
  complete,
  failed,
}

/// Supabase's uploadBinary API does not expose byte progress. Stage progress is
/// factual; uploading uses an indeterminate indicator rather than fake percent.
class MediaUploadService extends ChangeNotifier {
  MediaUploadService(this.backend, this.lessonId, {this.picker});
  final BackendService backend;
  final String lessonId;
  final FilePicker? picker;
  PlatformFile? selected;
  Uint8List? _bytes;
  UploadStage? stage;
  String? uploadedPath;
  String? mediaId;
  Map<String, dynamic>? _ticket;
  String? signedUrl;
  String? error;
  bool _busy = false;
  bool _disposed = false;
  bool get busy => _busy;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> pick() async {
    if (_busy) return;
    await backend.requireTeacher();
    IntegrationValidation.id(lessonId);
    final result = await (picker ?? FilePicker.platform).pickFiles(
      type: FileType.custom,
      allowedExtensions: MediaPolicy.mimeTypes.keys.toList(),
      allowMultiple: false,
      withData: false,
      withReadStream: true,
    );
    if (result == null || _disposed) return;
    final file = result.files.single;
    MediaPolicy.validate(file.name, file.size);
    Uint8List? bytes = file.bytes;
    if (bytes == null && file.readStream != null) {
      final buffer = BytesBuilder(copy: false);
      await for (final chunk in file.readStream!) {
        if (buffer.length + chunk.length > MediaPolicy.maxBytes) {
          throw const IntegrationException('Файл превышает ограничение 50 МБ.');
        }
        if (_disposed) return;
        buffer.add(chunk);
      }
      bytes = buffer.takeBytes();
    }
    if (bytes == null || bytes.length != file.size) {
      throw const IntegrationException(
        'Не удалось полностью прочитать файл. Выберите его повторно.',
      );
    }
    selected = file;
    _bytes = bytes;
    uploadedPath = null;
    mediaId = null;
    _ticket = null;
    signedUrl = null;
    stage = UploadStage.selected;
    error = null;
    _notify();
  }

  Future<void> upload() async {
    if (_busy) return;
    final file = selected;
    if (file == null) throw const IntegrationException('Выберите файл.');
    final Uint8List bytes = _bytes!;
    final mime = MediaPolicy.validate(file.name, bytes.length);
    _busy = true;
    error = null;
    _notify();
    try {
      await backend.requireTeacher();
      if (uploadedPath == null) {
        // Private buckets have no client write policy. Server issues a scoped
        // signed upload token after checking the teacher's lesson assignment.
        final retry = _ticket != null;
        _ticket ??= await backend.beginMediaUpload(
          filename: file.name,
          size: bytes.length,
          mimeType: mime,
          lessonId: lessonId,
        );
        mediaId = _ticket!['media_id'] as String;
        stage = UploadStage.uploading;
        _notify();
        bool finalized = false;
        if (retry) {
          // Lost responses are possible. First ask server to inspect the object.
          try {
            await backend.finalizeMediaUpload(mediaId!);
            finalized = true;
          } catch (_) {
            // Upload tokens expire. Remove our incomplete staging object and
            // request a fresh scoped token, rather than reuse an expired token.
            await backend.deleteMedia(mediaId!);
            _ticket = await backend.beginMediaUpload(
              filename: file.name,
              size: bytes.length,
              mimeType: mime,
              lessonId: lessonId,
            );
            mediaId = _ticket!['media_id'] as String;
          }
        }
        if (!finalized) await backend.uploadToTicket(_ticket!, bytes);
        uploadedPath = _ticket!['object_path'] as String;
        stage = UploadStage.uploaded;
        _notify();
      }
      stage = UploadStage.authorizing;
      _notify();
      await backend.finalizeMediaUpload(mediaId!);
      signedUrl = await backend.signedMediaUrl(mediaId!);
      stage = UploadStage.complete;
    } catch (exception) {
      stage = UploadStage.failed;
      error = integrationErrorText(exception);
      rethrow;
    } finally {
      _busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _bytes = null;
    super.dispose();
  }
}

/// Do not expose raw SDK exceptions containing URLs, tokens or receipt data.
String integrationErrorText(Object error) => error is IntegrationException
    ? error.message
    : 'Запрос не выполнен. Проверьте сеть, разрешения и конфигурацию сервиса; повторите позже.';
