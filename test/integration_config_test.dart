import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:arabic_academy/services/backend_service.dart';
import 'package:arabic_academy/services/media_upload_service.dart';
import 'package:arabic_academy/services/purchase_service.dart';
import 'package:arabic_academy/services/push_service.dart';

const _userId = '11111111-1111-4111-8111-111111111111';
const _eventId = '22222222-2222-4222-8222-222222222222';
const _lessonId = '33333333-3333-4333-8333-333333333333';

String _jwt(Map<String, dynamic> payload) =>
    'e30.'
    '${base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '')}.test';

void main() {
  group('public configuration and validation', () {
    test('missing backend remains offline and fails closed', () async {
      final backend = BackendService(
        config: const IntegrationConfig(supabaseUrl: '', supabaseAnonKey: ''),
      );
      expect(await backend.initialize(), isFalse);
      expect(backend.isConfigured, isFalse);
      expect(backend.isAuthenticated, isFalse);
      expect(() => backend.client, throwsA(isA<IntegrationException>()));
      await expectLater(
        backend.requireTeacher(),
        throwsA(isA<IntegrationException>()),
      );
      backend.dispose();
    });

    test('only root HTTPS URL and public key are accepted', () {
      final key = _jwt({'role': 'anon'});
      expect(
        IntegrationConfig(
          supabaseUrl: 'https://example.supabase.co',
          supabaseAnonKey: key,
        ).hasBackend,
        isTrue,
      );
      for (final url in [
        'http://example.com',
        'https://u:p@example.com',
        'https://example.com/path',
        'https://example.com?key=value',
        'https://example.com#fragment',
        'garbage',
        '',
      ]) {
        expect(
          IntegrationConfig(supabaseUrl: url, supabaseAnonKey: key).hasBackend,
          isFalse,
          reason: url,
        );
      }
      for (final secret in [
        'sb_secret_serverkey',
        _jwt({'role': 'service_role'}),
        _jwt({'role': 'authenticated'}),
        'broken.jwt.key',
        '',
        'sb_publishable_tiny',
      ]) {
        expect(
          IntegrationConfig(
            supabaseUrl: 'https://example.com',
            supabaseAnonKey: secret,
          ).hasBackend,
          isFalse,
        );
      }
    });

    test('phone is E164 and OTP/name preserve real Arabic text', () {
      expect(IntegrationValidation.phone(' +79991234567 '), '+79991234567');
      for (final phone in [
        '79991234567',
        '+0',
        '+7123',
        '+7 9991234567',
        '+1234567890123456',
      ]) {
        expect(
          () => IntegrationValidation.phone(phone),
          throwsA(isA<IntegrationException>()),
        );
      }
      expect(IntegrationValidation.otp(' 123456 '), '123456');
      expect(
        IntegrationValidation.uuid('ABCDEF12-3456-789A-BCDE-123456789ABC'),
        'abcdef12-3456-789a-bcde-123456789abc',
      );
      expect(
        () => IntegrationValidation.uuid('local-lesson-slug'),
        throwsA(isA<IntegrationException>()),
      );
      expect(
        () => IntegrationValidation.otp('12345a'),
        throwsA(isA<IntegrationException>()),
      );
      expect(IntegrationValidation.name('  عَائِشَة  '), 'عَائِشَة');
      expect(
        () => IntegrationValidation.name(''),
        throwsA(isA<IntegrationException>()),
      );
      expect(
        () => IntegrationValidation.name('name\nrole'),
        throwsA(isA<IntegrationException>()),
      );
      expect(
        () => IntegrationValidation.name('a' * 101),
        throwsA(isA<IntegrationException>()),
      );
    });

    test('consent and file restrictions cannot be bypassed', () {
      expect(
        () => IntegrationValidation.consent(false),
        throwsA(isA<IntegrationException>()),
      );
      expect(
        MediaPolicy.validate('lesson.PDF', MediaPolicy.maxBytes),
        'application/pdf',
      );
      expect(MediaPolicy.validate('audio.m4a', 1), 'audio/mp4');
      for (final filename in ['app.exe', 'file', 'lesson.pdf.exe']) {
        expect(
          () => MediaPolicy.validate(filename, 1),
          throwsA(isA<IntegrationException>()),
        );
      }
      for (final size in [0, -1, MediaPolicy.maxBytes + 1]) {
        expect(
          () => MediaPolicy.validate('lesson.pdf', size),
          throwsA(isA<IntegrationException>()),
        );
      }
      expect(
        () => IntegrationValidation.id('../other-user'),
        throwsA(isA<IntegrationException>()),
      );
    });

    test('products normalized; raw SDK failures are not displayed', () {
      expect(
        const IntegrationConfig(
          productIds: ' course,subscription,course, ',
        ).storeProductIds,
        {'course', 'subscription'},
      );
      expect(
        integrationErrorText(StateError('token=private-secret')),
        isNot(contains('private-secret')),
      );
      expect(
        integrationErrorText(const IntegrationException('safe error')),
        'safe error',
      );
    });

    test(
      'push does not initialize Firebase when disabled or unconfigured',
      () async {
        final backend = BackendService(
          config: const IntegrationConfig(supabaseUrl: '', supabaseAnonKey: ''),
        );
        final push = PushService(backend);
        expect(await push.enable(consent: true), isFalse);
        expect(push.status, contains('не настроен'));
        await push.disable();
        push.dispose();
        backend.dispose();
      },
    );
  });

  group('Supabase adapter contract', () {
    late HttpServer server;
    late SupabaseClient client;
    late BackendService backend;
    late List<Map<String, dynamic>> calls;
    var role = 'student';
    var failRole = false;
    var acknowledgeOwner = _userId;
    var verifiedOwner = _userId;
    var verifiedStatus = 'verified';

    setUp(() async {
      calls = [];
      role = 'student';
      failRole = false;
      acknowledgeOwner = _userId;
      verifiedOwner = _userId;
      verifiedStatus = 'verified';
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final raw = await utf8.decoder.bind(request).join();
        final body = raw.isEmpty ? null : jsonDecode(raw);
        calls.add({
          'path': request.uri.path,
          'query': request.uri.queryParameters,
          'body': body,
        });
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path.endsWith('/server_roles')) {
          request.response.statusCode = failRole ? 403 : 200;
          request.response.write(
            jsonEncode(
              failRole
                  ? {'message': 'denied', 'code': '42501'}
                  : [
                      {'role': role},
                    ],
            ),
          );
        } else if (request.uri.path.endsWith('/record_event')) {
          request.response.write(
            jsonEncode({
              'idempotency_key': (body as Map)['p_idempotency_key'],
              'user_id': acknowledgeOwner,
            }),
          );
        } else if (request.uri.path.endsWith('/products')) {
          request.response.write(
            jsonEncode({'id': 'product-uuid', 'kind': 'course'}),
          );
        } else if (request.uri.path.endsWith('/verify-purchase')) {
          request.response.write(
            jsonEncode({
              'purchase': {
                'user_id': verifiedOwner,
                'status': verifiedStatus,
                'product_id': 'product-uuid',
                'provider': 'google',
              },
            }),
          );
        } else {
          request.response.write('{}');
        }
        await request.response.close();
      });
      client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'public-test-key',
      );
      await client.auth.recoverSession(
        jsonEncode({
          'access_token': _jwt({
            'sub': _userId,
            'exp':
                DateTime.now()
                    .add(const Duration(hours: 1))
                    .millisecondsSinceEpoch ~/
                1000,
          }),
          'refresh_token': 'test-refresh',
          'token_type': 'bearer',
          'user': {
            'id': _userId,
            'aud': 'authenticated',
            'app_metadata': {},
            'user_metadata': {'role': 'teacher', 'demo_teacher': true},
            'created_at': '2026-01-01T00:00:00Z',
          },
        }),
      );
      backend = BackendService(client: client);
    });

    tearDown(() async {
      backend.dispose();
      await client.dispose();
      await server.close(force: true);
    });

    test(
      'metadata teacher and demo flags do not grant server privilege',
      () async {
        expect(await backend.loadRole(), ServerRole.student);
        await expectLater(
          backend.requireTeacher(),
          throwsA(isA<IntegrationException>()),
        );
        expect(calls.last['path'], '/rest/v1/server_roles');
        expect((calls.last['query'] as Map)['user_id'], 'eq.$_userId');
        role = 'teacher';
        await backend.requireTeacher();
      },
    );

    test('role loading denial fails closed', () async {
      failRole = true;
      await expectLater(
        backend.requireTeacher(),
        throwsA(isA<PostgrestException>()),
      );
    });

    test(
      'repeated sync keeps caller UUID and cannot become completion evidence',
      () async {
        for (var i = 0; i < 2; i++) {
          await backend.syncProgress(
            eventId: _eventId,
            lessonId: _lessonId,
            payload: {'opened': true, 'lesson_id': 'untrusted-override'},
          );
        }
        final events = calls
            .where((call) => call['path'] == '/rest/v1/rpc/record_event')
            .toList();
        expect(events, hasLength(2));
        expect(events[0]['body'], events[1]['body']);
        expect(events.first['body'], {
          'p_idempotency_key': _eventId,
          'p_kind': 'lesson_opened',
          'p_payload': {'opened': true, 'lesson_id': _lessonId},
        });
        await expectLater(
          backend.syncProgress(
            eventId: _eventId,
            lessonId: _lessonId,
            payload: {},
            kind: 'lesson_completed',
          ),
          throwsA(isA<IntegrationException>()),
        );
        expect(calls, hasLength(2));
      },
    );

    test(
      'store-specific payload and owner/status verification are enforced',
      () async {
        expect(
          await backend.verifyPurchase(
            productId: 'course',
            source: 'google_play',
            receipt: 'token',
            purchaseId: 'transaction',
          ),
          isTrue,
        );
        expect(calls.last['body'], {
          'provider': 'google',
          'product_id': 'course',
          'kind': 'course',
          'purchase_token': 'token',
        });
        verifiedOwner = 'other-user';
        await expectLater(
          backend.verifyPurchase(
            productId: 'course',
            source: 'google_play',
            receipt: 'token',
          ),
          throwsA(isA<IntegrationException>()),
        );
        verifiedOwner = _userId;
        verifiedStatus = 'revoked';
        await expectLater(
          backend.verifyPurchase(
            productId: 'course',
            source: 'google_play',
            receipt: 'token',
          ),
          throwsA(isA<IntegrationException>()),
        );
      },
    );

    test('wrong event acknowledgement cannot clear a pending sync', () async {
      acknowledgeOwner = 'other-user';
      await expectLater(
        backend.syncProgress(
          eventId: _eventId,
          lessonId: _lessonId,
          payload: {},
        ),
        throwsA(isA<IntegrationException>()),
      );
    });

    test('invalid sync UUID and missing consent send no request', () async {
      await expectLater(
        backend.syncProgress(
          eventId: 'new-on-each-retry',
          lessonId: _lessonId,
          payload: {},
        ),
        throwsA(isA<IntegrationException>()),
      );
      await expectLater(
        backend.requestPhoneOtp(
          phone: '+79991234567',
          name: 'Name',
          consent: false,
        ),
        throwsA(isA<IntegrationException>()),
      );
      expect(calls, isEmpty);
    });
  });

  group('private upload retry and bounded picking', () {
    late _UploadBackend backend;
    late _Picker picker;
    late MediaUploadService upload;
    setUp(() {
      backend = _UploadBackend();
      picker = _Picker();
      upload = MediaUploadService(backend, _lessonId, picker: picker);
    });
    tearDown(() {
      upload.dispose();
      backend.dispose();
    });

    test(
      'size rejected before reading stream; mismatch cannot upload',
      () async {
        var read = false;
        picker.file = PlatformFile(
          name: 'lesson.pdf',
          size: MediaPolicy.maxBytes + 1,
          readStream:
              Stream<List<int>>.fromIterable([
                [1],
              ]).map((chunk) {
                read = true;
                return chunk;
              }),
        );
        await expectLater(upload.pick(), throwsA(isA<IntegrationException>()));
        expect(read, isFalse);
        expect(backend.transfers, 0);
        picker.file = PlatformFile(
          name: 'lesson.pdf',
          size: 5,
          readStream: Stream<List<int>>.fromIterable([
            [1, 2, 3, 4],
          ]),
        );
        await expectLater(upload.pick(), throwsA(isA<IntegrationException>()));
        expect(upload.selected, isNull);
      },
    );

    test(
      'private ticket upload and signing succeed without public URL',
      () async {
        await upload.pick();
        await upload.upload();
        expect(picker.requestedStream, isTrue);
        expect(upload.stage, UploadStage.complete);
        expect(upload.mediaId, 'media-1');
        expect(backend.transfers, 1);
        expect(backend.signed, 1);
      },
    );

    test(
      'signing retry never uploads the already transferred object again',
      () async {
        await upload.pick();
        backend.signFailure = true;
        await expectLater(
          upload.upload(),
          throwsA(isA<IntegrationException>()),
        );
        expect(upload.stage, UploadStage.failed);
        expect(backend.transfers, 1);
        backend.signFailure = false;
        await upload.upload();
        expect(backend.transfers, 1);
        expect(upload.stage, UploadStage.complete);
      },
    );

    test('lost upload response is finalized before retrying bytes', () async {
      await upload.pick();
      backend.loseResponse = true;
      await expectLater(upload.upload(), throwsA(isA<IntegrationException>()));
      await upload.upload();
      expect(backend.transfers, 1);
      expect(backend.tickets, 1);
      expect(upload.stage, UploadStage.complete);
    });

    test(
      'incomplete expired ticket is deleted and replaced on retry',
      () async {
        await upload.pick();
        backend.transferFailure = true;
        await expectLater(
          upload.upload(),
          throwsA(isA<IntegrationException>()),
        );
        backend.transferFailure = false;
        await upload.upload();
        expect(backend.deleted, ['media-1']);
        expect(backend.tickets, 2);
        expect(backend.transfers, 2);
        expect(upload.mediaId, 'media-2');
      },
    );
  });

  group('store verification gate', () {
    late _PurchaseBackend backend;
    late _Store store;
    late PurchaseService service;
    setUp(() async {
      backend = _PurchaseBackend();
      store = _Store();
      service = PurchaseService(backend, store: store);
      await service.initialize();
    });
    tearDown(() async {
      service.dispose();
      backend.dispose();
      await store.updates.close();
    });

    test('false verification never completes or unlocks purchase', () async {
      backend.verified = false;
      store.updates.add([_purchase(PurchaseStatus.purchased)]);
      await _until(() => service.error != null);
      expect(store.completed, isEmpty);
      expect(backend.verifications, 1);
    });

    test(
      'network failure leaves transaction uncompleted for restore',
      () async {
        backend.failure = const IntegrationException('offline');
        store.updates.add([_purchase(PurchaseStatus.purchased)]);
        await _until(() => service.error != null);
        expect(store.completed, isEmpty);
        expect(service.status, contains('не подтверждён'));
      },
    );

    test(
      'completion waits for server confirmation, including restoration',
      () async {
        backend.gate = Completer<bool>();
        store.updates.add([_purchase(PurchaseStatus.restored)]);
        await _until(() => backend.verifications == 1);
        expect(store.completed, isEmpty);
        backend.gate!.complete(true);
        await _until(() => store.completed.isNotEmpty);
        expect(store.completed.single.status, PurchaseStatus.restored);
      },
    );

    test('pending/cancelled payment never invokes verifier', () async {
      store.updates.add([_purchase(PurchaseStatus.pending)]);
      await _until(() => service.busy);
      store.updates.add([_purchase(PurchaseStatus.canceled)]);
      await _until(() => !service.busy);
      expect(backend.verifications, 0);
      expect(store.completed, isEmpty);
    });

    test('purchase and restore bind the authenticated UUID', () async {
      await service.buy(store.product);
      expect(store.lastParam?.applicationUserName, _userId);
      store.updates.add([_purchase(PurchaseStatus.canceled)]);
      await _until(() => !service.busy);
      await service.restore();
      expect(store.restoreUser, _userId);
      backend.authenticated = false;
      await expectLater(
        service.buy(store.product),
        throwsA(isA<IntegrationException>()),
      );
    });
  });
}

Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('Condition did not become true');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

