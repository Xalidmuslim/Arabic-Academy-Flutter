import 'package:flutter/material.dart';
import '../../../ui/components.dart' show Panel;
import '../../../services/backend_service.dart';
import 'school_api.dart';
import 'school_widgets.dart';
import 'lesson_editor.dart';

class SchoolCatalogPanel extends StatefulWidget {
  const SchoolCatalogPanel({super.key, required this.api});
  final RemoteSchoolApi api;
  @override
  State<SchoolCatalogPanel> createState() => _SchoolCatalogPanelState();
}

class _SchoolCatalogPanelState extends State<SchoolCatalogPanel>
    with SchoolActions<SchoolCatalogPanel> {
  RemoteSchoolApi get api => widget.api;
  final List<Map<String, dynamic>> _path = [];
  Future<List<Map<String, dynamic>>>? _data;
  static const _tables = ['courses', 'levels', 'books', 'units', 'lessons'];
  static const _labels = ['Курсы', 'Уровни', 'Книги', 'Разделы', 'Уроки'];
  static const _parents = ['', 'course_id', 'level_id', 'book_id', 'unit_id'];
  void _reload() => setState(() => _data = null);
  Future<List<Map<String, dynamic>>> _load() {
    if (_path.isEmpty) return api.courses();
    return api.query(
      _tables[_path.length],
      filters: {_parents[_path.length]: _path.last['id']},
      order: 'position',
    );
  }

  Future<void> _create(List<Map<String, dynamic>> rows) async {
    final depth = _path.length;
    final next = rows.fold<int>(
      0,
      (value, row) => (row['position'] as int? ?? -1) >= value
          ? (row['position'] as int) + 1
          : value,
    );
    final values = await showSchoolForm(
      context,
      depth == 0 ? 'Создать курс' : 'Добавить: ${_labels[depth]}',
      [
        const SchoolField('title', 'Название', required: true),
        if (depth == 0) ...[
          const SchoolField(
            'access_tier',
            'Доступ к курсу',
            required: true,
            choices: {'free': 'Бесплатный', 'paid': 'Платный'},
          ),
          const SchoolField(
            'source_policy',
            'Происхождение и право использования материалов',
            multiline: true,
            required: true,
          ),
        ],
        if (depth > 0)
          const SchoolField('position', 'Порядок (0 — первый)', required: true),
        if (depth == 2) ...[
          const SchoolField('edition', 'Издание / том'),
          const SchoolField('license_reference', 'Лицензия / источник'),
        ],
      ],
      initial: {'position': next, 'access_tier': 'paid'},
    );
    if (values == null) return;
    if (depth == 0 && !const {'free', 'paid'}.contains(values['access_tier'])) {
      throw const IntegrationException('Выберите free или paid.');
    }
    final position = depth == 0
        ? null
        : int.tryParse(values['position'].toString());
    if (depth > 0 && (position == null || position < 0)) {
      throw const IntegrationException(
        'Порядок должен быть целым неотрицательным числом.',
      );
    }
    await api.rpc(
      const [
        'create_course',
        'create_level',
        'create_book',
        'create_unit',
        'create_lesson',
      ][depth],
      {
        'p_title': values['title'],
        if (depth == 0) ...{
          'p_access_tier': values['access_tier'],
          'p_source_policy': values['source_policy'],
        },
        if (depth > 0) ...{
          'p_${_parents[depth]}': _path.last['id'],
          'p_position': position,
        },
        if (depth == 2) ...{
          'p_edition': values['edition'],
          'p_license_reference': values['license_reference'],
        },
      },
    );
    if (mounted) _reload();
  }

  Future<void> _open(Map<String, dynamic> row) async {
    if (_path.length == 4) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => SchoolLessonEditor(api: api, id: row['id'] as String),
        ),
      );
      if (mounted) _reload();
    } else {
      setState(() {
        _path.add(row);
        _data = null;
      });
    }
  }

  Future<void> _publish() async {
    if (!await confirmSchoolAction(
      context,
      'Опубликовать курс?',
      'Сервер проверит наличие опубликованного урока и ваши права на курс.',
    )) {
      return;
    }
    await api.rpc('publish_course', {'p_course_id': _path.first['id']});
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            status,
            Row(
              children: [
                if (_path.isNotEmpty)
                  IconButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            _path.removeLast();
                            _data = null;
                          }),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'На уровень выше',
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => setState(() {
                                  _path.clear();
                                  _data = null;
                                }),
                          child: const Text('Все курсы'),
                        ),
                        for (var i = 0; i < _path.length; i++)
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => setState(() {
                                    _path.removeRange(i + 1, _path.length);
                                    _data = null;
                                  }),
                            child: Text(_path[i]['title'].toString()),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_path.isNotEmpty)
              OutlinedButton(
                onPressed: busy ? null : () => run(_publish),
                child: const Text('Опубликовать курс'),
              ),
          ],
        ),
      ),
      Expanded(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _data ??= _load(),
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
            final rows = snapshot.data!;
            return RefreshIndicator(
              onRefresh: () async {
                _reload();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _labels[_path.length],
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        onPressed: busy ? null : () => run(() => _create(rows)),
                        icon: const Icon(Icons.add),
                        tooltip: 'Добавить',
                      ),
                    ],
                  ),
                  if (rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Доступных записей пока нет.'),
                    ),
                  for (final row in rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Panel(
                        child: ListTile(
                          title: Text(row['title'].toString()),
                          subtitle: Text(
                            [
                              if (row['status'] != null) row['status'],
                              if (row['version'] != null)
                                'Версия ${row['version']}',
                            ].join(' · '),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: busy ? null : () => run(() => _open(row)),
                        ),
                      ),
                    ),
                  OutlinedButton(
                    onPressed: busy ? null : _reload,
                    child: const Text('Обновить данные'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ],
  );
}
