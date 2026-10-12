import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/academy_state.dart';
import '../../services/backend_service.dart';
import '../../ui/components.dart';
import '../../ui/design_tokens.dart';
import '../integrations/phone_auth_screen.dart';
import '../integrations/purchases_screen.dart';
import '../teacher/remote/online_learning_api.dart';
import '../teacher/remote/online_media_preview.dart';
export '../teacher/remote/online_learning_api.dart';

/// Server catalog and private lesson content always use RLS queries. None of
/// this content is bundled into the APK or unlocked by a local demo flag.
class OnlineCoursesScreen extends StatefulWidget {
  const OnlineCoursesScreen({super.key, required this.backend, this.api});
  final BackendService backend;
  final OnlineLearningApi? api;
  @override
  State<OnlineCoursesScreen> createState() => _OnlineCoursesScreenState();
}

class _OnlineCoursesScreenState extends State<OnlineCoursesScreen> {
  Future<List<Map<String, dynamic>>>? _courses;
  late OnlineLearningApi api;
  @override
  void initState() {
    super.initState();
    api = widget.api ?? OnlineLearningApi(widget.backend);
    _reload();
    widget.backend.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(_reload);
  }

  void _reload() {
    if (widget.backend.userId != api.owner) {
      api = widget.api ?? OnlineLearningApi(widget.backend);
    }
    _courses = widget.backend.isAuthenticated ? _loadCourses() : null;
  }

  Future<List<Map<String, dynamic>>> _loadCourses() async {
    api.requireOwner();
    final rows = await widget.backend.courses();
    api.requireOwner();
    return rows;
  }

