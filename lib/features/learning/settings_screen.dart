import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../core/academy_state.dart';
import '../../core/speech.dart';
import '../../core/app_strings.dart';
import '../../core/learning_sync.dart';
import '../../services/backend_service.dart';
import '../../services/push_service.dart';
import '../../ui/components.dart';
import '../../ui/design_tokens.dart';
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
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
        children: [
          Panel(
            padding: EdgeInsets.zero,
            child: ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: const EdgeInsets.symmetric(horizontal: 13),
              leading: const Icon(Icons.person_outline, size: 23),
              title: Text(tr(context, 'Аккаунт'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              subtitle: Text(
                backend.isAuthenticated
                    ? 'Выполнен вход по телефону'
                    : 'Данные обучения на этом устройстве',
                style: const TextStyle(fontSize: 12.5, height: 1.25),
                maxLines: 2,
              ),
              trailing: const Icon(Icons.chevron_right, size: 21),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PhoneAuthScreen(backend: backend),
                ),
              ),
            ),
          ),
          _section(tr(context, 'Язык интерфейса')),
          DropdownButtonFormField<String>(
            isDense: true,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            ),
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
          ExpansionTile(
            key: const ValueKey('reading-preferences'),
            initiallyExpanded: false,
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: Text(
              tr(context, 'Чтение и произношение'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            children: [
            _compactSlider(context, tr(context, 'Размер русского текста'),
                'russianScale', 0.85, 1.6, 1, '×'),
            _compactSlider(context, tr(context, 'Размер арабского текста'),
                'arabicSize', 22, 42, 28, ' dp'),
            Align(
              alignment: Alignment.centerRight,
              child: NaskhText(
                'أَنَا أَتَعَلَّمُ اللُّغَةَ الْعَرَبِيَّةَ.',
                size: (state.settings['arabicSize'] as num? ?? 28).toDouble(),
                height: 1.12, // Preview is compact; lesson spacing is unchanged.
              ),
            ),
            _compactSlider(context, tr(context, 'Межстрочный интервал'),
                'arabicHeight', 1.65, 2.5, 1.8, '×'),
            _compactSlider(context, tr(context, 'Скорость синтеза речи'),
                'audioSpeed', 0.38, 0.65, 0.50, '×'),
            _ArabicVoiceSettings(state: state),
            SwitchListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
              title: Text(tr(context, 'Уменьшить анимации'),
                  style: const TextStyle(fontSize: 14)),
              value: state.settings['reduceMotion'] == true,
              onChanged: (value) => guardedAction(
                context,
                () => state.setSetting('reduceMotion', value),
              ),
            ),
            ],
          ),
          _compactSlider(context, tr(context, 'Ежедневная цель'),
              'dailyGoal', 5, 60, 15, ' мин'),
          // Optional controls are kept, but do not dominate Settings.
          ExpansionTile(
            key: const ValueKey('notification-preferences'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 4),
            initiallyExpanded: false,
            title: Text(tr(context, 'Уведомления'),
              style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
              ),
            ),
            children: [
              for (final entry in const {
            'lesson': 'Новые уроки',
            'assignment': 'Домашние задания',
            'live': 'Прямые эфиры',
            'feedback': 'Проверка работ',
            'message': 'Сообщения',
            'review': 'Повторение слов',
          }.entries)
                SwitchListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
              title: Text(tr(context, entry.value),
                  style: const TextStyle(fontSize: 14)),
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
            ],
          ),
          if (backend.isAuthenticated) ...[
            _section('Синхронизация обучения'),
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
          _section(tr(context, 'Приватность')),
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
            _section('Восстановление данных'),
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

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 9, bottom: 4),
    child: Text(title, style: const TextStyle(
      fontSize: 14, fontWeight: FontWeight.w700, color: DesignTokens.ink,
    )),
  );

  Widget _compactSlider(BuildContext context, String title, String key,
      double min, double max, double fallback, String suffix) {
    final value = (state.settings[key] as num? ?? fallback).toDouble().clamp(min, max);
    final display = '${value.toStringAsFixed(
      key == 'arabicSize' || key == 'dailyGoal' ? 0 : 2,
    )}$suffix';
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title, style: const TextStyle(
            fontSize: 13.5, fontWeight: FontWeight.w600, color: DesignTokens.ink,
          ))),
          Text(display, style: const TextStyle(fontSize: 12.5,
              color: DesignTokens.secondary)),
        ]),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2.5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: SizedBox(height: 34, child: Slider(
            value: value, min: min, max: max,
            divisions: key == 'dailyGoal' ? 11 : 20,
            onChanged: (next) => guardedAction(
              context, () => state.setSetting(key, next),
            ),
          )),
        ),
      ]),
    );
  }

}


