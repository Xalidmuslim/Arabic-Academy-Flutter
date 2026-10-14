import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/academy_state.dart';
import '../../core/vocabulary_key.dart';
import '../../core/speech.dart';
import '../../services/backend_service.dart';
import '../../ui/components.dart';
import '../../ui/design_tokens.dart';
import '../../ui/premium_art.dart';
import '../exercises/exercises.dart';
import '../integrations/oral_practice_screen.dart';
import '../teacher/teacher_editor.dart' show ExtraLessonScreen;
import 'textbook_reader_screen.dart';

class LessonScreen extends StatefulWidget {
  const LessonScreen({
    super.key,
    required this.state,
    required this.lesson,
    this.initialTab = 0,
    this.backend,
  });
  final AcademyState state;
  final Map<String, dynamic> lesson;
  final int initialTab;
  final BackendService? backend;
  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen>
    with WidgetsBindingObserver {
  static const stages = [
    'Введение',
    'Лексика',
    'Диалог',
    'Грамматика',
    'Практика',
    'Проверка',
  ];
  late int _stage;
  late final List<Exercise> _exercises;
  final Map<String, ExerciseResult> _results = {};
  final Map<String, dynamic> _pendingDrafts = {};
  final Stopwatch _study = Stopwatch();
  Timer? _draftTimer;
  int _exerciseIndex = 0;
  int _round = 0;
  bool _finished = false;
  bool _showTranslation = true;
  late final TextEditingController _homework;
  late final TextEditingController _note;
  String get id => widget.lesson['id'] as String;
  List get _words => widget.lesson['vocabulary'] as List? ?? [];
  List get _dialogue => widget.lesson['dialogue'] as List? ?? [];

  @override
  void initState() {
    super.initState();
    _stage = widget.initialTab.clamp(0, 5);
    WidgetsBinding.instance.addObserver(this);
    _study.start();
    _exercises = [
      if (widget.lesson['options'] is List && widget.lesson['correct'] is int)
        Exercise.fromJson({
          ...widget.lesson,
          'id': '$id-check',
          'kind': 'singleChoice',
          'prompt': widget.lesson['question'],
          'explanation': widget.lesson['grammar'],
          'config': {'maxAttempts': 3, 'randomizeOptions': false, 'points': 1},
        }),
      ...((widget.lesson['exercises'] as List?) ?? []).map(
        (x) => Exercise.fromJson(Map<String, dynamic>.from(x as Map)),
      ),
    ];
    final saved = widget.state.drafts['homework:$id'] as Map?;
    _homework = TextEditingController(text: saved?['text'] as String? ?? '');
    _note = TextEditingController(text: widget.state.note(id));
    unawaited(widget.state.visitLesson(id));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _study.start();
    } else {
      _study.stop();
      unawaited(_flushDrafts());
      unawaited(ArabicSpeech.stop().catchError((Object _) {}));
    }
  }