  Future<void> _join() async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _JoinGroupDialog(),
    );
    if (code == null || !mounted) return;
    await guardedAction(context, () async {
      await api.claimInvite(code);
      if (mounted) {
        notice(context, 'Сервер подтвердил участие в группе.');
        setState(_reload);
      }
    });
  }

  @override
  void dispose() {
    widget.backend.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Онлайн-курсы школы'),
      actions: [
        if (widget.backend.isAuthenticated)
          IconButton(
            onPressed: _join,
            icon: const Icon(Icons.group_add_outlined),
            tooltip: 'Присоединиться к группе',
          ),
      ],
    ),
    body: _courses == null
        ? ListView(
            padding: const EdgeInsets.all(18),
            children: [
              EmptyState(
                title: 'Личный учебный доступ',
                message:
                    'Войдите по телефону, чтобы видеть назначенные и приобретённые материалы.',
                icon: Icons.cloud_outlined,
                action: FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PhoneAuthScreen(backend: widget.backend),
                    ),
                  ),
                  child: const Text('Войти по телефону'),
                ),
              ),
            ],
          )
        : FutureBuilder(
            future: _courses,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _networkError(
                  context,
                  snapshot.error!,
                  () => setState(_reload),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final courses = snapshot.data!;
              if (courses.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(18),
                  child: EmptyState(
                    title: 'Курсы ещё не опубликованы',
                    message: 'Опубликованные материалы школы появятся здесь.',
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  setState(_reload);
                  await _courses;
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(18),
                  itemCount: courses.length,
                  itemBuilder: (context, i) {
                    final course = courses[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Panel(
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          leading: const Icon(
                            Icons.school_outlined,
                            color: DesignTokens.olive,
                          ),
                          title: Text(course['title'] as String? ?? ''),
                          subtitle: Text(
                            course['description'] as String? ?? '',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  _OnlineLessons(api: api, course: course),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
  );
}

Widget _networkError(
  BuildContext context,
  Object error,
  VoidCallback retry,
) => ListView(
  padding: const EdgeInsets.all(18),
  children: [
    EmptyState(
      title: 'Не удалось получить данные',
      message: error is IntegrationException
          ? error.message
          : 'Проверьте подключение и учебный доступ. Локальные данные сохранены.',
      icon: Icons.cloud_off_outlined,
      action: OutlinedButton(onPressed: retry, child: const Text('Повторить')),
    ),
  ],
);

class _OnlineLessons extends StatefulWidget {
  const _OnlineLessons({required this.api, required this.course});
  final OnlineLearningApi api;
  final Map<String, dynamic> course;
  @override
  State<_OnlineLessons> createState() => _OnlineLessonsState();
}

class _OnlineLessonsState extends State<_OnlineLessons> {
  late Future<List<Map<String, dynamic>>> _lessons;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _lessons = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    widget.api.requireOwner();
    final rows = await widget.api.backend.lessons(
      widget.course['id'] as String,
    );
    widget.api.requireOwner();
    return rows;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.course['title'] as String? ?? 'Курс')),
    body: _LearnerAccess(
      api: widget.api,
      child: FutureBuilder(
        future: _lessons,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _networkError(
              context,
              snapshot.error!,
              () => setState(_reload),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final lessons = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              if (lessons.isEmpty)
                EmptyState(
                  title: 'Нет доступных уроков',
                  message:
                      'Материалы могут требовать приобретения курса или действующей подписки.',
                  icon: Icons.lock_outline,
                  action: FilledButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PurchasesScreen(backend: widget.api.backend),
                      ),
                    ),
                    child: const Text('Проверить доступ'),
                  ),
                ),
              ...lessons.map(
                (lesson) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Panel(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      title: Text(lesson['title'] as String? ?? ''),
                      subtitle: NaskhText(
                        lesson['title_ar'] as String? ?? '',
                        size: 20,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OnlineLessonScreen(
                            backend: widget.api.backend,
                            api: widget.api,
                            lessonId: lesson['id'] as String,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class OnlineLessonScreen extends StatefulWidget {
  const OnlineLessonScreen({
    super.key,
    required this.backend,
    required this.lessonId,
    this.api,
  });
  final BackendService backend;
  final String lessonId;
  final OnlineLearningApi? api;
  @override
  State<OnlineLessonScreen> createState() => _OnlineLessonState();
}

class _OnlineLessonState extends State<OnlineLessonScreen> {
  late final OnlineLearningApi api;
  late Future<Map<String, dynamic>> _content;
  int _step = 0;
  @override
  void initState() {
    super.initState();
    api = widget.api ?? OnlineLearningApi(widget.backend);
    _reload();
  }

  void _reload() {
    _content = api.lessonContent(widget.lessonId);
  }

  Widget _block(Map raw, List media) {
    final body = raw['body'] as Map? ?? {};
    final attached = media
        .where((m) => m['id'] == body['media_id'])
        .firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (body['text_ar'] is String) NaskhText(body['text_ar'] as String),
            if (body['translation'] is String ||
                body['text_ru'] is String ||
                body['text'] is String)
              Text(
                (body['translation'] ?? body['text_ru'] ?? body['text'])
                    .toString(),
              ),
            if (body['media_id'] != null)
              if (attached != null)
                OnlineMediaPreview(
                  key: ValueKey('${raw['id']}-${body['media_id']}'),
                  api: api,
                  media: Map<String, dynamic>.from(attached as Map),
                )
              else
                const Text(
                  'Прикреплённый материал недоступен вашему аккаунту.',
                ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Учебный материал')),
    body: _LearnerAccess(
      api: api,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _content,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _networkError(
              context,
              snapshot.error!,
              () => setState(_reload),
            );
          }
          final data = snapshot.data!, lesson = data['lesson'] as Map;
          final stepName = [
            'introduction',
            'vocabulary',
            'dialogue',
            'grammar',
            'practice',
            'test',
          ][_step];
          final media = data['media'] as List? ?? [];
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Text(
                lesson['title'] as String? ?? '',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              NaskhText(lesson['title_ar'] as String? ?? ''),
              Text(lesson['goal'] as String? ?? ''),
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: List.generate(
                  6,
                  (i) => ChoiceChip(
                    label: Text(
                      [
                        'Введение',
                        'Лексика',
                        'Диалог',
                        'Грамматика',
                        'Практика',
                        'Проверка',
                      ][i],
                    ),
                    selected: _step == i,
                    onSelected: (_) => setState(() => _step = i),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (final raw in (data['blocks'] as List).where(
                (b) => b['step'] == stepName,
              ))
                _block(raw as Map, media),
              if (_step == 1)
                for (final word in data['vocabulary'] as List)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          NaskhText(word['text_ar'] as String? ?? ''),
                          Text(word['translation'] as String? ?? ''),
                          if (word['example_ar'] is String)
                            NaskhText(word['example_ar'] as String),
                          if (word['example_translation'] is String)
                            Text(word['example_translation'] as String),
                        ],
                      ),
                    ),
                  ),
              if (_step == 2)
                for (final dialogue in data['dialogues'] as List? ?? [])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            dialogue['title'] as String? ?? '',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          for (final line in dialogue['lines'] as List)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(line['speaker'] as String? ?? ''),
                                  NaskhText(line['text_ar'] as String? ?? ''),
                                  Text(line['translation'] as String? ?? ''),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              if (_step == 3)
                for (final rule in data['grammar'] as List)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            rule['title'] as String? ?? '',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(rule['explanation'] as String? ?? ''),
                          for (final example in rule['examples'] as List? ?? [])
                            if (example is Map) ...[
                              if (example['text_ar'] is String)
                                NaskhText(example['text_ar'] as String),
                              if (example['translation'] is String)
                                Text(example['translation'] as String),
                            ] else
                              Text(example.toString()),
                        ],
                      ),
                    ),
                  ),
              if (_step >= 4)
                _ServerExercises(
                  key: ValueKey(widget.lessonId),
                  api: api,
                  lessonId: widget.lessonId,
                ),
            ],
          );
        },
      ),
    ),
  );
}