PurchaseDetails _purchase(PurchaseStatus status) => PurchaseDetails(
  purchaseID: 'transaction',
  productID: 'course',
  transactionDate: '12345',
  status: status,
  verificationData: PurchaseVerificationData(
    localVerificationData: '',
    serverVerificationData: 'receipt',
    source: 'google_play',
  ),
)..pendingCompletePurchase = true;

class _PurchaseBackend extends BackendService {
  _PurchaseBackend()
    : super(config: const IntegrationConfig(productIds: 'course'));
  bool authenticated = true;
  bool verified = true;
  Object? failure;
  Completer<bool>? gate;
  int verifications = 0;
  @override
  bool get isAuthenticated => authenticated;
  @override
  String? get userId => authenticated ? _userId : null;
  @override
  Future<bool> verifyPurchase({
    required String productId,
    required String source,
    required String receipt,
    String? purchaseId,
  }) async {
    verifications++;
    if (failure != null) throw failure!;
    return gate?.future ?? verified;
  }
}

class _Store implements InAppPurchase {
  final updates = StreamController<List<PurchaseDetails>>.broadcast();
  final completed = <PurchaseDetails>[];
  final product = ProductDetails(
    id: 'course',
    title: 'Course',
    description: 'Server mapped course',
    price: '1',
    rawPrice: 1,
    currencyCode: 'USD',
  );
  PurchaseParam? lastParam;
  String? restoreUser;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async => ProductDetailsResponse(productDetails: [product], notFoundIDs: []);
  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    lastParam = purchaseParam;
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed.add(purchase);
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restoreUser = applicationUserName;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UploadBackend extends BackendService {
  int tickets = 0;
  int transfers = 0;
  int signed = 0;
  bool uploaded = false;
  bool loseResponse = false;
  bool transferFailure = false;
  bool signFailure = false;
  final deleted = <String>[];
  @override
  Future<void> requireTeacher() async {}
  @override
  Future<Map<String, dynamic>> beginMediaUpload({
    required String filename,
    required int size,
    required String mimeType,
    String? lessonId,
    bool sttConsent = false,
  }) async {
    tickets++;
    uploaded = false;
    return {
      'media_id': 'media-$tickets',
      'bucket_id': 'course-media',
      'object_path': '$tickets.pdf',
      'token': 'scoped-token',
      'mime_type': mimeType,
    };
  }

  @override
  Future<void> uploadToTicket(
    Map<String, dynamic> ticket,
    Uint8List bytes,
  ) async {
    transfers++;
    if (transferFailure) throw const IntegrationException('transfer failed');
    uploaded = true;
    if (loseResponse) {
      loseResponse = false;
      throw const IntegrationException('lost response');
    }
  }

  @override
  Future<void> finalizeMediaUpload(String mediaId) async {
    if (!uploaded) throw const IntegrationException('incomplete');
  }

  @override
  Future<void> deleteMedia(String mediaId) async {
    deleted.add(mediaId);
  }

  @override
  Future<String> signedMediaUrl(String mediaId) async {
    signed++;
    if (signFailure) throw const IntegrationException('sign unavailable');
    return 'https://example.com/private-signed-url';
  }
}

class _Picker extends FilePicker {
  PlatformFile file = PlatformFile(
    name: 'lesson.pdf',
    size: 4,
    readStream: Stream<List<int>>.fromIterable([
      [1, 2],
      [3, 4],
    ]),
  );
  bool requestedStream = false;
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    requestedStream = withReadStream && !withData;
    return FilePickerResult([file]);
  }
}
