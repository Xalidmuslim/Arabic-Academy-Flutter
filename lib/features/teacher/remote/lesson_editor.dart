import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../ui/components.dart' show Panel, NaskhText;
import '../../../services/backend_service.dart';
import 'school_api.dart';
import 'school_models.dart';
import 'school_widgets.dart';
import '../../../core/academy_state.dart';
import '../../integrations/media_upload_screen.dart';
import 'exercises_panel.dart';

class SchoolLessonEditor extends StatefulWidget {
  const SchoolLessonEditor({super.key, required this.api, required this.id});
  final RemoteSchoolApi api;
  final String id;
  @override
  State<SchoolLessonEditor> createState() => _LessonEditorState();
}

class _LessonEditorState extends State<SchoolLessonEditor>
    with SchoolActions<SchoolLessonEditor> {
  Future<SchoolLessonDraft>? _future;
  SchoolLessonDraft? _draft;
  bool _allowExit = false;
  static const steps = {
    'introduction': 'Введение',
    'dialogue': 'Диалог',
    'vocabulary': 'Словарь',
    'grammar': 'Грамматика',
    'practice': 'Практика',
    'test': 'Тест',
    'homework': 'Домашнее задание',
  };
  static const kinds = {
    'text': 'Текст',
    'heading': 'Заголовок',
    'image': 'Изображение',
    'audio': 'Аудио',
    'video': 'Видео',
    'exercise': 'Упражнение',
  };
  Future<void> _save(SchoolLessonDraft draft, {String? status}) async {
    if (status != null &&
        !await confirmSchoolAction(
          context,
          'Изменить статус урока?',
          'Будут сохранены все изменения. Новый статус: ${schoolStatusLabel(status)}. Публикация открывает урок по правилам доступа курса.',
        )) {
      return;
    }
    final saved = await widget.api.rpc(
      'save_lesson',
      draft.saveParams(status: status),
    );
    if (saved is! Map ||
        saved['id'] != draft.lesson['id'] ||
        saved['version'] is! int ||
        (saved['version'] as int) <= (draft.lesson['version'] as int)) {
      throw const IntegrationException(
        'Сервер не подтвердил новую версию. Черновик оставлен на экране; проверьте серверную запись.',
      );
    }
    if (mounted) setState(() => draft.accept(Map<String, dynamic>.from(saved)));
  }

  Future<void> _reload() async {
    if (_draft?.dirty == true &&
        !await confirmSchoolAction(
          context,
          'Загрузить новую версию?',
          'Несохранённые изменения на экране будут заменены серверной версией. Можно сначала скопировать черновик из предпросмотра.',
        )) {
      return;
    }
    if (mounted) {
      setState(() {
        _draft = null;
        _future = null;
        error = null;
      });
    }
  }

  Future<void> _editRow(
    SchoolLessonDraft draft,
    String section,
    int? index,
  ) async {
    final existing = index == null
        ? <String, dynamic>{
            'id': AcademyState.newId(),
            'position': draft.rows(section).length,
          }
        : copySchoolMap(draft.rows(section)[index]);
    List<SchoolField> fields;
    var initial = <String, dynamic>{...existing};
    if (section == 'blocks') {
      final body = Map<String, dynamic>.from(existing['body'] as Map? ?? {});
      fields = [
        const SchoolField('step', 'Шаг урока', choices: steps),
        const SchoolField('kind', 'Тип блока', choices: kinds),
        const SchoolField(
          'text_ar',
          'Арабский текст',
          arabic: true,
          multiline: true,
        ),
        const SchoolField('translation', 'Русский текст', multiline: true),
        const SchoolField(
          'body_json',
          'Дополнительные поля блока (JSON)',
          multiline: true,
        ),
      ];
      initial = {
        ...initial,
        'step': existing['step'] ?? 'dialogue',
        'kind': existing['kind'] ?? 'text',
        'text_ar': body['text_ar'] ?? '',
        'translation':
            body['translation'] ?? body['text_ru'] ?? body['text'] ?? '',
        'body_json': const JsonEncoder.withIndent('  ').convert(body),
      };
    } else if (section == 'dialogues') {
      fields = [const SchoolField('title', 'Название диалога', required: true)];
    } else if (section == 'vocabulary') {
      fields = [
        const SchoolField(
          'text_ar',
          'Арабское слово',
          arabic: true,
          required: true,
        ),
        const SchoolField('translation', 'Перевод', required: true),
        const SchoolField('transliteration', 'Транслитерация'),
      ];
    } else {
      fields = [
        const SchoolField('title', 'Название правила', required: true),
        const SchoolField(
          'explanation',
          'Объяснение на русском',
          multiline: true,
          required: true,
        ),
      ];
    }
    if (section == 'vocabulary' || section == 'grammar') {
      fields.addAll(const [
        SchoolField('root', 'Корень слова', arabic: true),
        SchoolField('part_of_speech', 'Часть речи'),
        SchoolField('gender', 'Род'),
        SchoolField('number', 'Число'),
        SchoolField('level', 'Уровень (редакторская метка)'),
        SchoolField(
          'example_ar',
          'Арабский пример',
          arabic: true,
          multiline: true,
        ),
        SchoolField('example_translation', 'Перевод примера', multiline: true),
        SchoolField(
          'forms_json',
          'Формы слова (JSON объекта/массива)',
          multiline: true,
        ),
      ]);
      initial['forms_json'] = existing['forms'] == null
          ? ''
          : const JsonEncoder.withIndent('  ').convert(existing['forms']);
    }
    final result = await showSchoolForm(
      context,
      index == null ? 'Добавить материал' : 'Редактировать материал',
      fields,
      initial: initial,
    );
    if (result == null || !mounted) return;
    if (section == 'vocabulary' || section == 'grammar') {
      final raw = result.remove('forms_json').toString().trim();
      final forms = raw.isEmpty ? null : jsonDecode(raw);
      if (forms != null && forms is! Map && forms is! List) {
        throw const IntegrationException(
          'Формы должны быть JSON-объектом или массивом.',
        );
      }
      result['forms'] = forms;
    }
    Map<String, dynamic> row;
    if (section == 'blocks') {
      final decoded = jsonDecode(result['body_json'].toString());
      if (decoded is! Map) {
        throw const IntegrationException(
          'Дополнительные поля блока должны быть JSON-объектом.',
        );
      }
      final body = Map<String, dynamic>.from(decoded);
      body['text_ar'] = result['text_ar'];
      final ruKey = body.containsKey('translation')
          ? 'translation'
          : body.containsKey('text_ru')
          ? 'text_ru'
          : 'text';
      body[ruKey] = result['translation'];
      row = {
        ...existing,
        'step': result['step'],
        'kind': result['kind'],
        'body': body,
      };
    } else {
      row = {...existing, ...result};
      if (section == 'dialogues') {
        row.remove(
          'position',
        ); // Dialogues have no position column in the server schema.
        row.putIfAbsent('lines', () => []);
      }
      if (section == 'grammar') row.putIfAbsent('examples', () => []);
    }
    setState(() {
      if (index == null) {
        (draft.content[section] as List).add(row);
      } else {
        (draft.content[section] as List)[index] = row;
      }
    });
  }

  Future<void> _line(
    SchoolLessonDraft draft,
    Map<String, dynamic> dialogue,
    int? index,
  ) async {
    final lines = dialogue['lines'] as List;
    final existing = index == null
        ? <String, dynamic>{
            'id': AcademyState.newId(),
            'position': lines.length,
          }
        : copySchoolMap(lines[index] as Map);
    final values = await showSchoolForm(context, 'Строка диалога', [
      const SchoolField('speaker', 'Говорящий'),
      const SchoolField(
        'text_ar',
        'Арабская реплика',
        arabic: true,
        multiline: true,
        required: true,
      ),
      const SchoolField(
        'translation',
        'Русский перевод',
        multiline: true,
        required: true,
      ),
    ], initial: existing);
    if (values != null && mounted) {
      setState(() {
        final row = {...existing, ...values};
        if (index == null) {
          lines.add(row);
        } else {
          lines[index] = row;
        }
      });
    }
  }

  Future<void> _example(Map<String, dynamic> grammar, int? index) async {
    final examples = grammar['examples'] as List;
    final source = index == null
        ? <String, dynamic>{}
        : examples[index] is Map
        ? copySchoolMap(examples[index] as Map)
        : <String, dynamic>{'text_ar': examples[index].toString()};
    final values = await showSchoolForm(context, 'Пример правила', [
      const SchoolField(
        'text_ar',
        'Арабский пример',
        arabic: true,
        multiline: true,
        required: true,
      ),
      const SchoolField('translation', 'Русский перевод', multiline: true),
    ], initial: source);
    if (values != null && mounted) {
      setState(() {
        final row = {...source, ...values};
        if (index == null) {
          examples.add(row);
        } else {
          examples[index] = row;
        }
      });
    }
  }

  Future<void> _remove(List rows, int index) async {
    if (await confirmSchoolAction(
          context,
          'Удалить из черновика?',
          'Изменение попадёт на сервер только после сохранения урока.',
        ) &&
        mounted) {
      setState(() => rows.removeAt(index));
    }
  }

  void _move(List rows, int index, int target) {
    if (target >= 0 && target < rows.length) {
      setState(() {
        final row = rows.removeAt(index);
        rows.insert(target, row);
      });
    }
  }

  Future<void> _upload() async {
    await widget.api.guard();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            MediaUploadScreen(backend: widget.api.backend, lessonId: widget.id),
      ),
    );
  }

  Future<void> _attach(SchoolLessonDraft draft) async {
    final media = await widget.api.query(
      'media',
      filters: {'lesson_id': widget.id, 'upload_state': 'ready'},
    );
    if (!mounted) return;
    final selected = await pickSchoolRow(
      context,
      'Прикрепить загруженный материал',
      media
          .map(
            (row) => {
              ...row,
              'title': '${row['mime_type']} · ${row['byte_size']} байт',
            },
          )
          .toList(),
    );
    if (selected == null || !mounted) return;
    final kind = const {'image', 'audio', 'video'}.contains(selected['kind'])
        ? selected['kind']
        : 'text';
    setState(
      () => (draft.content['blocks'] as List).add({
        'id': AcademyState.newId(),
        'step': 'practice',
        'kind': kind,
        'position': draft.rows('blocks').length,
        'body': {
          'media_id': selected['id'],
          'mime_type': selected['mime_type'],
          if (kind == 'text') 'text': 'Документ PDF',
        },
      }),
    );
  }

  Widget _rowButtons(
    List rows,
    int index,
    VoidCallback edit, {
    bool movable = true,
  }) => Wrap(
    spacing: 2,
    children: [
      IconButton(
        onPressed: busy ? null : edit,
        icon: const Icon(Icons.edit_outlined),
        tooltip: 'Редактировать',
      ),
      if (movable)
        IconButton(
          onPressed: busy || index == 0
              ? null
              : () => _move(rows, index, index - 1),
          icon: const Icon(Icons.arrow_upward),
          tooltip: 'Выше',
        ),
      if (movable)
        IconButton(
          onPressed: busy || index == rows.length - 1
              ? null
              : () => _move(rows, index, index + 1),
          icon: const Icon(Icons.arrow_downward),
          tooltip: 'Ниже',
        ),
      IconButton(
        onPressed: busy ? null : () => run(() => _remove(rows, index)),
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Удалить из черновика',
      ),
    ],
  );
  Widget _content(SchoolLessonDraft draft, String section) {
    final rows = draft.rows(section);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          const {
            'blocks': 'Блоки урока',
            'dialogues': 'Диалоги',
            'vocabulary': 'Словарь',
            'grammar': 'Грамматика',
          }[section]!,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (section == 'blocks') ...[
                    Text(
                      '${steps[rows[i]['step']] ?? rows[i]['step']} · ${kinds[rows[i]['kind']] ?? rows[i]['kind']}',
                    ),
                    schoolBodyPreview(rows[i]['body']),
                  ] else if (section == 'vocabulary') ...[
                    NaskhText(rows[i]['text_ar']?.toString() ?? ''),
                    Text(rows[i]['translation']?.toString() ?? ''),
                  ] else
                    Text(rows[i]['title']?.toString() ?? ''),
                  if (draft.contentCompatibilityError == null)
                    _rowButtons(
                      rows,
                      i,
                      () => run(() => _editRow(draft, section, i)),
                      movable: section != 'dialogues',
                    ),
                  if (section == 'dialogues') ...[
                    for (var j = 0; j < (rows[i]['lines'] as List).length; j++)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (rows[i]['lines'][j]['speaker'] ?? '').toString(),
                            ),
                            NaskhText(
                              rows[i]['lines'][j]['text_ar'].toString(),
                            ),
                            Text(
                              (rows[i]['lines'][j]['translation'] ?? '')
                                  .toString(),
                            ),
                            if (draft.contentCompatibilityError == null)
                              _rowButtons(
                                rows[i]['lines'] as List,
                                j,
                                () => run(() => _line(draft, rows[i], j)),
                              ),
                          ],
                        ),
                      ),
                    if (draft.contentCompatibilityError == null)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => run(() => _line(draft, rows[i], null)),
                        child: const Text('Добавить реплику'),
                      ),
                  ],
                  if (section == 'grammar') ...[
                    Text(rows[i]['explanation']?.toString() ?? ''),
                    for (
                      var j = 0;
                      j <
                          (rows[i]['examples'] is List
                                  ? rows[i]['examples'] as List
                                  : [])
                              .length;
                      j++
                    )
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          schoolBodyPreview(rows[i]['examples'][j]),
                          if (draft.contentCompatibilityError == null)
                            _rowButtons(
                              rows[i]['examples'] as List,
                              j,
                              () => run(() => _example(rows[i], j)),
                            ),
                        ],
                      ),
                    if (draft.contentCompatibilityError == null)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => run(() => _example(rows[i], null)),
                        child: const Text('Добавить пример'),
                      ),
                  ],
                ],
              ),
            ),
          ),
        if (draft.contentCompatibilityError == null)
          OutlinedButton(
            onPressed: busy
                ? null
                : () => run(() => _editRow(draft, section, null)),
            child: const Text('Добавить материал'),
          ),
      ],
    );
  }

  Widget _editor(SchoolLessonDraft draft) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      status,
      Text(
        'Версия ${draft.lesson['version']} · ${schoolStatusLabel(draft.lesson['status'].toString())}',
      ),
      if (draft.contentCompatibilityError != null)
        Text(draft.contentCompatibilityError!),
      TextFormField(
        key: ValueKey('title-${draft.lesson['version']}'),
        initialValue: draft.lesson['title'].toString(),
        enabled: !busy,
        decoration: const InputDecoration(labelText: 'Название урока'),
        onChanged: (value) => setState(() => draft.lesson['title'] = value),
      ),
      TextFormField(
        key: ValueKey('ar-${draft.lesson['version']}'),
        initialValue: draft.lesson['title_ar']?.toString() ?? '',
        enabled: !busy,
        textDirection: TextDirection.rtl,
        style: const TextStyle(fontFamily: 'NotoNaskhArabic', height: 1.8),
        decoration: const InputDecoration(labelText: 'Арабское название'),
        onChanged: (value) => setState(() => draft.lesson['title_ar'] = value),
      ),
      TextFormField(
        key: ValueKey('goal-${draft.lesson['version']}'),
        initialValue: draft.lesson['goal']?.toString() ?? '',
        enabled: !busy,
        minLines: 2,
        maxLines: 5,
        decoration: const InputDecoration(labelText: 'Цель урока на русском'),
        onChanged: (value) => setState(() => draft.lesson['goal'] = value),
      ),
      SwitchListTile(
        value: draft.lesson['is_free_sample'] == true,
        onChanged: busy
            ? null
            : (value) => setState(() => draft.lesson['is_free_sample'] = value),
        title: const Text('Открытый бесплатный образец'),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton(
            onPressed: busy ? null : () => run(() => _save(draft)),
            child: const Text('Сохранить урок'),
          ),
          OutlinedButton(
            onPressed: busy
                ? null
                : () => run(() async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            SchoolLessonPreview(api: widget.api, draft: draft),
                      ),
                    );
                  }),
            child: const Text('Предпросмотр'),
          ),
          OutlinedButton(
            onPressed: busy ? null : () => run(_reload),
            child: const Text('Загрузить серверную версию'),
          ),
          OutlinedButton(
            onPressed: busy ? null : () => run(_upload),
            child: const Text('Загрузить медиа'),
          ),
          if (draft.contentCompatibilityError == null)
            OutlinedButton(
              onPressed: busy ? null : () => run(() => _attach(draft)),
              child: const Text('Прикрепить медиа'),
            ),
        ],
      ),
      for (final section in SchoolLessonDraft.sections)
        _content(draft, section),
      const Divider(height: 32),
      SchoolExercisesPanel(api: widget.api, lessonId: widget.id),
      const Divider(height: 32),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton(
            onPressed: busy
                ? null
                : () => run(() => _save(draft, status: 'published')),
            child: const Text('Опубликовать урок'),
          ),
          OutlinedButton(
            onPressed: busy
                ? null
                : () => run(() => _save(draft, status: 'draft')),
            child: const Text('Вернуть в черновик'),
          ),
          OutlinedButton(
            onPressed: busy
                ? null
                : () => run(() => _save(draft, status: 'archived')),
            child: const Text('Архивировать урок'),
          ),
        ],
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowExit || (!busy && _draft?.dirty != true),
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop || busy) return;
      if (await confirmSchoolAction(
            context,
            'Выйти без сохранения?',
            'Несохранённый черновик останется только до закрытия этого экрана.',
          ) &&
          mounted) {
        setState(() => _allowExit = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('Редактор урока')),
      body: SchoolAccess(
        api: widget.api,
        builder: (_) => FutureBuilder<SchoolLessonDraft>(
          future: _future ??= widget.api.lesson(widget.id),
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
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            _draft = snapshot.data!;
            _draft!.initializeBaseline();
            return _editor(_draft!);
          },
        ),
      ),
    ),
  );
}