class _ServerExercises extends StatefulWidget {
  const _ServerExercises({
    super.key,
    required this.api,
    required this.lessonId,
  });
  final OnlineLearningApi api;
  final String lessonId;
  @override
  State<_ServerExercises> createState() => _ServerExercisesState();
}

class _ServerExercisesState extends State<_ServerExercises> {
  Future<List<Map<String, dynamic>>>? _exercises;
  bool _completing = false;
  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _exercises ??= widget.api.exercises(widget.lessonId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Column(
              children: [
                const Text('Не удалось загрузить задания.'),
                OutlinedButton(
                  onPressed: () => setState(() => _exercises = null),
                  child: const Text('Повторить загрузку заданий'),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final exercise in snapshot.data!)
                ServerExerciseForm(
                  key: ValueKey('${exercise['id']}-${exercise['version']}'),
                  api: widget.api,
                  exercise: exercise,
                ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _completing
                    ? null
                    : () async {
                        setState(() => _completing = true);
                        await guardedAction(context, () async {
                          await widget.api.completeLesson(widget.lessonId);
                          if (context.mounted) {
                            notice(
                              context,
                              'Сервер подтвердил завершение урока.',
                            );
                          }
                        });
                        if (mounted) setState(() => _completing = false);
                      },
                child: Text(
                  _completing
                      ? 'Проверка завершения…'
                      : 'Завершить урок на сервере',
                ),
              ),
            ],
          );
        },
      );
}

/// Answers are public question/option IDs; grading and completion stay server-side.
class ServerExerciseForm extends StatefulWidget {
  const ServerExerciseForm({
    super.key,
    required this.api,
    required this.exercise,
  });
  final OnlineLearningApi api;
  final Map<String, dynamic> exercise;
  @override
  State<ServerExerciseForm> createState() => _ServerExerciseFormState();
}

