import 'package:flutter/material.dart';

import '../../core/academy_state.dart';
import '../../services/backend_service.dart';
import '../../ui/components.dart';
import '../../ui/design_tokens.dart';
import 'demo_school_store.dart';
import 'teacher_dashboard.dart';

String _demoDate(Object? input) {
  final date = DateTime.tryParse(input?.toString() ?? '')?.toLocal();
  if (date == null) return 'Не указано';
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year} · ${two(date.hour)}:${two(date.minute)}';
}

String _demoStatus(String? value) => switch (value) {
  'submitted' => 'Ожидает проверки',
  'graded' => 'Проверено',
  'revision_requested' => 'Вернуть на исправление',
  'scheduled' => 'Запланирован',
  'live' => 'Демоэфир начат',
  'ended' => 'Завершён',
  _ => 'Не сдано',
};

class DemoSchoolScreen extends StatefulWidget {
  const DemoSchoolScreen({
    super.key,
    required this.school,
    required this.learning,
    required this.backend,
  });
  final DemoSchoolStore school;
  final AcademyState learning;
  final BackendService backend;

  @override
  State<DemoSchoolScreen> createState() => _DemoSchoolScreenState();
}

class _DemoSchoolScreenState extends State<DemoSchoolScreen> {
  String section = 'groups';
  DemoSchoolStore get school => widget.school;
  Future<void> _open(Widget page) => Navigator.push(
      context, MaterialPageRoute<void>(builder: (_) => page));

