import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/backend_service.dart';
import '../../services/push_service.dart';
import 'integration_widgets.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key, required this.backend});
  final BackendService backend;
  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen>
    with IntegrationActions<PhoneAuthScreen> {
  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _code = TextEditingController();
  bool _consent = false;
  bool _sent = false;
  DateTime? _lastSent;
  String? _sentPhone;
  late final PushService _push;
  Future<ServerRole>? _role;

  @override
  void initState() {
    super.initState();
    _push = PushService(widget.backend);
    widget.backend.addListener(_authChanged);
    _authChanged();
  }

  void _authChanged() {
    if (!mounted) return;
    setState(() {
      _role = widget.backend.isAuthenticated ? widget.backend.loadRole() : null;
    });
  }

  Future<void> _send() async {
    if (_lastSent != null &&
        DateTime.now().difference(_lastSent!).inSeconds < 60) {
      throw const IntegrationException(
        'Перед повторной отправкой подождите 60 секунд.',
      );
    }
    if (!await widget.backend.initialize()) {
      throw IntegrationException(
        widget.backend.initializationError ?? 'Сервис недоступен.',
      );
    }
    await widget.backend.requestPhoneOtp(
      phone: _phone.text,
      name: _name.text,
      consent: _consent,
    );
    if (mounted) {
      setState(() {
        _sent = true;
        _sentPhone = IntegrationValidation.phone(_phone.text);
        _lastSent = DateTime.now();
      });
    }
  }

  Future<void> _verify() async {
    await widget.backend.verifyPhoneOtp(
      phone: _sentPhone!,
      token: _code.text,
      name: _name.text,
      consent: _consent,
    );
    if (mounted) {
      _code.clear();
      setState(() => _sent = false);
    }
  }

  Future<void> _export() async {
    final data = await widget.backend.exportAccount();
    if (!mounted) return;
    final json = const JsonEncoder.withIndent('  ').convert(data);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Экспорт данных аккаунта'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(child: SelectableText(json)),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: json));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Копировать JSON'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить аккаунт?'),
        content: const Text(
          'Сервер удалит аккаунт и его личные данные. '
          'Сначала можно экспортировать данные. Это действие необратимо. '
          'Подписка магазина отменяется отдельно в Google Play или App Store; удаление аккаунта её не отменяет.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final owner = widget.backend.userId;
      await _push.disable();
      await widget.backend.deleteAccount(confirmed: true);
      if (owner != null) {
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.remove('academy_account_$owner')) {
          throw const IntegrationException(
            'Аккаунт удалён на сервере, но локальное хранилище не подтвердило очистку. Проверьте настройки устройства.',
          );
        }
      }
    }
  }

  @override
  void dispose() {
    widget.backend.removeListener(_authChanged);
    _push.dispose();
    _phone.dispose();
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Аккаунт')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        actionStatus,
        if (!widget.backend.isAuthenticated) ...[
          if (!widget.backend.isConfigured)
            IntegrationNotice(
              widget.backend.initializationError ??
                  'Онлайн-сервис не подключён.',
            ),
          TextField(
            controller: _name,
            enabled: !working,
            textCapitalization: TextCapitalization.words,
            maxLength: 100,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(labelText: 'Имя в профиле'),
          ),
          TextField(
            controller: _phone,
            enabled: !working && !_sent,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: const InputDecoration(
              labelText: 'Телефон с кодом страны',
              hintText: '+79991234567',
            ),
          ),
          CheckboxListTile(
            value: _consent,
            onChanged: working
                ? null
                : (value) => setState(() => _consent = value ?? false),
            title: const Text(
              'Согласна на обработку телефона и имени для аккаунта',
            ),
            subtitle: const Text(
              'Телефон используется для SMS-входа; имя хранится в профиле. '
              'Отправка голоса и уведомления требуют отдельного согласия.',
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          FilledButton(
            onPressed: working || !_consent ? null : () => runAction(_send),
            child: Text(_sent ? 'Отправить код повторно' : 'Получить SMS-код'),
          ),
          if (_sent) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _code,
              enabled: !working,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              decoration: const InputDecoration(labelText: 'Код из SMS'),
            ),
            FilledButton(
              onPressed: working || !_consent ? null : () => runAction(_verify),
              child: const Text('Войти'),
            ),
            TextButton(
              onPressed: working
                  ? null
                  : () => setState(() {
                      _sent = false;
                      _code.clear();
                    }),
              child: const Text('Изменить телефон'),
            ),
          ],
        ] else ...[
          const IntegrationNotice(
            'Вход выполнен через SMS. Роль назначается сервером.',
          ),
          FutureBuilder<ServerRole>(
            future: _role,
            builder: (context, snapshot) => Text(
              snapshot.hasError
                  ? 'Не удалось загрузить роль. Доступ преподавателя закрыт.'
                  : snapshot.hasData
                  ? 'Роль: ${switch (snapshot.data!) {
                      ServerRole.student => 'ученица',
                      ServerRole.teacher => 'преподаватель',
                      ServerRole.admin => 'администратор',
                    }}'
                  : 'Загружаем роль…',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            enabled: !working,
            decoration: const InputDecoration(labelText: 'Новое имя профиля'),
          ),
          FilledButton.tonal(
            onPressed: working
                ? null
                : () => runAction(
                    () => widget.backend.saveProfile(
                      name: _name.text,
                      consent: true,
                    ),
                  ),
            child: const Text('Сохранить имя'),
          ),
          OutlinedButton(
            onPressed: working ? null : () => runAction(_export),
            child: const Text('Экспортировать мои данные'),
          ),
          ListenableBuilder(
            listenable: _push,
            builder: (context, _) => Text(_push.status),
          ),
          OutlinedButton(
            onPressed: working
                ? null
                : () => runAction(() async {
                    // Pressing this clearly labelled button is separate explicit consent.
                    await _push.enable(consent: true);
                  }),
            child: const Text('Разрешить push-уведомления'),
          ),
          TextButton(
            onPressed: working ? null : () => runAction(_push.disable),
            child: const Text('Выключить push-уведомления'),
          ),
          OutlinedButton(
            onPressed: working
                ? null
                : () => runAction(() async {
                    await _push.disable();
                    await widget.backend.signOut();
                  }),
            child: const Text('Выйти'),
          ),
          TextButton(
            onPressed: working ? null : () => runAction(_delete),
            child: const Text('Удалить аккаунт и личные данные'),
          ),
        ],
      ],
    ),
  );
}
