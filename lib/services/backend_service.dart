import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'integration_config.dart';
import '../core/secure_session_storage.dart';

export 'integration_config.dart';

enum ServerRole { student, teacher, admin }

/// All privilege decisions are checked again by RLS / Edge Functions.
/// This service never reads user_metadata or the local demo role.
class BackendService extends ChangeNotifier {
  BackendService({
    this.config = const IntegrationConfig(),
    SupabaseClient? client,
  }) : _client = client {
    if (client != null) _listenAuth();
  }

  final IntegrationConfig config;
  SupabaseClient? _client;
  StreamSubscription<AuthState>? _authSubscription;
  Future<bool>? _initializing;
  String? _initializationError;
  bool _disposed = false;

  bool get isConfigured => _client != null;
  bool get isAuthenticated => _client?.auth.currentUser != null;
  String? get userId => _client?.auth.currentUser?.id;
  String? get initializationError =>
      _client != null ? null : _initializationError ?? config.backendError;

  SupabaseClient get client {
    final value = _client;
    if (value == null) {
      throw IntegrationException(initializationError ?? 'Сервис недоступен.');
    }
    return value;
  }

  String get _authenticatedId {
    final id = client.auth.currentUser?.id;
    if (id == null) {
      throw const IntegrationException('Сначала войдите по телефону.');
    }
    return id;
  }

  /// Optional startup: offline app does not need Supabase or Firebase.
  Future<bool> initialize() {
    if (_client != null) return Future.value(true);
    return _initializing ??= _initialize().whenComplete(
      () => _initializing = null,
    );
  }

  Future<bool> _initialize() async {
    if (config.backendError != null) {
      _initializationError = config.backendError;
      return false;
    }
    try {
      await Supabase.initialize(
        url: config.supabaseUrl,
        publishableKey: config.supabaseAnonKey,
        debug: false,
        authOptions: FlutterAuthClientOptions(
          localStorage: SecureSessionStorage(),
        ),
      );
      if (_disposed) return false;
      _client = Supabase.instance.client;
      _initializationError = null;
      _listenAuth();
      notifyListeners();
      return true;
    } catch (_) {
      _initializationError =
          'Не удалось запустить онлайн-сервис. Проверьте конфигурацию и сеть.';
      return false;
    }
  }

  void _listenAuth() {
    _authSubscription = _client!.auth.onAuthStateChange.listen((_) {
      if (!_disposed) notifyListeners();
    });
  }

  Future<void> requestPhoneOtp({
    required String phone,
    required String name,
    required bool consent,
  }) async {
    IntegrationValidation.consent(consent);
    IntegrationValidation.name(name);
    await client.auth.signInWithOtp(phone: IntegrationValidation.phone(phone));
  }

  Future<void> verifyPhoneOtp({
    required String phone,
    required String token,
    required String name,
    required bool consent,
  }) async {
    IntegrationValidation.consent(consent);
    final displayName = IntegrationValidation.name(name);
    final response = await client.auth.verifyOTP(
      phone: IntegrationValidation.phone(phone),
      token: IntegrationValidation.otp(token),
      type: OtpType.sms,
    );
    if (response.session == null) {
      throw const IntegrationException('Код не создал авторизованную сессию.');
    }
    try {
      await saveProfile(name: displayName, consent: consent);
    } catch (_) {
      // A profile/consent failure must not silently leave a signed-in account.
      await client.auth.signOut(scope: SignOutScope.local);
      rethrow;
    }
  }

  Future<void> saveProfile({
    required String name,
    required bool consent,
  }) async {
    IntegrationValidation.consent(consent);
    _authenticatedId;
    await client.rpc(
      'save_profile',
      params: {
        'p_display_name': IntegrationValidation.name(name),
        'p_consent': true,
      },
    );
  }

  Future<Map<String, dynamic>?> profile() async => await client
      .from('profiles')
      .select('id,display_name,locale')
      .eq('id', _authenticatedId)
      .maybeSingle();

