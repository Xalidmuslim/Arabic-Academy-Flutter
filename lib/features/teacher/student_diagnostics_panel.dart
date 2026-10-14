import 'package:flutter/material.dart';

import '../../core/academy_state.dart';
import '../../ui/components.dart';
import '../../ui/design_tokens.dart';
import 'demo_school_store.dart';
import 'student_diagnostics.dart';

/// Per-student teacher dashboard, strictly separated by student_id.
/// Skill evidence, demo fixtures and unverified pronunciation are labelled.
class StudentDiagnosticsPanel extends StatelessWidget {
  const StudentDiagnosticsPanel({
    super.key,
    required this.school,
    required this.learning,
    required this.studentId,
  });

  final DemoSchoolStore school;
  final AcademyState learning;
  final String studentId;

  Future<void> _assess(BuildContext context) async {
    final assessment = await showDialog<_SkillAssessmentDraft>(
      context: context,
      builder: (_) => const _ManualSkillAssessmentDialog(),
    );
    if (assessment == null || !context.mounted) return;
    await guardedAction(context, () => school.addSkillAssessment(
      studentId: studentId,
      skill: assessment.skill,
      score: assessment.score,
      note: assessment.note,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final report = StudentLearningReport.build(school, learning, studentId);
    final date = report.lastActivity;
    final lastDate = date == null
        ? 'Не зафиксирована'
        : '${date.day.toString().padLeft(2, '0')}.'
          '${date.month.toString().padLeft(2, '0')}.${date.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Учебный профиль'),
        Panel(child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(report.localLearningAvailable
                ? 'Источники: выполненные задания на этом телефоне '
                  '+ индивидуальные оценки учительницы.'
                : 'Источники: только оценки и работы этого '
                  'демопрофиля. Учёба других учениц не подмешивается.',
              style: const TextStyle(
                fontSize: 12, color: DesignTokens.secondary)),
            const SizedBox(height: 12),
            Wrap(spacing: 16, runSpacing: 10, children: [
              _shortStat('Заданий', '${report.assigned}'),
              _shortStat('Отправлено', '${report.submitted}'),
              _shortStat('Проверено', '${report.graded}'),
              _shortStat('На исправление', '${report.revision}'),
            ]),
            const SizedBox(height: 12),
            Text('Средняя оценка домашних работ: '
                '${report.gradedHomeworkAverage == null
                  ? "Нет оценок"
                  : "${report.gradedHomeworkAverage!.round()}/100"}'),
            Text('Последняя активность: $lastDate'),
            if (report.localLearningAvailable) ...[
              Text('Упражнений: ${report.totalAttemptCount} · '
                'За 7 дней: ${report.recentAttemptCount}'),
              Text('Дней с заданиями: ${report.daysStudied}'),
            ],
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: report.assigned == 0
                  ? 0 : report.submitted / report.assigned,
              backgroundColor: DesignTokens.beige,
              color: DesignTokens.olive,
              borderRadius: BorderRadius.circular(8),
              minHeight: 7,
            ),
            const SizedBox(height: 4),
            const Text('Полоса показывает долю сданных домашних '
              'работ, а не знание арабского языка.',
              style: TextStyle(
                fontSize: 11, color: DesignTokens.secondary)),
          ],
        )),
        SectionTitle(
          'Усвоение по навыкам',
          trailing: IconButton(
            key: const ValueKey('student-manual-assessment'),
            tooltip: 'Добавить ручную оценку навыка',
            icon: const Icon(Icons.add_circle_outline,
                color: DesignTokens.deepOlive),
            onPressed: () => _assess(context),
          ),
        ),
        const Text('Автоматические результаты и оценки учительницы '
          'показаны отдельно. Произношение оценивается только вручную '
          'после прослушивания записи.',
          style: TextStyle(fontSize: 12, color: DesignTokens.secondary)),
        const SizedBox(height: 10),
        for (final skill in report.skills)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
              padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
              child: ExpansionTile(
                key: ValueKey('student-skill-${skill.id}'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 12),
                title: Text(skill.title,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(skill.status,
                  style: const TextStyle(
                    fontSize: 12, color: DesignTokens.secondary)),
                trailing: Text(skill.automaticAccuracy != null
                    ? '${(skill.automaticAccuracy! * 100).round()}%'
                    : skill.teacherAverage != null
                        ? '${skill.teacherAverage!.round()}/100*' : '—',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: DesignTokens.deepOlive)),
                children: [
                  if (skill.automaticAccuracy != null)
                    LinearProgressIndicator(
                      value: skill.automaticAccuracy!,
                      minHeight: 7,
                      backgroundColor: DesignTokens.beige,
                      color: DesignTokens.olive,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  const SizedBox(height: 7),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Упражнения: ${skill.attempts}; '
                      'верно: ${skill.correct}; '
                      'ошибок: ${skill.errors}.',
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(skill.teacherAverage == null
                        ? 'Учительская оценка: не проводилась.'
                        : 'Учительская оценка: '
                          '${skill.teacherAverage!.round()}/100 '
                          '(${skill.teacherScores.length} проверок).'),
                  ),
                  if (skill.pendingManual > 0)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Ручной проверки ожидают: '
                        '${skill.pendingManual} работ.'),
                    ),
                  if (skill.id == 'pronunciation')
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Нельзя оценивать произношение только '
                        'по записи текста или наличию аудиофайла.',
                        style: TextStyle(fontSize: 12,
                          color: DesignTokens.secondary)),
                    ),
                  for (final note in skill.notes)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Комментарий: $note',
                          style: const TextStyle(
                            fontSize: 12, color: DesignTokens.secondary)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        const Text('* Оценки со звёздочкой поставлены учительницей вручную.',
          style: TextStyle(fontSize: 11, color: DesignTokens.secondary)),
        if (report.localLearningAvailable) ...[
          const SectionTitle('Запоминание слов'),
          Panel(child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Повторяли: ${report.wordReviewed} · '
                'Устойчиво на этапах 2–5: ${report.wordMastered}'),
              const SizedBox(height: 5),
              Text('К повторению: ${report.wordDue} · '
                'Трудных: ${report.wordDifficult}'),
              Text('Случаев забывания в истории: ${report.wordLapses}'),
              if (report.hardWords.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Сложные слова пока не выявлены.'),
                ),
              for (final word in report.hardWords)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: NaskhText(word.arabic, size: 23),
                  subtitle: Text('${word.translation} · '
                    'этап ${word.stage}/5 · забываний ${word.lapses}'
                    '${word.due ? " · повторить" : ""}'),
                  trailing: word.due
                      ? const Icon(Icons.schedule,
                        color: DesignTokens.deepOlive) : null,
                ),
            ],
          )),
        ],
        const SectionTitle('Где чаще ошибается'),
        if (report.errors.isEmpty)
          const Panel(child: Text('Нет непроработанных ошибок по '
            'автоматически проверенным упражнениям. '
            'Ошибки других учениц сюда не попадают.'))
        else
          for (final error in report.errors)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${error.skill} · ${error.lesson}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text('Ошибок в истории: ${error.count}',
                    style: const TextStyle(
                      fontSize: 12, color: DesignTokens.secondary)),
                  if (error.response.isNotEmpty)
                    Text('Ответ ученицы: ${error.response}'),
                  if (error.expected.isNotEmpty)
                    Text('Правильный ответ: ${error.expected}'),
                  if (error.explanation.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(error.explanation),
                    ),
                ],
              )),
            ),
        const SectionTitle('Рекомендации учительнице'),
        Panel(child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final suggestion in report.recommendations)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 20,
                      color: DesignTokens.deepOlive),
                    const SizedBox(width: 10),
                    Expanded(child: Text(suggestion)),
                  ],
                ),
              ),
            OutlinedButton.icon(
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Добавить проверку навыка'),
              onPressed: () => _assess(context),
            ),
          ],
        )),
        if (report.sampleLessonScores.isNotEmpty) ...[
          const SectionTitle('Образцы результатов демоуроков'),
          Panel(child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Эти цифры — примеры заполнения демокабинета, '
                'а не подтверждённый уровень навыков ученицы.',
                style: TextStyle(fontSize: 12,
                  color: DesignTokens.secondary)),
              for (final sample in report.sampleLessonScores)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(sample['lesson_id']?.toString() ?? 'Урок'),
                  trailing: Text('${sample['score'] ?? "—"}/100'),
                ),
            ],
          )),
        ],
      ],
    );
  }

  Widget _shortStat(String label, String number) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(number,
            style: const TextStyle(fontWeight: FontWeight.w800,
              fontSize: 22, color: DesignTokens.deepOlive)),
          Text(label, style: const TextStyle(
            fontSize: 11, color: DesignTokens.secondary)),
        ],
      );
}

