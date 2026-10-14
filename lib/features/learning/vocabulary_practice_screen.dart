import 'package:flutter/material.dart';

import '../../core/academy_state.dart';
import '../../core/learning_insights.dart';
import '../../core/speech.dart';
import '../../core/vocabulary_practice.dart';
import '../../ui/components.dart';
import '../../ui/design_tokens.dart';
import 'library_screens.dart';

class VocabularyPracticeScreen extends StatefulWidget {
  const VocabularyPracticeScreen({super.key, required this.state, this.lessonId});
  final AcademyState state;
  final String? lessonId;

  @override
  State<VocabularyPracticeScreen> createState() =>
      _VocabularyPracticeScreenState();
}

class _TrainingItem {
  const _TrainingItem(this.word, this.type, {this.retry = false});
  final VocabularyPracticeWord word;
  final VocabularyChallenge type;
  final bool retry;
}

class _VocabularyPracticeScreenState extends State<VocabularyPracticeScreen> {
  late final VocabularyPracticePlan _plan;
  late final List<VocabularyPracticeWord> _all;
  late final List<_TrainingItem> _tasks;
  final _input = TextEditingController();
  int _position = 0;
  int _correct = 0;
  int _errors = 0;
  bool _checked = false;
  bool _hintUsed = false;
  bool _wasCorrect = false;
  bool _saving = false;
  int? _confidence;
  final Stopwatch _recallTimer = Stopwatch();
  String? _choice;

