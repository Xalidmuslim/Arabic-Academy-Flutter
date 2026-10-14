import 'package:flutter/material.dart';
import '../../core/academy_state.dart';
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
                      widget.state.completed.contains(lesson['id'])),
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
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Panel(
                            padding: EdgeInsets.zero,
                            child: ListTile(
                              key: ValueKey('private-pdf-textbook-entry-$part'),
                              leading: const Icon(Icons.picture_as_pdf_outlined),
                              title: Text(
                                'Оригинальный учебник · Часть $part',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(part == 1
                                  ? 'Разделы 1–8 · 282 страницы · импорт PDF с телефона'
                                  : 'Разделы 9–16 · 284 страницы · импорт PDF с телефона'),
                              trailing: const Icon(Icons.chevron_right),
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
                    final unitLessons = widget.state.allLessons
                        .where((x) => (x['module_id'] ?? 'u1') == unit['id'])
                        .toList();
                    final done = unitLessons
                        .where((x) => widget.state.completed.contains(x['id']))
                        .length;
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
                                CourseUnitArt(
                                  unitId: unit['id'] as String,
                                  imageAsset: unit['illustration_asset'] as String?,
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
                                        isOpen
                                            ? unitLessons.isEmpty
                                                ? 'Раздел открыт · материалы готовятся'
                                                : 'Открыто · $done/${unitLessons.length}'
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
            const SliverToBoxAdapter(child: SizedBox(height: 142))
          ],
        );
      },
    ),
  );
}