  Future<void> _addGroup() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Создать учебную группу'),
        content: TextField(
          controller: controller, autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(labelText: 'Название группы'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Создать')),
        ],
      ),
    );
    if (!mounted) return;
    if (value != null) {
      await guardedAction(context, () => school.createGroup(value));
    }
    controller.dispose();
  }

  Future<void> _addStudent(String groupId) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Добавить ученицу · демо'),
        content: TextField(
          controller: controller, autofocus: true, maxLength: 60,
          decoration: const InputDecoration(labelText: 'Имя ученицы'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Добавить')),
        ],
      ),
    );
    if (!mounted) return;
    if (name != null) {
      await guardedAction(context, () => school.addStudent(groupId, name));
    }
    controller.dispose();
  }

  Future<void> _createAssignment({String? groupId, String? studentId}) async {
    if (school.groups.isEmpty) {
      notice(context, 'Сначала создайте группу.');
      return;
    }
    final title = TextEditingController();
    final instructions = TextEditingController();
    String selectedGroup = groupId ?? school.groups.first['id'] as String;
    String? pupil = studentId;
    DateTime? due;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, change) => AlertDialog(
          title: const Text('Новое домашнее задание'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title, maxLength: 100,
                    decoration: const InputDecoration(labelText: 'Название задания'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: instructions, maxLines: 4, maxLength: 2000,
                    decoration: const InputDecoration(labelText: 'Что выполнить'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedGroup, isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Группа'),
                    items: [
                      for (final group in school.groups)
                        DropdownMenuItem<String>(
                          value: group['id'] as String,
                          child: Text(group['name'] as String, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) change(() {
                        selectedGroup = value;
                        pupil = null;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    key: ValueKey('assignment-scope-$selectedGroup'),
                    initialValue: pupil ?? 'all', isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Кому назначить'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: 'all', child: Text('Всем ученицам группы'),
                      ),
                      for (final student in school.members(selectedGroup))
                        DropdownMenuItem<String>(
                          value: student['id'] as String,
                          child: Text(student['name'] as String),
                        ),
                    ],
                    onChanged: (value) => change(() => pupil =
                        value == 'all' ? null : value),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final day = await showDatePicker(
                        context: ctx, initialDate: now,
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 365)),
                      );
                      if (day == null || !ctx.mounted) return;
                      final time = await showTimePicker(
                        context: ctx, initialTime: const TimeOfDay(hour: 18, minute: 0),
                      );
                      if (time != null && ctx.mounted) {
                        change(() => due = DateTime(
                          day.year, day.month, day.day, time.hour, time.minute));
                      }
                    },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(due == null ? 'Добавить срок (необязательно)' : _demoDate(due!.toIso8601String())),
                  ),
                  const SizedBox(height: 8),
                  const Text('Демо: ученицы увидят задание на этом устройстве.',
                      style: TextStyle(fontSize: 12, color: DesignTokens.secondary)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Назначить'),
            ),
          ],
        ),
      ),
    );
    if (result == true && mounted) {
      await guardedAction(context, () => school.createAssignment(
        title: title.text, instructions: instructions.text,
        groupId: selectedGroup, studentId: pupil, due: due,
      ));
    }
    title.dispose();
    instructions.dispose();
  }

  Future<void> _scheduleLive() async {
    if (school.groups.isEmpty) return;
    final title = TextEditingController();
    var groupId = 'all';
    var duration = 60;
    var reminder = 30;
    DateTime startsAt = DateTime.now().add(const Duration(hours: 1));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, change) => AlertDialog(
          title: const Text('Создать прямой эфир · демо'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: title, maxLength: 100,
                    decoration: const InputDecoration(labelText: 'Тема занятия')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: groupId, isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Участницы'),
                    items: [
                      const DropdownMenuItem(value: 'all', child: Text('Все группы')),
                      for (final g in school.groups)
                        DropdownMenuItem<String>(
                          value: g['id'] as String,
                          child: Text(g['name'] as String, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) { if (v != null) change(() => groupId = v); },
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.schedule),
                    label: Text('Начало: ${_demoDate(startsAt.toIso8601String())}'),
                    onPressed: () async {
                      final day = await showDatePicker(
                        context: ctx, initialDate: startsAt,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (day == null || !ctx.mounted) return;
                      final time = await showTimePicker(
                        context: ctx, initialTime: TimeOfDay.fromDateTime(startsAt),
                      );
                      if (time == null || !ctx.mounted) return;
                      change(() => startsAt = DateTime(day.year, day.month,
                          day.day, time.hour, time.minute));
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: duration,
                    decoration: const InputDecoration(labelText: 'Длительность'),
                    items: [
                      for (final v in [30, 45, 60, 90, 120])
                        DropdownMenuItem(value: v, child: Text('$v минут')),
                    ],
                    onChanged: (v) { if (v != null) change(() => duration = v); },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: reminder,
                    decoration: const InputDecoration(labelText: 'Напомнить до эфира'),
                    isExpanded: true,
                    items: [
                      for (final v in [5, 10, 15, 30, 60, 120, 180, 360, 1440])
                        DropdownMenuItem(
                          value: v,
                          child: Text(v < 60 ? '$v минут' :
                              v == 1440 ? '24 часа' : '${v ~/ 60} ч'),
                        ),
                    ],
                    onChanged: (v) { if (v != null) change(() => reminder = v); },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Демо: расписание и напоминание отображаются внутри приложения. '
                    'Видео и системные push-уведомления не отправляются.',
                    style: TextStyle(fontSize: 12, color: DesignTokens.secondary),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Запланировать')),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      await guardedAction(context, () => school.scheduleLive(
        title: title.text, groupId: groupId, startsAt: startsAt,
        durationMinutes: duration, remindMinutes: reminder,
      ));
    }
    title.dispose();
  }

  Future<void> _announce() async {
    final title = TextEditingController();
    final message = TextEditingController();
    String groupId = 'all';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, change) => AlertDialog(
          title: const Text('Уведомление ученицам'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: title, maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Заголовок')),
                const SizedBox(height: 10),
                TextField(controller: message, maxLines: 3, maxLength: 1000,
                  decoration: const InputDecoration(labelText: 'Текст сообщения')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: groupId, isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Получатели'),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('Все ученицы')),
                    for (final g in school.groups)
                      DropdownMenuItem<String>(
                        value: g['id'] as String,
                        child: Text(g['name'] as String, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) { if (v != null) change(() => groupId = v); },
                ),
                const SizedBox(height: 8),
                const Text('Появится во входящих учениц деморежима на этом телефоне.',
                  style: TextStyle(fontSize: 12, color: DesignTokens.secondary)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Разослать · демо')),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      await guardedAction(context, () => school.announce(
        title: title.text, text: message.text, groupId: groupId,
      ));
    }
    title.dispose();
    message.dispose();
  }

  Widget _groups() => Column(
    children: [
      for (final group in school.groups)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Panel(
            padding: EdgeInsets.zero,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              leading: const Icon(Icons.groups_2_outlined,
                color: DesignTokens.deepOlive, size: 34),
              title: Text(group['name'] as String,
                style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${school.members(group['id'] as String).length} учениц · ${group['level']}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(_DemoGroupDetails(
                school: school, learning: widget.learning,
                groupId: group['id'] as String,
                addStudent: () => _addStudent(group['id'] as String),
                newAssignment: () => _createAssignment(groupId: group['id'] as String),
              )),
            ),
          ),
        ),
    ],
  );

  Widget _submissions() {
    final rows = school.submissions.reversed.toList();
    return Column(
      children: [
        if (rows.isEmpty)
          const EmptyState(title: 'Работ пока нет',
              message: 'Отправьте ответ из кабинета ученицы. Он появится здесь.'),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Panel(padding: EdgeInsets.zero,
              child: ListTile(
                title: Text(school.studentName(row['student_id'] as String)),
                subtitle: Text('${_assignmentTitle(row['assignment_id'])} · ${_demoStatus(row['status'] as String?)}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(_DemoSubmissionDetails(
                    school: school, rowId: row['id'] as String)),
              ),
            ),
          ),
      ],
    );
  }

  String _assignmentTitle(Object? id) {
    for (final assignment in school.assignments) {
      if (assignment['id'] == id) return assignment['title'] as String;
    }
    return 'Задание';
  }

  Widget _sessions() => Column(
    children: [
      for (final row in school.sessions.reversed)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Panel(child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(row['title'] as String,
                style: Theme.of(context).textTheme.titleMedium),
              Text('${_demoDate(row['starts_at'])} · ${row['duration_minutes']} мин'),
              Text(row['group_id'] == 'all' ? 'Все группы' :
                  school.groupName(row['group_id'] as String)),
              Text('Напоминание за ${row['remind_minutes']} минут · ${_demoStatus(row['status'] as String?)}'),
              const SizedBox(height: 8),
              if (row['status'] == 'scheduled')
                OutlinedButton.icon(
                  onPressed: () => guardedAction(context, () =>
                      school.setLiveStatus(row['id'] as String, 'live')),
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Начать демонстрацию эфира'),
                ),
              if (row['status'] == 'live')
                OutlinedButton(
                  onPressed: () => guardedAction(context, () =>
                      school.setLiveStatus(row['id'] as String, 'ended')),
                  child: const Text('Завершить демонстрацию'),
                ),
            ],
          )),
        ),
      if (school.sessions.isEmpty)
        const EmptyState(title: 'Нет запланированных эфиров',
            message: 'Создайте встречу и выберите время оповещения.'),
    ],
  );

  Widget _notices() => Column(
    children: [
      for (final row in school.announcements.reversed)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Panel(child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(row['title'] as String,
                style: Theme.of(context).textTheme.titleMedium),
              Text(row['text'] as String),
              const SizedBox(height: 6),
              Text(row['group_id'] == 'all' ? 'Все ученицы' :
                  school.groupName(row['group_id'] as String),
                style: const TextStyle(fontSize: 12, color: DesignTokens.secondary)),
            ],
          )),
        ),
      if (school.announcements.isEmpty)
        const EmptyState(title: 'Нет уведомлений',
            message: 'Создайте сообщение для всех или отдельной группы.'),
    ],
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: school,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 150),
      children: [
        Text('Кабинет учительницы',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('ДЕМОРЕЖИМ · данные сохраняются только на этом устройстве. '
            'Отправка другим телефонам отключена.',
            style: TextStyle(fontSize: 12, color: DesignTokens.secondary)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _Metric(label: 'Группы', value: '${school.groups.length}')),
          const SizedBox(width: 10),
          Expanded(child: _Metric(label: 'Ученицы', value: '${school.students.length}')),
          const SizedBox(width: 10),
          Expanded(child: _Metric(label: 'Работы', value: '${school.submissions.length}')),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(onPressed: () => _createAssignment(),
            icon: const Icon(Icons.post_add_outlined), label: const Text('Задание')),
          OutlinedButton.icon(onPressed: _scheduleLive,
            icon: const Icon(Icons.videocam_outlined), label: const Text('Эфир')),
          OutlinedButton.icon(onPressed: _announce,
            icon: const Icon(Icons.notifications_active_outlined), label: const Text('Оповещение')),
          OutlinedButton.icon(onPressed: _addGroup,
            icon: const Icon(Icons.group_add_outlined), label: const Text('Группа')),
        ]),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          icon: const Icon(Icons.edit_note_outlined),
          label: const Text('Редактор уроков и материалов'),
          onPressed: () => _open(Scaffold(
            appBar: AppBar(title: const Text('Редактор учительницы')),
            body: TeacherDashboard(state: widget.learning, backend: widget.backend),
          )),
        ),
        const SizedBox(height: 18),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final tab in [
              ('groups', 'Группы', Icons.groups_outlined),
              ('submissions', 'Работы', Icons.fact_check_outlined),
              ('sessions', 'Эфиры', Icons.video_call_outlined),
              ('notices', 'Уведомления', Icons.notifications_outlined),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: Icon(tab.$3, size: 18, color: DesignTokens.deepOlive),
                  label: Text(tab.$2), selected: section == tab.$1,
                  onSelected: (_) => setState(() => section = tab.$1),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 14),
        if (section == 'groups') _groups(),
        if (section == 'submissions') _submissions(),
        if (section == 'sessions') _sessions(),
        if (section == 'notices') _notices(),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Panel(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      child: Column(children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: DesignTokens.secondary)),
      ]),
  );
}