class SchoolLessonPreview extends StatelessWidget {
  const SchoolLessonPreview({
    super.key,
    required this.api,
    required this.draft,
  });
  final RemoteSchoolApi api;
  final SchoolLessonDraft draft;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Предпросмотр черновика')),
    body: SchoolAccess(
      api: api,
      builder: (_) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            draft.lesson['title'].toString(),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          NaskhText(draft.lesson['title_ar']?.toString() ?? ''),
          Text(draft.lesson['goal']?.toString() ?? ''),
          for (final block in draft.rows('blocks'))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Panel(child: schoolBodyPreview(block['body'])),
            ),
          for (final dialogue in draft.rows('dialogues')) ...[
            Text(
              dialogue['title'].toString(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final line in schoolMaps(dialogue['lines']))
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(line['speaker']?.toString() ?? ''),
                    schoolBodyPreview(line),
                  ],
                ),
              ),
          ],
          for (final word in draft.rows('vocabulary'))
            Padding(
              padding: const EdgeInsets.all(8),
              child: schoolBodyPreview(word),
            ),
          for (final rule in draft.rows('grammar')) ...[
            Text(
              rule['title'].toString(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(rule['explanation'].toString()),
            for (final example
                in (rule['examples'] is List
                    ? rule['examples'] as List
                    : [rule['examples']]))
              schoolBodyPreview(example),
          ],
          ExpansionTile(
            title: const Text('Данные черновика для копирования'),
            children: [
              SelectableText(
                const JsonEncoder.withIndent(
                  '  ',
                ).convert({'lesson': draft.lesson, 'content': draft.content}),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
