import '../../services/backend_service.dart';

const notificationCategoryIds = {
  'lesson',
  'assignment',
  'live',
  'feedback',
  'message',
  'review',
};

/// Update one category through the server's atomic JSON merge. A previous full
/// snapshot is accepted for caller compatibility but is deliberately not sent:
/// another device's categories, global switch and consent must survive.
Future<Map<String, dynamic>> saveNotificationPreference(
  BackendService backend,
  String categoryId,
  bool enabled, [
  Map<String, dynamic>? fullPreferences,
]) async {
  if (!notificationCategoryIds.contains(categoryId)) {
    throw const IntegrationException('Неизвестная категория уведомлений.');
  }
  final owner = backend.userId;
  if (!backend.isAuthenticated || owner == null) {
    throw const IntegrationException(
      'Войдите в аккаунт для настройки уведомлений.',
    );
  }
  final response = await backend.client.rpc(
    'update_user_preferences',
    params: {
      'p_patch': {
        'preferences': {
          'notification_categories': {categoryId: enabled},
        },
      },
    },
  );
  if (!backend.isAuthenticated || owner != backend.userId) {
    throw const IntegrationException(
      'Аккаунт изменился. Откройте настройки заново.',
    );
  }
  if (response is! Map || response['user_id'] != owner) {
    throw const IntegrationException(
      'Сервер не подтвердил сохранение настроек.',
    );
  }
  return Map<String, dynamic>.from(response);
}
