import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/academy_state.dart';
import '../../core/speech.dart';
import '../../services/audio_practice_service.dart';
import '../../ui/components.dart';
import '../../ui/design_tokens.dart';

/// Guided A/B speaking practice. It does not misrepresent Android speech
/// recognition as a phonetic accuracy score. Teacher evaluation is manual.
class PronunciationComparisonScreen extends StatefulWidget {
  const PronunciationComparisonScreen({
    super.key, required this.state,
  });
  final AcademyState state;

  @override
  State<PronunciationComparisonScreen> createState() =>
      _PronunciationComparisonScreenState();
}

class _PronunciationComparisonScreenState
    extends State<PronunciationComparisonScreen> {
  final _recording = AudioPracticeService();
  bool _consent = false;
  bool _busy = false;
  bool _saved = false;
  String? _lessonId;
  String? _phrase;
  int _activeIndex = 0;

  List<({String id, String title, String text})> get _examples {
    final result = <({String id, String title, String text})>[];
    for (final lesson in widget.state.allLessons) {
      final id = lesson['id'];
      final dialogue = lesson['dialogue'];
      if (id is! String || dialogue is! List) continue;
      for (final item in dialogue.take(3)) {
        if (item is! Map) continue;
        final text = item['ar']?.toString() ?? '';
        if (text.isEmpty) continue;
        final colon = text.indexOf(':');
        final utterance = colon < 0 ? text : text.substring(colon + 1).trim();
        if (utterance.length < 4 || utterance.length > 160) continue;
        result.add((
          id: id,
          title: lesson['title']?.toString() ?? id,
          text: utterance,
        ));
      }
      if (result.length >= 50) break;
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    final choices = _examples;
    if (choices.isNotEmpty) {
      _lessonId = choices.first.id;
      _phrase = choices.first.text;
    }
  }

  Future<void> _selectPhrase(
    int index, List<({String id, String title, String text})> examples,
  ) async {
    if (_busy || index < 0 || index >= examples.length ||
        index == _activeIndex) return;
    if (_recording.isRecording) {
      notice(context, 'Сначала остановите запись.');
      return;
    }
    if (_recording.hasRecording && !_saved) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Сменить фразу?'),
          content: const Text('Несохранённая запись текущей фразы будет удалена.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Остаться')),
            FilledButton(onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Сменить')),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    await _do(() async {
      await ArabicSpeech.stop();
      await _recording.delete();
      if (!mounted) return;
      setState(() {
        _activeIndex = index;
        _lessonId = examples[index].id;
        _phrase = examples[index].text;
        _saved = false;
      });
    });
  }

  Future<void> _choosePhrase(
      List<({String id, String title, String text})> examples) async {
    if (_busy || _recording.isRecording) return;
    String query = '';
    final choice = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, update) {
          final indexes = List<int>.generate(examples.length, (i) => i)
              .where((i) => examples[i].title.toLowerCase().contains(
                  query.toLowerCase()) ||
                  examples[i].text.contains(query))
              .toList();
          return SafeArea(child: SizedBox(
            height: MediaQuery.sizeOf(sheet).height * .73,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
              child: Column(children: [
                Text('Выберите фразу из урока',
                  style: Theme.of(sheet).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('pronunciation-phrase-search'),
                  onChanged: (value) => update(() => query = value.trim()),
                  decoration: const InputDecoration(
                    hintText: 'Поиск по уроку или арабскому тексту',
                    prefixIcon: Icon(Icons.search_outlined)),
                ),
                const SizedBox(height: 8),
                Expanded(child: ListView.builder(
                  itemCount: indexes.length,
                  itemBuilder: (sheet, row) {
                    final index = indexes[row];
                    final example = examples[index];
                    return ListTile(
                      key: ValueKey('pronunciation-choice-$index'),
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      title: NaskhText(example.text, size: 21),
                      subtitle: Text(example.title, maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                      trailing: index == _activeIndex
                          ? Icon(Icons.check_circle,
                              color: Theme.of(sheet).colorScheme.primary)
                          : const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(sheet, index),
                    );
                  },
                )),
              ]),
            ),
          ));
        },
      ),
    );
    if (choice != null && mounted) await _selectPhrase(choice, examples);
  }

  Future<void> _do(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) notice(context, 'Аудиотренировка: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _speak() => _do(() async {
    await ArabicSpeech.speak(
      _phrase ?? '',
      speed: (widget.state.settings['audioSpeed'] as num? ?? .5).toDouble(),
      engine: widget.state.settings['audioEngine'] as String?,
      voiceName: widget.state.settings['audioVoiceName'] as String?,
      voiceLocale: widget.state.settings['audioVoiceLocale'] as String?,
    );
  });

  Future<void> _toggleRecord() => _do(() async {
    if (_recording.isRecording) {
      await _recording.stop();
    } else {
      await ArabicSpeech.stop();
      await _recording.start(consent: _consent);
    }
    if (mounted) setState(() => _saved = false);
  });

  Future<void> _save() => _do(() async {
    final phrase = _phrase;
    final lessonId = _lessonId;
    if (phrase == null || lessonId == null) return;
    if (_recording.isRecording) {
      await _recording.stop();
    }
    final path = await _recording.preserveForHomework();
    await widget.state.recordAttempt(
      lessonId: lessonId,
      exerciseId: 'pronunciation:$lessonId',
      answer: {
        'phrase': phrase,
        'audio_path': path,
        'source': 'self_recording',
        'automated_phonetic_score': null,
        'review_type': 'teacher_manual',
      },
      status: 'needsReview', points: 0,
    );
    if (mounted) {
      setState(() => _saved = true);
      notice(context, 'Запись сохранена для ручной проверки.');
    }
  });

  @override
  void dispose() {
    ArabicSpeech.stop();
    unawaited(_recording.dispose().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final examples = _examples;
    final ready = _phrase != null && examples.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Сравнить произношение')),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: ListView(
        key: const PageStorageKey<String>('pronunciation-practice-scroll'),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 172),
        children: [
          Text('Послушайте образец, запишите свой голос и сравните на слух. '
            'Окончательную оценку ставит учительница.',
            style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          Panel(child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(child: Text(ready
                    ? 'Фраза ${_activeIndex + 1} из ${examples.length}'
                    : 'Фразы не найдены',
                  style: Theme.of(context).textTheme.titleMedium)),
                OutlinedButton.icon(
                  key: const ValueKey('pronunciation-choose-phrase'),
                  onPressed: !ready || _busy || _recording.isRecording
                      ? null : () => _choosePhrase(examples),
                  icon: const Icon(Icons.list_alt_outlined, size: 19),
                  label: const Text('Выбрать'),
                ),
              ]),
              if (ready) ...[
                Text(examples[_activeIndex].title,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 14),
                NaskhText(_phrase!, size: 31, align: TextAlign.center),
                const SizedBox(height: 9),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      key: const ValueKey('pronunciation-prev-phrase'),
                      onPressed: _activeIndex == 0 || _busy || _recording.isRecording
                          ? null : () => _selectPhrase(_activeIndex - 1, examples),
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('Назад'),
                    ),
                    TextButton.icon(
                      key: const ValueKey('pronunciation-next-phrase'),
                      onPressed: _activeIndex >= examples.length - 1 ||
                          _busy || _recording.isRecording
                          ? null : () => _selectPhrase(_activeIndex + 1, examples),
                      icon: const Icon(Icons.chevron_right),
                      iconAlignment: IconAlignment.end,
                      label: const Text('Следующая'),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                OutlinedButton.icon(
                  key: const ValueKey('pronunciation-play-model'),
                  icon: const Icon(Icons.volume_up_outlined),
                  onPressed: _busy || _recording.isRecording ? null : _speak,
                  label: const Text('1 · Слушать образец (Android)'),
                ),
                const SizedBox(height: 6),
              ],
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _consent,
                title: const Text('Разрешаю запись голоса на этом телефоне'),
                onChanged: _recording.isRecording ? null :
                    (value) => setState(() => _consent = value ?? false),
              ),
              FilledButton.icon(
                key: const ValueKey('pronunciation-record'),
                onPressed: !_consent || !ready || _busy
                    ? null : _toggleRecord,
                icon: Icon(_recording.isRecording
                    ? Icons.stop_circle_outlined : Icons.mic_none_outlined),
                label: Text(_recording.isRecording
                    ? 'Остановить запись'
                    : '2 · Записать свой голос'),
              ),
              if (_recording.hasRecording) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  key: const ValueKey('pronunciation-play-self'),
                  onPressed: _busy ? null : () => _do(_recording.play),
                  icon: const Icon(Icons.play_arrow_outlined),
                  label: const Text('3 · Прослушать себя'),
                ),
                const SizedBox(height: 6),
                FilledButton.icon(
                  key: const ValueKey('pronunciation-save'),
                  onPressed: _busy || _saved ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saved
                    ? 'Сохранено для учительницы'
                    : 'Сохранить для проверки'),
                ),
              ],
            ],
          )),
          const SizedBox(height: 12),
          if (!ready)
            const EmptyState(
              title: 'Фразы для тренировки отсутствуют',
              message: 'Добавьте диалоги к урокам, чтобы тренировать произношение.',
            ),
          Text('Образец озвучивает Android, а не носитель языка. '
            'Запись остаётся на устройстве до явного сохранения. '
            'Смена фразы удаляет несохранённую запись после подтверждения.',
            style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
