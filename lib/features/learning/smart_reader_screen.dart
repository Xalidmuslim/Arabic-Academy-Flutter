import 'package:flutter/material.dart';

import '../../core/academy_state.dart';
import '../../core/app_strings.dart';
import '../../core/speech.dart';
import '../../core/vocabulary_key.dart';
import '../../services/lesson_audio_library.dart';
import '../../features/exercises/arabic_normalization.dart';
import '../../ui/components.dart';
import '../../ui/design_tokens.dart';
import '../../ui/dialogue_scene_illustration.dart';

/// Uses only the selected catalog lesson; no synthetic or unverified
/// translations are shown for words missing from that lesson's vocabulary.
class SmartReaderScreen extends StatefulWidget {
  const SmartReaderScreen({
    super.key, required this.state, required this.lesson,
  });
  final AcademyState state;
  final Map<String, dynamic> lesson;

  @override
  State<SmartReaderScreen> createState() => _SmartReaderScreenState();
}

class _SmartReaderScreenState extends State<SmartReaderScreen> {
  bool _translations = false;
  int? _activeLine;
  int? _activeToken;
  bool _continuous = false;
  int _playGeneration = 0;
  double _speed = .50;
  late final LessonAudioLibrary _audioLibrary =
      LessonAudioLibrary(widget.state);

  List<Map<String, dynamic>> get _lines {
    final rows = widget.lesson['dialogue'];
    if (rows is! List) return [];
    return rows.whereType<Map>()
        .map((r) => Map<String, dynamic>.from(r)).toList();
  }

  ({String ar, String ru, String id})? _findWord(String token) {
    final raw = ArabicNormalization.forGrading(token,
      ignoreDiacritics: true).replaceAll(
        RegExp(r'[^\u0621-\u064A]'), '');
    if (raw.isEmpty) return null;
    final vocabulary = widget.lesson['vocabulary'];
    if (vocabulary is! List) return null;
    for (var i = 0; i < vocabulary.length; i++) {
      final item = vocabulary[i];
      if (item is! Map) continue;
      final word = item['ar']?.toString() ?? '';
      final normalized = ArabicNormalization.forGrading(
        word, ignoreDiacritics: true).replaceAll(
        RegExp(r'[^\u0621-\u064A]'), '');
      if (normalized == raw) {
        return (
          ar: word,
          ru: item['ru']?.toString() ?? '',
          id: vocabularyKey(widget.lesson['id'].toString(), i, item),
        );
      }
    }
    return null;
  }

  /// Highlights real TTS speech-progress callbacks, not a guessed timer.
  /// Some Android voices do not expose word offsets: in that case only the
  /// current phrase is highlighted, without pretending to know timing.
  Future<void> _speak(String arabic, {int? lineIndex}) async {
    final generation = _playGeneration;
    await guardedAction(context, () => ArabicSpeech.speak(
      arabic,
      speed: _speed,
      engine: widget.state.settings['audioEngine'] as String?,
      voiceName: widget.state.settings['audioVoiceName'] as String?,
      voiceLocale: widget.state.settings['audioVoiceLocale'] as String?,
      onProgress: (start, end, spoken) {
        if (!mounted || generation != _playGeneration ||
            lineIndex == null || _activeLine != lineIndex) {
          return;
        }
        final tokens = RegExp(r'\S+').allMatches(arabic).toList();
        final selected = tokens.indexWhere((m) =>
            start >= m.start && start < m.end);
        if (selected >= 0 && _activeToken != selected) {
          setState(() => _activeToken = selected);
        }
      },
      onCompleted: () {
        if (!mounted || generation != _playGeneration ||
            lineIndex == null) {
          return;
        }
        if (_continuous && _activeLine == lineIndex &&
            lineIndex + 1 < _lines.length) {
          _readLine(lineIndex + 1);
        } else if (_activeLine == lineIndex) {
          setState(() {
            _continuous = false;
            _activeToken = null;
          });
        }
      },
    ));
  }