  void _draft(String key, dynamic value) {
    _pendingDrafts[key] = value;
    _draftTimer?.cancel();
    _draftTimer = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_flushDrafts()),
    );
  }

  Future<void> _flushDrafts() async {
    final updates = Map<String, dynamic>.from(_pendingDrafts);
    _pendingDrafts.clear();
    for (final entry in updates.entries) {
      await widget.state.saveDraft(entry.key, {
        'answer': entry.value,
        if (entry.key.startsWith('homework:')) 'text': entry.value,
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftTimer?.cancel();
    unawaited(_flushDrafts());
    unawaited(widget.state.recordStudy(id, _study.elapsed.inSeconds));
    unawaited(ArabicSpeech.stop().catchError((Object _) {}));
    _homework.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _speak(String text) => guardedAction(
    context,
    () => ArabicSpeech.speak(
      text,
      speed: (widget.state.settings['audioSpeed'] as num? ?? 0.50).toDouble(),
      engine: widget.state.settings['audioEngine'] as String?,
      voiceName: widget.state.settings['audioVoiceName'] as String?,
      voiceLocale: widget.state.settings['audioVoiceLocale'] as String?,
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.lesson['title'] as String? ?? 'Урок',
        maxLines: 2,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      actions: [
        AnimatedBuilder(
          animation: widget.state,
          builder: (context, _) => IconButton(
            tooltip: 'Закладка урока',
            icon: Icon(
              widget.state.bookmarks.contains('lesson:$id')
                  ? Icons.bookmark
                  : Icons.bookmark_border,
            ),
            onPressed: () => guardedAction(
              context,
              () => widget.state.toggleBookmark('lesson:$id'),
            ),
          ),
        ),
      ],
    ),
    body: ArtworkBackdrop(
      child: Column(
        children: [
          LinearProgressIndicator(
            value: (_stage + 1) / stages.length,
            minHeight: 4,
            color: DesignTokens.olive,
            backgroundColor: DesignTokens.beige,
          ),
          SizedBox(
            height: MediaQuery.textScalerOf(context).scale(58).clamp(58, 100),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: List.generate(
                  stages.length,
                  (i) => Padding(
                    padding: const EdgeInsetsDirectional.only(end: 7),
                    child: ActionChip(
                      avatar: CircleAvatar(
                        radius: 12,
                        backgroundColor: i == _stage
                            ? DesignTokens.olive
                            : DesignTokens.beige,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            color: i == _stage ? Colors.white : green,
                          ),
                        ),
                      ),
                      label: Text(stages[i]),
                      backgroundColor: i == _stage
                          ? const Color(0xFFE3E8D5)
                          : cream,
                      onPressed: () => setState(() {
                        _stage = i;
                        _exerciseIndex = 0;
                        _finished = false;
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: Duration(
                milliseconds: widget.state.settings['reduceMotion'] == true
                    ? 0
                    : 150,
              ),
              child: _stage >= 4 ? _practice() : _reading(),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _reading() => ListView(
    key: ValueKey(_stage),
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 142),
    children: [
      if (_stage == 0) ...[
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(
                'assets/artwork/${widget.lesson['grammar_topic'] == null ? 'teacher' : 'grammar'}.webp',
                height: 175,
                fit: BoxFit.contain,
                cacheWidth: 600,
                excludeFromSemantics: true,
              ),
              Text(
                widget.lesson['title'] as String? ?? '',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              NaskhText(
                widget.lesson['title_ar'] as String? ?? '',
                size: _arabicSize,
              ),
              const SizedBox(height: 8),
              Text(widget.lesson['goal'] as String? ?? ''),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => setState(() => _stage = 1),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Начать урок'),
              ),
            ],
          ),
        ),
        if ((widget.lesson['video'] as String?)?.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.ondemand_video),
              label: const Text('Открыть видеоматериал'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ExtraLessonScreen(data: widget.lesson),
                ),
              ),
            ),
          ),
        const SectionTitle('Цель обучения'),
        Panel(
          child: Text(
            widget.lesson['goal'] as String? ??
                'Изучите материал и выполните задания.',
          ),
        ),
        const SectionTitle('Личные заметки'),
        TextField(
          controller: _note,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'Ваши заметки сохраняются на устройстве',
          ),
          onChanged: (text) => unawaited(widget.state.saveNote(id, text)),
        ),
        const SizedBox(height: 10),
        Text(
          widget.lesson['source'] == 'original_editorial'
              ? 'Авторский материал. Не является страницей издательского учебника.'
              : 'Сохранённый учебный материал.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ] else if (_stage == 1) ...[
        const SectionTitle('Новые слова'),
        if (_words.isEmpty)
          const EmptyState(
            title: 'Словарь урока пуст',
            message: 'В этом материале слова ещё не добавлены.',
          ),
        ..._words.asMap().entries.map((entry) {
          final word = entry.value as Map;
          final key = vocabularyKey(id, entry.key, entry.value as Map);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NaskhText(word['ar'] as String? ?? '', size: _arabicSize),
                  Text(word['ru'] as String? ?? ''),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Синтез речи устройства',
                        icon: const Icon(Icons.volume_up_outlined),
                        onPressed: () => _speak(word['ar'] as String? ?? ''),
                      ),
                      AnimatedBuilder(
                        animation: widget.state,
                        builder: (context, _) => IconButton(
                          tooltip: 'Избранное слово',
                          icon: Icon(
                            widget.state.bookmarks.contains(key)
                                ? Icons.favorite
                                : Icons.favorite_border,
                          ),
                          onPressed: () => guardedAction(
                            context,
                            () => widget.state.toggleBookmark(key),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ] else if (_stage == 2) ...[
        Row(
          children: [
            Expanded(
              child: Text(
                'Диалог',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Перевод',
              onPressed: () =>
                  setState(() => _showTranslation = !_showTranslation),
              icon: Icon(
                _showTranslation ? Icons.translate : Icons.translate_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.lesson['pdf_page'] is int)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton.icon(
              key: const ValueKey('open-original-pdf-page'),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(
                'Учебник · Часть ${widget.lesson['pdf_part'] == 2 ? 2 : 1} · страница ${(widget.lesson['pdf_page'] as int) + 1}',
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TextbookReaderScreen(
                    part: widget.lesson['pdf_part'] == 2 ? 2 : 1,
                    initialPage: widget.lesson['pdf_page'] as int,
                  ),
                ),
              ),
            ),
          ),
        if (widget.lesson['pdf_page'] is int)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Диалог в приложении авторский. По кнопке — соответствующая '
              'страница оригинального учебника для самостоятельной сверки.',
              style: TextStyle(fontSize: 12.5),
            ),
          ),
        if (_dialogue.isEmpty)
          const EmptyState(
            title: 'Диалог не добавлен',
            message: 'Продолжите изучение других блоков.',
          ),
        ..._dialogue.map((raw) {
          final line = raw as Map;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NaskhText(line['ar'] as String? ?? '', size: _arabicSize),
                  if (_showTranslation) Text(line['ru'] as String? ?? ''),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: IconButton(
                      tooltip: 'Повторить реплику: синтез речи',
                      icon: const Icon(Icons.volume_up_outlined),
                      onPressed: () => _speak(line['ar'] as String? ?? ''),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        if (_dialogue.isNotEmpty)
          OutlinedButton.icon(
            icon: const Icon(Icons.headphones),
            onPressed: () =>
                _speak(_dialogue.map((x) => (x as Map)['ar']).join(' ')),
            label: const Text('Прослушать: синтез речи'),
          ),
      ] else if (_stage == 3) ...[
        const SectionTitle('Объяснение грамматики'),
        Panel(
          child: Text(
            widget.lesson['grammar'] as String? ?? 'Объяснение не добавлено.',
            style: const TextStyle(fontSize: 16, height: 1.6),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => setState(() => _stage = 4),
          child: const Text('Перейти к практике'),
        ),
      ],
      if (_stage < 3) ...[
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.arrow_forward),
          onPressed: () => setState(() => _stage++),
          label: const Text('Далее'),
        ),
      ],
    ],
  );

  double get _arabicSize =>
      (widget.state.settings['arabicSize'] as num? ?? 28).toDouble();

  Widget _practice() {
    final exercises = _stage == 5
        ? _exercises
              .where(
                (x) => ![
                  ExerciseKind.writing,
                  ExerciseKind.speaking,
                  ExerciseKind.pronunciation,
                  ExerciseKind.dialogue,
                  ExerciseKind.unknown,
                ].contains(x.kind),
              )
              .toList()
        : _exercises;
    if (exercises.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 142),
        children: [
          const EmptyState(
            title: 'Автоматическая проверка не задана',
            message:
                'Этот материал можно изучить и отправить письменный ответ на ручную проверку.',
          ),
          _homeworkBlock(),
        ],
      );
    }
    _exerciseIndex = _exerciseIndex.clamp(0, exercises.length - 1);
    final current = exercises[_exerciseIndex];
    final draftKey = '$id:${current.id}';
    final correctCount = exercises
        .where((x) => _results[x.id]?.passed == true)
        .length;
    final score = (correctCount / exercises.length * 100).round();
    return ListView(
      key: ValueKey('practice-$_stage'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 142),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _stage == 5 ? 'Итоговая проверка' : 'Практика',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Text('${_exerciseIndex + 1}/${exercises.length}'),
          ],
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: correctCount / exercises.length,
          color: DesignTokens.olive,
          backgroundColor: DesignTokens.beige,
          minHeight: 6,
        ),
        const SizedBox(height: 14),
        Panel(
          padding: EdgeInsets.zero,
          child: ExerciseRunner(
            key: ValueKey('${current.id}:$_stage:$_round'),
            exercise: current,
            initialAnswer: (widget.state.drafts[draftKey] as Map?)?['answer'],
            onDraft: (answer) => _draft(draftKey, answer),
            onAttempt: (result, answer) => unawaited(
              widget.state.recordAttempt(
                lessonId: id,
                exerciseId: current.id,
                answer: answer,
                status: result.status.name,
                points: result.points,
              ),
            ),
            onCompleted: (result, answer) => setState(() {
              _results[current.id] = result;
              _finished = true;
            }),
          ),
        ),
        if (_finished) ...[
          const SizedBox(height: 12),
          if (_exerciseIndex + 1 < exercises.length)
            FilledButton(
              onPressed: () => setState(() {
                _exerciseIndex++;
                _finished = false;
              }),
              child: const Text('Следующее задание'),
            ),
          OutlinedButton(
            onPressed: () => setState(() {
              _round++;
              _finished = false;
            }),
            child: const Text('Повторить упражнение'),
          ),
        ],
        if (_stage == 4) ...[
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => setState(() {
              _stage = 5;
              _exerciseIndex = 0;
              _finished = false;
              _results.clear();
            }),
            child: const Text('Перейти к проверке'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OralPracticeScreen(backend: widget.backend),
              ),
            ),
            icon: const Icon(Icons.mic_none),
            label: const Text('Записать устный ответ'),
          ),
        ],
        if (_stage == 5) ...[
          const SizedBox(height: 16),
          Text('Результат: $score% · $correctCount из ${exercises.length}'),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: correctCount == exercises.length
                ? () => guardedAction(context, () async {
                    await widget.state.finish(id);
                    if (mounted) {
                      notice(context, 'Результат сохранён. Урок завершён.');
                    }
                  })
                : null,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Завершить урок'),
          ),
          _homeworkBlock(),
        ],
      ],
    );
  }

  Widget _homeworkBlock() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionTitle('Домашнее задание'),
      Panel(
        child: Text(
          widget.lesson['homework'] as String? ?? 'Добавьте собственный ответ.',
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _homework,
        minLines: 3,
        maxLines: 8,
        decoration: const InputDecoration(labelText: 'Ваш ответ'),
        onChanged: (value) => _draft('homework:$id', value),
      ),
      const SizedBox(height: 10),
      FilledButton.icon(
        icon: const Icon(Icons.save_outlined),
        label: const Text('Сохранить работу'),
        onPressed: () => guardedAction(context, () async {
          await widget.state.submitHomework(id, _homework.text);
          if (mounted) {
            notice(
              context,
              'Работа сохранена локально. В демо её можно проверить в кабинете учительницы.',
            );
          }
        }),
      ),
    ],
  );
}
