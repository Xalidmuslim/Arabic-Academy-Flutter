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
    return Scaffold(
      appBar: AppBar(title: const Text('Сравнить произношение')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 150),
        children: [
          const Text('Сначала прослушайте арабскую фразу, затем запишите '
            'свой голос. Можно повторять запись и сравнивать на слух. '
            'Окончательную оценку ставит учительница.',
            style: TextStyle(fontSize: 12, color: DesignTokens.secondary)),
          const SizedBox(height: 13),
          Panel(child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_phrase == null
                  ? 'Выберите фразу из урока'
                  : 'Фраза для повторения',
                  style: Theme.of(context).textTheme.titleMedium),
              if (_phrase != null) ...[
                const SizedBox(height: 10),
                NaskhText(_phrase!, size: 29,
                  align: TextAlign.center,
                  color: DesignTokens.emerald),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.volume_up_outlined),
                  onPressed: _busy ? null : _speak,
                  label: const Text('Слушать образец (голос Android)'),
                ),
              ],
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _consent,
                title: const Text('Разрешаю запись голоса на этом телефоне'),
                onChanged: _recording.isRecording ? null :
                    (v) => setState(() => _consent = v ?? false),
              ),
              FilledButton.icon(
                key: const ValueKey('pronunciation-record'),
                onPressed: !_consent || _phrase == null || _busy
                    ? null : _toggleRecord,
                icon: Icon(_recording.isRecording
                  ? Icons.stop_circle_outlined
                  : Icons.mic_none_outlined),
                label: Text(_recording.isRecording
                  ? 'Остановить запись' : 'Записать свой ответ'),
              ),
              if (_recording.hasRecording) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _do(_recording.play),
                  icon: const Icon(Icons.play_arrow_outlined),
                  label: const Text('Прослушать себя'),
                ),
                FilledButton.icon(
                  key: const ValueKey('pronunciation-save'),
                  onPressed: _busy || _saved ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saved ? 'Сохранено для учительницы'
                    : 'Сохранить для ручной проверки'),
                ),
              ],
            ],
          )),
          const SectionTitle('Фразы из уроков'),
          if (examples.isEmpty)
            const Panel(child: Text('Нет проверенных диалогов для практики.'))
          else
            for (var i = 0; i < examples.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Panel(padding: EdgeInsets.zero, child: ListTile(
                  key: ValueKey('pronunciation-phrase-$i'),
                  title: Text(examples[i].title),
                  subtitle: NaskhText(examples[i].text, size: 21),
                  trailing: _phrase == examples[i].text
                      ? const Icon(Icons.check_circle,
                          color: DesignTokens.deepOlive)
                      : const Icon(Icons.chevron_right),
                  onTap: () {
                    if (_recording.isRecording) {
                      notice(context, 'Сначала остановите запись.');
                      return;
                    }
                    setState(() {
                      _lessonId = examples[i].id;
                      _phrase = examples[i].text;
                      _saved = false;
                    });
                  },
                )),
              ),
          const Text('Записи сохраняются в закрытом каталоге приложения. '
            'Они не отправляются на сервер и могут исчезнуть при удалении APK.',
            style: TextStyle(fontSize: 12,
              color: DesignTokens.secondary)),
        ],
      ),
    );
  }
}
