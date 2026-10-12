import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../ui/components.dart' show Panel;
import '../../../services/backend_service.dart';
import 'school_api.dart';
import 'school_models.dart';
import 'school_widgets.dart';
import '../../../core/academy_state.dart';
import 'submission_panel.dart';

class SchoolGroupsPanel extends StatefulWidget {
  const SchoolGroupsPanel({super.key, required this.api});
  final RemoteSchoolApi api;
  @override
  State<SchoolGroupsPanel> createState() => _SchoolGroupsPanelState();
}

class _SchoolGroupsPanelState extends State<SchoolGroupsPanel>
    with SchoolActions<SchoolGroupsPanel> {
  Future<List<Map<String, dynamic>>>? _future;
  void _reload() => setState(() => _future = null);
  Future<void> _create() async {
    final courses = await widget.api.courses();
    if (!mounted) return;
    final course = await pickSchoolRow(context, 'Выберите курс', courses);
    if (course == null || !mounted) return;
    final values = await showSchoolForm(context, 'Новая группа', [
      const SchoolField('title', 'Название группы', required: true),
    ]);
    if (values == null) return;
    await widget.api.rpc('create_group', {
      'p_course_id': course['id'],
      'p_title': values['title'],
    });
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      status,
      Expanded(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future ??= widget.api.groups(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return schoolErrorCard(snapshot.error!, _reload);
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FilledButton(
                  onPressed: busy ? null : () => run(_create),
                  child: const Text('Создать группу'),
                ),
                if (snapshot.data!.isEmpty) const Text('Доступных групп нет.'),
                for (final group in snapshot.data!)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Panel(
                      child: ListTile(
                        title: Text(group['title'].toString()),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: busy
                            ? null
                            : () => run(() async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => SchoolGroupPage(
                                      api: widget.api,
                                      group: group,
                                    ),
                                  ),
                                );
                                if (mounted) _reload();
                              }),
                      ),
                    ),
                  ),
                OutlinedButton(
                  onPressed: busy ? null : _reload,
                  child: const Text('Обновить группы'),
                ),
              ],
            );
          },
        ),
      ),
    ],
  );
}