class _SkillAssessmentDraft {
  const _SkillAssessmentDraft(this.skill, this.score, this.note);
  final String skill;
  final int score;
  final String note;
}

class _ManualSkillAssessmentDialog extends StatefulWidget {
  const _ManualSkillAssessmentDialog();
  @override
  State<_ManualSkillAssessmentDialog> createState() =>
      _ManualSkillAssessmentDialogState();
}

class _ManualSkillAssessmentDialogState
    extends State<_ManualSkillAssessmentDialog> {
  final _form = GlobalKey<FormState>();
  final _score = TextEditingController(text: '80');
  final _note = TextEditingController();
  String _skill = 'pronunciation';

  @override
  void dispose() {
    _score.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ручная оценка навыка'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Оценка учительницы сохраняется как '
                'ручное наблюдение, не как результат алгоритма.',
                style: TextStyle(fontSize: 12,
                  color: DesignTokens.secondary)),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _skill,
                decoration: const InputDecoration(
                  labelText: 'Какой навык проверили'),
                isExpanded: true,
                items: [
                  for (final skill in StudentLearningReport.skillNames.entries)
                    DropdownMenuItem(
                      value: skill.key, child: Text(skill.value)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _skill = value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _score,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Оценка от 0 до 100'),
                validator: (value) {
                  final score = int.tryParse(value?.trim() ?? '');
                  return score == null || score < 0 || score > 100
                      ? 'Введите целое число от 0 до 100'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                maxLines: 3,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Где ошиблась и что повторить',
                  hintText: 'Например, путает долгие гласные',
                ),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? 'Укажите конкретное наблюдение'
                    : null,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена')),
      FilledButton(
        key: const ValueKey('save-student-skill-assessment'),
        onPressed: () {
          if (!(_form.currentState?.validate() ?? false)) return;
          Navigator.pop(context, _SkillAssessmentDraft(
            _skill, int.parse(_score.text.trim()), _note.text.trim()));
        },
        child: const Text('Сохранить оценку'),
      ),
    ],
  );
}
