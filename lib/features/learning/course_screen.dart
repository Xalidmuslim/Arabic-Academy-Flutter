import 'package:flutter/material.dart';
import '../../core/academy_state.dart';
import '../../core/arabic.dart';
import '../../core/app_strings.dart';
import '../../services/backend_service.dart';
import '../../ui/components.dart';
import '../../ui/design_tokens.dart';
import '../integrations/purchases_screen.dart';
import 'lesson_screen.dart';
import 'online_courses_screen.dart';

class UnitScreen extends StatefulWidget {
  const UnitScreen({super.key, required this.state, this.unitId, this.backend});
  final AcademyState state;
  final String? unitId;
  final BackendService? backend;
  @override
  State<UnitScreen> createState() => _UnitScreenState();
}

class _UnitScreenState extends State<UnitScreen> {
  String _filter = 'Все';
  String _query = '';
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(tr(context, 'Уроки')),
      actions: [
        IconButton(
          tooltip: 'Очистить поиск',
          icon: const Icon(Icons.search),
          onPressed: () => setState(() {
            _search.clear();
            _query = '';
          }),
        ),
      ],
    ),
    body: AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final lessons = widget.state.allLessons
            .where(
              (lesson) =>
                  widget.unitId == null ||
                  (lesson['module_id'] ?? 'u1') == widget.unitId,
            )
            .where(
              (lesson) =>
                  matchesSearch(_query, [
                    lesson['title'] as String? ?? '',
                    lesson['title_ar'] as String? ?? '',
                  ]) &&
                  (_filter != 'Избранное' ||
                      widget.state.bookmarks.contains(
                        'lesson:${lesson['id']}',
                      )) &&
                  (_filter != 'Завершённые' ||
                      widget.state.completed.contains(lesson['id'])) &&
                  !['Средний', 'Продвинутый'].contains(_filter),
            )
            .toList();
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    TextField(
                      controller: _search,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: const InputDecoration(
                        hintText: 'Поиск курсов и уроков',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: MediaQuery.textScalerOf(context).scale(52),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children:
                            [
                                  'Все',
                                  'Начальный',
                                  'Средний',
                                  'Продвинутый',
                                  'Избранное',
                                  'Завершённые',
                                ]
                                .map(
                                  (filter) => Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                      end: 7,
                                    ),
                                    child: ChoiceChip(
                                      label: Text(tr(context, filter)),
                                      selected: _filter == filter,
                                      onSelected: (_) =>
                                          setState(() => _filter = filter),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.unitId == null &&
                _filter != 'Избранное' &&
                _filter != 'Завершённые')
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                sliver: SliverList.builder(
                  itemCount: widget.state.units.length,
                  itemBuilder: (context, i) {
                    final unit = widget.state.units[i] as Map;
                    if (!matchesSearch(_query, [
                      unit['title_ru'] as String? ?? '',
                      unit['title_ar'] as String? ?? '',
                    ])) {
                      return const SizedBox.shrink();
                    }
                    final unitLessons = widget.state.allLessons
                        .where((x) => (x['module_id'] ?? 'u1') == unit['id'])
                        .toList();
                    final done = unitLessons
                        .where((x) => widget.state.completed.contains(x['id']))
                        .length;
                    final free = unit['access_default'] == 'free';
                    const illustrations = [
                      'lessons',
                      'teacher',
                      'grammar',
                      'progress',
                      'oral',
                      'live',
                      'exercises',
                      'vocabulary',
                    ];
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Panel(
                        padding: EdgeInsets.zero,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () {
                            if (free) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UnitScreen(
                                    state: widget.state,
                                    unitId: unit['id'] as String,
                                    backend: widget.backend,
                                  ),
                                ),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PurchasesScreen(
                                    backend: widget.backend ?? BackendService(),
                                  ),
                                ),
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Image.asset(
                                  'assets/artwork/${illustrations[i % illustrations.length]}.webp',
                                  width: 78,
                                  height: 82,
                                  cacheWidth: 240,
                                  excludeFromSemantics: true,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        unit['title_ru'] as String? ?? '',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        unitLessons.isEmpty
                                            ? 'Каталог · материалы не импортированы'
                                            : '${unitLessons.length} уроков · Начальный',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        free
                                            ? 'Бесплатно · $done/${unitLessons.length}'
                                            : 'Доступ после серверного подтверждения',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: DesignTokens.olive,
                                        ),
                                      ),
                                      if (unitLessons.isNotEmpty) ...[
                                        const SizedBox(height: 7),
                                        LinearProgressIndicator(
                                          value: done / unitLessons.length,
                                          color: DesignTokens.olive,
                                          backgroundColor: DesignTokens.beige,
                                          minHeight: 4,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Icon(
                                  free
                                      ? Icons.chevron_right
                                      : Icons.lock_outline,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (widget.unitId != null ||
                _filter == 'Избранное' ||
                _filter == 'Завершённые' ||
                widget.state.units.isEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                sliver: SliverToBoxAdapter(
                  child: lessons.isEmpty
                      ? const EmptyState(
                          title: 'Нет подходящих уроков',
                          message: 'Измените фильтр или поисковый запрос.',
                        )
                      : const SizedBox(height: 12),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                sliver: SliverList.builder(
                  itemCount: lessons.length,
                  itemBuilder: (context, i) {
                    final lesson = lessons[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Panel(
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: DesignTokens.beige,
                            child: Text('${i + 1}'),
                          ),
                          title: Text(lesson['title'] as String? ?? ''),
                          subtitle: NaskhText(
                            lesson['title_ar'] as String? ?? '',
                            size: 19,
                          ),
                          trailing: Icon(
                            widget.state.completed.contains(lesson['id'])
                                ? Icons.check_circle
                                : Icons.chevron_right,
                            color: DesignTokens.olive,
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LessonScreen(
                                state: widget.state,
                                lesson: lesson,
                                backend: widget.backend,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            SliverPadding(
              padding: const EdgeInsets.all(18),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    const Text(
                      'Оригинальные учебные материалы. Структура лицензионного издания импортируется отдельно.',
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.cloud_outlined),
                      label: const Text('Онлайн-курсы школы'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OnlineCoursesScreen(
                            backend: widget.backend ?? BackendService(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
