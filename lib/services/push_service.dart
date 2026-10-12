import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'backend_service.dart';
import 'media_upload_service.dart' show integrationErrorText;

class PushService extends ChangeNotifier {
  PushService(this.backend);
  final BackendService backend;
  StreamSubscription<String>? _refresh;
  StreamSubscription<RemoteMessage>? _messages;
  String status = 'Push-уведомления выключены.';
  RemoteMessage? lastMessage;
  bool _disposed = false;
  String? _token;
  String? _ownerId;

  /// Owner initializes Firebase with platform options. This service never does.
  Future<bool> enable({required bool consent}) async {
    IntegrationValidation.consent(consent);
    if (!backend.config.pushEnabled || Firebase.apps.isEmpty) {
      status = 'Push не настроен. Обратитесь к администратору приложения.';
      if (!_disposed) notifyListeners();
      return false;
    }
    if (!backend.isAuthenticated) {
      throw const IntegrationException('Сначала войдите в аккаунт.');
    }
    final messaging = FirebaseMessaging.instance;
    final owner = backend.userId;
    final settings = await messaging.requestPermission();
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      throw const IntegrationException(
        'Уведомления запрещены в настройках устройства.',
      );
    }
    final token = await messaging.getToken();
    if (token == null) {
      throw const IntegrationException('Firebase не выдал токен устройства.');
    }
    if (_disposed || owner != backend.userId) {
      throw const IntegrationException(
        'Аккаунт изменился. Повторите включение уведомлений.',
      );
    }
    await backend.registerPushToken(token);
    _token = token;
    _ownerId = owner;
    await _refresh?.cancel();
    await _messages?.cancel();
    _refresh = messaging.onTokenRefresh.listen((token) async {
      try {
        if (!_disposed &&
            _ownerId == backend.userId &&
            backend.isAuthenticated) {
          if (_token != null && _token != token) {
            await backend.unregisterPushToken(_token!);
          }
          await backend.registerPushToken(token);
          _token = token;
        }
      } catch (exception) {
        status = integrationErrorText(exception);
        if (!_disposed) notifyListeners();
      }
    });
    _messages = FirebaseMessaging.onMessage.listen((message) {
      lastMessage = message;
      if (!_disposed) notifyListeners();
    });
    status = 'Уведомления подключены.';
    if (!_disposed) notifyListeners();
    return true;
  }

  Future<void> disable() async {
    await _refresh?.cancel();
    await _messages?.cancel();
    if (backend.config.pushEnabled && Firebase.apps.isNotEmpty) {
      final token = _token ?? await FirebaseMessaging.instance.getToken();
      if (token != null && backend.isAuthenticated) {
        await backend.unregisterPushToken(token);
      }
      await FirebaseMessaging.instance.deleteToken();
    }
    _token = null;
    _ownerId = null;
    status = 'Push-уведомления выключены.';
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_refresh?.cancel());
    unawaited(_messages?.cancel());
    super.dispose();
  }
}
