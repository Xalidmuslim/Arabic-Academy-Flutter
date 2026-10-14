import 'package:flutter/material.dart';

import '../../core/academy_state.dart';
import '../../core/learning_insights.dart';
import '../../core/study_calendar.dart';
import '../../services/local_study_reminders.dart';
import '../../ui/components.dart';
import '../../ui/design_tokens.dart';

class StudyCalendarScreen extends StatefulWidget {
  const StudyCalendarScreen({super.key, required this.state});
  final AcademyState state;

  @override
  State<StudyCalendarScreen> createState() => _StudyCalendarScreenState();
}

class _StudyCalendarScreenState extends State<StudyCalendarScreen> {
  late StudyCalendarPlan _plan;
  bool _saving = false;

  static const weekdays = <int, String>{
    1: 'Пн', 2: 'Вт', 3: 'Ср', 4: 'Чт',
    5: 'Пт', 6: 'Сб', 7: 'Вс',
  };

  @override
  void initState() {
    super.initState();
    _plan = StudyCalendarPlan.fromState(widget.state);
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _plan.hour, minute: _plan.minute),
      helpText: 'Время занятий на телефоне',
    );
    if (selected != null && mounted) {
      setState(() => _plan = _plan.copyWith(
        hour: selected.hour, minute: selected.minute,
      ));
    }
  }

  Future<void> _save() async {
    if (_saving || _plan.weekdays.isEmpty) {
      if (_plan.weekdays.isEmpty) {
        notice(context, 'Выберите хотя бы один день занятий.');
      }
      return;
    }
    setState(() => _saving = true);
    try {
      var plan = _plan;
      final previous = StudyCalendarPlan.fromState(widget.state);
      if (plan.notificationsEnabled) {
        final granted = await LocalStudyReminders().schedule(plan);
        if (!granted) {
          plan = plan.copyWith(notificationsEnabled: false);
          if (mounted) {
            notice(context,
              'Уведомления Android не разрешены. Расписание сохранится без них.');
          }
        }
      } else if (previous.notificationsEnabled) {
        await LocalStudyReminders().cancel();
      }
      await widget.state.setSetting('study_calendar_v1', plan.toJson());
      if (!mounted) return;
      setState(() => _plan = plan);
      notice(context, 'Личное расписание сохранено на этом устройстве.');
    } catch (error) {
      if (mounted) notice(context, 'Не удалось включить уведомления: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final insights = LearningInsights.dailyPlan(widget.state);
    final dateFormat = MaterialLocalizations.of(context);
    final upcoming = _plan.nextSessions(count: 12);
    return Scaffold(
      appBar: AppBar(title: const Text('Моё расписание')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 155),
        children: [
          const Text('Небольшие регулярные занятия помогают '
            'удерживать новые слова. Выберите удобные дни и время.',
            style: TextStyle(color: DesignTokens.secondary)),
          const SizedBox(height: 15),
          Panel(child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('План на ближайшее занятие',
                style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('К повторению: ${insights.due} слов'),
              Text('Новые слова: до ${insights.newWordLimit}'),
              Text('Текущие проверочные задания за день: '
                '${insights.completedQuestionsToday}'),
              if (insights.weakSkill != null)
                Text('Приоритет навыка: '
                    '${LearningInsights.skillLabels[
                      insights.weakSkill] ?? "повторение"}'),
              const SizedBox(height: 6),
              const Text('Количество повторений пересчитывается '
                'после ваших ответов; календарь не обещает '
                'точный результат обучения.',
                style: TextStyle(fontSize: 12,
                  color: DesignTokens.secondary)),
            ],
          )),
          const SectionTitle('Время и дни'),
          Panel(child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('study-calendar-time'),
                icon: const Icon(Icons.schedule),
                onPressed: _pickTime,
                label: Text('Начало: '
                    '${_plan.hour.toString().padLeft(2, "0")}:'
                    '${_plan.minute.toString().padLeft(2, "0")}'),
              ),
              const SizedBox(height: 11),
              Wrap(spacing: 7, runSpacing: 7, children: [
                for (final day in weekdays.entries)
                  FilterChip(
                    key: ValueKey('study-weekday-${day.key}'),
                    label: Text(day.value),
                    selected: _plan.weekdays.contains(day.key),
                    onSelected: (enabled) {
                      setState(() {
                        final days = {..._plan.weekdays};
                        enabled ? days.add(day.key) : days.remove(day.key);
                        _plan = _plan.copyWith(weekdays: days);
                      });
                    },
                  ),
              ]),
              const SizedBox(height: 10),
              Text('Продолжительность: ${_plan.dailyMinutes} мин'),
              Slider(
                value: _plan.dailyMinutes.toDouble(),
                min: 5, max: 60, divisions: 11,
                onChanged: (v) => setState(() => _plan =
                    _plan.copyWith(dailyMinutes: v.round())),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                key: const ValueKey('study-calendar-reminders'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Напоминания Android'),
                subtitle: const Text('Только по вашему согласию. '
                  'Энергосбережение телефона может задерживать уведомления.'),
                value: _plan.notificationsEnabled,
                onChanged: (v) => setState(() => _plan =
                    _plan.copyWith(notificationsEnabled: v)),
              ),
              if (_plan.notificationsEnabled) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: _plan.notifyMinutesBefore,
                  decoration: const InputDecoration(
                    labelText: 'Напомнить до занятия'),
                  items: const [
                    DropdownMenuItem(value: 0,
                      child: Text('В момент начала')),
                    DropdownMenuItem(value: 15,
                      child: Text('За 15 минут')),
                    DropdownMenuItem(value: 30,
                      child: Text('За 30 минут')),
                    DropdownMenuItem(value: 60,
                      child: Text('За 1 час')),
                    DropdownMenuItem(value: 120,
                      child: Text('За 2 часа')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _plan =
                          _plan.copyWith(notifyMinutesBefore: v));
                    }
                  },
                ),
              ],
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const ValueKey('study-calendar-save'),
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Сохранение…'
                  : 'Сохранить расписание'),
              ),
            ],
          )),
          const SectionTitle('Ближайшие занятия'),
          if (upcoming.isEmpty)
            const Panel(child: Text('Отметьте дни занятий.'))
          else
            Panel(child: Column(
              children: [
                for (final date in upcoming)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_available_outlined,
                      color: DesignTokens.deepOlive),
                    title: Text(dateFormat.formatMediumDate(date)),
                    subtitle: Text('${weekdays[date.weekday]} · '
                      '${date.hour.toString().padLeft(2, "0")}:'
                      '${date.minute.toString().padLeft(2, "0")} · '
                      '${_plan.dailyMinutes} минут'),
                  ),
              ],
            )),
          const SizedBox(height: 14),
          const Text('Работает без учётной записи и интернета. '
            'Запланированные уведомления — локальные, не сообщения '
            'учительницы. Переустановка может удалить план и прогресс.',
            style: TextStyle(
              fontSize: 12, color: DesignTokens.secondary)),
        ],
      ),
    );
  }
}
