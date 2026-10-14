import 'package:flutter/material.dart';

import '../../core/academy_state.dart';
import '../../ui/components.dart';
import '../../ui/design_tokens.dart';
import 'demo_school_store.dart';

String _readableDate(Object? value) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (date == null) return 'Без срока';
  String part(int v) => v.toString().padLeft(2, '0');
  return '${part(date.day)}.${part(date.month)}.${date.year} · ${part(date.hour)}:${part(date.minute)}';
}

class DemoStudentSchoolScreen extends StatefulWidget {
  const DemoStudentSchoolScreen({
    super.key, required this.school, required this.learning,
  });
  final DemoSchoolStore school;
  final AcademyState learning;

  @override
  State<DemoStudentSchoolScreen> createState() => _DemoStudentSchoolScreenState();
}

class _DemoStudentSchoolScreenState extends State<DemoStudentSchoolScreen> {
  String tab = 'homework';

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
    final send = await showDialog<bool>(
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
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton.icon(
            icon: const Icon(Icons.send_outlined),
            onPressed: () => Navigator.pop(ctx, true),
            label: const Text('Отправить учительнице'),
          ),
        ],
      ),
    );
    if (send == true && mounted) {
      await guardedAction(context, () => widget.school.submit(
        assignmentId: assignment['id'] as String,
        studentId: studentId, answer: controller.text,
      ));
    }
    controller.dispose();
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
          const SizedBox(height: 10),
          Text(switch (status) {
            'submitted' => 'Отправлено · ожидает проверки',
            'graded' => 'Проверено · ${submission?['grade']}/100',
            'revision_requested' => 'Возвращено на исправление',
            _ => 'Ожидает выполнения',
          }, style: const TextStyle(
            color: DesignTokens.deepOlive, fontWeight: FontWeight.w700)),
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
                const Text('Деморежим не передаёт видео и звук. '
                    'Реальный эфир требует подключения LiveKit и сервера.',
                    style: TextStyle(fontSize: 12, color: DesignTokens.secondary)),
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