  Future<ServerRole> loadRole() async {
    final rows = await client
        .from('server_roles')
        .select('role')
        .eq('user_id', _authenticatedId);
    final roles = rows.map((row) => row['role']).toSet();
    if (roles.contains('admin')) return ServerRole.admin;
    if (roles.contains('teacher')) return ServerRole.teacher;
    return ServerRole.student;
  }

  Future<void> requireTeacher() async {
    final role = await loadRole();
    if (role != ServerRole.teacher && role != ServerRole.admin) {
      throw const IntegrationException(
        'Нужна роль преподавателя, назначенная сервером.',
      );
    }
  }

  Future<void> signOut() => client.auth.signOut();

  Future<Map<String, dynamic>> exportAccount() => invoke('account-export', {});

  Future<void> deleteAccount({required bool confirmed}) async {
    if (!confirmed) {
      throw const IntegrationException('Подтвердите удаление аккаунта.');
    }
    final result = await invoke('account-delete', {'confirm': true});
    if (result['deleted'] != true) {
      throw const IntegrationException(
        'Сервер не подтвердил удаление аккаунта.',
      );
    }
    await client.auth.signOut(scope: SignOutScope.local);
  }

  Future<Map<String, dynamic>> invoke(
    String function,
    Map<String, dynamic> body,
  ) async {
    _authenticatedId;
    final response = await client.functions.invoke(function, body: body);
    if (response.status < 200 ||
        response.status >= 300 ||
        response.data is! Map) {
      throw const IntegrationException(
        'Онлайн-сервис не подтвердил запрос. Повторите позже.',
      );
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['error'] != null) {
      throw const IntegrationException(
        'Сервер отклонил запрос. Проверьте доступ и настройки сервиса.',
      );
    }
    return data;
  }

  Future<List<Map<String, dynamic>>> courses() async {
    _authenticatedId;
    return await client
        .from('courses')
        .select('id,title,description')
        .eq('status', 'published')
        .order('title');
  }

  Future<List<Map<String, dynamic>>> lessons(String courseId) async {
    _authenticatedId;
    final levels = await client
        .from('levels')
        .select('id')
        .eq('course_id', IntegrationValidation.uuid(courseId));
    if (levels.isEmpty) return [];
    final books = await client
        .from('books')
        .select('id')
        .inFilter('level_id', levels.map((row) => row['id']).toList());
    if (books.isEmpty) return [];
    final units = await client
        .from('units')
        .select('id')
        .inFilter('book_id', books.map((row) => row['id']).toList());
    if (units.isEmpty) return [];
    return await client
        .from('lessons')
        .select('id,unit_id,title,title_ar,goal,position,version')
        .inFilter('unit_id', units.map((row) => row['id']).toList())
        .eq('status', 'published')
        .order('position');
  }

  Future<Map<String, dynamic>> lessonContent(String lessonId) async {
    _authenticatedId;
    final id = IntegrationValidation.uuid(lessonId);
    final lesson = await client.from('lessons').select().eq('id', id).single();
    final blocks = await client
        .from('lesson_blocks')
        .select()
        .eq('lesson_id', id)
        .order('position');
    final vocabulary = await client
        .from('vocabulary')
        .select()
        .eq('lesson_id', id)
        .order('position');
    final grammar = await client
        .from('grammar')
        .select()
        .eq('lesson_id', id)
        .order('position');
    return {
      'lesson': lesson,
      'blocks': blocks,
      'vocabulary': vocabulary,
      'grammar': grammar,
    };
  }

  /// Completion requires passing current-version attempts on the server.
  Future<void> completeLesson(String lessonId) async {
    _authenticatedId;
    await client.rpc(
      'complete_lesson',
      params: {'p_lesson_id': IntegrationValidation.uuid(lessonId)},
    );
  }

  Future<List<Map<String, dynamic>>> studyProgress() async => await client
      .from('study_progress')
      .select('lesson_id,completed_at')
      .eq('student_id', _authenticatedId);

