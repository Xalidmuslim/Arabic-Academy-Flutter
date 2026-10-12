import 'package:flutter/material.dart';
import '../../core/academy_state.dart';
import '../../core/study_analytics.dart';
import '../../ui/components.dart';
import '../../ui/design_tokens.dart';
import '../../ui/premium_art.dart';
import 'lesson_screen.dart';

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
        final today = DateTime.now();
        final days = List.generate(
          7,
          (i) => today.subtract(Duration(days: 6 - i)),
        );
        return ListView(
          padding: const EdgeInsets.all(18),
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
                    subtitle: Text('Ваш ответ: ${attempt['answer']}'),
                    onTap: lesson == null
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
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
