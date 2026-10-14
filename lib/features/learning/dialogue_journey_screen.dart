import 'package:flutter/material.dart';

import '../../core/academy_state.dart';
import '../../core/practice_generator.dart';
import '../../core/speech.dart';
import '../../ui/components.dart';
import '../../ui/design_tokens.dart';
import '../../ui/fitted_study_artwork.dart';
import '../../ui/study_art_asset.dart';

/// Context-preserving, branching practice: a correct choice advances the
/// course dialogue, a mistake branches into listening/repair, and a completed
/// conversation offers other authentic scenes from the same module.
/// Every line/translation remains attributed to an existing editorial lesson.
class DialogueJourneyScreen extends StatefulWidget {
  const DialogueJourneyScreen({
    super.key, required this.state, required this.lesson,
  });

  final AcademyState state;
  final Map<String, dynamic> lesson;

  @override
  State<DialogueJourneyScreen> createState() => _DialogueJourneyScreenState();
}

class _DialogueJourneyScreenState extends State<DialogueJourneyScreen> {
  late Map<String, dynamic> _lesson;
  int _step = 0;
  int _errors = 0;
  int _correct = 0;
  bool _help = false;
  bool _showTranslations = false;
  bool _saving = false;
  String? _chosen;

  @override
  void initState() {
    super.initState();
    _lesson = widget.lesson;
  }

  List<({String ar, String ru})> get _lines {
    final raw = _lesson['dialogue'];
    if (raw is! List) return [];
    return [
      for (final row in raw)
        if (row is Map &&
            row['ar']?.toString().trim().isNotEmpty == true)
          (
            ar: PracticeGenerator.utterance(row['ar'].toString()),
            ru: PracticeGenerator.utterance(
                row['ru']?.toString() ?? ''),
          ),
    ];
  }

  List<String> get _options {
    final lines = _lines;
    if (_step + 1 >= lines.length) return [];
    final correct = lines[_step + 1].ar;
    final distractors = <String>[];
    for (var i = 0; i < lines.length; i++) {
      if (i == _step || i == _step + 1) continue;
      final text = lines[i].ar;
      if (text != correct && !distractors.contains(text)) {
        distractors.add(text);
      }
      if (distractors.length >= 3) break;
    }
    if (distractors.isEmpty) return [correct];
    final options = [correct, ...distractors];
    final offset = (_step + 1) % options.length;
    return [...options.skip(offset), ...options.take(offset)];
  }

  List<Map<String, dynamic>> get _related {
    final module = _lesson['module_id'];
    return widget.state.allLessons.where((lesson) =>
        lesson['id'] != _lesson['id'] &&
        lesson['module_id'] == module &&
        lesson['dialogue'] is List &&
        (lesson['dialogue'] as List).length >= 2).take(5).toList();
  }

  bool get _finished => _lines.length < 2 || _step + 1 >= _lines.length;

  Future<void> _speak(String text) => guardedAction(context, () =>
      ArabicSpeech.speak(text,
        speed: (widget.state.settings['audioSpeed'] as num? ?? 0.5)
            .toDouble(),
        engine: widget.state.settings['audioEngine'] as String?,
        voiceName: widget.state.settings['audioVoiceName'] as String?,
        voiceLocale: widget.state.settings['audioVoiceLocale'] as String?,
      ));

