import 'package:flutter/material.dart';

import '../../core/academy_state.dart';
import '../../ui/components.dart';
import '../../ui/design_tokens.dart';
import 'demo_school_store.dart';
import 'demo_voice_homework.dart';

String _readableDate(Object? value) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (date == null) return 'Без срока';
  String part(int v) => v.toString().padLeft(2, '0');
  return '${part(date.day)}.${part(date.month)}.${date.year} · ${part(date.hour)}:${part(date.minute)}';
}

class DemoStudentSchoolScreen extends StatefulWidget {
  const DemoStudentSchoolScreen({
    super.key, required this.school, required this.learning,
    this.initialTab = 'homework',
  });
  final DemoSchoolStore school;
  final AcademyState learning;
  final String initialTab;

  @override
  State<DemoStudentSchoolScreen> createState() => _DemoStudentSchoolScreenState();
}

class _DemoStudentSchoolScreenState extends State<DemoStudentSchoolScreen> {
  late String tab = widget.initialTab;

  Future<void> _changeStudent() async {
    final id = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: DesignTokens.cardSurface,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Выберите демоученицу',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              const Text('Переключение нужно для проверки адресных и групповых заданий.',
                  style: TextStyle(fontSize: 12, color: DesignTokens.secondary)),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * .52),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final pupil in widget.school.students)
                      ListTile(
                        title: Text(pupil['name'] as String),
                        subtitle: Text(widget.school.groupName(
                            pupil['group_id'] as String)),
                        leading: Icon(
                          pupil['id'] == widget.school.currentStudentId
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: DesignTokens.deepOlive,
                        ),
                        onTap: () => Navigator.pop(ctx, pupil['id'] as String),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (id != null && mounted) {
      await guardedAction(context, () => widget.school.selectStudent(id));
    }
  }

  Future<void> _answer(Map<String, dynamic> assignment) async {
    final studentId = widget.school.currentStudentId;
    final previous = widget.school.submissionFor(
        assignment['id'] as String, studentId);
    final controller = TextEditingController(
      text: previous?['answer'] as String? ?? '',
    );
    final send = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(assignment['title'] as String),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(assignment['instructions'] as String? ?? ''),
                const SizedBox(height: 12),
                Text('Срок: ${_readableDate(assignment['due_at'])}',
                  style: const TextStyle(fontSize: 12, color: DesignTokens.secondary)),
                const SizedBox(height: 16),
                TextField(
                  controller: controller, autofocus: true,
                  maxLines: 6, maxLength: 4000,
                  decoration: const InputDecoration(
                    labelText: 'Ваш ответ',
                    hintText: 'Напишите ответ на арабском или русском языке'),
                ),
                if (previous?['status'] == 'revision_requested')
                  Text('Исправление по комментарию: ${previous?['feedback']}'),
                const SizedBox(height: 8),
                const Text('Демо: ответ сохраняется на этом телефоне и будет '
                    'доступен в кабинете учительницы.',
                    style: TextStyle(fontSize: 12, color: DesignTokens.secondary)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена')),
          TextButton.icon(
            icon: const Icon(Icons.mic_none_outlined),
            onPressed: () => Navigator.pop(ctx, 'voice'),
            label: const Text('Голосом'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.send_outlined),
            onPressed: () => Navigator.pop(ctx, 'text'),
            label: const Text('Отправить'),
          ),
        ],
      ),
    );
    if (send == null || !mounted) return;
    String? audioPath;
    if (send == 'voice') {
      audioPath = await Navigator.push<String>(
        context,
        MaterialPageRoute<String>(builder: (_) =>
          const DemoVoiceRecorderScreen(title: 'Ответ ученицы · аудио')),
      );
      if (audioPath == null || !mounted) return;
    }
    if (!mounted) return;
    await guardedAction(context, () => widget.school.submit(
      assignmentId: assignment['id'] as String,
      studentId: studentId,
      answer: send == 'text' ? controller.text : '',
      audioPath: audioPath,
    ));
  }

  Widget _assignment(Map<String, dynamic> row, String studentId) {
    final submission = widget.school.submissionFor(
        row['id'] as String, studentId);
    final status = submission?['status'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.assignment_outlined, color: DesignTokens.deepOlive),
            const SizedBox(width: 9),
            Expanded(child: Text(row['title'] as String,
                style: Theme.of(context).textTheme.titleMedium)),
          ]),
          const SizedBox(height: 8),
          Text(row['instructions'] as String),
          const SizedBox(height: 8),
          Text(row['student_id'] == null ? 'Для всей группы' :
              'Индивидуальное задание',
              style: const TextStyle(fontSize: 12, color: DesignTokens.secondary)),
          Text('Срок: ${_readableDate(row['due_at'])}',
              style: const TextStyle(fontSize: 12, color: DesignTokens.secondary)),
          if ((row['audio_path'] as String?)?.isNotEmpty == true)
            DemoVoicePlayback(
              path: row['audio_path'] as String?,
              title: 'Прослушать голосовое условие учительницы',
            ),
          const SizedBox(height: 10),
          Text(switch (status) {
            'submitted' => 'Отправлено · ожидает проверки',
            'graded' => 'Проверено · ${submission?['grade']}/100',
            'revision_requested' => 'Возвращено на исправление',
            _ => 'Ожидает выполнения',
          }, style: const TextStyle(
            color: DesignTokens.deepOlive, fontWeight: FontWeight.w700)),
          if ((submission?['audio_path'] as String?)?.isNotEmpty == true)
            DemoVoicePlayback(
              path: submission?['audio_path'] as String?,
              title: 'Прослушать свой голосовой ответ',
            ),
          if ((submission?['feedback_audio_path'] as String?)?.isNotEmpty == true)
            DemoVoicePlayback(
              path: submission?['feedback_audio_path'] as String?,
              title: 'Прослушать голосовой комментарий учительницы',
            ),
          if ((submission?['feedback'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text('Комментарий: ${submission?['feedback']}'),
          ],
          if (submission?['answer'] is String) ...[
            const SizedBox(height: 6),
            Text('Ваш ответ: ${submission?['answer']}',
              maxLines: 4, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: Icon(status == null ? Icons.edit_note : Icons.edit_outlined),
            label: Text(status == null ? 'Выполнить и отправить' :
                'Просмотреть или исправить'),
            onPressed: () => _answer(row),
          ),
        ],
      )),
    );
  }

  Widget _homework(String id) {
    final assigned = widget.school.homeworkFor(id);
    final delivered = assigned.where((a) => widget.school.submissionFor(
        a['id'] as String, id) != null).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Домашние задания · отправлено $delivered из ${assigned.length}',
        style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      if (assigned.isEmpty)
        const EmptyState(title: 'Заданий пока нет',
          message: 'Учительница может назначить работу группе или лично вам.'),
      for (final row in assigned) _assignment(row, id),
    ]);
  }

  Widget _schedule(String id) {
    final list = widget.school.sessionsFor(id);
    final reminders = widget.school.dueReminders(id, DateTime.now());
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (reminders.isNotEmpty)
        Panel(child: Text('Пора на занятие: ${reminders.first['title']}',
          style: const TextStyle(color: DesignTokens.deepOlive,
            fontWeight: FontWeight.w700))),
      if (reminders.isNotEmpty) const SizedBox(height: 12),
      if (list.isEmpty)
        const EmptyState(title: 'Эфиры ещё не запланированы',
          message: 'После создания встречи появится дата и время напоминания.'),
      for (final row in list)
        Padding(padding: const EdgeInsets.only(bottom: 12),
          child: Panel(child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(row['title'] as String,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 5),
              Text('Начало: ${_readableDate(row['starts_at'])}'),
              Text('Напоминание за ${row['remind_minutes']} минут'),
              const SizedBox(height: 6),
              Text(switch (row['status']) {
                'live' => 'Демоэфир идёт',
                'ended' => 'Эфир завершён',
                _ => 'Запланирован',
              }, style: const TextStyle(color: DesignTokens.deepOlive)),
              if (row['status'] == 'live') ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => Navigator.push(context,
                    MaterialPageRoute<void>(builder: (_) => DemoLiveRoomScreen(
                      school: widget.school, sessionId: row['id'] as String,
                      isTeacher: false,
                    ))),
                  icon: const Icon(Icons.meeting_room_outlined),
                  label: const Text('Войти в демокомнату'),
                ),
              ],
            ],
          )),
        ),
    ]);
  }

  Widget _notices(String id) {
    final announcements = widget.school.announcementsFor(id);
    final reminders = widget.school.dueReminders(id, DateTime.now());
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final session in reminders)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Panel(child: ListTile(
            leading: const Icon(Icons.alarm_on_outlined,
              color: DesignTokens.deepOlive),
            title: Text('Скоро эфир: ${session['title']}'),
            subtitle: Text('Начало: ${_readableDate(session['starts_at'])}'),
          )),
        ),
      for (final row in announcements)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Panel(child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(row['title'] as String,
                style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(row['text'] as String),
              const SizedBox(height: 8),
              Text(_readableDate(row['created_at']),
                style: const TextStyle(fontSize: 12,
                  color: DesignTokens.secondary)),
            ],
          )),
        ),
      if (announcements.isEmpty && reminders.isEmpty)
        const EmptyState(title: 'Нет уведомлений',
          message: 'Здесь появятся сообщения учительницы и напоминания при открытии приложения.'),
      const Text('В деморежиме уведомления появляются только внутри приложения. '
          'Фоновые push-сообщения не отправляются.',
          style: TextStyle(fontSize: 12, color: DesignTokens.secondary)),
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Моя школа · демо')),
    body: AnimatedBuilder(
      animation: widget.school,
      builder: (context, _) {
        final studentId = widget.school.currentStudentId;
        final student = widget.school.student(studentId);
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 150),
          children: [
            Panel(child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Кабинет ученицы',
                  style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 7),
                Text(student?['name'] as String? ?? ''),
                Text(widget.school.groupName(
                    student?['group_id'] as String? ?? ''),
                  style: const TextStyle(color: DesignTokens.secondary)),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _changeStudent,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Выбрать демоученицу'),
                ),
              ],
            )),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final item in [
                  ('homework', 'Задания', Icons.assignment_outlined),
                  ('sessions', 'Расписание', Icons.video_call_outlined),
                  ('notices', 'Уведомления', Icons.notifications_outlined),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(item.$2),
                      avatar: Icon(item.$3, size: 18),
                      selected: tab == item.$1,
                      onSelected: (_) => setState(() => tab = item.$1),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 18),
            if (tab == 'homework') _homework(studentId),
            if (tab == 'sessions') _schedule(studentId),
            if (tab == 'notices') _notices(studentId),
          ],
        );
      },
    ),
  );
}

 
/// Interactive LOCAL room: chat and raised hands only; no streaming or push.
class DemoLiveRoomScreen extends StatefulWidget {
  const DemoLiveRoomScreen({
    super.key, required this.school, required this.sessionId,
    required this.isTeacher,
  });
  final DemoSchoolStore school;
  final String sessionId;
  final bool isTeacher;
  @override
  State<DemoLiveRoomScreen> createState() => _DemoLiveRoomScreenState();
}