  Future<void> _readLine(int index) async {
    if (!mounted || index >= _lines.length) return;
    final generation = ++_playGeneration;
    setState(() {
      _activeLine = index;
      _activeToken = null;
    });
    final lessonId = widget.lesson['id']?.toString() ?? '';
    try {
      if (await _audioLibrary.hasSample(lessonId, index)) {
        // A real recording has no word-level time marks: highlight only
        // the current sentence rather than fake token timing.
        await ArabicSpeech.stop();
        if (!mounted || generation != _playGeneration) return;
        await _audioLibrary.play(
          lessonId, index, speed: (_speed / 0.5).clamp(0.7, 1.25),
        );
        if (!mounted || generation != _playGeneration) return;
        if (_continuous && index + 1 < _lines.length) {
          await _readLine(index + 1);
        } else {
          setState(() {
            _continuous = false;
            _activeToken = null;
          });
        }
      } else {
        await _audioLibrary.stop();
        if (!mounted || generation != _playGeneration) return;
        await _speak(_lines[index]['ar']?.toString() ?? '', lineIndex: index);
      }
    } catch (error) {
      if (mounted) {
        notice(context, 'Не удалось прочитать реплику: $error');
        setState(() => _continuous = false);
      }
    }
  }

  Future<void> _importAudio(int index) async {
    _playGeneration++;
    _continuous = false;
    await ArabicSpeech.stop();
    await _audioLibrary.stop();
    try {
      final success = await _audioLibrary.importFor(
        widget.lesson['id']?.toString() ?? '', index,
      );
      if (mounted && success) {
        setState(() {});
        notice(context, 'Аудиозапись носителя добавлена для реплики.');
      }
    } catch (error) {
      if (mounted) {
        notice(context, 'Не удалось импортировать аудио: $error');
      }
    }
  }

  Future<void> _toggleDialogue() async {
    if (_continuous) {
      _playGeneration++;
      await ArabicSpeech.stop();
      await _audioLibrary.stop();
      if (mounted) {
        setState(() {
          _continuous = false;
          _activeToken = null;
        });
      }
      return;
    }
    if (_lines.isEmpty) return;
    setState(() => _continuous = true);
    await _readLine(0);
  }

