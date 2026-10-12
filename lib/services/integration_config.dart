import 'dart:convert';

class IntegrationException implements Exception {
  const IntegrationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Only public client configuration belongs in dart-defines.
class IntegrationConfig {
  const IntegrationConfig({
    this.supabaseUrl = const String.fromEnvironment('SUPABASE_URL'),
    this.supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY'),
    this.sttEnabled = const bool.fromEnvironment('STT_ENABLED'),
    this.pushEnabled = const bool.fromEnvironment('FIREBASE_PUSH_ENABLED'),
    this.productIds = const String.fromEnvironment('IAP_PRODUCT_IDS'),
  });

  final String supabaseUrl;
  final String supabaseAnonKey;
  final bool sttEnabled;
  final bool pushEnabled;
  final String productIds;

  bool get hasBackend => backendError == null;
  String? get backendError {
    if (supabaseUrl.trim().isEmpty || supabaseAnonKey.trim().isEmpty) {
      return 'Онлайн-сервис не настроен. Обратитесь к администратору приложения.';
    }
    final uri = Uri.tryParse(supabaseUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        (uri.path != '' && uri.path != '/')) {
      return 'Адрес онлайн-сервиса настроен неверно. Обратитесь к администратору.';
    }
    final key = supabaseAnonKey.trim();
    if (key.startsWith('sb_secret_')) {
      return 'Секретный серверный ключ нельзя использовать в приложении.';
    }
    // Reject service-role JWTs even when accidentally supplied as an anon key.
    if (!key.startsWith('sb_publishable_')) {
      try {
        final parts = key.split('.');
        if (parts.length != 3) throw const FormatException();
        final payload =
            jsonDecode(
                  utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
                )
                as Map<String, dynamic>;
        if (payload['role'] != 'anon') throw const FormatException();
      } catch (_) {
        return 'Ключ онлайн-сервиса настроен неверно. Обратитесь к администратору.';
      }
    } else if (key.length < 24) {
      return 'Публичный ключ имеет неверный формат.';
    }
    return null;
  }

  Set<String> get storeProductIds => productIds
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet();
}

class IntegrationValidation {
  static String phone(String input) {
    final value = input.trim();
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(value)) {
      throw const IntegrationException(
        'Телефон: + и 8–15 цифр, с кодом страны.',
      );
    }
    return value;
  }

  static String name(String input) {
    final value = input.trim();
    if (value.isEmpty ||
        value.runes.length > 100 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
      throw const IntegrationException(
        'Введите имя длиной от 1 до 100 символов.',
      );
    }
    return value;
  }

  static String otp(String input) {
    final value = input.trim();
    if (!RegExp(r'^\d{6,8}$').hasMatch(value)) {
      throw const IntegrationException('Введите код из SMS (6–8 цифр).');
    }
    return value;
  }

  static void consent(bool accepted) {
    if (!accepted) {
      throw const IntegrationException(
        'Нужно явное согласие на обработку данных.',
      );
    }
  }

  static String id(String input) {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(input)) {
      throw const IntegrationException('Недопустимый идентификатор.');
    }
    return input;
  }

  static String uuid(String input) {
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(input)) {
      throw const IntegrationException(
        'Для серверной записи нужен UUID из каталога.',
      );
    }
    return input.toLowerCase();
  }
}

class MediaPolicy {
  static const maxBytes = 50 * 1024 * 1024;
  static const mimeTypes = <String, String>{
    'pdf': 'application/pdf',
    'mp3': 'audio/mpeg',
    'm4a': 'audio/mp4',
    'wav': 'audio/wav',
    'mp4': 'video/mp4',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  static String validate(String filename, int size) {
    final extension = filename.split('.').last.toLowerCase();
    if (!filename.contains('.') || !mimeTypes.containsKey(extension)) {
      throw const IntegrationException(
        'Допустимы PDF, MP3, M4A, WAV, MP4, JPG, PNG, WebP.',
      );
    }
    if (size <= 0 || size > maxBytes) {
      throw const IntegrationException(
        'Файл должен быть непустым и не больше 50 МБ.',
      );
    }
    return mimeTypes[extension]!;
  }
}
