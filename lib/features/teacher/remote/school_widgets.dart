import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/backend_service.dart';
import '../../../ui/components.dart' show Panel, NaskhText;
import 'school_api.dart';
import 'school_models.dart';

String schoolError(Object error) {
  if (error is IntegrationException) return error.message;
  if (error is PostgrestException && error.code == 'PGRST202') {
    return 'Функция школы ещё не активирована на сервере. Администратору нужно развернуть актуальный серверный контракт. После активации повторите действие.';
  }
  if (error is PostgrestException && error.code == '40001') {
    return 'Запись уже изменена на сервере. Ваш черновик сохранён на экране. Сверьте его с новой версией перед повторным сохранением.';
  }
  if (error is PostgrestException && error.code == '42501') {
    return 'Сервер отклонил действие. Проверьте роль и назначение на курс или группу.';
  }
  if (error is PostgrestException && error.code == '23505') {
    return 'Такая запись или оценка уже существует. Обновите список перед повторным действием.';
  }
  return 'Не удалось выполнить запрос. Проверьте сеть и подключение школы. Обновите данные и повторите действие.';
}

mixin SchoolActions<T extends StatefulWidget> on State<T> {
  bool busy = false;
  String? error;
  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (exception) {
      if (mounted) {
        final message = schoolError(exception);
        setState(() => error = message);
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget get status => Column(
    children: [
      if (busy && ModalRoute.of(context)?.isCurrent != false)
        const LinearProgressIndicator(),
      if (error != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Semantics(
            liveRegion: true,
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
    ],
  );
}

class SchoolAccess extends StatefulWidget {
  const SchoolAccess({super.key, required this.api, required this.builder});
  final RemoteSchoolApi api;
  final Widget Function(ServerRole role) builder;
  @override
  State<SchoolAccess> createState() => _SchoolAccessState();
}

class _SchoolAccessState extends State<SchoolAccess> {
  late Future<ServerRole> _role;
  late String? _owner;
  String? _roleError;
  Future<ServerRole> _checkedRole() async {
    try {
      return await widget.api.guard();
    } catch (exception) {
      _roleError = schoolError(exception);
      return ServerRole.student;
    }
  }

  @override
  void initState() {
    super.initState();
    _owner = widget.api.backend.userId;
    _role = _checkedRole();
    widget.api.backend.addListener(_reload);
  }

  void _reload() {
    if (mounted) {
      setState(() {
        _role = _checkedRole();
      });
    }
  }

  @override
  void dispose() {
    widget.api.backend.removeListener(_reload);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ServerRole>(
    future: _role,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError ||
          !snapshot.hasData ||
          snapshot.data == ServerRole.student ||
          _owner != widget.api.backend.userId) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 42),
                const SizedBox(height: 12),
                Text(
                  _owner != widget.api.backend.userId
                      ? 'Аккаунт изменился. Закройте панель и откройте заново.'
                      : 'Серверный доступ к управлению школой не подтверждён.',
                ),
                if (_roleError != null) Text(_roleError!),
                OutlinedButton(
                  onPressed: _reload,
                  child: const Text('Проверить доступ снова'),
                ),
              ],
            ),
          ),
        );
      }
      return widget.builder(snapshot.data!);
    },
  );
}

class SchoolField {
  const SchoolField(
    this.key,
    this.label, {
    this.multiline = false,
    this.arabic = false,
    this.required = false,
    this.choices,
  });
  final String key, label;
  final bool multiline, arabic, required;
  final Map<String, String>? choices;
}

Future<Map<String, dynamic>?> showSchoolForm(
  BuildContext context,
  String title,
  List<SchoolField> fields, {
  Map<String, dynamic> initial = const {},
}) => showDialog<Map<String, dynamic>>(
  context: context,
  builder: (_) =>
      _SchoolFormDialog(title: title, fields: fields, initial: initial),
);

class _SchoolFormDialog extends StatefulWidget {
  const _SchoolFormDialog({
    required this.title,
    required this.fields,
    required this.initial,
  });
  final String title;
  final List<SchoolField> fields;
  final Map<String, dynamic> initial;
  @override
  State<_SchoolFormDialog> createState() => _SchoolFormDialogState();
}