class _ServerExerciseFormState extends State<ServerExerciseForm> {
  final Map<String, dynamic> _answers = {};
  Map<String, dynamic>? _pendingAnswers;
  String _requestId = AcademyState.newId();
  String? _result, _error;
  bool _busy = false;
  bool get _supported => const {
    'singleChoice',
    'multipleChoice',
    'shortAnswer',
    'writing',
  }.contains(widget.exercise['kind']);
  void _answer(String id, dynamic value) => setState(() {
    _answers[id] = value;
    _requestId = AcademyState.newId();
    _result = null;
    _error = null;
  });
  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_pendingAnswers == null) {
        for (final question in widget.exercise['questions'] as List) {
          final answer = _answers[question['id']];
          if (answer == null ||
              (answer is String && answer.trim().isEmpty) ||
              (answer is List && answer.isEmpty)) {
            throw const IntegrationException('Ответьте на каждый вопрос.');
          }
        }
        _pendingAnswers = Map<String, dynamic>.from(
          jsonDecode(jsonEncode(_answers)) as Map,
        );
      }
      final attempt = await widget.api.rpc('submit_attempt', {
        'p_exercise_id': widget.exercise['id'],
        'p_idempotency_key': _requestId,
        'p_answers': _pendingAnswers,
      });
      if (attempt is! Map ||
          attempt['exercise_id'] != widget.exercise['id'] ||
          attempt['student_id'] != widget.api.owner ||
          !const {'graded', 'pending_review'}.contains(attempt['status'])) {
        throw const IntegrationException(
          'Сервер не подтвердил попытку. Повторите отправку того же ответа.',
        );
      }
      if (mounted) {
        setState(() {
          _result = attempt['status'] == 'pending_review'
              ? 'Отправлено на ручную проверку.'
              : 'Результат: ${attempt['score']}/${attempt['max_score']} · ${attempt['passed'] == true ? 'Пройдено' : 'Повторите материал'}';
          _pendingAnswers = null;
          _requestId = AcademyState.newId();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is IntegrationException
              ? error.message
              : 'Не удалось отправить ответ. Повторите отправку; ключ и ответ сохранены на этом экране.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _optionLabel(dynamic value) {
    final text = value?.toString() ?? '';
    return RegExp(r'[\u0600-\u06ff]').hasMatch(text)
        ? NaskhText(text, size: 22)
        : Text(text);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.exercise['title'] as String? ?? 'Задание',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (!_supported)
            const Text(
              'Этот формат задания пока не поддерживается на этом экране. Автоматическая оценка не выполняется.',
            ),
          for (final question in widget.exercise['questions'] as List)
            Builder(
              builder: (context) {
                final prompt = question['prompt'] as Map? ?? {},
                    options = question['options'] as List? ?? [],
                    id = question['id'] as String;
                final enabled = !_busy && _pendingAnswers == null && _supported;
                final kind = widget.exercise['kind'];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (prompt['text_ar'] is String)
                      NaskhText(prompt['text_ar'] as String),
                    Text(
                      (prompt['translation'] ?? prompt['text'] ?? '')
                          .toString(),
                    ),
                    if (kind == 'multipleChoice')
                      for (final option in options)
                        CheckboxListTile(
                          title: _optionLabel(option['label']),
                          value: (_answers[id] as List? ?? []).contains(
                            option['id'],
                          ),
                          onChanged: !enabled
                              ? null
                              : (selected) {
                                  final chosen = Set<String>.from(
                                    (_answers[id] as List? ?? [])
                                        .cast<String>(),
                                  );
                                  if (selected == true) {
                                    chosen.add(option['id'] as String);
                                  } else {
                                    chosen.remove(option['id']);
                                  }
                                  _answer(
                                    id,
                                    options
                                        .map((o) => o['id'] as String)
                                        .where(chosen.contains)
                                        .toList(),
                                  );
                                },
                        )
                    else if (kind == 'singleChoice')
                      RadioGroup<String>(
                        groupValue: _answers[id] as String?,
                        onChanged: (value) {
                          if (enabled) _answer(id, value);
                        },
                        child: Column(
                          children: [
                            for (final option in options)
                              RadioListTile<String>(
                                value: option['id'] as String,
                                title: _optionLabel(option['label']),
                                enabled: enabled,
                              ),
                          ],
                        ),
                      )
                    else if (_supported)
                      TextField(
                        enabled: enabled,
                        minLines: 1,
                        maxLines: 5,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          fontFamily: 'NotoNaskhArabic',
                          height: 1.8,
                        ),
                        onChanged: (value) => _answer(id, value),
                        decoration: const InputDecoration(
                          labelText: 'Ответ (арабский или русский)',
                        ),
                      ),
                  ],
                );
              },
            ),
          if (_result != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_result!),
            ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_supported)
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(
                _busy
                    ? 'Проверка…'
                    : _pendingAnswers != null
                    ? 'Повторить отправку'
                    : 'Проверить на сервере',
              ),
            ),
        ],
      ),
    ),
  );
}

class _LearnerAccess extends StatelessWidget {
  const _LearnerAccess({required this.api, required this.child});
  final OnlineLearningApi api;
  final Widget child;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: api.backend,
    builder: (context, _) {
      try {
        api.requireOwner();
        return child;
      } catch (error) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Учебный аккаунт изменился или выход выполнен. Закройте экран и войдите заново.',
            ),
          ),
        );
      }
    },
  );
}

class _JoinGroupDialog extends StatefulWidget {
  const _JoinGroupDialog();
  @override
  State<_JoinGroupDialog> createState() => _JoinGroupDialogState();
}

class _JoinGroupDialogState extends State<_JoinGroupDialog> {
  final controller = TextEditingController();
  String? error;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Приглашение группы'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Код от преподавателя'),
        ),
        if (error != null) Text(error!),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: () {
          if (controller.text.trim().isEmpty) {
            setState(() => error = 'Введите код приглашения.');
            return;
          }
          Navigator.pop(context, controller.text.trim());
        },
        child: const Text('Присоединиться'),
      ),
    ],
  );
}
