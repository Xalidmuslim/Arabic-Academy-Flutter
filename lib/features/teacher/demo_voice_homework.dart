import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../services/audio_practice_service.dart';
import '../../ui/components.dart';
import '../../ui/design_tokens.dart';

/// Reusable microphone capture for DEMO assignments and feedback. Recordings
/// stay inside app-private storage, never upload to a server.
class DemoVoiceRecorderScreen extends StatefulWidget {
  const DemoVoiceRecorderScreen({super.key, required this.title});
  final String title;
  @override
  State<DemoVoiceRecorderScreen> createState() => _DemoVoiceRecorderScreenState();
}

class _DemoVoiceRecorderScreenState extends State<DemoVoiceRecorderScreen> {
  final _audio = AudioPracticeService();
  bool _consent = false;
  bool _busy = false;
  int _seconds = 0;
  Timer? _timer;

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) notice(context, 'Аудиозапись: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle() async {
    if (_audio.isRecording) {
      _timer?.cancel();
      await _audio.stop();
    } else {
      await _audio.start(consent: _consent);
      _seconds = 0;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() => _seconds++);
        if (_seconds >= 180 && _audio.isRecording) {
          _perform(() async {
            _timer?.cancel();
            await _audio.stop();
          });
        }
      });
    }
  }

  Future<void> _save() async {
    final path = await _audio.preserveForHomework();
    if (mounted) Navigator.pop(context, path);
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_audio.dispose().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 150),
      children: [
        Panel(child: Column(
          children: [
            const Icon(Icons.mic_none_outlined,
              color: DesignTokens.deepOlive, size: 58),
            const SizedBox(height: 8),
            const Text('Голосовое сообщение · локальное демо',
              style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Записи доступны учительнице и ученице только '
              'в пределах этого устройства. Никаких отправок в интернет.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12,
                color: DesignTokens.secondary)),
          ],
        )),
        const SizedBox(height: 15),
        CheckboxListTile(
          value: _consent,
          title: const Text('Разрешаю запись на этом устройстве'),
          subtitle: const Text('Запись сохраняется в закрытом каталоге приложения.'),
          onChanged: _busy || _audio.isRecording ? null :
              (v) => setState(() => _consent = v ?? false),
        ),
        if (_audio.isRecording) Text('Запись: $_seconds с · максимум 180 с',
          textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey('demo-record-audio'),
          icon: Icon(_audio.isRecording ? Icons.stop_circle_outlined
              : Icons.mic_none_outlined),
          onPressed: _busy || (!_consent && !_audio.isRecording)
              ? null : () => _perform(_toggle),
          label: Text(_audio.isRecording
              ? 'Остановить запись' : 'Начать запись'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          icon: const Icon(Icons.play_circle_outline),
          onPressed: _busy || !_audio.hasRecording ? null
              : () => _perform(_audio.play),
          label: const Text('Прослушать свой ответ'),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          key: const ValueKey('demo-save-voice'),
          icon: const Icon(Icons.save_outlined),
          onPressed: _busy || !_audio.hasRecording ? null :
              () => _perform(_save),
          label: const Text('Сохранить голосовое сообщение'),
        ),
        const SizedBox(height: 12),
        const Text('Удаление данных приложения удалит также эти записи. '
          'Перед переустановкой сделайте резервную копию.',
          style: TextStyle(fontSize: 12, color: DesignTokens.secondary)),
      ],
    ),
  );
}

class DemoVoicePlayback extends StatefulWidget {
  const DemoVoicePlayback({
    super.key, required this.path, required this.title,
  });
  final String? path;
  final String title;
  @override
  State<DemoVoicePlayback> createState() => _DemoVoicePlaybackState();
}

class _DemoVoicePlaybackState extends State<DemoVoicePlayback> {
  final AudioPlayer _player = AudioPlayer();
  bool _loading = false;

  Future<void> _play() async {
    if (_loading) return;
    final path = widget.path;
    if (path == null || path.isEmpty || !await File(path).exists()) {
      if (mounted) notice(context, 'Аудиофайл не найден на этом устройстве.');
      return;
    }
    setState(() => _loading = true);
    try {
      await _player.setFilePath(path);
      unawaited(_player.play().catchError((Object error) {
        if (mounted) notice(context, 'Ошибка воспроизведения: $error');
      }));
    } catch (error) {
      if (mounted) notice(context, 'Не удалось воспроизвести: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: _loading ? null : _play,
    icon: const Icon(Icons.play_arrow_outlined),
    label: Text(widget.title),
  );
}
