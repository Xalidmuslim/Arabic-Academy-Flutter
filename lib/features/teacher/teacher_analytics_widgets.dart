import 'package:flutter/material.dart';

import '../../ui/components.dart';
import 'student_diagnostics.dart';

/// Concise teacher chart with no fabricated values.
/// Automatic accuracy and teacher judgement are separate columns.
class PupilSkillsOverview extends StatelessWidget {
  const PupilSkillsOverview({super.key, required this.report});
  final StudentLearningReport report;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.bar_chart_rounded, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text('Диаграмма навыков',
            style: Theme.of(context).textTheme.titleMedium)),
        ]),
        const SizedBox(height: 6),
        Text('Автоматическая точность и оценки учительницы — разные показатели.',
          style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 14),
        for (final skill in report.skills) ...[
          Row(children: [
            Expanded(child: Text(skill.title,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
            Text(skill.automaticAccuracy == null
                ? '—' : '${(skill.automaticAccuracy! * 100).round()}%',
              style: TextStyle(fontWeight: FontWeight.w800,
                color: scheme.onSurface)),
            const SizedBox(width: 10),
            Text(skill.teacherAverage == null
                ? '—' : '${skill.teacherAverage!.round()}*',
              style: TextStyle(fontSize: 12, color: scheme.secondary)),
          ]),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Stack(children: [
              LinearProgressIndicator(
                value: skill.automaticAccuracy ?? 0,
                minHeight: 10,
                color: scheme.primary,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
              if (skill.teacherAverage != null)
                FractionallySizedBox(
                  widthFactor: (skill.teacherAverage! / 100).clamp(0.0, 1.0),
                  child: Align(alignment: Alignment.centerRight,
                    child: Container(
                      height: 10, width: 3,
                      color: scheme.secondary,
                    )),
                ),
            ]),
          ),
          const SizedBox(height: 10),
        ],
        Wrap(spacing: 14, runSpacing: 6, children: [
          _legend(context, scheme.primary, 'Автопроверка'),
          _legend(context, scheme.secondary, 'Оценка учительницы *'),
        ]),
        const SizedBox(height: 10),
        Divider(color: scheme.outlineVariant),
        const SizedBox(height: 4),
        Text('Проверки по навыкам',
          style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(2.5),
            1: FlexColumnWidth(1.1),
            2: FlexColumnWidth(1.1),
            3: FlexColumnWidth(1.2),
          },
          children: [
            _row(context, ['Навык', 'Попыток', 'Верно', 'Оценка'], heading: true),
            for (final skill in report.skills)
              _row(context, [
                skill.title,
                skill.attempts == 0 ? '—' : '${skill.attempts}',
                skill.attempts == 0 ? '—' : '${skill.correct}',
                skill.teacherAverage == null ? '—'
                    : '${skill.teacherAverage!.round()}/100',
              ]),
          ],
        ),
        const SizedBox(height: 6),
        Text('«—» означает, что достоверных результатов пока нет.',
          style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }

  TableRow _row(BuildContext context, List<String> items,
      {bool heading = false}) => TableRow(children: [
    for (final value in items)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
        child: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: heading ? 10 : 11.5,
            fontWeight: heading ? FontWeight.w800 : FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface)),
      ),
  ]);

  Widget _legend(BuildContext context, Color color, String label) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ]);
}

/// Word-learning chart is only displayed when this pupil owns word reviews.
class PupilVocabularyOverview extends StatelessWidget {
  const PupilVocabularyOverview({super.key, required this.report});
  final StudentLearningReport report;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!report.localLearningAvailable) {
      return Panel(child: Row(children: [
        Icon(Icons.info_outline, color: scheme.primary),
        const SizedBox(width: 10),
        const Expanded(child: Text('Данных повторений пока нет. '
          'Нужны результаты этой ученицы, а не другого профиля.')),
      ]));
    }
    final reviewed = report.wordReviewed;
    final mastered = report.wordMastered;
    final fraction = reviewed == 0
        ? 0.0 : (mastered / reviewed).clamp(0.0, 1.0).toDouble();
    return Panel(child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Запоминание слов', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(children: [
          SizedBox(height: 104, width: 104,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox.expand(child: CircularProgressIndicator(
                value: fraction,
                strokeWidth: 10,
                strokeCap: StrokeCap.round,
                color: scheme.primary,
                backgroundColor: scheme.surfaceContainerHighest,
              )),
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(reviewed == 0 ? '—' : '${(fraction * 100).round()}%',
                  style: Theme.of(context).textTheme.titleLarge),
                Text('закреплено', style: Theme.of(context).textTheme.bodySmall),
              ]),
            ]),
          ),
          const SizedBox(width: 18),
          Expanded(child: Column(children: [
            _metric(context, 'Повторяли', report.wordReviewed),
            _metric(context, 'Закреплено', report.wordMastered),
            _metric(context, 'К повторению', report.wordDue),
            _metric(context, 'Трудных', report.wordDifficult),
            _metric(context, 'Забываний', report.wordLapses),
          ])),
        ]),
        const SizedBox(height: 10),
        Text('Круг отражает долю закреплённых среди повторявшихся слов. '
          'Это не общая оценка знания языка.',
          style: Theme.of(context).textTheme.bodySmall),
      ],
    ));
  }

  Widget _metric(BuildContext context, String title, int value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Expanded(child: Text(title, style: Theme.of(context).textTheme.bodySmall)),
      Text('$value', style: TextStyle(fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.onSurface)),
    ]),
  );
}