class _ArabicVoiceSettings extends StatefulWidget {
  const _ArabicVoiceSettings({required this.state});
  final AcademyState state;
  @override
  State<_ArabicVoiceSettings> createState() => _ArabicVoiceSettingsState();
}

class _ArabicVoiceSettingsState extends State<_ArabicVoiceSettings> {
  late Future<(List<String>, List<ArabicVoice>)> _available = _load();

  Future<(List<String>, List<ArabicVoice>)> _load() async {
    final engines = await ArabicSpeech.availableEngines();
    final chosen = widget.state.settings['audioEngine'] as String?;
    final voices = await ArabicSpeech.availableVoices(engine: chosen);
    return (engines, voices);
  }

  void _refresh() => setState(() => _available = _load());

  @override
  Widget build(BuildContext context) => FutureBuilder<(List<String>, List<ArabicVoice>)>(
    future: _available,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Не удалось получить голоса устройства. Проверьте настройки TTS Android.'),
            TextButton(onPressed: _refresh, child: const Text('Обновить список')),
          ],
        );
      }
      if (!snapshot.hasData) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: LinearProgressIndicator(minHeight: 2),
        );
      }
      final engines = snapshot.requireData.$1;
      final voices = snapshot.requireData.$2;
      final engine = widget.state.settings['audioEngine'] as String?;
      final voiceName = widget.state.settings['audioVoiceName'] as String?;
      final voiceLocale = widget.state.settings['audioVoiceLocale'] as String?;
      final selectedVoice = voices.any((voice) =>
          voice.name == voiceName && voice.locale == voiceLocale)
          ? '$voiceLocale::$voiceName' : '';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Арабский голос телефона',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            key: ValueKey('tts-engine-${engine ?? 'system'}'),
            isDense: true,
            initialValue: engines.contains(engine) ? engine : '',
            decoration: const InputDecoration(labelText: 'Движок речи', isDense: true),
            items: [
              const DropdownMenuItem(value: '', child: Text('Системный')),
              for (final value in engines)
                DropdownMenuItem(value: value, child: Text(value,
                    overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (value) => guardedAction(context, () async {
              await widget.state.setSetting('audioEngine', value ?? '');
              await widget.state.setSetting('audioVoiceName', '');
              await widget.state.setSetting('audioVoiceLocale', '');
              _refresh();
            }),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey('tts-voice-$selectedVoice'),
            isDense: true,
            initialValue: selectedVoice,
            decoration: const InputDecoration(labelText: 'Голос арабского языка', isDense: true),
            items: [
              const DropdownMenuItem(value: '', child: Text('Автоматически')),
              for (final voice in voices)
                DropdownMenuItem(value: voice.key,
                  child: Text(voice.label, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (value) => guardedAction(context, () async {
              final selected = voices.where((voice) => voice.key == value).firstOrNull;
              await widget.state.setSetting('audioVoiceName', selected?.name ?? '');
              await widget.state.setSetting('audioVoiceLocale', selected?.locale ?? '');
            }),
          ),
          const SizedBox(height: 5),
          Text(voices.isEmpty
              ? 'Арабские голоса не найдены. Установите арабский голос в настройках Android.'
              : 'Качество определяется установленным голосом. Для онлайн-голосов нужен интернет.',
              style: const TextStyle(fontSize: 11.5, color: DesignTokens.secondary)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('tts-preview'),
              onPressed: () => guardedAction(context, () => ArabicSpeech.speak(
                'السَّلَامُ عَلَيْكُمْ. أَهْلًا وَسَهْلًا.',
                speed: (widget.state.settings['audioSpeed'] as num? ?? 0.50).toDouble(),
                engine: engine,
                voiceName: voiceName,
                voiceLocale: voiceLocale,
              )),
              icon: const Icon(Icons.volume_up_outlined),
              label: const Text('Послушать выбранный голос'),
            ),
          ),
        ],
      );
    },
  );
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