  void _wordSheet(String raw) {
    _continuous = false;
    _playGeneration++;
    _audioLibrary.stop();
    final word = _findWord(raw);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: DesignTokens.cardSurface,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NaskhText(word?.ar ?? raw,
                size: 34, align: TextAlign.center),
              const SizedBox(height: 8),
              Text(word == null || word.ru.isEmpty
                ? 'Для этого слова нет подтверждённого отдельного перевода.'
                : word.ru, textAlign: TextAlign.center),
              const SizedBox(height: 15),
              OutlinedButton.icon(
                icon: const Icon(Icons.volume_up_outlined),
                onPressed: () => _speak(word?.ar ?? raw),
                label: const Text('Произнести'),
              ),
              if (word != null)
                FilledButton.icon(
                  icon: Icon(widget.state.bookmarks.contains(word.id)
                    ? Icons.favorite : Icons.favorite_border),
                  onPressed: () async {
                    await guardedAction(context,
                      () => widget.state.toggleBookmark(word.id));
                    if (context.mounted) Navigator.pop(context);
                  },
                  label: const Text('Сохранить / убрать из избранного'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _continuous = false;
    _playGeneration++;
    ArabicSpeech.stop();
    _audioLibrary.dispose();
    super.dispose();
  }

  void _readerOptions() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, refresh) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr(context, 'Настройки чтения'),
                style: Theme.of(sheet).textTheme.titleLarge),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(tr(context, 'Показывать перевод фраз')),
                value: _translations,
                onChanged: (value) {
                  setState(() => _translations = value);
                  refresh(() {});
                },
              ),
              Text('Скорость воспроизведения · ${(_speed * 100).round()}%',
                style: const TextStyle(color: DesignTokens.secondary)),
              Slider(
                value: _speed, min: .4, max: .65, divisions: 5,
                onChanged: (value) {
                  setState(() => _speed = value);
                  refresh(() {});
                },
              ),
              ExpansionTile(
                title: Text(tr(context, 'Записи носителя (необязательно)'),
                children: [
                  for (var i = 0; i < _lines.length; i++)
                    ListTile(
                      dense: true,
                      title: Text('Запись для реплики ${i + 1}'),
                      trailing: const Icon(Icons.audio_file_outlined),
                      onTap: () {
                        Navigator.pop(sheet);
                        _importAudio(i);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Для реплик можно импортировать запись носителя '
                'в настройках чтения. Если записи нет, используется '
                'системный синтезатор. Подсветка отдельного слова доступна '
                'только когда движок передаёт точные временные метки.',
                style: TextStyle(
                  fontSize: 12, color: DesignTokens.secondary)),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr(context, 'Умное чтение')), actions: [
      IconButton(
        key: const ValueKey('reader-settings'),
        tooltip: 'Настройки чтения и скорости',
        icon: const Icon(Icons.tune_outlined),
        onPressed: _readerOptions,
      ),
    ]),
    body: AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 150),
        children: [
          Text(widget.lesson['title']?.toString() ?? '',
            style: Theme.of(context).textTheme.titleLarge),
          if (DialogueSceneIllustration.sceneFor(
              widget.lesson['title']?.toString() ?? '') != null) ...[
            const SizedBox(height: 10),
            Center(child: SizedBox(
                width: 190,
                child: DialogueSceneIllustration(
                  setting: widget.lesson['title']?.toString() ?? '',
                ),
              )),
          ],
          const SizedBox(height: 8),
          const Text('Нажмите арабское слово, чтобы узнать перевод '
            'и прослушать произношение.',
            style: TextStyle(color: DesignTokens.secondary, fontSize: 12)),
          const SizedBox(height: 10),
          FilledButton.icon(
            key: const ValueKey('reader-play-dialogue'),
            onPressed: _lines.isEmpty ? null : _toggleDialogue,
            icon: Icon(_continuous ? Icons.stop_circle_outlined
                : Icons.play_circle_outline),
            label: Text(tr(context, _continuous ? 'Остановить диалог'
                : 'Прослушать диалог по репликам')),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < _lines.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Panel(child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Text('Реплика ${i + 1}',
                      style: TextStyle(
                        fontWeight: _activeLine == i
                          ? FontWeight.w800 : FontWeight.w500,
                        color: DesignTokens.deepOlive)),
                    const Spacer(),
                    IconButton(
                      key: ValueKey('reader-audio-$i'),
                      tooltip: 'Повторить реплику (запись или TTS)',
                      onPressed: () async {
                        _continuous = false;
                        await _audioLibrary.stop();
                        await ArabicSpeech.stop();
                        await _readLine(i);
                      },
                      icon: const Icon(Icons.record_voice_over_outlined),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Wrap(
                      spacing: 6, runSpacing: 8,
                      children: [
                        for (final entry in RegExp(r'\S+')
                            .allMatches(_lines[i]['ar']?.toString() ?? '')
                            .toList().asMap().entries)
                          InkWell(
                            key: ValueKey('reader-word-$i-${entry.key}'),
                            onTap: () => _wordSheet(entry.value.group(0)!),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3, vertical: 3),
                              decoration: BoxDecoration(
                                color: _activeLine == i &&
                                    _activeToken == entry.key
                                      ? const Color(0xFFDAE5C6)
                                      : Colors.transparent,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: NaskhText(entry.value.group(0)!, size: 26,
                                color: DesignTokens.emerald),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_translations)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(_lines[i]['ru']?.toString() ?? ''),
                    ),
                ],
              )),
            ),
          if (_lines.isEmpty)
            EmptyState(title: tr(context, 'Диалог пока не добавлен'),
              message: 'Откройте урок с диалогом для умного чтения.'),
        ],
      ),
    ),
  );
}