class _DemoGroupDetails extends StatelessWidget {
  const _DemoGroupDetails({
    required this.school, required this.learning, required this.groupId,
    required this.addStudent, required this.newAssignment,
  });
  final DemoSchoolStore school;
  final AcademyState learning;
  final String groupId;
  final VoidCallback addStudent;
  final VoidCallback newAssignment;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(school.groupName(groupId))),
    body: AnimatedBuilder(
      animation: school,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 150),
        children: [
          Text('Состав группы', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(icon: const Icon(Icons.person_add_alt_1_outlined),
              onPressed: addStudent, label: const Text('Добавить ученицу')),
            OutlinedButton.icon(icon: const Icon(Icons.assignment_outlined),
              onPressed: newAssignment, label: const Text('Задание группе')),
          ]),
          const SizedBox(height: 16),
          for (final pupil in school.members(groupId))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: DesignTokens.beige,
                    child: Icon(Icons.person_outline, color: DesignTokens.emerald)),
                  title: Text(pupil['name'] as String),
                  subtitle: Text('${school.assignmentsForStudent(pupil['id'] as String).length} заданий'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute<void>(builder: (_) => DemoStudentDetails(
                      school: school, learning: learning,
                      studentId: pupil['id'] as String,
                    ))),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class DemoStudentDetails extends StatelessWidget {
  const DemoStudentDetails({
    super.key,
    required this.school, required this.learning, required this.studentId,
  });
  final DemoSchoolStore school;
  final AcademyState learning;
  final String studentId;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(school.studentName(studentId))),
    body: AnimatedBuilder(
      animation: Listenable.merge([school, learning]),
      builder: (context, _) {
        final assigned = school.homeworkFor(studentId);
        final finished = <String>{
          for (final row in school.studentResults(studentId))
            row['lesson_id'] as String,
          if (studentId == 's1') ...learning.completed,
        };
        final catalog = learning.allLessons;
        final valid = finished.where(
          (id) => catalog.any((lesson) => lesson['id'] == id),
        ).length;
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 150),
          children: [
            Panel(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(school.groupName(school.student(studentId)?['group_id'] as String? ?? '')),
                const SizedBox(height: 12),
                Text('Пройдено уроков: $valid из ${catalog.length}',
                  style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: catalog.isEmpty ? 0 : valid / catalog.length,
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(8),
                  backgroundColor: DesignTokens.beige,
                  color: DesignTokens.olive,
                ),
                const SizedBox(height: 10),
                const Text('Демоученицы используют локальные результаты. '
                  'У первой ученицы также виден реальный прогресс на этом устройстве.',
                  style: TextStyle(fontSize: 12, color: DesignTokens.secondary)),
              ],
            )),
            const SectionTitle('Результаты уроков'),
            if (finished.isEmpty)
              const Text('Завершённых уроков пока нет.'),
            for (final id in finished.take(12))
              ListTile(
                leading: const Icon(Icons.check_circle_outline,
                    color: DesignTokens.olive),
                title: Text(catalog.where((x) => x['id'] == id).isEmpty ? id :
                    catalog.firstWhere((x) => x['id'] == id)['title'].toString()),
                subtitle: const Text('Завершён'),
              ),
            const SectionTitle('Домашние задания и проверки'),
            for (final assignment in assigned)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(padding: EdgeInsets.zero,
                  child: ListTile(
                    title: Text(assignment['title'] as String),
                    subtitle: Text(_demoStatus(school.submissionFor(
                        assignment['id'] as String, studentId)?['status'] as String?)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      final submission = school.submissionFor(
                          assignment['id'] as String, studentId);
                      if (submission == null) {
                        showDialog<void>(context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Ответ ещё не получен'),
                            content: const Text('Ученица может отправить работу '
                                'из своего демо-кабинета.'),
                            actions: [TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Закрыть'))],
                          ));
                        return;
                      }
                      Navigator.push(context, MaterialPageRoute<void>(
                        builder: (_) => _DemoSubmissionDetails(
                          school: school, rowId: submission['id'] as String)));
                    },
                  )),
              ),
            if (assigned.isEmpty) const Text('Для ученицы нет заданий.'),
          ],
        );
      },
    ),
  );
}