class SchoolGroupPage extends StatefulWidget {
  const SchoolGroupPage({super.key, required this.api, required this.group});
  final RemoteSchoolApi api;
  final Map<String, dynamic> group;
  @override
  State<SchoolGroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<SchoolGroupPage>
    with SchoolActions<SchoolGroupPage> {
  Future<Map<String, dynamic>>? _future;
  final List<Map<String, dynamic>> _notifications = [];
  String? _invite;
  Map<String, dynamic>? _pendingCompose;
  Future<Map<String, dynamic>> _load() async {
    final members = await widget.api.query(
      'group_members',
      filters: {'group_id': widget.group['id'], 'left_at': null},
      order: 'student_id',
    );
    final profiles = await widget.api.query(
      'profiles',
      within: {'id': members.map((row) => row['student_id']).toList()},
      columns: 'id,display_name',
      order: 'display_name',
    );
    return {
      'members': members
          .map(
            (member) => {
              ...member,
              'display_name':
                  profiles
                      .where((p) => p['id'] == member['student_id'])
                      .firstOrNull?['display_name'] ??
                  member['student_id'],
              'id': member['student_id'],
            },
          )
          .toList(),
      'assignments': await widget.api.query(
        'assignments',
        filters: {'group_id': widget.group['id']},
        order: 'created_at',
      ),
    };
  }

  void _reload() => setState(() => _future = null);
  Future<void> _add(ServerRole role, {bool byId = false}) async {
    final courseId = widget.group['course_id'] as String;
    String? student;
    if (byId) {
      final values = await showSchoolForm(
        context,
        'Добавить зарегистрированную ученицу',
        [const SchoolField('id', 'UUID аккаунта ученицы', required: true)],
      );
      if (values == null) return;
      student = IntegrationValidation.uuid(values['id'].toString());
    } else {
      final profiles = await widget.api.enrolledProfiles(courseId);
      if (!mounted) return;
      student =
          (await pickSchoolRow(
                context,
                'Ученицы, записанные на курс',
                profiles,
              ))?['id']
              as String?;
      if (student == null) return;
    }
    final enrolled = await widget.api.query(
      'enrollments',
      filters: {'course_id': courseId, 'student_id': student},
      order: 'student_id',
    );
    if (enrolled.isEmpty) {
      throw const IntegrationException(
        'Нет доступной записи ученицы на этот курс. Назначение не выполнено.',
      );
    }
    await widget.api.rpc('set_group_member', {
      'p_group_id': widget.group['id'],
      'p_student_id': student,
      'p_active': true,
    });
    if (mounted) _reload();
  }

  Future<void> _removeMember(String id) async {
    if (!await confirmSchoolAction(
      context,
      'Убрать ученицу из группы?',
      'Прогресс и сданные работы не удаляются. Сервер закроет участие в группе.',
    )) {
      return;
    }
    await widget.api.rpc('set_group_member', {
      'p_group_id': widget.group['id'],
      'p_student_id': id,
      'p_active': false,
    });
    if (mounted) _reload();
  }

  Future<void> _inviteGroup() async {
    if (!await confirmSchoolAction(
      context,
      'Создать приглашение группы?',
      'Код выдаёт сервер. Он не назначает преподавательскую роль и не заменяет оплату курса.',
    )) {
      return;
    }
    final result = await widget.api.rpc('create_group_invite', {
      'p_group_id': widget.group['id'],
    });
    if (result is! Map ||
        result['code'] is! String ||
        !RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(result['code'] as String) ||
        DateTime.tryParse(result['expires_at']?.toString() ?? '') == null) {
      throw const IntegrationException('Сервер не выдал приглашение группы.');
    }
    if (mounted) {
      setState(
        () => _invite =
            '${result['code']}\nДействует до: ${schoolDate(result['expires_at'])}',
      );
    }
  }

  Future<List<Map<String, dynamic>>> _courseExercises() async {
    final levels = await widget.api.query(
      'levels',
      filters: {'course_id': widget.group['course_id']},
    );
    final books = await widget.api.query(
      'books',
      within: {'level_id': levels.map((r) => r['id']).toList()},
    );
    final units = await widget.api.query(
      'units',
      within: {'book_id': books.map((r) => r['id']).toList()},
    );
    final lessons = await widget.api.query(
      'lessons',
      within: {'unit_id': units.map((r) => r['id']).toList()},
      filters: {'status': 'published'},
    );
    return widget.api.query(
      'exercises',
      within: {'lesson_id': lessons.map((r) => r['id']).toList()},
      filters: {'published': true},
      order: 'title',
    );
  }

  Future<void> _assignment() async {
    final exercises = await _courseExercises();
    if (!mounted) return;
    final exercise = await pickSchoolRow(
      context,
      'Опубликованные упражнения курса',
      exercises,
    );
    if (exercise == null || !mounted) return;
    final values = await showSchoolForm(
      context,
      'Новое задание',
      [const SchoolField('title', 'Название задания', required: true)],
      initial: {'title': exercise['title']},
    );
    if (values == null || !mounted) return;
    final due = await chooseSchoolDate(
      context,
      'Срок сдачи (можно пропустить)',
    );
    await widget.api.rpc('create_assignment', {
      'p_group_id': widget.group['id'],
      'p_exercise_id': exercise['id'],
      'p_title': values['title'],
      'p_due_at': due?.toUtc().toIso8601String(),
    });
    if (mounted) _reload();
  }

  Future<void> _compose(List<Map<String, dynamic>> members) async {
    final recipient = await pickSchoolRow(
      context,
      'Получатель в этой группе',
      members,
    );
    if (recipient == null || !mounted) return;
    final values = await showSchoolForm(context, 'Сообщение ученице', [
      const SchoolField('title', 'Тема', required: true),
      const SchoolField(
        'text',
        'Текст сообщения',
        multiline: true,
        required: true,
      ),
    ]);
    if (values == null || !mounted) return;
    if (!await confirmSchoolAction(
      context,
      'Создать уведомление?',
      'Получатель: ${recipient['display_name']}. Оно будет записано в её аккаунт. Отправка push выполняется отдельной кнопкой.',
    )) {
      return;
    }
    final body = {'title': values['title'], 'text': values['text']};
    if (utf8.encode(jsonEncode(body)).length > 4096) {
      throw const IntegrationException(
        'Сообщение должно быть не больше 4096 байт.',
      );
    }
    _pendingCompose = {
      'p_student_id': recipient['student_id'],
      'p_group_id': widget.group['id'],
      'p_kind': 'teacher_message',
      'p_body': body,
      'p_idempotency_key': AcademyState.newId(),
      'recipient_name': recipient['display_name'],
    };
    await _retryCompose();
  }

  Future<void> _retryCompose() async {
    final pending = _pendingCompose;
    if (pending == null) return;
    final params = Map<String, dynamic>.from(pending)..remove('recipient_name');
    final row = await widget.api.rpc('create_notification', params);
    if (row is! Map || row['id'] is! String) {
      throw const IntegrationException(
        'Сервер не подтвердил создание уведомления.',
      );
    }
    final record = {
      ...Map<String, dynamic>.from(row),
      'recipient_name': pending['recipient_name'],
      'dispatch_state': 'unknown',
    };
    if (mounted) {
      setState(() {
        _notifications.add(record);
        _pendingCompose = null;
      });
    }
    await _dispatchStatus(record);
  }

  Future<void> _dispatch(Map<String, dynamic> row) async {
    await widget.api.guard();
    final summary = await widget.api.backend.invoke('dispatch-notification', {
      'notification_id': row['id'],
    });
    if (summary['notification_id'] != row['id'] ||
        summary['state'] is! String) {
      throw const IntegrationException(
        'Сервис не подтвердил состояние отправки.',
      );
    }
    if (mounted) {
      setState(
        () => row.addAll({
          'dispatch_state': summary['state'],
          'accepted_count': summary['accepted_count'],
          'failed_count': summary['failed_count'],
        }),
      );
    }
  }

  Future<void> _dispatchStatus(Map<String, dynamic> row) async {
    final summary = await widget.api.rpc('notification_dispatch_status', {
      'p_notification_id': row['id'],
    });
    if (summary is! Map) {
      throw const IntegrationException(
        'Не удалось получить состояние отправки.',
      );
    }
    if (mounted) {
      setState(
        () => row.addAll({
          'dispatch_state': summary['state'],
          'accepted_count': summary['accepted_count'],
          'failed_count': summary['failed_count'],
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.group['title'].toString())),
    body: SchoolAccess(
      api: widget.api,
      builder: (role) => FutureBuilder<Map<String, dynamic>>(
        future: _future ??= _load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return schoolErrorCard(snapshot.error!, _reload);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final members = schoolMaps(snapshot.data!['members']),
              assignments = schoolMaps(snapshot.data!['assignments']);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              status,
              Text(
                'Ученицы группы',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (role == ServerRole.admin)
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: busy ? null : () => run(() => _add(role)),
                      child: const Text('Добавить из записанных на курс'),
                    ),
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => run(() => _add(role, byId: true)),
                      child: const Text('Добавить по UUID'),
                    ),
                  ],
                )
              else
                const Text(
                  'Изменение состава группы выполняет серверный администратор.',
                ),
              if (members.isEmpty) const Text('Активных участниц нет.'),
              for (final member in members)
                ListTile(
                  title: Text(member['display_name'].toString()),
                  subtitle: Text(member['student_id'].toString()),
                  trailing: role == ServerRole.admin
                      ? IconButton(
                          onPressed: busy
                              ? null
                              : () => run(
                                  () => _removeMember(
                                    member['student_id'] as String,
                                  ),
                                ),
                          icon: const Icon(Icons.person_remove_outlined),
                          tooltip: 'Убрать из группы',
                        )
                      : null,
                ),
              OutlinedButton(
                onPressed: busy ? null : () => run(_inviteGroup),
                child: const Text('Создать приглашение группы'),
              ),
              if (_invite != null) SelectableText(_invite!),
              const Divider(height: 32),
              Text('Задания', style: Theme.of(context).textTheme.titleLarge),
              FilledButton(
                onPressed: busy ? null : () => run(_assignment),
                child: const Text('Назначить упражнение'),
              ),
              for (final assignment in assignments)
                ListTile(
                  title: Text(assignment['title'].toString()),
                  subtitle: Text('Срок: ${schoolDate(assignment['due_at'])}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: busy
                      ? null
                      : () => run(() async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => SchoolSubmissionPage(
                                api: widget.api,
                                assignment: assignment,
                              ),
                            ),
                          );
                          if (mounted) _reload();
                        }),
                ),
              if (assignments.isEmpty) const Text('Назначенных заданий нет.'),
              const Divider(height: 32),
              Text(
                'Уведомления',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              OutlinedButton(
                onPressed: busy || members.isEmpty || _pendingCompose != null
                    ? null
                    : () => run(() => _compose(members)),
                child: const Text('Написать ученице группы'),
              ),
              if (_pendingCompose != null)
                OutlinedButton(
                  onPressed: busy ? null : () => run(_retryCompose),
                  child: const Text('Повторить создание уведомления'),
                ),
              for (final notification in _notifications)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Записано в аккаунт: ${notification['recipient_name']}',
                        ),
                        Text(
                          (notification['body'] as Map?)?['title']
                                  ?.toString() ??
                              '',
                        ),
                        Text(
                          'Состояние FCM: ${notification['dispatch_state']}',
                        ),
                        if (notification['accepted_count'] != null)
                          Text(
                            'Принято FCM: ${notification['accepted_count']}; отклонено: ${notification['failed_count']}. Это не подтверждение доставки на устройство.',
                          ),
                        SelectableText('ID: ${notification['id']}'),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed:
                                  busy ||
                                      notification['dispatch_state'] !=
                                          'not_dispatched'
                                  ? null
                                  : () => run(() => _dispatch(notification)),
                              child: const Text('Передать в FCM'),
                            ),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => run(
                                      () => _dispatchStatus(notification),
                                    ),
                              child: const Text('Проверить состояние'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              OutlinedButton(
                onPressed: busy ? null : _reload,
                child: const Text('Обновить группу'),
              ),
            ],
          );
        },
      ),
    ),
  );
}
