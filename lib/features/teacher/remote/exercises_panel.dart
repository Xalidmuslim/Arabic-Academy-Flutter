import 'package:flutter/material.dart';
import '../../../ui/components.dart' show Panel, NaskhText;
import '../../../services/backend_service.dart';
import 'school_api.dart';
import 'school_models.dart';
import 'school_widgets.dart';
import '../../../core/academy_state.dart';

class SchoolExercisesPanel extends StatefulWidget {
  const SchoolExercisesPanel({
    super.key,
    required this.api,
    required this.lessonId,
  });
  final RemoteSchoolApi api;
  final String lessonId;
  @override
  State<SchoolExercisesPanel> createState() => _ExercisesPanelState();
}

class _ExercisesPanelState extends State<SchoolExercisesPanel>
    with SchoolActions<SchoolExercisesPanel> {
  Future<List<Map<String, dynamic>>>? _future;
  Future<void> _edit(Map<String, dynamic>? row) async {
    final draft = row == null
        ? SchoolExerciseDraft.create(widget.lessonId)
        : await widget.api.exercise(row);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SchoolExerciseEditor(api: widget.api, draft: draft),
      ),
    );
    if (mounted) setState(() => _future = null);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Упражнения урока', style: Theme.of(context).textTheme.titleLarge),
      status,
      OutlinedButton(
        onPressed: busy ? null : () => run(() => _edit(null)),
        child: const Text('Создать упражнение'),
      ),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _future ??= widget.api.exercises(widget.lessonId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return schoolErrorCard(
              snapshot.error!,
              () => setState(() => _future = null),
            );
          }
          if (!snapshot.hasData) return const LinearProgressIndicator();
          return Column(
            children: [
              for (final row in snapshot.data!)
                ListTile(
                  title: Text(row['title'].toString()),
                  subtitle: Text(
                    '${row['kind']} · версия ${row['version']} · ${row['published'] == true ? 'опубликовано' : 'черновик'}',
                  ),
                  onTap: busy ? null : () => run(() => _edit(row)),
                ),
              if (snapshot.data!.isEmpty) const Text('Упражнений нет.'),
            ],
          );
        },
      ),
    ],
  );
}

class SchoolExerciseEditor extends StatefulWidget {
  const SchoolExerciseEditor({
    super.key,
    required this.api,
    required this.draft,
  });
  final RemoteSchoolApi api;
  final SchoolExerciseDraft draft;
  @override
  State<SchoolExerciseEditor> createState() => _ExerciseEditorState();
}