class _DemoLiveRoomScreenState extends State<DemoLiveRoomScreen> {
  final _message = TextEditingController();
  bool _sending = false;
  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || _message.text.trim().isEmpty) return;
    setState(() => _sending = true);
    final text = _message.text;
    try {
      await widget.school.postLiveMessage(
        sessionId: widget.sessionId,
        authorId: widget.isTeacher
            ? 'teacher' : widget.school.currentStudentId,
        text: text,
      );
      _message.clear();
    } catch (error) {
      if (mounted) notice(context, error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Учебный эфир · демо')),
    body: AnimatedBuilder(
      animation: widget.school,
      builder: (context, _) {
        final matches = widget.school.sessions.where(
          (row) => row['id'] == widget.sessionId);
        if (matches.isEmpty) {
          return const Center(child: Text('Эфир не найден.'));
        }
        final row = matches.first;
        final live = row['status'] == 'live';
        final hands = List<String>.from(
          row['raised_hands'] as List? ?? const [],
        );
        final studentId = widget.school.currentStudentId;
        final messages = row['messages'] as List? ?? const [];
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 150),
          children: [
            Panel(child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(row['title'] as String,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(live ? 'Демоэфир открыт' : 'Занятие завершено',
                  style: const TextStyle(
                    color: DesignTokens.deepOlive,
                    fontWeight: FontWeight.w800,
                  )),
                const SizedBox(height: 10),
                const Icon(Icons.video_call_outlined, size: 70,
                  color: DesignTokens.sage),
                const Text('Здесь можно проверить чат и поднятие руки. '
                    'Реальная передача видео и звука отсутствует.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12, color: DesignTokens.secondary,
                    )),
              ],
            )),
            const SizedBox(height: 12),
            if (widget.isTeacher) ...[
              Text('Подняли руку: ${hands.length}',
                style: Theme.of(context).textTheme.titleMedium),
              if (hands.isNotEmpty)
                Text(hands.map(widget.school.studentName).join(', ')),
            ] else if (live) ...[
              OutlinedButton.icon(
                onPressed: () => guardedAction(context, () =>
                    widget.school.toggleLiveHand(
                      sessionId: widget.sessionId, studentId: studentId,
                    )),
                icon: Icon(hands.contains(studentId)
                    ? Icons.pan_tool : Icons.pan_tool_outlined),
                label: Text(hands.contains(studentId)
                    ? 'Опустить руку' : 'Поднять руку'),
              ),
            ],
            const SectionTitle('Чат занятия'),
            if (messages.isEmpty)
              const Text('Сообщений пока нет.'),
            for (final value in messages)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Panel(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text((value as Map)['author_id'] == 'teacher'
                        ? 'Учительница'
                        : widget.school.studentName(
                            value['author_id'] as String),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: DesignTokens.deepOlive,
                      )),
                    const SizedBox(height: 4),
                    Text(value['text'] as String),
                    const SizedBox(height: 3),
                    Text(_readableDate(value['at']),
                      style: const TextStyle(
                        color: DesignTokens.secondary, fontSize: 11,
                      )),
                  ],
                )),
              ),
            if (live) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _message,
                maxLength: 1000,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Сообщение в чат',
                  prefixIcon: Icon(Icons.chat_bubble_outline),
                ),
              ),
              FilledButton.icon(
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.send_outlined),
                label: const Text('Отправить в чат'),
              ),
            ],
          ],
        );
      },
    ),
  );
}
