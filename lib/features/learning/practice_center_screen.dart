import 'package:flutter/material.dart';

import '../../core/academy_state.dart';
import '../../core/app_strings.dart';
import '../../core/practice_generator.dart';
import '../../core/practice_feedback.dart';
import '../../core/speech.dart';
import '../../core/study_analytics.dart';
import '../../core/vocabulary_practice.dart';
import '../../ui/components.dart';
import '../../ui/design_tokens.dart';
import 'pronunciation_comparison_screen.dart';
import 'vocabulary_practice_screen.dart';
import 'words_hub_screen.dart';
import 'illustrated_dictionary_screen.dart';
import 'situations_screen.dart';
import 'handwriting_screen.dart';
import 'library_screens.dart' show GrammarScreen;

/// A single practice hub: no extra main navigation tabs or decorative noise.
class PracticeCenterScreen extends StatelessWidget {
  const PracticeCenterScreen({super.key, required this.state});
  final AcademyState state;

  static const _modes = <(PracticeMode, String, String, IconData)>[
    (PracticeMode.quiz, 'Викторина', 'Выберите точный перевод', Icons.quiz_outlined),
    (PracticeMode.illustrations, 'Слово и рисунок',
        'Предметы с проверенными иллюстрациями', Icons.image_outlined),
    (PracticeMode.sentence, 'Собери фразу',
        'Восстановите предложение', Icons.view_agenda_outlined),
    (PracticeMode.missingWord, 'Пропущенное слово',
        'Вспомните слово в контексте', Icons.edit_note_outlined),
    (PracticeMode.dictation, 'Аудиодиктант',
        'Слушайте и пишите по-арабски', Icons.headphones_outlined),
    (PracticeMode.dialogue, 'Диалог по ролям',
        'Выберите следующую реплику', Icons.forum_outlined),
    (PracticeMode.exam, 'Контрольная работа',
        'Проверка после раздела', Icons.assignment_turned_in_outlined),
    (PracticeMode.mistakes, 'Работа над ошибками',
        'Повторите трудные упражнения', Icons.replay_outlined),
  ];

  void _open(BuildContext context, PracticeMode mode, {String? moduleId}) {
    Navigator.push(context, MaterialPageRoute<void>(
      builder: (_) => PracticeSessionScreen(
        state: state, mode: mode, moduleId: moduleId,
      ),
    ));
  }

  /// Unit titles are localized in the bundled textbook catalog.
  static String moduleDisplayTitle(Map module, {bool arabic = false}) {
    final id = module['id']?.toString() ?? '';
    final number = RegExp(r'^u([0-9]+)$').firstMatch(id)?.group(1);
    final candidates = [
      arabic ? module['title_ar'] : module['title_ru'],
      arabic ? module['title_ru'] : module['title_ar'],
      module['title'], module['name'],
    ].whereType<String>().map((value) => value.trim())
        .where((value) => value.isNotEmpty &&
            !RegExp(r'^u[0-9]+$').hasMatch(value));
    final heading = arabic
        ? (number == null ? 'الوحدة' : 'الوحدة $number')
        : (number == null ? 'Учебный раздел' : 'Раздел $number');
    return candidates.isEmpty ? heading : '$heading · ${candidates.first}';
  }