  @override
  void initState() {
    super.initState();
    _plan = VocabularyPractice.plan(widget.state,
      lessonId: widget.lessonId,
      newLimit: LearningInsights.reviewGoal(widget.state));
    _all = VocabularyPractice.words(widget.state, lessonId: widget.lessonId);
    _recallTimer.start();
    _tasks = [
      for (var i = 0; i < _plan.words.length; i++)
        _TrainingItem(
          _plan.words[i],
          VocabularyPractice.challengeAt(i),
        ),
    ];
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  _TrainingItem get _task => _tasks[_position];

  List<String> get _choices => VocabularyPractice.options(
        correct: _task.word, all: _all, type: _task.type,
      );

  bool get _selfReview =>
      _task.type != VocabularyChallenge.writeArabic && _choices.length < 2;

  String get _answer => switch (_task.type) {
    VocabularyChallenge.russianToArabic ||
    VocabularyChallenge.writeArabic => _task.word.ar,
    _ => _task.word.ru,
  };

  bool get _canCheck => _task.type == VocabularyChallenge.writeArabic
      ? _input.text.trim().isNotEmpty
      : _choice != null;

  void _check() {
    if (_checked || !_canCheck) return;
    final correct = _task.type == VocabularyChallenge.writeArabic
        ? VocabularyPractice.matchesArabic(_input.text, _answer)
        : _choice == _answer;
    setState(() {
      _wasCorrect = correct && !_hintUsed;
      _checked = true;
      _recallTimer.stop();
    });
  }

  void _selfCheck(bool recalled) {
    if (_checked || !_hintUsed) return;
    setState(() {
      _wasCorrect = recalled;
      _checked = true;
      _recallTimer.stop();
    });
  }

  Future<void> _next() async {
    if (!_checked || _saving) return;
    setState(() => _saving = true);
    final task = _task;
    try {
      if (!task.retry) {
        await widget.state.reviewWord(
          task.word.id, _wasCorrect,
          responseMillis: _recallTimer.elapsedMilliseconds,
          confidence: _wasCorrect ? (_confidence ?? 4) : 0,
        );
      }
      if (!mounted) return;
      setState(() {
        if (!task.retry) {
          if (_wasCorrect) {
            _correct++;
          } else {
            _errors++;
            // Incorrect words reappear after the main round for reinforcement.
            // A successful same-session retry must NOT promote their SRS stage.
            _tasks.add(_TrainingItem(
              task.word,
              VocabularyChallenge.arabicToRussian,
              retry: true,
            ));
          }
        }
        _position++;
        _confidence = null;
        _recallTimer
          ..reset()
          ..start();
        _checked = false;
        _hintUsed = false;
        _wasCorrect = false;
        _choice = null;
        _input.clear();
      });
    } catch (error) {
      if (mounted) {
        notice(context, 'Ответ не сохранён: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _speak() => guardedAction(context, () =>
      ArabicSpeech.speak(
        _task.word.ar,
        speed: ((widget.state.settings['audioSpeed'] as num?) ?? 0.5)
            .toDouble().clamp(0.2, 0.8),
      ));

  Widget _arabic(String text, {double size = 31}) => NaskhText(
    text, size: size, height: 1.65, align: TextAlign.center,
    color: DesignTokens.emerald,
  );

  Widget _quiz(_TrainingItem task) {
    final word = task.word;
    final type = task.type;
    final prompt = switch (type) {
      VocabularyChallenge.arabicToRussian => 'Вспомните перевод',
      VocabularyChallenge.russianToArabic => 'Выберите арабское слово',
      VocabularyChallenge.listening => 'Услышьте и выберите перевод',
      VocabularyChallenge.writeArabic => 'Напишите слово по-арабски',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(prompt, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (type == VocabularyChallenge.arabicToRussian)
                _arabic(word.ar)
              else if (type == VocabularyChallenge.listening) ...[
                Align(
                  alignment: Alignment.center,
                  child: IconButton.filledTonal(
                    key: const ValueKey('practice-audio'),
                    tooltip: 'Произнести слово по-арабски',
                    iconSize: 40,
                    onPressed: _speak,
                    icon: const Icon(Icons.volume_up_outlined),
                  ),
                ),
                const Text(
                  'Нажмите для прослушивания. Арабский голос должен '
                  'быть установлен на телефоне.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12,
                      color: DesignTokens.secondary),
                ),
                if (_hintUsed || _checked) _arabic(word.ar, size: 26),
                if (!_hintUsed && !_checked)
                  TextButton(
                    key: const ValueKey('practice-listen-hint'),
                    onPressed: () => setState(() => _hintUsed = true),
                    child: const Text('Нет озвучки? Показать слово (будет ошибкой)'),
                  ),
              ] else
                Text(word.ru, textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(word.lessonTitle, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12,
                    color: DesignTokens.secondary)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (_selfReview) ...[
          if (!_hintUsed)
            FilledButton(
              onPressed: () => setState(() => _hintUsed = true),
              child: const Text('Показать ответ'),
            )
          else ...[
            _arabic(word.ar, size: 27),
            Text(word.ru, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _selfCheck(false),
              child: const Text('Ещё не помню'),
            ),
            FilledButton(
              onPressed: () => _selfCheck(true),
              child: const Text('Вспомнила до подсказки'),
            ),
          ],
        ] else if (type == VocabularyChallenge.writeArabic) ...[
          TextField(
            key: const ValueKey('practice-arabic-answer'),
            controller: _input,
            onChanged: (_) => setState(() {}),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            enabled: !_checked,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Введите слово по-арабски',
              helperText: 'Огласовки необязательны, буквы проверяются.',
            ),
          ),
        ] else
          for (final option in _choices)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: OutlinedButton(
                key: ValueKey('practice-option-$option'),
                onPressed: _checked ? null : () =>
                    setState(() => _choice = option),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: _choice == option
                      ? const Color(0xFFE5EAD7)
                      : DesignTokens.cardSurface,
                ),
                child: type == VocabularyChallenge.russianToArabic
                    ? _arabic(option, size: 25)
                    : Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(option, textAlign: TextAlign.center),
                      ),
              ),
            ),
        if (!_selfReview && !_checked) ...[
          const SizedBox(height: 8),
          FilledButton(
            key: const ValueKey('practice-check'),
            onPressed: _canCheck ? _check : null,
            child: const Text('Проверить'),
          ),
        ],
        if (_checked) ...[
          const SizedBox(height: 14),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Icon(_wasCorrect ? Icons.check_circle_outline
                      : Icons.refresh_outlined,
                    color: DesignTokens.deepOlive),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_wasCorrect ? 'Верно!' : 'Повторим ещё раз',
                      style: Theme.of(context).textTheme.titleMedium),
                  ),
                ]),
                const SizedBox(height: 9),
                _arabic(word.ar, size: 27),
                Text(word.ru, textAlign: TextAlign.center),
                if (!_wasCorrect)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Слово вернётся в конце тренировки и останется '
                      'к повторению. Не нужно угадывать.',
                      style: TextStyle(fontSize: 12,
                          color: DesignTokens.secondary),
                    ),
                  ),
              ],
            ),
          ),
          if (_wasCorrect && !task.retry) ...[
            const SizedBox(height: 9),
            const Text('Насколько уверенно вспомнили?',
              style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 7),
            Wrap(spacing: 8, runSpacing: 6, children: [
              ChoiceChip(
                label: const Text('С сомнением'),
                selected: _confidence == 2,
                onSelected: (_) => setState(() => _confidence = 2),
              ),
              ChoiceChip(
                label: const Text('Уверенно'),
                selected: _confidence == 5,
                onSelected: (_) => setState(() => _confidence = 5),
              ),
            ]),
          ],
          const SizedBox(height: 10),
          FilledButton(
            key: const ValueKey('practice-next'),
            onPressed: _saving ? null : _next,
            child: Text(_saving ? 'Сохранение…' : 'Далее'),
          ),
        ],
      ],
    );
  }

  Widget _summary(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 42),
      const Icon(Icons.verified_outlined, size: 64,
          color: DesignTokens.deepOlive),
      const SizedBox(height: 18),
      Text(_plan.words.isEmpty
          ? _plan.totalEligible == 0
              ? 'В уроках ещё нет слов с переводами'
              : 'На сегодня всё повторено'
          : 'Тренировка завершена',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 16),
      if (_plan.words.isNotEmpty)
        Panel(
          child: Column(children: [
            Text('Проверено слов: ${_plan.words.length}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Вспомнила сразу: $_correct · Потребовали повторения: $_errors'),
            const SizedBox(height: 6),
            const Text(
              'Результаты сохранены. Сложные слова вернутся в следующий сеанс.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12,
                  color: DesignTokens.secondary),
            ),
          ]),
        ),
      if (_plan.words.isEmpty)
        const Text(
          'Возвращайтесь к повторению позже или откройте словарь. '
          'Повторение не требует постоянного интернета.',
          textAlign: TextAlign.center,
        ),
      const SizedBox(height: 18),
      FilledButton.icon(
        icon: const Icon(Icons.menu_book_outlined),
        onPressed: () => Navigator.push(context,
          MaterialPageRoute<void>(
            builder: (_) => DictionaryScreen(
              state: widget.state,
              lessonId: widget.lessonId,
            ),
          ),
        ),
        label: const Text('Открыть словарь'),
      ),
      const SizedBox(height: 10),
      OutlinedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Вернуться к обучению'),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final done = _position >= _tasks.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Повторение слов')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
          children: [
            if (done)
              _summary(context)
            else ...[
              Row(children: [
                Expanded(
                  child: Text('Задание ${_position + 1} из ${_tasks.length}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Text('${_plan.due} к повторению · ${_plan.words.length - _plan.due.clamp(0, 20)} новых',
                  style: const TextStyle(
                    fontSize: 11, color: DesignTokens.secondary,
                  )),
              ]),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: _tasks.isEmpty ? 0 : _position / _tasks.length,
                minHeight: 6,
                borderRadius: BorderRadius.circular(6),
                backgroundColor: DesignTokens.beige,
                color: DesignTokens.olive,
              ),
              if (_task.retry)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text('Закрепляем трудное слово',
                    style: TextStyle(color: DesignTokens.secondary,
                        fontWeight: FontWeight.w600)),
                ),
              const SizedBox(height: 22),
              _quiz(_task),
            ],
          ],
        ),
      ),
    );
  }
}
