import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import '../../core/academy_state.dart';
import '../../services/backend_service.dart';
import '../../ui/components.dart';
import '../integrations/phone_auth_screen.dart';
import '../teacher/remote/online_learning_api.dart';
import '../teacher/remote/homework_draft.dart';
export '../teacher/remote/online_learning_api.dart';
export '../teacher/remote/homework_draft.dart';

class OnlineHomeworkScreen extends StatefulWidget {
  const OnlineHomeworkScreen({
    super.key,
    required this.backend,
    this.state,
    this.api,
  });
  final BackendService backend;
  final AcademyState? state;
  final OnlineLearningApi? api;
  @override
  State<OnlineHomeworkScreen> createState() => _OnlineHomeworkScreenState();
}

class _OnlineHomeworkScreenState extends State<OnlineHomeworkScreen> {
  late final OnlineLearningApi api;
  Future<List<Map<String, dynamic>>>? _future;
  AcademyState? _state;
  bool _ownsState = false;
  @override
  void initState() {
    super.initState();
    api = widget.api ?? OnlineLearningApi(widget.backend);
  }

  Future<List<Map<String, dynamic>>> _load() async {
    api.requireOwner();
    if (_state == null) {
      if (widget.state != null) {
        _state = widget.state;
      } else {
        final prefs = await SharedPreferences.getInstance();
        api.requireOwner();
        _state = AcademyState(prefs, const {
          'modules': [],
          'lessons': [],
        }, namespace: 'academy_account_${api.owner}');
        _ownsState = true;
        await _state!.initialize();
      }
    }
    if (_state!.namespace != 'academy_account_${api.owner}') {
      throw const IntegrationException(
        'Выберите личный аккаунт: школьные черновики не сохраняются в демо или чужом профиле.',
      );
    }
    return api.assignments();
  }

  void _reload() => setState(() => _future = null);
  @override
  void dispose() {
    if (_ownsState) _state?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Домашние задания школы')),
    body: AnimatedBuilder(
      animation: widget.backend,
      builder: (context, _) {
        if (!widget.backend.isAuthenticated) {
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              EmptyState(
                title: 'Задания личного аккаунта',
                message:
                    'Войдите, чтобы получить задания ваших школьных групп.',
                action: FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => PhoneAuthScreen(backend: widget.backend),
                    ),
                  ),
                  child: const Text('Войти по телефону'),
                ),
              ),
            ],
          );
        }
        if (api.owner != widget.backend.userId) {
          return const Center(
            child: Text('Аккаунт изменился. Закройте экран и откройте заново.'),
          );
        }
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _future ??= _load(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _homeworkError(snapshot.error!, _reload);
            }
            return RefreshIndicator(
              onRefresh: () async {
                _reload();
                await _future;
              },
              child: ListView(
                padding: const EdgeInsets.all(18),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (snapshot.data!.isEmpty)
                    const EmptyState(
                      title: 'Заданий пока нет',
                      message:
                          'Здесь появятся задания активных групп, в которые вы приняты сервером.',
                    ),
                  for (final assignment in snapshot.data!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Panel(
                        child: ListTile(
                          title: Text(
                            assignment['title'] as String? ?? 'Задание',
                          ),
                          subtitle: Text(
                            '${assignment['group_title'] ?? ''}\nСрок: ${_date(assignment['due_at'])}\n${_status((assignment['submission'] as Map?)?['status'])}',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => OnlineHomeworkEditor(
                                  api: api,
                                  assignmentId: assignment['id'] as String,
                                  state: _state!,
                                ),
                              ),
                            );
                            if (mounted) _reload();
                          },
                        ),
                      ),
                    ),
                  OutlinedButton(
                    onPressed: _reload,
                    child: const Text('Обновить задания'),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}

String _date(dynamic value) =>
    DateTime.tryParse(
      value?.toString() ?? '',
    )?.toLocal().toString().substring(0, 16) ??
    'без срока';
String _status(dynamic value) =>
    const {
      'submitted': 'Отправлено',
      'revision_requested': 'Нужны исправления',
      'graded': 'Проверено',
    }[value] ??
    'Ответ ещё не отправлен';