class _DemoSubmissionDetails extends StatelessWidget {
  const _DemoSubmissionDetails({required this.school, required this.rowId});
  final DemoSchoolStore school;
  final String rowId;

  Future<void> _grade(BuildContext context) async {
    final rows = school.submissions.where((x) => x['id'] == rowId);
    if (rows.isEmpty) return;
    final original = rows.first;
    final score = TextEditingController(text: '${original['grade'] ?? 100}');
    final feedback = TextEditingController(text: original['feedback'] as String? ?? '');
    var revision = false;
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, update) =>
        AlertDialog(
          title: const Text('Проверить домашнюю работу'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: score,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Оценка от 0 до 100')),
            const SizedBox(height: 12),
            TextField(controller: feedback, maxLines: 3,
              decoration: const InputDecoration(labelText: 'Отзыв учительницы')),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Вернуть на исправление'),
              value: revision,
              onChanged: (v) => update(() => revision = v),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Сохранить оценку')),
          ],
        ),
      ),
    );
    if (save == true && context.mounted) {
      await guardedAction(context, () => school.grade(
        submissionId: rowId,
        score: int.tryParse(score.text) ?? -1,
        feedback: feedback.text,
        revision: revision,
      ));
    }
    score.dispose();
    feedback.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Проверка работы · демо')),
    body: AnimatedBuilder(
      animation: school,
      builder: (context, _) {
        final matches = school.submissions.where((x) => x['id'] == rowId);
        if (matches.isEmpty) return const Center(child: Text('Работа не найдена.'));
        final row = matches.first;
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 150),
          children: [
            Panel(child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(school.studentName(row['student_id'] as String),
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Статус: ${_demoStatus(row['status'] as String?)}'),
                const SizedBox(height: 12),
                SelectableText(row['answer'] as String? ?? ''),
                if (row['grade'] != null) ...[
                  const SizedBox(height: 12),
                  Text('Оценка: ${row['grade']}/100'),
                ],
                if ((row['feedback'] as String?)?.isNotEmpty == true)
                  Text('Комментарий: ${row['feedback']}'),
              ],
            )),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.fact_check_outlined),
              onPressed: () => _grade(context),
              label: const Text('Оценить или вернуть на исправление')),
            const SectionTitle('История работы'),
            for (final event in (row['history'] as List? ?? []).reversed)
              ListTile(
                title: Text(_demoStatus((event as Map)['status'] as String?)),
                subtitle: Text(_demoDate(event['at'])),
              ),
          ],
        );
      },
    ),
  );
}
