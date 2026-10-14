import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/academy_state.dart';
import '../../services/backend_service.dart';
import '../../ui/components.dart';
import '../../ui/premium_art.dart';
import 'teacher_editor.dart';
import 'teacher_word_card_studio_screen.dart';

class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({
    super.key,
    required this.state,
    required this.backend,
  });
  final AcademyState state;
  final BackendService backend;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: state,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          'Кабинет учительницы',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ArtworkIcon('students', size: 115),
              const Text(
                'Локальный конструктор',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontVariations: [FontVariation('wght', 800)],
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Демо-кабинет работает на этом устройстве. Для публикации в школе войдите в аккаунт с серверной ролью учительницы.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Создать урок'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TeacherEditor(state: state)),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const ValueKey('teacher-local-word-cards'),
          icon: const Icon(Icons.collections_bookmark_outlined),
          label: const Text('Карточки слов и изображения'),
          onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) =>
              TeacherWordCardStudioScreen(state: state))),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Проверка локальных работ'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LocalHomeworkScreen(state: state, teacher: true),
            ),
          ),
        ),
        const SectionTitle('Мои материалы'),
        Text(
          '${state.teacherLessons.length} уроков · ${state.published.length} опубликовано',
          style: const TextStyle(fontSize: 12, color: muted),
        ),
        const SizedBox(height: 12),
        if (state.teacherLessons.isEmpty)
          const EmptyState(
            title: 'Начните с первого урока',
            message: 'Добавьте текст, диалог, словарь и интерактивное задание.',
          ),
        if (state.teacherLessons.isNotEmpty)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: state.teacherLessons.length,
            onReorder: (oldIndex, newIndex) => guardedAction(context, () async {
              final ids = state.teacherLessons
                  .map((x) => x['id'] as String)
                  .toList();
              if (newIndex > oldIndex) newIndex--;
              ids.insert(newIndex, ids.removeAt(oldIndex));
              await state.reorderLessons(ids);
            }),
            itemBuilder: (context, i) {
              final item = state.teacherLessons[i];
              return Padding(
                key: ValueKey(item['id']),
                padding: const EdgeInsets.only(bottom: 12),
                child: Panel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: ReorderableDragStartListener(
                          index: i,
                          child: const Icon(Icons.drag_handle),
                        ),
                        title: Text(item['title'] as String? ?? ''),
                        subtitle: Text(
                          item['published'] == true
                              ? 'Опубликован на устройстве'
                              : 'Черновик',
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                TeacherEditor(state: state, original: item),
                          ),
                        ),
                      ),
                      Wrap(
                        alignment: WrapAlignment.end,
                        children: [
                          IconButton(
                            tooltip: 'Предпросмотр',
                            icon: const Icon(Icons.visibility_outlined),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ExtraLessonScreen(data: item),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Копировать',
                            icon: const Icon(Icons.copy),
                            onPressed: () => guardedAction(
                              context,
                              () => state.copyLesson(item),
                            ),
                          ),
                          IconButton(
                            tooltip: item['published'] == true
                                ? 'Снять с публикации'
                                : 'Опубликовать',
                            icon: Icon(
                              item['published'] == true
                                  ? Icons.unpublished_outlined
                                  : Icons.publish,
                            ),
                            onPressed: () => guardedAction(
                              context,
                              () => state.save({
                                ...item,
                                'published': item['published'] != true,
                              }),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Удалить в архив',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text(
                                    'Переместить урок в архив?',
                                  ),
                                  content: const Text(
                                    'Содержание и прогресс сохранятся. Урок можно восстановить.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, false),
                                      child: const Text('Отмена'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, true),
                                      child: const Text('В архив'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true && context.mounted) {
                                await guardedAction(
                                  context,
                                  () => state.remove(item['id'] as String),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        const SectionTitle('Резервная копия материалов'),
        OutlinedButton.icon(
          icon: const Icon(Icons.file_download_outlined),
          label: const Text('Экспортировать уроки'),
          onPressed: () => guardedAction(context, () async {
            await FilePicker.platform.saveFile(
              fileName: 'bayna-teacher-materials.json',
              type: FileType.custom,
              allowedExtensions: ['json'],
              bytes: Uint8List.fromList(
                utf8.encode(
                  jsonEncode({
                    'schema_version': 1,
                    'teacher_lessons': state.teacherLessons,
                    'archived_lessons': state.archivedLessons,
                  }),
                ),
              ),
            );
          }),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.file_upload_outlined),
          label: const Text('Импортировать уроки'),
          onPressed: () => guardedAction(context, () async {
            final selected = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['json'],
              withData: true,
            );
            if (selected == null) return;
            final bytes = selected.files.single.bytes;
            if (bytes == null || bytes.length > 5 * 1024 * 1024) {
              throw const FormatException('Допустим JSON-файл не больше 5 МБ.');
            }
            final data = jsonDecode(utf8.decode(bytes)) as Map;
            final materials = (data['teacher_lessons'] as List)
                .map((x) => Map<String, dynamic>.from(x as Map))
                .toList();
            if (materials.length > 1000 ||
                materials.any(
                  (x) =>
                      x['title'] is! String ||
                      (x['title'] as String).trim().isEmpty,
                )) {
              throw const FormatException('Неверный файл материалов.');
            }
            // Import as new drafts; never overwrite an existing owner's lesson.
            for (final item in materials) {
              await state.save({
                ...item,
                'id': AcademyState.newId(),
                'published': false,
              });
            }
            if (context.mounted) {
              notice(
                context,
                'Импортировано ${materials.length} черновиков. Исходные уроки сохранены.',
              );
            }
          }),
        ),
        if (state.archivedLessons.isNotEmpty) ...[
          const SectionTitle('Архив'),
          ...state.archivedLessons.map(
            (item) => ListTile(
              title: Text(item['title'] as String? ?? ''),
              trailing: IconButton(
                tooltip: 'Восстановить',
                icon: const Icon(Icons.restore),
                onPressed: () => guardedAction(
                  context,
                  () => state.restoreLesson(item['id'] as String),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class LocalHomeworkScreen extends StatelessWidget {
  const LocalHomeworkScreen({
    super.key,
    required this.state,
    this.teacher = false,
  });
  final AcademyState state;
  final bool teacher;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(teacher ? 'Проверка работ · демо' : 'Домашние задания'),
    ),
    body: AnimatedBuilder(
      animation: state,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          if (state.submissions.isEmpty)
            const EmptyState(
              title: 'Пока нет сохранённых работ',
              message:
                  'Ответ можно написать на шаге проверки урока. Он сохранится вместе с историей изменений.',
            ),
          ...state.submissions.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _lessonName(item['lesson_id'] as String),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(item['text'] as String? ?? ''),
                    const SizedBox(height: 10),
                    Text('Статус: ${_status(item['status'] as String? ?? '')}'),
                    if (item['grade'] != null)
                      Text('Оценка: ${item['grade']}/100'),
                    if ((item['feedback'] as String?)?.isNotEmpty == true)
                      Text('Комментарий: ${item['feedback']}'),
                    const SizedBox(height: 6),
                    Text(
                      'Изменений: ${(item['history'] as List? ?? []).length}',
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                    if (teacher)
                      OutlinedButton(
                        onPressed: () => _grade(context, item),
                        child: const Text('Проверить'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  String _lessonName(String id) {
    final lesson = state.allLessons.where((x) => x['id'] == id);
    return lesson.isEmpty ? 'Учебная работа' : lesson.first['title'] as String;
  }

  String _status(String status) =>
      const {
        'submitted': 'Отправлено локально',
        'graded': 'Проверено',
        'revision_requested': 'Требует исправления',
      }[status] ??
      status;
  Future<void> _grade(BuildContext context, Map<String, dynamic> item) async {
    final score = TextEditingController(text: '${item['grade'] ?? 100}');
    final comment = TextEditingController(
      text: item['feedback'] as String? ?? '',
    );
    bool returnForRevision = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Проверка работы'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: score,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Оценка: 0–100'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: comment,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Комментарий'),
                ),
                SwitchListTile(
                  title: const Text('Вернуть на исправление'),
                  value: returnForRevision,
                  onChanged: (value) =>
                      setState(() => returnForRevision = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && context.mounted) {
      await guardedAction(
        context,
        () => state.gradeHomework(
          item['id'] as String,
          int.tryParse(score.text) ?? -1,
          comment.text,
          returnForRevision: returnForRevision,
        ),
      );
    }
    score.dispose();
    comment.dispose();
  }
}