  Future<void> _exam(BuildContext context) async {
    final modules = state.catalog['modules'];
    if (modules is! List || modules.isEmpty) {
      _open(context, PracticeMode.exam);
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: DesignTokens.cardSurface,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight:
              MediaQuery.sizeOf(sheet).height * .75),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            children: [
              Text('Контрольная по разделу',
                  style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: 7),
              const Text('Задания только из изучаемого раздела. '
                  'Вопросы выбираются из сохранённых учебных материалов.',
                  style: TextStyle(color: DesignTokens.secondary)),
              ListTile(
                title: const Text('Общая контрольная'),
                onTap: () => Navigator.pop(sheet, 'all'),
              ),
              for (final item in modules)
                if (item is Map && item['id'] is String)
                  ListTile(
                    title: Text(moduleDisplayTitle(item,
                      arabic: Localizations.localeOf(sheet).languageCode == 'ar')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(sheet, item['id'] as String),
                  ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || selected == null) return;
    _open(context, PracticeMode.exam,
      moduleId: selected == 'all' ? null : selected);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: state,
    builder: (context, _) {
      final plan = VocabularyPractice.plan(state);
      final analytics = StudyAnalytics(state);
      final now = DateTime.now().toLocal();
      final today = StudyAnalytics.dayKey(now);
      final reviewedToday = state.reviews.values.where((value) {
        if (value is! Map) return false;
        final d = DateTime.tryParse(value['last_review']?.toString() ?? '');
        return d != null && StudyAnalytics.dayKey(d.toLocal()) == today;
      }).length;
      final answeredToday = state.attempts.where((row) {
        final d = DateTime.tryParse(row['created_at']?.toString() ?? '');
        return d != null && StudyAnalytics.dayKey(d.toLocal()) == today &&
            (row['exercise_id']?.toString().startsWith('practice:') ?? false);
      }).length;
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 150),
        children: [
          Text(tr(context, 'Практика'), style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 5),
          const Text('Сначала вспомните материал, затем проверьте себя.',
            style: TextStyle(color: DesignTokens.secondary)),
          const SizedBox(height: 15),
          Panel(child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Icon(Icons.psychology_alt_outlined,
                  color: DesignTokens.deepOlive, size: 35),
                const SizedBox(width: 12),
                Expanded(child: Text(tr(context, 'Ежедневный план'),
                  style: Theme.of(context).textTheme.titleLarge)),
              ]),
              const SizedBox(height: 10),
              Text('Повторено сегодня: $reviewedToday · '
                  'Заданий выполнено: $answeredToday'),
              Text('К повторению: ${plan.due} · '
                  'Новых слов: ${plan.newWords}'),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const ValueKey('practice-daily'),
                onPressed: () => Navigator.push(context,
                  MaterialPageRoute<void>(
                    builder: (_) => VocabularyPracticeScreen(state: state),
                  )),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Начать повторение'),
              ),
              const SizedBox(height: 10),
              Text('Изучено слов: ${analytics.learnedWords} · '
                  'Трудных: ${analytics.difficultWords}',
                style: const TextStyle(
                  fontSize: 12, color: DesignTokens.secondary)),
            ],
          )),
          SectionTitle(tr(context, 'Тренировка навыков')),
          Panel(
            padding: EdgeInsets.zero,
            child: ListTile(
              key: const ValueKey('practice-words-unified'),
              leading: const Icon(Icons.collections_bookmark_outlined,
                color: DesignTokens.deepOlive, size: 30),
              title: Text(tr(context, 'Все слова в одном месте'),
                style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(tr(context, 'Слова с рисунками, проверка и повторение')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute<void>(
                builder: (_) => WordsHubScreen(state: state),
              )),
            ),
          ),
          const SizedBox(height: 10),
          Panel(
            padding: EdgeInsets.zero,
            child: ListTile(
              key: const ValueKey('practice-grammar-entry'),
              leading: const Icon(Icons.menu_book_outlined,
                  color: DesignTokens.deepOlive, size: 30),
              title: const Text('Грамматика',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text(
                'Правила, арабские примеры, таблицы и упражнения'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => GrammarScreen(state: state),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (final group in <
              (String, String, IconData, List<PracticeMode>)>[
            ('Слова', 'Викторина, рисунки и пропуски',
                Icons.style_outlined, [
                  PracticeMode.quiz, PracticeMode.illustrations,
                  PracticeMode.missingWord,
                ]),
            ('Письмо', 'Построение фраз и буквы',
                Icons.edit_note_outlined, [PracticeMode.sentence]),
            ('Слушаю и говорю', 'Диктант, реплики и произношение',
                Icons.headphones_outlined, [
                  PracticeMode.dictation, PracticeMode.dialogue,
                ]),
            ('Проверяю', 'Контрольная и мои ошибки',
                Icons.fact_check_outlined, [
                  PracticeMode.exam, PracticeMode.mistakes,
                ]),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                padding: EdgeInsets.zero,
                child: ExpansionTile(
                  key: ValueKey('practice-group-${group.$1}'),
                  initiallyExpanded: group.$1 == 'Слова',
                  tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                  leading: Icon(group.$3, color: DesignTokens.deepOlive),
                  title: Text(group.$1, style: const TextStyle(
                    fontWeight: FontWeight.w800)),
                  subtitle: Text(group.$2, maxLines: 2,
                    style: const TextStyle(fontSize: 12)),
                  children: [
                    for (final mode in group.$4)
                      if (_modes.any((m) => m.$1 == mode))
                        ListTile(
                          dense: true,
                          key: ValueKey('practice-mode-${mode.name}'),
                          contentPadding: const EdgeInsets.only(left: 20, right: 14),
                          title: Text(_modes.firstWhere((m) => m.$1 == mode).$2),
                          subtitle: Text(_modes.firstWhere((m) => m.$1 == mode).$3,
                            style: const TextStyle(fontSize: 11)),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: () => mode == PracticeMode.exam
                              ? _exam(context) : _open(context, mode),
                        ),
                    if (group.$1 == 'Письмо')
                      ListTile(
                        dense: true,
                        key: const ValueKey('handwriting-entry'),
                        title: const Text('Письмо пальцем'),
                        subtitle: const Text('Арабские буквы и формы'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(context, MaterialPageRoute<void>(
                          builder: (_) => HandwritingScreen(state: state),
                        )),
                      ),
                    if (group.$1 == 'Слушаю и говорю') ...[
                      ListTile(
                        dense: true,
                        key: const ValueKey('situation-practice-entry'),
                        title: const Text('Живые разговорные ситуации'),
                        subtitle: const Text('Реплики и контекстные ответы'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(context, MaterialPageRoute<void>(
                          builder: (_) => SituationsScreen(state: state),
                        )),
                      ),
                      ListTile(
                        dense: true,
                        title: const Text('Произношение'),
                        subtitle: const Text('Образец, запись и сравнение'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(context, MaterialPageRoute<void>(
                          builder: (_) => PronunciationComparisonScreen(state: state),
                        )),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class PracticeSessionScreen extends StatefulWidget {
  const PracticeSessionScreen({
    super.key, required this.state, required this.mode,
    this.moduleId, this.lessonId,
  });
  final AcademyState state;
  final PracticeMode mode;
  final String? moduleId;
  final String? lessonId;

  @override
  State<PracticeSessionScreen> createState() => _PracticeSessionScreenState();
}

class _PracticeSessionScreenState extends State<PracticeSessionScreen> {
  late final List<PracticeQuestion> _questions;
  final _text = TextEditingController();
  String? _selected;
  final List<int> _ordered = [];
  int _index = 0;
  int _successes = 0;
  int _incorrect = 0;
  bool _busy = false;
  bool _checked = false;
  bool _wasCorrect = false;
  bool _showHint = false;
  String _feedback = '';

  @override
  void initState() {
    super.initState();
    _questions = PracticeGenerator.build(
      widget.state, widget.mode,
      lessonId: widget.lessonId, moduleId: widget.moduleId,
      limit: widget.mode == PracticeMode.exam ? 12 : 10,
    );
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _finished => _index >= _questions.length;
  PracticeQuestion get _current => _questions[_index];

  Future<void> _speak(PracticeQuestion question) => guardedAction(context, () =>
      ArabicSpeech.speak(question.answer,
        speed: (widget.state.settings['audioSpeed'] as num? ?? 0.5)
            .toDouble().clamp(0.2, 0.8),
      ));

  String get _answer {
    final q = _current;
    if (q.usesOrder) {
      return _ordered.map((index) => q.tokens[index]).join(' ');
    }
    return q.usesChoices ? (_selected ?? '') : _text.text.trim();
  }

  bool get _canCheck {
    if (_current.usesOrder) return _ordered.length == _current.tokens.length;
    return _answer.trim().isNotEmpty;
  }

  Future<void> _submit({bool skip = false}) async {
    if (_busy || _checked || (!skip && !_canCheck)) return;
    final q = _current;
    final response = skip ? '' : _answer;
    final correct = !skip && !_showHint && (q.usesOrder
        ? List.generate(q.tokens.length, (i) => i)
            .asMap().entries.every((item) => _ordered[item.key] == item.value)
        : q.usesChoices
            ? response == q.answer
            : PracticeGenerator.matchesArabic(response, q.answer));
    setState(() => _busy = true);
    try {
      final message = PracticeFeedback.explain(
        q, response, correct: correct, revealed: skip || _showHint,
      );
      await widget.state.recordAttempt(
        lessonId: q.lessonId,
        exerciseId: q.id,
        answer: {
          'response': response,
          'expected': q.answer,
          'feedback': message,
          'source': q.lessonTitle,
          'mode': q.mode.name,
        },
        status: correct ? 'correct' : 'incorrect',
        points: correct ? 1 : 0,
      );
      if (!mounted) return;
      setState(() {
        _checked = true;
        _wasCorrect = correct;
        _feedback = message;
        if (correct) {
          _successes++;
        } else {
          _incorrect++;
        }
      });
    } catch (error) {
      if (mounted) notice(context, 'Не удалось сохранить ответ: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _next() async {
    if (!_checked || _busy) return;
    if (_index + 1 == _questions.length &&
        widget.mode == PracticeMode.exam) {
      setState(() => _busy = true);
      try {
        final passed = _successes * 100 >= _questions.length * 70;
        await widget.state.recordAttempt(
          lessonId: widget.moduleId ?? 'all',
          exerciseId: 'practice:exam:${widget.moduleId ?? 'all'}',
          answer: {
            'completed': _questions.length,
            'correct': _successes,
            'incorrect': _incorrect,
            'module_id': widget.moduleId,
          },
          status: passed ? 'correct' : 'incorrect',
          points: _successes,
        );
      } catch (error) {
        if (mounted) notice(context, 'Не удалось сохранить контрольную: $error');
        return;
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
    if (!mounted) return;
    setState(() {
      _index++;
      _selected = null;
      _ordered.clear();
      _text.clear();
      _showHint = false;
      _checked = false;
      _wasCorrect = false;
      _feedback = '';
    });
  }

  Widget _arabic(String value, {double size = 25}) => NaskhText(
    value, size: size, height: 1.7,
    align: TextAlign.center, color: DesignTokens.emerald,
  );

  Widget _illustration(String arabic) =>
      SemanticWordIllustration(arabic: arabic, size: 145);

  Widget _questionContent(PracticeQuestion q) {
    final enable = !_checked && !_busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(q.prompt, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (q.mode == PracticeMode.illustrations)
                _illustration(q.word)
              else if (q.mode == PracticeMode.dictation) ...[
                Center(child: IconButton.filledTonal(
                  key: const ValueKey('session-play-audio'),
                  tooltip: 'Прослушать оригинальную фразу',
                  icon: const Icon(Icons.volume_up_outlined, size: 38),
                  onPressed: () => _speak(q),
                )),
                const Text('Используется арабский голос устройства.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12,
                    color: DesignTokens.secondary)),
                if (_showHint || _checked) _arabic(q.answer, size: 22),
              ] else if (q.mode == PracticeMode.missingWord ||
                  q.mode == PracticeMode.dialogue)
                _arabic(q.reference)
              else if (q.mode == PracticeMode.sentence)
                Text(q.translation, textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge)
              else
                _arabic(q.reference),
              const SizedBox(height: 8),
              Text(q.lessonTitle, textAlign: TextAlign.center,
                style: const TextStyle(
                  color: DesignTokens.secondary, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (q.usesOrder) ...[
          const Text('Собранное предложение'),
          const SizedBox(height: 7),
          Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: DesignTokens.cardSurface,
              border: Border.all(color: DesignTokens.softOutline),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final i in _ordered)
                InputChip(
                  label: Text(q.tokens[i], textDirection: TextDirection.rtl),
                  onPressed: enable ? () =>
                      setState(() => _ordered.remove(i)) : null,
                ),
            ]),
          ),
          const SizedBox(height: 12),
          const Text('Нажмите на слова в исходном порядке'),
          const SizedBox(height: 8),
          Wrap(spacing: 7, runSpacing: 7, children: [
            for (var i = q.tokens.length - 1; i >= 0; i--)
              if (!_ordered.contains(i))
                ActionChip(
                  key: ValueKey('order-token-$i'),
                  label: Text(q.tokens[i],
                    textDirection: TextDirection.rtl),
                  onPressed: enable ? () =>
                      setState(() => _ordered.add(i)) : null,
                ),
          ]),
          const SizedBox(height: 7),
          TextButton(
            onPressed: !enable ? null : () => setState(_ordered.clear),
            child: const Text('Собрать заново'),
          ),
        ] else if (q.usesChoices) ...[
          for (final option in q.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: OutlinedButton(
                key: ValueKey('practice-answer-${q.options.indexOf(option)}'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: option == _selected
                      ? const Color(0xFFE5EAD7) : DesignTokens.cardSurface,
                  minimumSize: const Size.fromHeight(54),
                ),
                onPressed: enable ? () =>
                    setState(() => _selected = option) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: q.mode == PracticeMode.dialogue ||
                          q.mode == PracticeMode.illustrations
                      ? _arabic(option, size: 23)
                      : Text(option, textAlign: TextAlign.center),
                ),
              ),
            ),
        ] else
          TextField(
            controller: _text,
            enabled: enable,
            key: const ValueKey('practice-written-answer'),
            maxLines: q.mode == PracticeMode.dictation ? 3 : 2,
            maxLength: 280,
            textDirection: TextDirection.rtl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: q.mode == PracticeMode.dictation
                  ? 'Напишите услышанную фразу'
                  : 'Введите пропущенное слово',
              helperText: 'Огласовки необязательны. Буквы и хамза важны.',
            ),
          ),
        if (q.mode == PracticeMode.dictation && !_checked)
          TextButton(
            onPressed: () => setState(() => _showHint = true),
            child: const Text('Не слышно? Показать фразу для тренировки'),
          ),
        if (!_checked) ...[
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey('practice-submit-answer'),
            onPressed: !_canCheck || _busy ? null : _submit,
            icon: const Icon(Icons.check_circle_outline),
            label: Text(_busy ? 'Сохранение…' : 'Проверить ответ'),
          ),
          OutlinedButton(
            onPressed: _busy ? null : () => _submit(skip: true),
            child: const Text('Не знаю — показать ответ'),
          ),
        ] else ...[
          const SizedBox(height: 10),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Icon(_wasCorrect ? Icons.check_circle : Icons.refresh,
                    color: DesignTokens.deepOlive),
                  const SizedBox(width: 9),
                  Expanded(child: Text(_wasCorrect
                      ? 'Верно! Результат сохранён.'
                      : 'Нужно повторить. Ошибка сохранена.',
                    style: Theme.of(context).textTheme.titleMedium)),
                ]),
                const SizedBox(height: 12),
                _arabic(q.mode == PracticeMode.illustrations
                    ? q.word : q.answer),
                if (q.translation.isNotEmpty)
                  Text(q.translation, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(_feedback, style: const TextStyle(
                  color: DesignTokens.secondary,
                  fontSize: 13,
                )),
                if (!_wasCorrect)
                  const Text('Вы найдёте это задание в разделе ошибок.',
                    style: TextStyle(
                      fontSize: 12, color: DesignTokens.secondary)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _busy ? null : _next,
            key: const ValueKey('practice-next-question'),
            child: const Text('Далее'),
          ),
        ],
      ],
    );
  }

  Widget _result() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 34),
      const Icon(Icons.fact_check_outlined, size: 64,
          color: DesignTokens.deepOlive),
      const SizedBox(height: 14),
      Text(_questions.isEmpty ? 'Материала пока недостаточно' :
          'Проверка завершена', textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      Text(_questions.isEmpty
          ? 'В выбранном разделе пока нет проверенных заданий этого вида. '
            'Попробуйте другой режим или раздел.'
          : 'Всего: ${_questions.length} · Верно: $_successes · '
            'Ошибок: $_incorrect\n'
            'Результаты сохранены для журнала и анализа ошибок.',
        textAlign: TextAlign.center),
      const SizedBox(height: 18),
      if (_questions.isNotEmpty && widget.mode == PracticeMode.exam) ...[
        Panel(child: Column(children: [
          Text('Итог: ${(_successes * 100 / _questions.length).round()}%',
            style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(_successes * 100 >= _questions.length * 70
            ? 'Зачтено · результат сохранён'
            : 'Не зачтено · рекомендовано повторение'),
          const Text('Порог зачёта — 70%',
            style: TextStyle(fontSize: 12, color: DesignTokens.secondary)),
        ])),
        const SizedBox(height: 12),
      ],
      if (_questions.isNotEmpty && _incorrect > 0)
        FilledButton.icon(
          onPressed: () => Navigator.pushReplacement(context,
            MaterialPageRoute<void>(builder: (_) => PracticeSessionScreen(
              state: widget.state, mode: PracticeMode.mistakes,
              moduleId: widget.moduleId,
            ))),
          icon: const Icon(Icons.refresh),
          label: const Text('Повторить ошибки'),
        ),
      const SizedBox(height: 12),
      OutlinedButton(onPressed: () => Navigator.pop(context),
        child: const Text('В практику')),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.mode == PracticeMode.exam
        ? 'Контрольная работа' : 'Тренировка · ${_modeTitle(widget.mode)}')),
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    body: SafeArea(bottom: false,
      child: ListView(
        key: const PageStorageKey<String>('practice-session-scroll'),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 175),
        children: [
          if (_finished)
            _result()
          else ...[
            Row(children: [
              Expanded(child: Text('Вопрос ${_index + 1} из ${_questions.length}',
                style: const TextStyle(fontWeight: FontWeight.w700))),
              Text('Верно: $_successes',
                style: const TextStyle(color: DesignTokens.secondary)),
            ]),
            const SizedBox(height: 11),
            LinearProgressIndicator(
              value: _questions.isEmpty ? 0 : _index / _questions.length,
              minHeight: 6, borderRadius: BorderRadius.circular(8),
              color: DesignTokens.olive,
              backgroundColor: DesignTokens.beige,
            ),
            const SizedBox(height: 20),
            _questionContent(_current),
          ],
        ],
      ),
    ),
  );

  static String _modeTitle(PracticeMode mode) => switch (mode) {
    PracticeMode.quiz => 'Викторина',
    PracticeMode.illustrations => 'Слова с рисунками',
    PracticeMode.sentence => 'Собери предложение',
    PracticeMode.missingWord => 'Пропущенное слово',
    PracticeMode.dictation => 'Аудиодиктант',
    PracticeMode.dialogue => 'Диалог',
    PracticeMode.exam => 'Контрольная',
    PracticeMode.mistakes => 'Мои ошибки',
  };
}
