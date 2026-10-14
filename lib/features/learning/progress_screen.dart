import 'package:flutter/material.dart';
import '../../core/academy_state.dart';
import '../../core/study_analytics.dart';
import '../../core/learning_insights.dart';
import '../../ui/components.dart';
import '../../ui/design_tokens.dart';
import '../../ui/premium_art.dart';
import 'lesson_screen.dart';
import 'practice_center_screen.dart';

class LearnerProgressScreen extends StatelessWidget {
  const LearnerProgressScreen({super.key, required this.state});
  final AcademyState state;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Мой прогресс')),
    body: AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final data = StudyAnalytics(state);
        final skills = LearningInsights.skills(state);
        final plan = LearningInsights.dailyPlan(state);
        final weak = <String, int>{};
        for (final attempt in data.mistakes) {
          final id = attempt['lesson_id']?.toString() ?? '';
          if (id.isNotEmpty) weak[id] = (weak[id] ?? 0) + 1;
        }
        final weakTopics = weak.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final exams = state.attempts.where((attempt) =>
          attempt['exercise_id']?.toString().startsWith(
            'practice:exam:') == true).toList().reversed.take(8);
        final today = DateTime.now();
        final days = List.generate(
          7,
          (i) => today.subtract(Duration(days: 6 - i)),
        );
        return ListView(
          key: const PageStorageKey<String>('learner-progress-position'),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 150),
          children: [
            Panel(
              child: Row(
                children: [
                  ProgressRing(value: data.progress),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Базовый уровень 1',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Пройдено ${data.completedLessons} из ${data.totalLessons} уроков',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SectionTitle('Статистика'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _metric(
                  context,
                  'Уроки',
                  '${data.completedLessons}',
                  Icons.auto_stories_outlined,
                ),
                _metric(
                  context,
                  'Попытки',
                  '${state.attempts.length}',
                  Icons.fact_check_outlined,
                ),
                _metric(
                  context,
                  'Точность',
                  data.accuracy == null
                      ? '—'
                      : '${(data.accuracy! * 100).round()}%',
                  Icons.check_circle_outline,
                ),
                _metric(
                  context,
                  'Время',
                  '${data.studySeconds ~/ 60} мин',
                  Icons.schedule,
                ),
                _metric(
                  context,
                  'Слова',
                  '${data.learnedWords}',
                  Icons.style_outlined,
                ),
                _metric(
                  context,
                  'Серия дней',
                  '${data.streak()}',
                  Icons.local_fire_department_outlined,
                ),
              ],
            ),
            const SectionTitle('Неделя обучения'),
            Panel(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: days
                    .map(
                      (day) => Column(
                        children: [
                          Text(
                            '${day.day}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          CircleAvatar(
                            radius: 14,
                            backgroundColor:
                                data.activeDays.contains(
                                  StudyAnalytics.dayKey(day),
                                )
                                ? DesignTokens.olive
                                : DesignTokens.beige,
                            child:
                                data.activeDays.contains(
                                  StudyAnalytics.dayKey(day),
                                )
                                ? const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
            if (data.completedLessons > 0) ...[
              const SectionTitle('Достижения'),
              const Panel(
                child: ListTile(
                  leading: Icon(
                    Icons.workspace_premium_outlined,
                    color: DesignTokens.olive,
                  ),
                  title: Text('Первый шаг'),
                  subtitle: Text('Вы завершили первый урок.'),
                ),
              ),
            ],
            const SectionTitle('Карта знаний'),
            Panel(child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Оцениваем только проверенные ответы. '
                  'Отсутствие данных не означает отсутствие знаний.',
                  style: TextStyle(fontSize: 12, color: DesignTokens.secondary)),
                const SizedBox(height: 14),
                LayoutBuilder(builder: (context, constraints) {
                  final single = constraints.maxWidth < 330 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.5;
                  final width = single ? constraints.maxWidth :
                      (constraints.maxWidth - 9) / 2;
                  return Wrap(spacing: 9, runSpacing: 9, children: [
                    for (final skill in skills)
                      SizedBox(width: width, child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: ValueKey('skill-map-${skill.id}'),
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            showDragHandle: true,
                            builder: (sheet) => SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.all(22),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(skill.name,
                                      style: Theme.of(sheet).textTheme.titleLarge),
                                    const SizedBox(height: 8),
                                    Text(skill.accuracy == null
                                      ? 'Результатов пока нет. Пройдите упражнение, '
                                        'чтобы начать отслеживать этот навык.'
                                      : 'Верных ответов: ${skill.percent}% '
                                        'из ${skill.total} проверенных попыток.'),
                                    const SizedBox(height: 12),
                                    const Text('Рекомендация: тренируйте навык '
                                      'короткими занятиями и повторяйте ошибки.',
                                      style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          child: Panel(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(skill.name, maxLines: 2,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Text(skill.accuracy == null
                                  ? 'Не проверено'
                                  : '${skill.percent}% · ${skill.total} ответов',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: DesignTokens.secondary)),
                              const SizedBox(height: 9),
                              LinearProgressIndicator(
                                value: skill.accuracy ?? 0,
                                backgroundColor: DesignTokens.beige,
                                color: DesignTokens.olive,
                                minHeight: 7,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ],
                          )),
                        ),
                      )),
                  ]);
                }),
                const SizedBox(height: 14),
                Text('Устойчиво освоенных слов: '
                  '${LearningInsights.totalMasteredWords(state)}'),
                Text('Следующий план: ${plan.due} повторений; '
                  'до ${plan.newWordLimit} новых слов.'),
              ],
            )),
            const SectionTitle('Проверка знаний'),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Сложных слов: ${data.difficultWords} · '
                    'Освоенных: ${data.learnedWords}'),
                  const SizedBox(height: 8),
                  Text('Автоматических проверок: '
                    '${data.automaticAttempts} · '
                    'Точность: ${data.accuracy == null
                      ? "—" : "${(data.accuracy! * 100).round()}%"}'),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(context,
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('Практика')),
                          body: PracticeCenterScreen(state: state),
                        ),
                      )),
                    icon: const Icon(Icons.psychology_alt_outlined),
                    label: const Text('Повторить и закрепить'),
                  ),
                ],
              ),
            ),
            if (weakTopics.isNotEmpty) ...[
              const SectionTitle('Сложные темы'),
              for (final entry in weakTopics.take(4))
                ListTile(
                  leading: const Icon(Icons.trending_down_outlined,
                    color: DesignTokens.olive),
                  title: Text(state.allLessons
                    .where((lesson) => lesson['id'] == entry.key)
                    .map((lesson) => lesson['title']?.toString() ?? entry.key)
                    .firstOrNull ?? entry.key),
                  subtitle: Text('Ошибок: ${entry.value}'),
                ),
            ],
            if (exams.isNotEmpty) ...[
              const SectionTitle('Контрольные работы'),
              for (final result in exams)
                Panel(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.assignment_turned_in_outlined,
                      color: DesignTokens.deepOlive),
                    title: Text('Раздел: ${result['lesson_id']}'),
                    subtitle: Text('Правильно: '
                      '${(result['answer'] as Map?)?['correct'] ?? "—"} из '
                      '${(result['answer'] as Map?)?['completed'] ?? "—"} · '
                      '${result['status'] == 'correct'
                        ? 'Зачтено' : 'Повторить'}'),
                  ),
                ),
            ],
            const SectionTitle('Работа над ошибками'),
            if (data.mistakes.isEmpty)
              const EmptyState(
                title: 'Ошибок пока нет',
                message: 'Здесь появятся задания, которые стоит повторить.',
              ),
            ...data.mistakes.take(10).map((attempt) {
              final matches = state.allLessons.where(
                (lesson) => lesson['id'] == attempt['lesson_id'],
              );
              final lesson = matches.isEmpty ? null : matches.first;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(
                      Icons.refresh,
                      color: DesignTokens.olive,
                    ),
                    title: Text(lesson?['title'] as String? ?? 'Упражнение'),
                    subtitle: _MistakeSummary(answer: attempt['answer']),
                    onTap: lesson == null
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              settings: const RouteSettings(name: '/progress/review-mistake'),
                              builder: (_) => LessonScreen(
                                state: state,
                                lesson: lesson,
                                initialTab: 4,
                              ),
                            ),
                          ),
                  ),
                ),
              );
            }),
            const SectionTitle('Мои уроки'),
            ...state.allLessons.map(
              (lesson) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Panel(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: const ArtworkIcon('books', size: 46),
                    title: Text(lesson['title'] as String? ?? ''),
                    subtitle: Text(
                      state.completed.contains(lesson['id'])
                          ? 'Завершён'
                          : 'Для изучения',
                    ),
                    trailing: Icon(
                      state.completed.contains(lesson['id'])
                          ? Icons.check_circle
                          : Icons.chevron_right,
                      color: DesignTokens.olive,
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            LessonScreen(state: state, lesson: lesson),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _metric(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) => SizedBox(
    width: (MediaQuery.sizeOf(context).width - 46) / 2,
    child: Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: DesignTokens.olive),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          Text(title),
        ],
      ),
    ),
  );
}

/// Practice results use structured JSON. Never stringify maps into the UI:
/// response/expected/feedback/source are internal keys, not Russian words.
class _MistakeSummary extends StatelessWidget {
  const _MistakeSummary({required this.answer});
  final Object? answer;

  @override
  Widget build(BuildContext context) {
    if (answer is Map) {
      final fields = Map<Object?, Object?>.from(answer as Map);
      final response = fields['response']?.toString().trim() ?? '';
      final expected = fields['expected']?.toString().trim() ?? '';
      final feedback = fields['feedback']?.toString().trim() ?? '';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (response.isNotEmpty) Text('Ответ ученицы: $response'),
          if (expected.isNotEmpty) Text('Правильный ответ: $expected'),
          if (feedback.isNotEmpty) Text('Пояснение: $feedback'),
          if (response.isEmpty && expected.isEmpty && feedback.isEmpty)
            const Text('Повторите это упражнение.'),
        ],
      );
    }
    final response = answer?.toString().trim() ?? '';
    return Text(response.isEmpty
        ? 'Нажмите, чтобы повторить упражнение'
        : 'Ваш ответ: $response');
  }
}
