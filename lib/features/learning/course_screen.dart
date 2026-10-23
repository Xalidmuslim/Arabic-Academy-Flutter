import 'package:flutter/material.dart';
import '../../core/academy_state.dart';
import '../../core/performance_probe.dart';
import '../../core/arabic.dart';
import '../../core/app_strings.dart';
import '../../services/backend_service.dart';
import '../../ui/components.dart';
import '../../ui/course_unit_art.dart';
import '../../ui/design_tokens.dart';
import '../integrations/purchases_screen.dart';
import 'lesson_screen.dart';
import 'online_courses_screen.dart';
import 'textbook_reader_screen.dart';

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

  // Only visible unit artwork listens to the diagnostic A/B flag.
  // Normal releases continue to show identical blurred 3D silhouettes.
  Widget _unitArtwork(Map unit) {
    final unitId = unit['id'] as String;
    final path = unit['illustration_asset'] as String?;
    Widget render(bool blur) => CourseUnitArt(
      unitId: unitId,
      size: 88,
      imageAsset: path,
      blurSilhouette: blur,
    );
    if (!PerformanceProbe.enabled) return render(true);
    return ValueListenableBuilder<bool>(
      valueListenable: PerformanceProbe.silhouetteBlurEnabled,
      builder: (context, blur, _) => render(blur),
    );
  }

  int get _textbookStartPage => const <String, int>{
    'u01': 22, 'u02': 48, 'u03': 76, 'u04': 102,
    'u05': 130, 'u06': 156, 'u07': 184, 'u08': 210,
    'u1': 22, 'u2': 48, 'u3': 76, 'u4': 102,
    'u5': 130, 'u6': 156, 'u7': 184, 'u8': 210,
    // Zero-based PDF starts for the separate Student Book 1 Part 2 PDF.
    'u9': 22, 'u10': 48, 'u11': 76, 'u12': 102,
    'u13': 130, 'u14': 156, 'u15': 184, 'u16': 210,
  }[widget.unitId] ?? 22;

  int get _textbookPart => widget.unitId == null ||
          (int.tryParse(widget.unitId!.replaceFirst('u', '')) ?? 1) <= 8 ? 1 : 2;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(tr(context, 'Уроки')),
      actions: [
        if (PerformanceProbe.enabled && widget.unitId == null)
          ValueListenableBuilder<bool>(
            valueListenable: PerformanceProbe.silhouetteBlurEnabled,
            builder: (context, blur, _) => IconButton(
              icon: Icon(blur ? Icons.blur_on : Icons.blur_off),
              tooltip: blur
                  ? 'GPU-тест: отключить размытие 3D-тени'
                  : 'GPU-тест: включить размытие 3D-тени',
              onPressed: PerformanceProbe.toggleSilhouetteBlur,
            ),
          ),
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
        // Index the lesson count and completion once per state change.
        // Lazy unit tiles can then render in O(1), even while flinging.
        final catalog = widget.state.allLessons;
        final completedIds = widget.state.completed;
        final unitProgress = <String, ({int total, int done})>{};
        if (widget.unitId == null &&
            _filter != 'Избранное' &&
            _filter != 'Завершённые') {
          for (final lesson in catalog) {
            final moduleId = lesson['module_id'] ?? 'u1';
            if (moduleId is! String) continue;
            final previous = unitProgress[moduleId];
            unitProgress[moduleId] = (
              total: (previous?.total ?? 0) + 1,
              done: (previous?.done ?? 0) +
                  (completedIds.contains(lesson['id']) ? 1 : 0),
            );
          }
        }
        final lessons = catalog
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
                      completedIds.contains(lesson['id'])),
            )
            .toList();
        return CustomScrollView(
          key: PageStorageKey<String>(
              'unit-scroll-${widget.unitId ?? "all"}'),
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
            if (_filter == 'Все' && _query.trim().isEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 5, 18, 14),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      for (final part in widget.unitId == null
                          ? const [1, 2] : [_textbookPart])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Panel(
                            padding: EdgeInsets.zero,
                            child: ListTile(
                              dense: true,
                              visualDensity: const VisualDensity(vertical: -4),
                              minVerticalPadding: 0,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                              key: ValueKey('private-pdf-textbook-entry-$part'),
                              leading: const Icon(Icons.picture_as_pdf_outlined, size: 23),
                              title: Text(
                                'Оригинальный учебник · Часть $part',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(part == 1
                                  ? 'Разделы 1–8 · 282 стр. · импорт PDF'
                                  : 'Разделы 9–16 · 284 стр. · импорт PDF',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10.5),
                              ),
                              trailing: const Icon(Icons.chevron_right, size: 19),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TextbookReaderScreen(
                                    part: part,
                                    initialPage: widget.unitId == null
                                        ? 22 : _textbookStartPage,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (widget.unitId != null &&
                _filter == 'Все' &&
                _query.trim().isEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                sliver: SliverToBoxAdapter(
                  child: ExpansionTile(
                    key: const ValueKey('book1-outline'),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                    title: const Text('Порядок раздела по учебнику'),
                    subtitle: const Text(
                      '3 диалога → лексика → грамматика → аудирование → '
                      'говорение → чтение → письмо',
                      style: TextStyle(fontSize: 12),
                    ),
                    children: const [
                      ListTile(dense: true, title: Text('1. Диалог 1 · слова и практика')),
                      ListTile(dense: true, title: Text('2. Диалог 2 · слова и практика')),
                      ListTile(dense: true, title: Text('3. Диалог 3 · слова и практика')),
                      ListTile(
                        dense: true,
                        title: Text('4. Лексика и грамматические упражнения'),
                        subtitle: Text('Оригинальные задания — в PDF'),
                      ),
                      ListTile(
                        dense: true,
                        title: Text('5. Аудирование и говорение'),
                        subtitle: Text('Оригинальные задания — в PDF'),
                      ),
                      ListTile(
                        dense: true,
                        title: Text('6. Чтение и письмо'),
                        subtitle: Text('Оригинальные задания — в PDF'),
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
                    final progress = unitProgress[unit['id']];
                    final unitTotal = progress?.total ?? 0;
                    final done = progress?.done ?? 0;
                    final free = unit['access_default'] == 'free';
                    final isOpen = free || AcademyState.temporaryLocalLessonAccess;
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Panel(
                        padding: EdgeInsets.zero,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () {
                            if (isOpen) {
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
                                _unitArtwork(unit),
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
                                        unitTotal == 0
                                            ? 'Каталог · материалы не импортированы'
                                            : '$unitTotal уроков · Начальный',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        isOpen
                                            ? unitTotal == 0
                                                ? 'Раздел открыт · материалы готовятся'
                                                : 'Открыто · $done/$unitTotal'
                                            : 'Доступ после серверного подтверждения',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: DesignTokens.olive,
                                        ),
                                      ),
                                      if (unitTotal > 0) ...[
                                        const SizedBox(height: 7),
                                        LinearProgressIndicator(
                                          value: done / unitTotal,
                                          color: DesignTokens.olive,
                                          backgroundColor: DesignTokens.beige,
                                          minHeight: 4,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Icon(
                                  isOpen
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
                      ? EmptyState(
                          title: widget.unitId != null &&
                                  _query.trim().isEmpty &&
                                  _filter == 'Все'
                              ? 'Материалы пока не загружены'
                              : 'Нет подходящих уроков',
                          message: widget.unitId != null &&
                                  _query.trim().isEmpty &&
                                  _filter == 'Все'
                              ? 'Раздел открыт. Учебные тексты появятся после импорта.'
                              : 'Измените фильтр или поисковый запрос.',
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
                            completedIds.contains(lesson['id'])
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
            const SliverToBoxAdapter(child: SizedBox(height: 142))
          ],
        );
      },
    ),
  );
}
