import 'package:flutter/material.dart';

import '../../services/backend_service.dart';
import 'remote/school_api.dart';
import 'remote/school_widgets.dart';
import 'remote/catalog_panel.dart';
import 'remote/groups_panel.dart';
import 'remote/reports_panel.dart';

export 'remote/school_api.dart';
export 'remote/school_models.dart';

/// Entry point shared by the native router and embedded teacher home.
/// Local demo flags never authorize this panel or its nested routes.
class RemoteSchoolScreen extends StatefulWidget {
  const RemoteSchoolScreen({
    super.key,
    required this.backend,
    this.embedded = false,
    this.api,
    this.initialArea = 'catalog',
    this.compactEmbedded = false,
  });
  final BackendService backend;
  final bool embedded;
  final RemoteSchoolApi? api;
  final String initialArea;
  final bool compactEmbedded;
  @override
  State<RemoteSchoolScreen> createState() => _RemoteSchoolScreenState();
}

class _RemoteSchoolScreenState extends State<RemoteSchoolScreen> {
  late final RemoteSchoolApi api;
  late String area;
  @override
  void initState() {
    super.initState();
    area = widget.initialArea;
    api = widget.api ?? RemoteSchoolApi(widget.backend);
  }

  Widget _body(ServerRole role) => Column(
    children: [
      if (!widget.compactEmbedded) Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Управление школой',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              role == ServerRole.admin
                  ? 'Серверный администратор'
                  : 'Назначенные курсы и группы преподавателя',
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'catalog',
                    label: Text('Курсы'),
                    icon: Icon(Icons.auto_stories_outlined),
                  ),
                  ButtonSegment(
                    value: 'groups',
                    label: Text('Группы'),
                    icon: Icon(Icons.groups_outlined),
                  ),
                  ButtonSegment(
                    value: 'reports',
                    label: Text('Отчёты'),
                    icon: Icon(Icons.bar_chart_outlined),
                  ),
                ],
                selected: {area},
                onSelectionChanged: (value) =>
                    setState(() => area = value.single),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: switch (area) {
          'groups' => SchoolGroupsPanel(api: api),
          'reports' => SchoolReportsPanel(api: api),
          _ => SchoolCatalogPanel(api: api),
        },
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final body = SchoolAccess(api: api, builder: _body);
    return widget.embedded
        ? body
        : Scaffold(
            appBar: AppBar(title: const Text('Школа')),
            body: body,
          );
  }
}
