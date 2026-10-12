import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../core/academy_state.dart';
import '../../core/app_strings.dart';
import '../../core/learning_sync.dart';
import '../../services/backend_service.dart';
import '../../services/push_service.dart';
import '../../ui/components.dart';
import '../integrations/phone_auth_screen.dart';
import '../integrations/purchases_screen.dart';
import 'notification_preferences.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.state, required this.backend});
  final AcademyState state;
  final BackendService backend;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr(context, 'Настройки'))),
    body: AnimatedBuilder(
      animation: state,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Panel(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(tr(context, 'Аккаунт')),
              subtitle: Text(
                backend.isAuthenticated
                    ? 'Выполнен вход по телефону'
                    : 'Данные обучения на этом устройстве',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PhoneAuthScreen(backend: backend),
                ),
              ),
            ),
          ),
          SectionTitle(tr(context, 'Язык интерфейса')),
          DropdownButtonFormField<String>(
            initialValue: state.settings['language'] as String? ?? 'ru',
            items: const [
              DropdownMenuItem(value: 'ru', child: Text('Русский')),
              DropdownMenuItem(value: 'ar', child: Text('العربية')),
            ],
            onChanged: (value) => guardedAction(
              context,
              () => state.setSetting('language', value ?? 'ru'),
            ),
          ),
          SectionTitle(tr(context, 'Размер русского текста')),
          _slider(context, 'russianScale', 0.85, 1.6, 1, '×'),
          SectionTitle(tr(context, 'Размер арабского текста')),
          _slider(context, 'arabicSize', 22, 42, 28, ' dp'),
          NaskhText(
            'أَنَا أَتَعَلَّمُ اللُّغَةَ الْعَرَبِيَّةَ.',
            size: (state.settings['arabicSize'] as num? ?? 28).toDouble(),
            height: (state.settings['arabicHeight'] as num? ?? 1.8).toDouble(),
          ),
          SectionTitle(tr(context, 'Межстрочный интервал')),
          _slider(context, 'arabicHeight', 1.65, 2.5, 1.8, '×'),
          SectionTitle(tr(context, 'Скорость синтеза речи')),
          _slider(context, 'audioSpeed', 0.2, 0.8, 0.45, '×'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr(context, 'Уменьшить анимации')),
            value: state.settings['reduceMotion'] == true,
            onChanged: (value) => guardedAction(
              context,
              () => state.setSetting('reduceMotion', value),
            ),
          ),
          SectionTitle(tr(context, 'Ежедневная цель')),
          _slider(context, 'dailyGoal', 5, 60, 15, ' мин'),
          SectionTitle(tr(context, 'Уведомления')),
          for (final entry in const {
            'lesson': 'Новые уроки',
            'assignment': 'Домашние задания',
            'live': 'Прямые эфиры',
            'feedback': 'Проверка работ',
            'message': 'Сообщения',
            'review': 'Повторение слов',
          }.entries)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr(context, entry.value)),
              value:
                  (state.settings['notification:${entry.key}'] ??
                      state.settings['notification:${entry.value}']) !=
                  false,
              onChanged: (value) => guardedAction(context, () async {
                if (backend.isAuthenticated) {
                  await saveNotificationPreference(backend, entry.key, value);
                }
                await state.setSetting('notification:${entry.key}', value);
              }),
            ),
          _PushButton(backend: backend),
          if (backend.isAuthenticated) ...[
            const SectionTitle('Синхронизация обучения'),
            OutlinedButton.icon(
              icon: const Icon(Icons.sync),
              label: Text(
                'Синхронизировать · ${state.pendingEvents.length} событий',
              ),
              onPressed: () => guardedAction(context, () async {
                final count = await LearningSync(backend).synchronize(state);
                if (context.mounted) {
                  notice(
                    context,
                    'Отправлено событий: $count. Личные данные обновлены.',
                  );
                }
              }),
            ),
          ],
          for (final conflict in state.syncConflicts)
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Две версии: ${conflict['draft_id']}'),
                  const Text(
                    'Выберите версию после сравнения. Автоматическая замена не выполняется.',
                  ),
                  SelectableText(
                    'На устройстве: ${jsonEncode(conflict['local'])}\nНа сервере: ${jsonEncode(conflict['remote'])}',
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => guardedAction(
                          context,
                          () => state.resolveDraftConflict(
                            conflict['id'] as String,
                            useRemote: false,
                          ),
                        ),
                        child: const Text('Оставить свою'),
                      ),
                      OutlinedButton(
                        onPressed: () => guardedAction(
                          context,
                          () => state.resolveDraftConflict(
                            conflict['id'] as String,
                            useRemote: true,
                          ),
                        ),
                        child: const Text('Принять серверную'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          SectionTitle(tr(context, 'Приватность')),
          OutlinedButton.icon(
            icon: const Icon(Icons.download),
            label: Text(tr(context, 'Экспорт данных')),
            onPressed: () => guardedAction(context, () async {
              final path = await FilePicker.platform.saveFile(
                dialogTitle: 'Сохранить резервную копию',
                fileName: 'bayna-learning-backup.json',
                type: FileType.custom,
                allowedExtensions: ['json'],
                bytes: Uint8List.fromList(utf8.encode(state.exportData())),
              );
              if (path != null && context.mounted) {
                notice(context, 'Резервная копия сохранена.');
              }
            }),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.workspace_premium_outlined),
            label: Text(tr(context, 'Покупки и подписки')),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PurchasesScreen(backend: backend),
              ),
            ),
          ),
          if (state.storageWarnings.isNotEmpty) ...[
            const SectionTitle('Восстановление данных'),
            ...state.storageWarnings.map(
              (message) => Panel(child: Text(message)),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Запись голоса выполняется только после согласия. Отправка записи на сервер запрашивает отдельное согласие. Демо-данные не публикуются автоматически.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 16),
          const Text(
            'Байна Ядайк · 0.7.0',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ],
      ),
    ),
  );

  Widget _slider(
    BuildContext context,
    String key,
    double min,
    double max,
    double fallback,
    String suffix,
  ) {
    final value = (state.settings[key] as num? ?? fallback).toDouble().clamp(
      min,
      max,
    );
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: key == 'dailyGoal' ? 11 : 20,
            onChanged: (value) =>
                guardedAction(context, () => state.setSetting(key, value)),
          ),
        ),
        Text(
          '${value.toStringAsFixed(key == 'arabicSize' || key == 'dailyGoal' ? 0 : 2)}$suffix',
        ),
      ],
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.backend});
  final BackendService backend;
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final Future<List<Map<String, dynamic>>> _items = _load();
  Future<List<Map<String, dynamic>>> _load() async {
    if (!widget.backend.isAuthenticated) return [];
    return await widget.backend.client
        .from('notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(100);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Уведомления')),
    body: FutureBuilder(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(18),
            child: EmptyState(
              title: 'Не удалось загрузить уведомления',
              message: 'Проверьте соединение и заново откройте раздел.',
              icon: Icons.cloud_off,
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(18),
            child: EmptyState(
              title: 'Пока нет уведомлений',
              message:
                  'Здесь появятся назначения, комментарии и изменения расписания.',
              icon: Icons.notifications_none,
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(18),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, i) {
            final item = snapshot.data![i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Panel(
                child: ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: Text(
                    (item['body'] as Map?)?['title'] as String? ??
                        item['kind'] as String? ??
                        'Уведомление',
                  ),
                  subtitle: Text(
                    (item['body'] as Map?)?['text'] as String? ?? '',
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

class _PushButton extends StatefulWidget {
  const _PushButton({required this.backend});
  final BackendService backend;
  @override
  State<_PushButton> createState() => _PushButtonState();
}

class _PushButtonState extends State<_PushButton> {
  late final PushService _push = PushService(widget.backend);
  bool _busy = false;
  @override
  void dispose() {
    _push.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    icon: const Icon(Icons.notifications_active_outlined),
    label: Text(_busy ? 'Подключение…' : 'Подключить push-уведомления'),
    onPressed: _busy
        ? null
        : () async {
            setState(() => _busy = true);
            await guardedAction(context, () async {
              if (!widget.backend.config.pushEnabled) {
                throw const IntegrationException(
                  'Push не настроен. Администратор должен подключить Firebase.',
                );
              }
              if (Firebase.apps.isEmpty) await Firebase.initializeApp();
              final confirmed = await _push.enable(consent: true);
              if (!confirmed) throw IntegrationException(_push.status);
              if (context.mounted) notice(context, _push.status);
            });
            if (mounted) setState(() => _busy = false);
          },
  );
}
