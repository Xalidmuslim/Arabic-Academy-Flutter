import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../ui/components.dart' show Panel;
import '../../../services/backend_service.dart';
import 'school_api.dart';
import 'school_widgets.dart';

class SchoolReportsPanel extends StatefulWidget {
  const SchoolReportsPanel({super.key, required this.api});
  final RemoteSchoolApi api;
  @override
  State<SchoolReportsPanel> createState() => _ReportsState();
}

class _ReportsState extends State<SchoolReportsPanel>
    with SchoolActions<SchoolReportsPanel> {
  Future<List<List<Map<String, dynamic>>>>? _future;
  Future<void> _review(Map<String, dynamic> attempt) async {
    final values = await showSchoolForm(
      context,
      'Ручная проверка попытки',
      [
        SchoolField(
          'score',
          'Баллы от 0 до ${attempt['max_score']}',
          required: true,
        ),
      ],
      initial: {'score': 0},
    );
    if (values == null) return;
    final score = num.tryParse(values['score'].toString());
    if (score == null ||
        !score.isFinite ||
        score < 0 ||
        score > (attempt['max_score'] as num)) {
      throw const IntegrationException(
        'Оценка выходит за пределы баллов упражнения.',
      );
    }
    await widget.api.rpc('review_attempt', {
      'p_attempt_id': attempt['id'],
      'p_score': score,
    });
    if (mounted) setState(() => _future = null);
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<List<Map<String, dynamic>>>>(
    future: _future ??= Future.wait([
      widget.api.query(
        'attempts',
        columns:
            'id,student_id,exercise_id,status,score,max_score,passed,answers,created_at',
      ),
      widget.api.query(
        'submissions',
        columns: 'id,student_id,revision,status,updated_at,assignment_id',
      ),
      widget.api.query(
        'grades',
        columns: 'id,submission_id,revision,score,created_at',
      ),
    ]),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return schoolErrorCard(
          snapshot.error!,
          () => setState(() => _future = null),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final attempts = snapshot.data![0],
          submissions = snapshot.data![1],
          grades = snapshot.data![2];
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          status,
          const Text(
            'Только фактические записи, доступные вашему аккаунту по правилам сервера. Показатели не оценивают произношение и не меняют завершение уроков.',
          ),
          for (final entry in {
            'Попытки': attempts.length,
            'На ручной проверке': attempts
                .where((row) => row['status'] == 'pending_review')
                .length,
            'Работы': submissions.length,
            'Работы с запросом исправлений': submissions
                .where((row) => row['status'] == 'revision_requested')
                .length,
            'Записанные оценки': grades.length,
          }.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Panel(
                child: ListTile(
                  title: Text(entry.key),
                  trailing: Text('${entry.value}'),
                ),
              ),
            ),
          OutlinedButton(
            onPressed: busy ? null : () => setState(() => _future = null),
            child: const Text('Обновить отчёт'),
          ),
          for (final row in attempts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ученица ${row['student_id']}'),
                    Text(
                      '${row['status']} · ${row['score'] ?? '—'}/${row['max_score']} · ${schoolDate(row['created_at'])}',
                    ),
                    if (row['status'] == 'pending_review') ...[
                      SelectableText(
                        const JsonEncoder.withIndent(
                          '  ',
                        ).convert(row['answers']),
                      ),
                      FilledButton(
                        onPressed: busy ? null : () => run(() => _review(row)),
                        child: const Text('Оценить попытку'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}