class _SchoolFormDialogState extends State<_SchoolFormDialog> {
  late final Map<String, TextEditingController> controllers;
  String? error;
  @override
  void initState() {
    super.initState();
    controllers = {
      for (final field in widget.fields)
        field.key: TextEditingController(
          text:
              widget.initial[field.key]?.toString() ??
              field.choices?.keys.first ??
              '',
        ),
    };
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fields = widget.fields, title = widget.title;
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final field in fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: field.choices != null
                      ? DropdownButtonFormField<String>(
                          initialValue:
                              field.choices!.containsKey(
                                controllers[field.key]!.text,
                              )
                              ? controllers[field.key]!.text
                              : field.choices!.keys.first,
                          decoration: InputDecoration(labelText: field.label),
                          items: field.choices!.entries
                              .map(
                                (entry) => DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              controllers[field.key]!.text = value ?? '',
                        )
                      : TextField(
                          controller: controllers[field.key],
                          minLines: field.multiline ? 3 : 1,
                          maxLines: field.multiline ? 8 : 1,
                          textDirection: field.arabic
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          decoration: InputDecoration(labelText: field.label),
                          style: field.arabic
                              ? const TextStyle(
                                  fontFamily: 'NotoNaskhArabic',
                                  height: 1.8,
                                )
                              : null,
                        ),
                ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            try {
              for (final field in fields.where((field) => field.required)) {
                requiredSchoolText(controllers[field.key]!.text, field.label);
              }
              Navigator.pop(context, {
                for (final field in fields)
                  field.key: controllers[field.key]!.text,
              });
            } catch (exception) {
              setState(() => error = schoolError(exception));
            }
          },
          child: const Text('Готово'),
        ),
      ],
    );
  }
}

Future<bool> confirmSchoolAction(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    ) ??
    false;
Widget schoolErrorCard(Object error, VoidCallback retry) => Padding(
  padding: const EdgeInsets.all(16),
  child: Panel(
    child: Column(
      children: [
        Text(schoolError(error)),
        OutlinedButton(
          onPressed: retry,
          child: const Text('Повторить загрузку'),
        ),
      ],
    ),
  ),
);
String schoolDate(dynamic date) =>
    DateTime.tryParse(
      date?.toString() ?? '',
    )?.toLocal().toString().substring(0, 16) ??
    '—';

Future<Map<String, dynamic>?> pickSchoolRow(
  BuildContext context,
  String title,
  List<Map<String, dynamic>> rows,
) => showModalBottomSheet<Map<String, dynamic>>(
  context: context,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          Expanded(
            child: ListView(
              children: [
                if (rows.isEmpty)
                  const ListTile(title: Text('Доступных записей нет.')),
                for (final row in rows)
                  ListTile(
                    title: Text(
                      (row['title'] ?? row['display_name'] ?? row['id'])
                          .toString(),
                    ),
                    subtitle: row['display_name'] != null
                        ? Text(row['id'].toString())
                        : null,
                    onTap: () => Navigator.pop(context, row),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);

// Child pages retain the same server guard when opened from a nested route.
String schoolStatusLabel(String status) =>
    const {
      'draft': 'Черновик',
      'published': 'Опубликован',
      'archived': 'Архив',
    }[status] ??
    status;
Widget schoolBodyPreview(dynamic body) {
  if (body is! Map) return Text(body?.toString() ?? '');
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (body['text_ar'] != null) NaskhText(body['text_ar'].toString()),
      if (body['translation'] != null ||
          body['text_ru'] != null ||
          body['text'] != null)
        Text(
          (body['translation'] ?? body['text_ru'] ?? body['text']).toString(),
        ),
      if (body['media_id'] != null) Text('Материал: ${body['media_id']}'),
      if (!body.keys.any(
        (key) => const {
          'text_ar',
          'translation',
          'text_ru',
          'text',
          'media_id',
        }.contains(key),
      ))
        SelectableText(const JsonEncoder.withIndent('  ').convert(body)),
    ],
  );
}

Future<DateTime?> chooseSchoolDate(BuildContext context, String title) async {
  final today = DateTime.now();
  final day = await showDatePicker(
    context: context,
    helpText: title,
    initialDate: today.add(const Duration(days: 7)),
    firstDate: today,
    lastDate: today.add(const Duration(days: 730)),
  );
  if (day == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: const TimeOfDay(hour: 20, minute: 0),
  );
  if (time == null) return null;
  return DateTime(day.year, day.month, day.day, time.hour, time.minute);
}
