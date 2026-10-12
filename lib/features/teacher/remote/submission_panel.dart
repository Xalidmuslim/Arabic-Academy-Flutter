import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../ui/components.dart' show Panel;
import '../../../services/backend_service.dart';
import 'school_api.dart';
import 'school_models.dart';
import 'school_widgets.dart';

class SchoolSubmissionPage extends StatefulWidget {
  const SchoolSubmissionPage({
    super.key,
    required this.api,
    required this.assignment,
  });
  final RemoteSchoolApi api;
  final Map<String, dynamic> assignment;
  @override
  State<SchoolSubmissionPage> createState() => _AssignmentPageState();
}

class _AssignmentPageState extends State<SchoolSubmissionPage>
    with SchoolActions<SchoolSubmissionPage> {
  Future<Map<String, dynamic>>? _future;
  Future<Map<String, dynamic>> _load() async {
    final submissions = await widget.api.query(
      'submissions',
      filters: {'assignment_id': widget.assignment['id']},
      order: 'updated_at',
    );
    final profiles = await widget.api.query(
      'profiles',
      within: {'id': submissions.map((r) => r['student_id']).toList()},
      columns: 'id,display_name',
    );
    final grades = await widget.api.query(
      'grades',
      within: {'submission_id': submissions.map((r) => r['id']).toList()},
      order: 'revision',
    );
    final feedback = await widget.api.query(
      'feedback',
      within: {'grade_id': grades.map((r) => r['id']).toList()},
    );
    return {
      'submissions': submissions
          .map(
            (row) => {
              ...row,
              'student_name':
                  profiles
                      .where((p) => p['id'] == row['student_id'])
                      .firstOrNull?['display_name'] ??
                  row['student_id'],
            },
          )
          .toList(),
      'grades': grades,
      'feedback': feedback,
    };
  }

  void _reload() => setState(() => _future = null);
  Future<void> _grade(Map<String, dynamic> submission) async {
    final values = await showSchoolForm(
      context,
      'Оценить ревизию ${submission['revision']}',
      [
        const SchoolField('score', 'Баллы (0–100)', required: true),
        const SchoolField(
          'feedback',
          'Обратная связь ученице',
          multiline: true,
          required: true,
        ),
      ],
    );
    if (values == null) return;
    final score = num.tryParse(values['score'].toString());
    if (score == null || !score.isFinite || score < 0 || score > 100) {
      throw const IntegrationException(
        'Оценка должна быть числом от 0 до 100.',
      );
    }
    await widget.api.rpc('grade_submission', {
      'p_submission_id': submission['id'],
      'p_revision': submission['revision'],
      'p_score': score,
      'p_feedback': values['feedback'],
    });
    if (mounted) _reload();
  }

  Future<void> _revision(Map<String, dynamic> submission) async {
    final values = await showSchoolForm(context, 'Попросить исправления', [
      const SchoolField(
        'reason',
        'Что нужно исправить',
        multiline: true,
        required: true,
      ),
    ]);
    if (values == null) return;
    await widget.api.rpc('request_submission_revision', {
      'p_submission_id': submission['id'],
      'p_revision': submission['revision'],
      'p_reason': values['reason'],
    });
    if (mounted) _reload();
  }

  Future<void> _history(Map<String, dynamic> submission) async {
    final history = await widget.api.query(
      'submission_history',
      filters: {'submission_id': submission['id']},
      order: 'revision',
    );
    final requests = await widget.api.query(
      'revision_requests',
      filters: {'submission_id': submission['id']},
      order: 'revision',
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('История работы'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: SelectableText(
              const JsonEncoder.withIndent(
                '  ',
              ).convert({'versions': history, 'revision_requests': requests}),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.assignment['title'].toString())),
    body: SchoolAccess(
      api: widget.api,
      builder: (_) => FutureBuilder<Map<String, dynamic>>(
        future: _future ??= _load(),
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
          final submissions = schoolMaps(snapshot.data!['submissions']),
              grades = schoolMaps(snapshot.data!['grades']),
              feedback = schoolMaps(snapshot.data!['feedback']);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              status,
              Text('Срок задания: ${schoolDate(widget.assignment['due_at'])}'),
              if (submissions.isEmpty) const Text('Работ пока нет.'),
              for (final row in submissions)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row['student_name'].toString(),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          'Ревизия ${row['revision']} · ${row['status'] ?? 'submitted'} · ${schoolDate(row['updated_at'])}',
                        ),
                        SelectableText(
                          const JsonEncoder.withIndent(
                            '  ',
                          ).convert(row['body']),
                        ),
                        for (final grade in grades.where(
                          (g) =>
                              g['submission_id'] == row['id'] &&
                              g['revision'] == row['revision'],
                        )) ...[
                          Text('Оценка: ${grade['score']}/100'),
                          for (final note in feedback.where(
                            (f) => f['grade_id'] == grade['id'],
                          ))
                            Text(note['body'].toString()),
                        ],
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton(
                              onPressed:
                                  busy ||
                                      row['status'] == 'revision_requested' ||
                                      row['status'] == 'graded'
                                  ? null
                                  : () => run(() => _grade(row)),
                              child: const Text('Оценить работу'),
                            ),
                            OutlinedButton(
                              onPressed:
                                  busy || row['status'] == 'revision_requested'
                                  ? null
                                  : () => run(() => _revision(row)),
                              child: const Text('Запросить исправления'),
                            ),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => run(() => _history(row)),
                              child: const Text('История ревизий'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              OutlinedButton(
                onPressed: busy ? null : _reload,
                child: const Text('Обновить работы'),
              ),
            ],
          );
        },
      ),
    ),
  );
}