class _ExerciseEditorState extends State<SchoolExerciseEditor>
    with SchoolActions<SchoolExerciseEditor> {
  bool _dirty = false, _allowExit = false;
  Future<void> _question(int? index) async {
    final draft = widget.draft;
    final source = index == null
        ? <String, dynamic>{
            'id': AcademyState.newId(),
            'prompt': <String, dynamic>{},
            'points': 1,
            'options': <Map<String, dynamic>>[],
          }
        : copySchoolMap(draft.questions[index]);
    final prompt = Map<String, dynamic>.from(source['prompt'] as Map);
    final values = await showSchoolForm(
      context,
      'Вопрос',
      [
        const SchoolField(
          'text_ar',
          'Вопрос на арабском',
          arabic: true,
          multiline: true,
        ),
        const SchoolField(
          'translation',
          'Вопрос / инструкция на русском',
          multiline: true,
        ),
        const SchoolField('points', 'Баллы', required: true),
      ],
      initial: {
        'text_ar': prompt['text_ar'] ?? '',
        'translation': prompt['translation'] ?? prompt['text'] ?? '',
        'points': source['points'],
      },
    );
    if (values == null || !mounted) return;
    if (values['text_ar'].toString().trim().isEmpty &&
        values['translation'].toString().trim().isEmpty) {
      throw const IntegrationException(
        'Введите текст вопроса хотя бы на одном языке.',
      );
    }
    final points = num.tryParse(values['points'].toString());
    if (points == null || !points.isFinite || points <= 0) {
      throw const IntegrationException(
        'Баллы должны быть положительным числом.',
      );
    }
    final row = {
      ...source,
      'prompt': {
        ...prompt,
        'text_ar': values['text_ar'],
        'translation': values['translation'],
      },
      'points': points,
    };
    setState(() => _dirty = true);
    if (index == null) {
      draft.questions.add(row);
    } else {
      draft.questions[index] = row;
    }
  }

  Future<void> _option(Map<String, dynamic> question, int? index) async {
    final options = question['options'] as List;
    final old = index == null
        ? <String, dynamic>{'id': AcademyState.newId()}
        : copySchoolMap(options[index] as Map);
    final values = await showSchoolForm(context, 'Вариант ответа', [
      const SchoolField(
        'label',
        'Текст варианта',
        arabic: true,
        required: true,
        multiline: true,
      ),
    ], initial: old);
    if (values == null || !mounted) return;
    setState(() {
      _dirty = true;
      final row = {...old, ...values};
      if (index == null) {
        options.add(row);
      } else {
        options[index] = row;
      }
    });
  }

  Future<void> _textAnswers(Map<String, dynamic> question) async {
    final values = await showSchoolForm(
      context,
      'Допустимые текстовые ответы',
      [
        const SchoolField(
          'answers',
          'Один допустимый ответ на строку (диакритика сохраняется)',
          arabic: true,
          multiline: true,
          required: true,
        ),
      ],
      initial: {
        'answers': (question['accepted_answers'] as List? ?? [])
            .whereType<String>()
            .join('\n'),
      },
    );
    if (values == null || !mounted) return;
    setState(() {
      _dirty = true;
      question['accepted_answers'] = values['answers']
          .toString()
          .split('\n')
          .where((s) => s.trim().isNotEmpty)
          .toList();
      question['comparison'] = 'exact';
    });
  }

  void _choice(Map<String, dynamic> question, String optionId, bool selected) {
    final multiple = widget.draft.exercise['kind'] == 'multipleChoice';
    setState(() {
      _dirty = true;
      if (multiple) {
        final old = question['accepted_answers'];
        final chosen = old is List && old.isNotEmpty && old.first is List
            ? List<String>.from(old.first as List)
            : <String>[];
        if (selected) {
          if (!chosen.contains(optionId)) chosen.add(optionId);
        } else {
          chosen.remove(optionId);
        }
        // Arrays are complete accepted answers; order is server-significant.
        final ordered = schoolMaps(
          question['options'],
        ).map((o) => o['id'] as String).where(chosen.contains).toList();
        question['accepted_answers'] = [ordered];
      } else {
        question['accepted_answers'] = selected ? [optionId] : <String>[];
      }
      question['comparison'] = 'exact';
    });
  }

  Future<void> _remove(List rows, int index) async {
    if (await confirmSchoolAction(
          context,
          'Удалить из упражнения?',
          'После сохранения сервер заменит вопросы и закрытые ответы новой версией.',
        ) &&
        mounted) {
      setState(() {
        _dirty = true;
        rows.removeAt(index);
      });
    }
  }

  Future<void> _save() async {
    final draft = widget.draft;
    final params = draft.saveParams();
    if (draft.exercise['published'] == true &&
        !await confirmSchoolAction(
          context,
          'Сохранить опубликованное упражнение?',
          'Сервер сохранит новую версию и заданные ответы. Предыдущие попытки сохранятся, но не заменят прохождение новой версии.',
        )) {
      return;
    }
    final saved = await widget.api.rpc('save_exercise', params);
    if (saved is! Map ||
        saved['id'] != draft.exercise['id'] ||
        saved['version'] is! int ||
        (saved['version'] as int) <= (draft.exercise['version'] as int)) {
      throw const IntegrationException(
        'Сервер не подтвердил сохранение упражнения. Черновик оставлен на экране.',
      );
    }
    if (mounted) {
      setState(() {
        draft.exercise.addAll(Map<String, dynamic>.from(saved));
        _dirty = false;
        draft.replaceKeys = false;
      });
    }
  }

  Widget _questionCard(Map<String, dynamic> question, int index) {
    final draft = widget.draft;
    final choice = const {
      'singleChoice',
      'multipleChoice',
    }.contains(draft.exercise['kind']);
    final answers = question['accepted_answers'];
    final chosen = answers is List && answers.isNotEmpty
        ? (answers.first is List
              ? List<dynamic>.from(answers.first as List)
              : answers)
        : [];
    final options = schoolMaps(question['options'] ?? []);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Вопрос ${index + 1} · ${question['points']} балл.'),
            schoolBodyPreview(question['prompt']),
            Wrap(
              children: [
                TextButton(
                  onPressed: busy ? null : () => run(() => _question(index)),
                  child: const Text('Изменить вопрос'),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => run(() => _remove(draft.questions, index)),
                  child: const Text('Удалить вопрос'),
                ),
              ],
            ),
            if (choice) ...[
              for (var i = 0; i < options.length; i++)
                Column(
                  children: [
                    CheckboxListTile(
                      value: chosen.contains(options[i]['id']),
                      onChanged:
                          busy || draft.exercise['grading_mode'] != 'automatic'
                          ? null
                          : (value) => _choice(
                              question,
                              options[i]['id'] as String,
                              value == true,
                            ),
                      title:
                          RegExp(
                            r'[\u0600-\u06ff]',
                          ).hasMatch(options[i]['label'].toString())
                          ? NaskhText(options[i]['label'].toString())
                          : Text(options[i]['label'].toString()),
                      subtitle: const Text(
                        'Отметка задаёт новый правильный ответ',
                      ),
                    ),
                    Wrap(
                      children: [
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => run(() => _option(question, i)),
                          child: const Text('Изменить вариант'),
                        ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => run(
                                  () => _remove(question['options'] as List, i),
                                ),
                          child: const Text('Удалить вариант'),
                        ),
                      ],
                    ),
                  ],
                ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => run(() => _option(question, null)),
                child: const Text('Добавить вариант'),
              ),
            ],
            if (draft.exercise['kind'] == 'shortAnswer') ...[
              Text(
                'Новые допустимые ответы: ${(question['accepted_answers'] as List? ?? []).join(' / ')}',
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => run(() => _textAnswers(question)),
                child: const Text('Задать текстовые ответы'),
              ),
              SwitchListTile(
                value: question['comparison'] == 'text_trim',
                onChanged: busy
                    ? null
                    : (value) => setState(() {
                        _dirty = true;
                        question['comparison'] = value ? 'text_trim' : 'exact';
                      }),
                title: const Text('Игнорировать только пробелы по краям'),
                subtitle: const Text(
                  'Харакаты и остальные символы сравниваются точно.',
                ),
              ),
            ],
            if (draft.exercise['grading_mode'] == 'manual')
              const Text(
                'Ответ проверяет преподаватель; ключ автоматической проверки не отправляется.',
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return PopScope(
      canPop: _allowExit || (!_dirty && !busy),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || busy) return;
        if (await confirmSchoolAction(
              context,
              'Выйти без сохранения?',
              'Черновик упражнения будет закрыт.',
            ) &&
            mounted) {
          setState(() => _allowExit = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Конструктор упражнения')),
        body: SchoolAccess(
          api: widget.api,
          builder: (_) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              status,
              if (draft.compatibilityError != null)
                Text(draft.compatibilityError!),
              TextFormField(
                initialValue: draft.exercise['title'].toString(),
                enabled: !busy && draft.compatibilityError == null,
                decoration: const InputDecoration(
                  labelText: 'Название упражнения',
                ),
                onChanged: (value) => setState(() {
                  _dirty = true;
                  draft.exercise['title'] = value;
                }),
              ),
              if (draft.compatibilityError == null)
                DropdownButtonFormField<String>(
                  initialValue: draft.exercise['kind'] as String,
                  decoration: const InputDecoration(labelText: 'Тип задания'),
                  items: SchoolExerciseDraft.kinds.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: busy
                      ? null
                      : (value) => setState(() {
                          _dirty = true;
                          draft.exercise['kind'] = value;
                          draft.exercise['grading_mode'] = value == 'writing'
                              ? 'manual'
                              : 'automatic';
                          for (final q in draft.questions) {
                            q.remove('accepted_answers');
                            q.remove('comparison');
                          }
                        }),
                ),
              TextFormField(
                initialValue: draft.exercise['pass_percent'].toString(),
                enabled: !busy && draft.compatibilityError == null,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Проходной процент',
                ),
                onChanged: (value) => setState(() {
                  _dirty = true;
                  draft.exercise['pass_percent'] = value;
                }),
              ),
              SwitchListTile(
                value: draft.exercise['published'] == true,
                onChanged: busy || draft.compatibilityError != null
                    ? null
                    : (value) => setState(() {
                        _dirty = true;
                        draft.exercise['published'] = value;
                      }),
                title: const Text('Опубликовать после сохранения'),
              ),
              if (draft.existing &&
                  draft.exercise['grading_mode'] == 'automatic')
                CheckboxListTile(
                  value: draft.replaceKeys,
                  onChanged: busy
                      ? null
                      : (value) =>
                            setState(() => draft.replaceKeys = value == true),
                  title: const Text('Подтверждаю замену всех закрытых ответов'),
                  subtitle: const Text(
                    'Сервер не отдаёт прежние ключи. Укажите новые ответы для каждого вопроса.',
                  ),
                ),
              if (draft.compatibilityError == null) ...[
                for (var i = 0; i < draft.questions.length; i++)
                  _questionCard(draft.questions[i], i),
                OutlinedButton(
                  onPressed: busy ? null : () => run(() => _question(null)),
                  child: const Text('Добавить вопрос'),
                ),
                FilledButton(
                  onPressed: busy ? null : () => run(_save),
                  child: const Text('Сохранить упражнение'),
                ),
              ] else
                for (final question in draft.questions)
                  schoolBodyPreview(question['prompt']),
            ],
          ),
        ),
      ),
    );
  }
}