String _errorMessage(Object error) {
  if (error is IntegrationException) return error.message;
  if (error is PostgrestException && error.code == '40001') {
    return 'На сервере появилась другая ревизия. Ваш ответ сохранён. Обновите работу и сверьте историю перед новой отправкой.';
  }
  if (error is PostgrestException &&
      error.message.contains('assignment_closed')) {
    return 'Срок сдачи закрыт сервером. Новая отправка доступна после запроса исправлений преподавателем.';
  }
  if (error is StateError) {
    return 'Не удалось сохранить черновик на устройстве. Отправка не подтверждена. Проверьте хранилище и повторите действие.';
  }
  return 'Не удалось выполнить запрос. Проверьте подключение и повторите действие.';
}

Widget _homeworkError(Object error, VoidCallback retry) => ListView(
  padding: const EdgeInsets.all(18),
  children: [
    EmptyState(
      title: 'Не удалось получить задания',
      message: _errorMessage(error),
      action: OutlinedButton(onPressed: retry, child: const Text('Повторить')),
    ),
  ],
);

class OnlineHomeworkEditor extends StatefulWidget {
  const OnlineHomeworkEditor({
    super.key,
    required this.api,
    required this.assignmentId,
    required this.state,
  });
  final OnlineLearningApi api;
  final String assignmentId;
  final AcademyState state;
  @override
  State<OnlineHomeworkEditor> createState() => _OnlineHomeworkEditorState();
}

class _OnlineHomeworkEditorState extends State<OnlineHomeworkEditor> {
  Future<Map<String, dynamic>>? _future;
  OnlineHomeworkDraft? _draft;
  final _arabic = TextEditingController(), _russian = TextEditingController();
  String? _error, _notice;
  bool _busy = false;
  Future<Map<String, dynamic>> _load() async {
    widget.api.requireOwner();
    if (widget.state.namespace != 'academy_account_${widget.api.owner}') {
      throw const IntegrationException(
        'Личный черновик относится к другому аккаунту.',
      );
    }
    final details = await widget.api.homeworkDetails(widget.assignmentId);
    widget.api.requireOwner();
    if (_draft == null) {
      final saved =
          widget.state.drafts['online_assignment:${widget.assignmentId}'];
      final submission = details['submission'] as Map?;
      _draft = OnlineHomeworkDraft(
        owner: widget.api.owner!,
        assignmentId: widget.assignmentId,
        revision: submission?['revision'] as int? ?? 0,
        saved: saved == null ? null : Map<String, dynamic>.from(saved as Map),
      );
      if (saved == null && submission?['body'] is Map) {
        final body = submission!['body'] as Map;
        _draft!.textAr = body['text_ar'] as String? ?? '';
        _draft!.text = body['text'] as String? ?? '';
      }
      _arabic.text = _draft!.textAr;
      _russian.text = _draft!.text;
    }
    if (_draft!.reconcile(details)) await _draft!.persist(widget.state);
    return details;
  }

  @override
  void dispose() {
    _arabic.dispose();
    _russian.dispose();
    super.dispose();
  }