  /// Caller retains UUID/payload in its durable outbox until acknowledgement.
  /// Telemetry never grants completion. Server checks completion independently.
  Future<void> syncProgress({
    required String eventId,
    required String lessonId,
    required Map<String, dynamic> payload,
    String kind = 'lesson_opened',
  }) async {
    final idempotencyKey = IntegrationValidation.uuid(eventId);
    final owner = _authenticatedId;
    if (utf8.encode(jsonEncode(payload)).length > 65536) {
      throw const IntegrationException('Событие прогресса слишком большое.');
    }
    if (!const {
      'lesson_opened',
      'draft_saved',
      'study_reviewed',
      'settings_changed',
    }.contains(kind)) {
      throw const IntegrationException(
        'Недопустимый вид события. Завершение урока проверяется сервером.',
      );
    }
    final acknowledgement = await client.rpc(
      'record_event',
      params: {
        'p_idempotency_key': idempotencyKey,
        'p_kind': kind,
        'p_payload': {
          ...payload,
          'lesson_id': IntegrationValidation.uuid(lessonId),
        },
      },
    );
    if (acknowledgement is! Map ||
        acknowledgement['idempotency_key'] != idempotencyKey ||
        acknowledgement['user_id'] != owner ||
        owner != userId) {
      throw const IntegrationException(
        'Событие не подтверждено. Сохраните его для повторной синхронизации.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> liveSessions() async {
    _authenticatedId;
    return await client
        .from('live_sessions')
        .select('id,title,starts_at,ends_at,group_id,recording_enabled')
        .isFilter('cancelled_at', null)
        .gte('ends_at', DateTime.now().toUtc().toIso8601String())
        .order('starts_at');
  }

  Future<List<Map<String, dynamic>>> groups() async {
    _authenticatedId;
    return await client
        .from('groups')
        .select('id,title,course_id,teacher_id')
        .isFilter('archived_at', null);
  }

  Future<void> createLiveSession({
    required String title,
    required String groupId,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    await requireTeacher();
    if (!endsAt.isAfter(startsAt) || !startsAt.isAfter(DateTime.now())) {
      throw const IntegrationException(
        'Выберите будущее время и окончание после начала.',
      );
    }
    await client.rpc(
      'create_live_session',
      params: {
        'p_title': IntegrationValidation.name(title),
        'p_group_id': IntegrationValidation.uuid(groupId),
        'p_starts_at': startsAt.toUtc().toIso8601String(),
        'p_ends_at': endsAt.toUtc().toIso8601String(),
        'p_recording_enabled': false,
      },
    );
  }

  Future<Map<String, dynamic>> liveRoomToken(
    String sessionId, {
    bool recordingConsent = false,
  }) async {
    if (recordingConsent) {
      await client
          .from('user_settings')
          .update({'recording_consent': true})
          .eq('user_id', _authenticatedId);
    }
    return invoke('livekit-token', {
      'session_id': IntegrationValidation.uuid(sessionId),
      'recording_consent': recordingConsent,
    });
  }

  Future<String> signedMediaUrl(String mediaId) async {
    final result = await invoke('protected-media', {
      'media_id': IntegrationValidation.uuid(mediaId),
    });
    final url = result['url'];
    if (url is! String || Uri.tryParse(url)?.scheme != 'https') {
      throw const IntegrationException('Сервис не выдал защищённую ссылку.');
    }
    return url;
  }

  Future<String> transcribe(Uint8List audio, {required bool consent}) async {
    IntegrationValidation.consent(consent);
    if (!config.sttEnabled) {
      throw const IntegrationException(
        'Распознавание речи не подключено. Запись доступна локально.',
      );
    }
    if (audio.isEmpty || audio.length > 10 * 1024 * 1024) {
      throw const IntegrationException('Запись должна быть не больше 10 МБ.');
    }
    await client
        .from('user_settings')
        .update({'stt_consent': true})
        .eq('user_id', _authenticatedId);
    final ticket = await beginMediaUpload(
      filename: 'oral.m4a',
      size: audio.length,
      mimeType: 'audio/mp4',
      sttConsent: true,
    );
    final mediaId = ticket['media_id'] as String;
    try {
      await uploadToTicket(ticket, audio);
      await finalizeMediaUpload(mediaId);
      final result = await invoke('transcribe', {'media_id': mediaId});
      if (result['text'] is! String ||
          result['assessment'] != 'transcription_only') {
        throw const IntegrationException('Сервис не вернул расшифровку.');
      }
      return result['text'] as String;
    } finally {
      await deleteMedia(mediaId);
    }
  }

  Future<Map<String, dynamic>> beginMediaUpload({
    required String filename,
    required int size,
    required String mimeType,
    String? lessonId,
    bool sttConsent = false,
  }) async {
    MediaPolicy.validate(filename, size);
    final ticket = await invoke('media-upload', {
      'action': 'begin',
      'filename': filename,
      'byte_size': size,
      'mime_type': mimeType,
      'lesson_id': lessonId,
      'consent_stt': sttConsent,
    });
    if (ticket['media_id'] is! String ||
        ticket['bucket_id'] is! String ||
        ticket['object_path'] is! String ||
        ticket['token'] is! String) {
      throw const IntegrationException(
        'Сервер не выдал разрешение на загрузку.',
      );
    }
    return ticket;
  }

  Future<void> uploadToTicket(
    Map<String, dynamic> ticket,
    Uint8List bytes,
  ) async {
    await client.storage
        .from(ticket['bucket_id'] as String)
        .uploadBinaryToSignedUrl(
          ticket['object_path'] as String,
          ticket['token'] as String,
          bytes,
          FileOptions(
            contentType: ticket['mime_type'] as String?,
            upsert: false,
          ),
        );
  }

  Future<void> finalizeMediaUpload(String mediaId) async {
    final result = await invoke('media-upload', {
      'action': 'complete',
      'media_id': IntegrationValidation.uuid(mediaId),
    });
    final media = result['media'];
    if (media is! Map ||
        media['id'] != mediaId ||
        media['upload_state'] != 'ready') {
      throw const IntegrationException(
        'Сервер не подтвердил целостность загруженного файла.',
      );
    }
  }

  Future<void> deleteMedia(String mediaId) async {
    final result = await invoke('delete-media', {
      'media_id': IntegrationValidation.uuid(mediaId),
    });
    if (result['deleted'] != true) {
      throw const IntegrationException(
        'Сервер не подтвердил удаление записи. Повторите позже.',
      );
    }
  }

  Future<bool> verifyPurchase({
    required String productId,
    required String source,
    required String receipt,
    String? purchaseId,
  }) async {
    if (receipt.isEmpty || productId.isEmpty) {
      throw const IntegrationException(
        'Магазин не предоставил данные проверки покупки.',
      );
    }
    final provider = switch (source) {
      'app_store' => 'apple',
      'google_play' => 'google',
      _ => null,
    };
    if (provider == null ||
        (provider == 'apple' && (purchaseId == null || purchaseId.isEmpty))) {
      throw const IntegrationException(
        'Неизвестный магазин или отсутствует идентификатор транзакции.',
      );
    }
    final product = await client
        .from('products')
        .select('id,kind')
        .eq('provider', provider)
        .eq('external_id', productId)
        .eq('active', true)
        .single();
    final result = await invoke('verify-purchase', {
      'provider': provider,
      'product_id': productId,
      'kind': product['kind'],
      if (provider == 'apple') 'transaction_id': purchaseId,
      if (provider == 'google') 'purchase_token': receipt,
    });
    final purchase = result['purchase'];
    if (purchase is! Map ||
        purchase['status'] != 'verified' ||
        purchase['user_id'] != _authenticatedId ||
        purchase['product_id'] != product['id'] ||
        purchase['provider'] != provider) {
      throw const IntegrationException(
        'Покупка не подтверждена сервером; доступ не выдан.',
      );
    }
    return true;
  }

  Future<List<Map<String, dynamic>>> entitlements() async => await client
      .from('entitlements')
      .select('course_id,starts_at,expires_at')
      .eq('user_id', _authenticatedId)
      .isFilter('revoked_at', null)
      .lte('starts_at', DateTime.now().toUtc().toIso8601String());

  Future<void> registerPushToken(String token) async {
    _authenticatedId;
    await client.rpc('register_push_token', params: {'p_token': token});
  }

  Future<void> unregisterPushToken(String token) async {
    _authenticatedId;
    await client.rpc('unregister_push_token', params: {'p_token': token});
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }
}
