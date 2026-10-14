import 'package:flutter/material.dart';

import '../../core/academy_state.dart';
import '../../services/backend_service.dart';
import '../../ui/components.dart';
import '../../ui/design_tokens.dart';
import '../learning/settings_screen.dart';
import 'demo_school_store.dart';
import 'demo_school_screen.dart';
import 'remote_school_screen.dart';
import 'teacher_dashboard.dart';
import 'teacher_editor.dart';
import 'teacher_word_card_studio_screen.dart';

/// Teacher-only presentation shell. It never navigates to learner practice,
/// lessons or purchases, and cannot grant any server role.
class TeacherToolsScreen extends StatelessWidget {
  const TeacherToolsScreen({
    super.key,
    required this.state,
    required this.school,
    required this.backend,
    this.online = false,
    this.onDemoRoleChanged,
  });

  final AcademyState state;
  final DemoSchoolStore school;
  final BackendService backend;
  final bool online;
  final Future<bool> Function()? onDemoRoleChanged;

  void _open(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));

  Widget _demoSection(String section) => Scaffold(
    appBar: AppBar(title: Text(switch (section) {
      'reports' => 'Отчёты и статистика',
      'sessions' => 'Эфиры и встречи',
      'notices' => 'Уведомления',
      _ => 'Управление школой',
    })),
    body: DemoSchoolScreen(
      school: school, learning: state, backend: backend,
      initialSection: section, compactEmbedded: true,
    ),
  );

  Widget _onlineSection(String area) =>
      RemoteSchoolScreen(backend: backend, initialArea: area);

  Widget _materials() => Scaffold(
    appBar: AppBar(title: const Text('Мои учебные материалы')),
    body: TeacherDashboard(state: state, backend: backend),
  );

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 350 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final tiles = <({String title, String detail, IconData icon, Widget page})>[
      (
        title: 'Карточки слов',
        detail: 'Рисунки, арабский текст',
        icon: Icons.collections_bookmark_outlined,
        page: TeacherWordCardStudioScreen(state: state),
      ),
      (
        title: 'Конструктор уроков',
        detail: 'Тексты и упражнения',
        icon: Icons.edit_note_outlined,
        page: TeacherEditor(state: state),
      ),
      (
        title: 'Мои материалы',
        detail: 'Уроки и публикации',
        icon: Icons.auto_stories_outlined,
        page: _materials(),
      ),
      (
        title: 'Отчёты',
        detail: 'Успеваемость и навыки',
        icon: Icons.bar_chart_outlined,
        page: online ? _onlineSection('reports') : _demoSection('reports'),
      ),
      (
        title: online ? 'Курсы школы' : 'Прямые эфиры',
        detail: online ? 'Серверные материалы' : 'Расписание встреч · демо',
        icon: online ? Icons.school_outlined : Icons.video_camera_front_outlined,
        page: online ? _onlineSection('catalog') : _demoSection('sessions'),
      ),
      if (!online) (
        title: 'Уведомления',
        detail: 'Сообщения ученицам',
        icon: Icons.notifications_active_outlined,
        page: _demoSection('notices'),
      ),
    ];
    return CustomScrollView(slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
        sliver: SliverToBoxAdapter(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Инструменты учительницы',
              style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(online
                ? 'Управление курсами и группами в рамках серверных прав'
                : 'Локальная демонстрация. Нет доступа к данным чужих учениц.',
              style: const TextStyle(
                color: DesignTokens.secondary, fontSize: 12)),
            const SizedBox(height: 14),
            if (!online) ...[
              OutlinedButton.icon(
                key: const ValueKey('teacher-populate-showcase'),
                onPressed: school.readOnly ? null :
                    () => guardedAction(context, school.populateShowcase),
                icon: const Icon(Icons.auto_graph_outlined),
                label: const Text('Заполнить демонстрационную статистику'),
              ),
              const SizedBox(height: 12),
            ],
          ],
        )),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        sliver: SliverGrid.builder(
          itemCount: tiles.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: narrow ? 1 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: narrow ? 2.7 : 1.12,
          ),
          itemBuilder: (context, index) {
            final tile = tiles[index];
            return Material(
              color: Colors.transparent,
              child: InkWell(
                key: ValueKey('teacher-tool-${tile.title}'),
                borderRadius: BorderRadius.circular(20),
                onTap: () => _open(context, tile.page),
                child: Panel(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(tile.icon, color: DesignTokens.deepOlive, size: 27),
                    const SizedBox(height: 6),
                    Text(tile.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(tile.detail, maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11,
                        color: DesignTokens.secondary)),
                  ],
                )),
              ),
            );
          },
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 15, 18, 160),
        sliver: SliverToBoxAdapter(child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle('Система'),
            Panel(padding: EdgeInsets.zero, child: ListTile(
              key: const ValueKey('teacher-settings-entry'),
              dense: true,
              leading: const Icon(Icons.settings_outlined,
                color: DesignTokens.deepOlive),
              title: const Text('Настройки'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(context, SettingsScreen(
                state: state, backend: backend,
                onDemoRoleChanged: onDemoRoleChanged)),
            )),
            if (!online && onDemoRoleChanged != null) ...[
              const SizedBox(height: 9),
              Panel(padding: EdgeInsets.zero, child: ListTile(
                key: const ValueKey('teacher-switch-cabinet'),
                dense: true,
                leading: const Icon(Icons.switch_account_outlined,
                  color: DesignTokens.deepOlive),
                title: const Text('Сменить демо-кабинет'),
                subtitle: const Text('Вернуться к роли ученицы'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onDemoRoleChanged!(),
              )),
            ],
          ],
        )),
      ),
    ]);
  }
}
