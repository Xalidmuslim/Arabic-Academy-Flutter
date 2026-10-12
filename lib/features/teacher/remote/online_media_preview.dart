import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';
import '../../../services/backend_service.dart';
import 'online_learning_api.dart';

/// Resolves only a lesson-scoped media row through the authorized Edge function.
/// No URL from a lesson JSON body is trusted as a private media authorization.
class OnlineMediaPreview extends StatefulWidget {
  const OnlineMediaPreview({super.key, required this.api, required this.media});
  final OnlineLearningApi api;
  final Map<String, dynamic> media;
  @override
  State<OnlineMediaPreview> createState() => _OnlineMediaPreviewState();
}

class _OnlineMediaPreviewState extends State<OnlineMediaPreview> {
  AudioPlayer? _audio;
  VideoPlayerController? _video;
  String? _url, _error;
  bool _busy = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    widget.api.backend.addListener(_accountChanged);
  }

  void _accountChanged() {
    try {
      widget.api.requireOwner();
    } catch (error) {
      _generation++;
      if (mounted) {
        setState(() {
          _url = null;
          _busy = false;
          _error = 'Аккаунт изменился. Закройте материал.';
        });
      }
      unawaited(
        _disposePlayers().catchError((Object error) {
          debugPrint('Media player cleanup failed.');
        }),
      );
    }
  }

  Future<void> _disposePlayers() async {
    final audio = _audio, video = _video;
    _audio = null;
    _video = null;
    await Future.wait<void>([
      if (audio != null) audio.dispose(),
      if (video != null) video.dispose(),
    ]);
  }

  @override
  void dispose() {
    _generation++;
    widget.api.backend.removeListener(_accountChanged);
    unawaited(
      _disposePlayers().catchError((Object error) {
        debugPrint('Media player cleanup failed.');
      }),
    );
    super.dispose();
  }

  String _message(Object error) => error is IntegrationException
      ? error.message
      : 'Не удалось открыть материал. Проверьте сеть и учебный доступ.';
  Future<void> _load() async {
    if (_busy) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
      _url = null;
    });
    AudioPlayer? audio;
    VideoPlayerController? video;
    try {
      await _disposePlayers();
      final url = await widget.api.mediaUrl(widget.media['id'] as String);
      if (widget.media['kind'] == 'audio') {
        audio = AudioPlayer();
        await audio.setUrl(url);
      }
      if (widget.media['kind'] == 'video') {
        video = VideoPlayerController.networkUrl(Uri.parse(url));
        await video.initialize();
      }
      widget.api.requireOwner();
      if (!mounted || generation != _generation) {
        await audio?.dispose();
        await video?.dispose();
        return;
      }
      setState(() {
        _audio = audio;
        _video = video;
        _url = url;
      });
      final controller = video;
      controller?.addListener(() {
        if (mounted && identical(_video, controller)) {
          setState(() {
            if (controller.value.hasError) {
              _error = 'Воспроизведение прервано. Откройте материал заново.';
            }
          });
        }
      });
    } catch (error) {
      await audio?.dispose();
      await video?.dispose();
      if (mounted && generation == _generation) {
        setState(() => _error = _message(error));
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _control(Future<void> Function() action) async {
    try {
      widget.api.requireOwner();
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    }
  }

  Future<void> _toggleAudio(AudioPlayer player) async {
    if (player.playing && player.processingState != ProcessingState.completed) {
      await player.pause();
      return;
    }
    if (player.processingState == ProcessingState.completed) {
      await player.seek(Duration.zero);
    }
    await player.play();
  }

  Future<void> _toggleVideo(VideoPlayerController player) async {
    if (player.value.isPlaying) {
      await player.pause();
      return;
    }
    if (player.value.duration > Duration.zero &&
        player.value.position >= player.value.duration) {
      await player.seekTo(Duration.zero);
    }
    await player.play();
  }

  Widget _audioControls(AudioPlayer player) => Column(
    children: [
      StreamBuilder<PlayerState>(
        stream: player.playerStateStream,
        builder: (context, snapshot) => FilledButton.icon(
          onPressed: () => _control(() => _toggleAudio(player)),
          icon: Icon(
            player.playing &&
                    player.processingState != ProcessingState.completed
                ? Icons.pause
                : Icons.play_arrow,
          ),
          label: Text(
            player.processingState == ProcessingState.completed
                ? 'Слушать сначала'
                : player.playing
                ? 'Пауза'
                : 'Слушать аудио',
          ),
        ),
      ),
      StreamBuilder<Duration>(
        stream: player.positionStream,
        builder: (context, snapshot) {
          final max = (player.duration?.inMilliseconds ?? 0).toDouble();
          final position = (snapshot.data?.inMilliseconds ?? 0)
              .toDouble()
              .clamp(0, max)
              .toDouble();
          return Column(
            children: [
              Text(
                '${Duration(milliseconds: position.toInt()).toString().split('.').first} / ${player.duration?.toString().split('.').first ?? '—'}',
              ),
              Slider(
                value: position,
                max: max == 0 ? 1 : max,
                onChanged: max == 0
                    ? null
                    : (v) => _control(
                        () => player.seek(Duration(milliseconds: v.toInt())),
                      ),
              ),
            ],
          );
        },
      ),
    ],
  );
  Widget _videoControls(VideoPlayerController player) => Column(
    children: [
      AspectRatio(
        aspectRatio: player.value.aspectRatio,
        child: VideoPlayer(player),
      ),
      FilledButton.icon(
        onPressed: () => _control(() => _toggleVideo(player)),
        icon: Icon(player.value.isPlaying ? Icons.pause : Icons.play_arrow),
        label: Text(player.value.isPlaying ? 'Пауза' : 'Смотреть видео'),
      ),
      Slider(
        value: player.value.position.inMilliseconds.toDouble().clamp(
          0,
          player.value.duration.inMilliseconds.toDouble(),
        ),
        max: player.value.duration.inMilliseconds == 0
            ? 1
            : player.value.duration.inMilliseconds.toDouble(),
        onChanged: player.value.duration.inMilliseconds == 0
            ? null
            : (v) => _control(
                () => player.seekTo(Duration(milliseconds: v.toInt())),
              ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_busy) const LinearProgressIndicator(),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      if (_url != null && widget.media['kind'] == 'image')
        Image.network(
          _url!,
          cacheWidth: 1024,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) =>
              const Text('Изображение недоступно. Откройте материал заново.'),
        ),
      if (_audio != null) _audioControls(_audio!),
      if (_video != null) _videoControls(_video!),
      if (!const {'image', 'audio', 'video'}.contains(widget.media['kind']))
        const Text(
          'Документ прикреплён. Просмотр PDF на этом экране пока не поддерживается.',
        ),
      if (const {'image', 'audio', 'video'}.contains(widget.media['kind']))
        OutlinedButton.icon(
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.lock_open_outlined),
          label: Text(
            _url == null
                ? 'Открыть защищённый материал'
                : 'Открыть материал заново',
          ),
        ),
    ],
  );
}