  Future<void> _saveEdit({String? arabic, String? russian}) async {
    try {
      widget.api.requireOwner();
      _draft!.edit(arabic: arabic, russian: russian);
      await _draft!.persist(widget.state);
      if (mounted) setState(() => _error = null);
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    var dispatched = false;
    final wasPending = _draft!.pending;
    try {
      widget.api.requireOwner();
      _draft!.queue();
      await _draft!.persist(widget.state);
      widget.api.requireOwner();
      dispatched = true;
      final response = await widget.api.rpc(
        'submit_assignment',
        _draft!.submitParams(),
      );
      if (response is! Map) {
        throw const IntegrationException(
          'Сервер не подтвердил ревизию. Повторите отправку сохранённого ответа.',
        );
      }
      _draft!.accept(response);
      await _draft!.persist(widget.state);
      if (mounted) {
        setState(() {
          _notice =
              'Сервер принял ревизию ${response['revision']}. Проверку выполняет преподаватель.';
          _future = null;
        });
      }
    } catch (error) {
      if (!dispatched && !wasPending) _draft!.pendingBody = null;
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolveRevision() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сверить ревизию и продолжить?'),
        content: const Text(
          'Будут загружены история и текущая ревизия. Текст черновика сохранится. Если старая отправка подтверждена, её ключ не будет отправлен ещё раз. Продолжайте только после сверки работы.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сверить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final details = await widget.api.homeworkDetails(widget.assignmentId);
      _draft!.reconcile(details);
      _draft!.useRevision(
        (details['submission'] as Map?)?['revision'] as int? ?? 0,
      );
      await _draft!.persist(widget.state);
      if (mounted) {
        setState(() {
          _future = Future.value(details);
          _error = null;
          _notice =
              'Текст сохранён. Новая отправка будет проверена относительно текущей ревизии.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _body(Map<String, dynamic> data) {
    final assignment = data['assignment'] as Map,
        submission = data['submission'] as Map?,
        draft = _draft!;
    final serverRevision = submission?['revision'] as int? ?? 0;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          assignment['title'] as String? ?? 'Задание',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text('Срок: ${_date(assignment['due_at'])}'),
        Text('${_status(submission?['status'])} · Ревизия $serverRevision'),
        if (data['exercise'] is Map)
          Text((data['exercise'] as Map)['title']?.toString() ?? ''),
        for (final question in data['questions'] as List)
          Builder(
            builder: (context) {
              final prompt = question['prompt'] as Map? ?? {};
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (prompt['text_ar'] is String)
                    NaskhText(prompt['text_ar'] as String),
                  Text(
                    (prompt['translation'] ?? prompt['text'] ?? '').toString(),
                  ),
                ],
              );
            },
          ),
        for (final request in data['requests'] as List)
          if (request['resolved_at'] == null)
            Panel(
              child: Text(
                'Преподаватель просит исправить: ${request['reason'] ?? ''}',
              ),
            ),
        for (final grade in data['grades'] as List)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Ревизия ${grade['revision']}: ${grade['score']}/100'),
                  for (final feedback in (data['feedback'] as List).where(
                    (f) => f['grade_id'] == grade['id'],
                  ))
                    Text(feedback['body']?.toString() ?? ''),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _arabic,
          enabled: !_busy && !draft.pending,
          minLines: 3,
          maxLines: 8,
          textDirection: TextDirection.rtl,
          style: const TextStyle(fontFamily: 'NotoNaskhArabic', height: 1.8),
          decoration: const InputDecoration(labelText: 'Ответ на арабском'),
          onChanged: (value) => unawaited(_saveEdit(arabic: value)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _russian,
          enabled: !_busy && !draft.pending,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'Ответ / комментарий на русском',
          ),
          onChanged: (value) => unawaited(_saveEdit(russian: value)),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'На этом экране отправляется текст. Загрузка ученических PDF и изображений ещё не разрешена сервером; локальные файлы не выдаются за вложения.',
          ),
        ),
        if (draft.expectedRevision != serverRevision)
          Text(
            'Черновик основан на ревизии ${draft.expectedRevision}; на сервере $serverRevision. Сверьте историю.',
          ),
        if (draft.pending)
          const Text(
            'Отправка ожидает подтверждения. Ответ и ключ сохранены; повторная отправка использует те же данные.',
          ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (_notice != null) Text(_notice!),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(
            draft.pending
                ? 'Повторить отправку'
                : serverRevision == 0
                ? 'Отправить работу'
                : 'Отправить новую ревизию',
          ),
        ),
        OutlinedButton(
          onPressed: _busy ? null : () => setState(() => _future = null),
          child: const Text('Обновить работу и историю'),
        ),
        if (draft.pending || draft.expectedRevision != serverRevision)
          OutlinedButton(
            onPressed: _busy ? null : _resolveRevision,
            child: const Text('Сверить ревизию, сохранив текст'),
          ),
        const Divider(height: 32),
        Text('История ответов', style: Theme.of(context).textTheme.titleLarge),
        for (final history in data['history'] as List)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Ревизия ${history['revision']} · ${_date(history['created_at'])}',
                  ),
                  Builder(
                    builder: (context) {
                      final body = history['body'];
                      if (body is! Map) return SelectableText(jsonEncode(body));
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (body['text_ar'] is String)
                            NaskhText(body['text_ar'] as String),
                          if (body['text'] is String)
                            Text(body['text'] as String),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ответ на задание')),
    body: AnimatedBuilder(
      animation: widget.api.backend,
      builder: (context, _) {
        try {
          widget.api.requireOwner();
        } catch (error) {
          return const Center(
            child: Text('Аккаунт изменился. Закройте работу и войдите заново.'),
          );
        }
        return FutureBuilder<Map<String, dynamic>>(
          future: _future ??= _load(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _homeworkError(
                snapshot.error!,
                () => setState(() => _future = null),
              );
            }
            return _body(snapshot.data!);
          },
        );
      },
    ),
  );
}
