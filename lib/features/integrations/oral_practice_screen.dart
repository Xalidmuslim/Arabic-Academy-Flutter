import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../services/audio_practice_service.dart';
import '../../services/backend_service.dart';
import 'integration_widgets.dart';

class OralPracticeScreen extends StatefulWidget {
  const OralPracticeScreen({super.key, this.backend});
  final BackendService? backend;
  @override
  State<OralPracticeScreen> createState() => _OralPracticeScreenState();
}

class _OralPracticeScreenState extends State<OralPracticeScreen>
    with WidgetsBindingObserver, IntegrationActions<OralPracticeScreen> {
  final _audio = AudioPracticeService();
  bool _localConsent = false;
  bool _uploadConsent = false;
  String? _transcript;
  Timer? _timer;
  int _seconds = 0;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (state != AppLifecycleState.resumed) {
      unawaited(_audio.player.pause().catchError((Object _) {}));
      if (_audio.isRecording && !working) unawaited(runAction(_stop));
    }
  }

  Future<void> _start() async {
    await _audio.start(consent: _localConsent);
    if (!mounted) return;
    if (!_foreground) {
      await _audio.stop();
      return;
    }
    setState(() {
      _seconds = 0;
      _transcript = null;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
      if (_seconds >= 180 && !working) unawaited(runAction(_stop));
    });
  }

  Future<void> _stop() async {
    _timer?.cancel();
    await _audio.stop();
  }

  Future<void> _delete() async {
    _timer?.cancel();
    await _audio.delete();
    if (mounted) {
      setState(() {
        _transcript = null;
        _seconds = 0;
      });
    }
  }

  Future<void> _transcribe() async {
    final backend = widget.backend;
    if (backend == null ||
        !backend.isAuthenticated ||
        !backend.config.sttEnabled) {
      throw const IntegrationException(
        'Войдите в аккаунт с подключённым распознаванием речи.',
      );
    }
    final bytes = await _audio.readForTranscription(consent: _uploadConsent);
    final text = await backend.transcribe(bytes, consent: _uploadConsent);
    if (mounted) setState(() => _transcript = text);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    unawaited(_audio.dispose().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Устная практика')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 155),
      children: [
        const IntegrationNotice(
          'Запишите арабскую речь и послушайте себя. '
          'Запись хранится локально до выхода с экрана. Автоматическая оценка произношения не выполняется.',
        ),
        const Text(
          'اقرأ بصوت واضح',
          textDirection: TextDirection.rtl,
          style: TextStyle(fontSize: 30, height: 1.8),
        ),
        actionStatus,
        ValueListenableBuilder<String?>(
          valueListenable: _audio.playbackError,
          builder: (context, error, _) => error == null
              ? const SizedBox.shrink()
              : IntegrationNotice(error),
        ),
        CheckboxListTile(
          value: _localConsent,
          onChanged: working || _audio.isRecording
              ? null
              : (value) => setState(() => _localConsent = value ?? false),
          title: const Text('Разрешаю локальную запись микрофона'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (_audio.isRecording)
          Semantics(
            liveRegion: true,
            child: Text('Идёт запись: $_seconds с (максимум 3 минуты)'),
          ),
        FilledButton(
          onPressed: working || (!_localConsent && !_audio.isRecording)
              ? null
              : () => runAction(_audio.isRecording ? _stop : _start),
          child: Text(
            _audio.isRecording ? 'Остановить запись' : 'Записать голос',
          ),
        ),
        StreamBuilder<PlayerState>(
          stream: _audio.player.playerStateStream,
          builder: (context, snapshot) {
            final playing =
                snapshot.data?.playing == true &&
                snapshot.data?.processingState != ProcessingState.completed;
            return OutlinedButton(
              onPressed: working || !_audio.hasRecording
                  ? null
                  : () =>
                        runAction(playing ? _audio.player.pause : _audio.play),
              child: Text(playing ? 'Пауза' : 'Послушать запись'),
            );
          },
        ),
        StreamBuilder<Duration>(
          stream: _audio.player.positionStream,
          builder: (context, snapshot) =>
              Text('Воспроизведение: ${snapshot.data?.inSeconds ?? 0} с'),
        ),
        TextButton(
          onPressed: working || (!_audio.hasRecording && !_audio.isRecording)
              ? null
              : () => runAction(_delete),
          child: const Text('Удалить запись с устройства'),
        ),
        const Divider(),
        CheckboxListTile(
          value: _uploadConsent,
          onChanged: working
              ? null
              : (value) => setState(() => _uploadConsent = value ?? false),
          title: const Text(
            'Разрешаю отправить эту запись в сервис распознавания',
          ),
          subtitle: const Text(
            'Голос покинет устройство только по кнопке ниже. '
            'Расшифровка — это текст, а не фонетическая оценка.',
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (widget.backend?.config.sttEnabled != true)
          const IntegrationNotice(
            'Сервис распознавания речи не настроен. Запись и прослушивание доступны локально.',
          ),
        FilledButton.tonal(
          onPressed: working || !_audio.hasRecording || !_uploadConsent
              ? null
              : () => runAction(_transcribe),
          child: const Text('Отправить запись и получить текст'),
        ),
        if (_transcript != null)
          SelectableText(
            _transcript!,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontSize: 24, height: 1.8),
          ),
      ],
    ),
  );
}