  Future<void> _answer(String choice) async {
    if (_saving || _help || _finished) return;
    final expected = _lines[_step + 1].ar;
    final correct = choice == expected;
    setState(() => _saving = true);
    try {
      await widget.state.recordAttempt(
        lessonId: _lesson['id']?.toString() ?? '',
        exerciseId: 'practice:dialogue:${_lesson['id']}:$_step',
        answer: {
          'response': choice,
          'expected': expected,
          'feedback': correct
              ? 'Следующая реплика учебного диалога.'
              : 'В этом диалоге следующая реплика: $expected',
          'source': _lesson['title']?.toString() ?? '',
        },
        status: correct ? 'correct' : 'incorrect',
        points: correct ? 1 : 0,
      );
      if (!mounted) return;
      setState(() {
        _chosen = choice;
        if (correct) {
          _correct++;
          _step++;
        } else {
          _errors++;
          _help = true;
        }
      });
    } catch (error) {
      if (mounted) notice(context, 'Не удалось сохранить ответ: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _switchScene(Map<String, dynamic> scene) {
    ArabicSpeech.stop();
    setState(() {
      _lesson = scene;
      _step = 0;
      _errors = 0;
      _correct = 0;
      _help = false;
      _chosen = null;
    });
  }

  Widget _studyLine(String text, {double size = 27}) =>
      NaskhText(text, size: size, color: DesignTokens.emerald,
          align: TextAlign.center, height: 1.5);

  @override
  void dispose() {
    ArabicSpeech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lines = _lines;
    return Scaffold(
      appBar: AppBar(title: const Text('Разговор по ролям')),
      body: SafeArea(child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 145),
        children: [
          Text(_lesson['title']?.toString() ?? '',
            style: Theme.of(context).textTheme.titleLarge),
          if (StudyArtAsset.valid(_lesson['dialogue_illustration_asset']) case final imagePath?) ...[
            const SizedBox(height: 10),
            Center(child: FittedStudyArtwork(
              image: AssetImage(imagePath), width: 295, height: 166,
            )),
          ],
          const SizedBox(height: 8),
          const Text('Выбирайте следующую реплику. Ошибки открывают '
            'ветку с подсказкой; после завершения можно выбрать '
            'другую ситуацию из того же раздела.',
            style: TextStyle(fontSize: 12, color: DesignTokens.secondary)),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Перевод для подсказки'),
            value: _showTranslations,
            onChanged: (v) => setState(() => _showTranslations = v),
          ),
          const SizedBox(height: 9),
          if (_finished) ...[
            Panel(child: Column(children: [
              const Icon(Icons.verified_outlined,
                size: 50, color: DesignTokens.deepOlive),
              const SizedBox(height: 10),
              Text(lines.length < 2
                  ? 'Недостаточно реплик'
                  : 'Диалог завершён',
                style: Theme.of(context).textTheme.titleLarge),
              Text('Верно: $_correct · Ошибок: $_errors'),
              const SizedBox(height: 8),
              const Text('Следующий диалог выбирается из подтверждённых '
                'уроков этого же раздела.',
                textAlign: TextAlign.center),
            ])),
            const SectionTitle('Выберите продолжение'),
            for (final other in _related)
              ListTile(
                title: Text(other['title']?.toString() ?? 'Диалог'),
                subtitle: const Text('Другая учебная ситуация'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _switchScene(other),
              ),
            OutlinedButton(
              onPressed: () => _switchScene(_lesson),
              child: const Text('Повторить этот диалог'),
            ),
          ] else ...[
            LinearProgressIndicator(
              value: (_step + 1) / lines.length,
              color: DesignTokens.olive,
              backgroundColor: DesignTokens.beige,
              minHeight: 6,
              borderRadius: BorderRadius.circular(6),
            ),
            const SizedBox(height: 13),
            Panel(child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Собеседница говорит · реплика ${_step + 1}',
                  style: const TextStyle(
                    color: DesignTokens.secondary,
                    fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                _studyLine(lines[_step].ar),
                if (_showTranslations) ...[
                  const SizedBox(height: 8),
                  Text(lines[_step].ru, textAlign: TextAlign.center),
                ],
                Center(child: IconButton(
                  tooltip: 'Прослушать реплику',
                  onPressed: () => _speak(lines[_step].ar),
                  icon: const Icon(Icons.volume_up_outlined,
                    size: 30, color: DesignTokens.deepOlive),
                )),
              ],
            )),
            const SizedBox(height: 12),
            if (_help) ...[
              Panel(child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Давайте разберём эту реплику',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (_chosen != null)
                    Text('Ваш вариант: $_chosen'),
                  const SizedBox(height: 8),
                  _studyLine(lines[_step + 1].ar, size: 24),
                  if (_showTranslations)
                    Text(lines[_step + 1].ru,
                      textAlign: TextAlign.center),
                  OutlinedButton.icon(
                    onPressed: () => _speak(lines[_step + 1].ar),
                    icon: const Icon(Icons.volume_up_outlined),
                    label: const Text('Послушать правильный ответ'),
                  ),
                ],
              )),
              const SizedBox(height: 9),
              FilledButton.icon(
                key: const ValueKey('dialogue-retry'),
                onPressed: () => setState(() {
                  _help = false;
                  _chosen = null;
                }),
                icon: const Icon(Icons.refresh_outlined),
                label: const Text('Попробовать снова'),
              ),
              OutlinedButton(
                onPressed: () => setState(() {
                  _help = false;
                  _chosen = null;
                  _step++;
                }),
                child: const Text('Продолжить после подсказки'),
              ),
            ] else ...[
              Text('Как вы ответите?',
                style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 9),
              for (final option in _options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => _answer(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: _studyLine(option, size: 23),
                    ),
                  ),
                ),
              if (_options.length < 2)
                const Text('Выберите единственную доступную реплику '
                  'или перейдите к следующему диалогу.',
                  style: TextStyle(fontSize: 12,
                    color: DesignTokens.secondary)),
            ],
          ],
        ],
      )),
    );
  }
}
