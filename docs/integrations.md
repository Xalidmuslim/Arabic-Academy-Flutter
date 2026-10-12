# Flutter integrations and activation

Integration services live in `lib/services`; native screens live in `lib/features/integrations`. Backend RPC contracts and activation prerequisites are documented below.

## Dependencies (Flutter 3.35.7 / Dart 3.9.2)

The coordinator's successful resolution is the integration validation target:

| Dependency | Resolved version |
| --- | --- |
| supabase_flutter | 2.18.3 (minimum 2.18.3; uses `publishableKey` initialization) |
| file_picker | 10.3.10 |
| record | 6.2.1 |
| just_audio | 0.10.6 |
| path_provider | 2.1.5 |
| livekit_client | 2.6.4 |
| in_app_purchase | 3.2.3 |
| firebase_core | 4.15.0 |
| firebase_messaging | 16.7.0 |

No additional package is needed for these integrations. The earlier exact dependency set was also resolved/tested, but initialization now uses Supabase's current non-deprecated API. Native minimums include Android API 23 for record and iOS 15 for the resolved Firebase pods (also supports StoreKit 2); coordinator must retain the higher requirements of other resolved plugins. Firebase does not initialize on an offline/unconfigured launch.

## Public screens / startup

```dart
final backend = BackendService();
await backend.initialize(); // false + readable error when absent; offline app proceeds
PhoneAuthScreen(backend: backend);
OralPracticeScreen(backend: backend); // backend optional; audio stays local
LiveSessionsScreen(backend: backend);
MediaUploadScreen(backend: backend, lessonId: lessonId);
PurchasesScreen(backend: backend);
```

Import each screen from `lib/features/integrations/<snake_case_name>.dart`, or the barrel `integrations.dart`. `BackendService` also exposes `isConfigured`, `isAuthenticated`, `initializationError`, `userId`, `loadRole`, `courses`, `lessons`, `lessonContent`, `studyProgress`, `syncProgress`, and `completeLesson`. Dispose the shared backend with the app owner, not on leaving individual screens.

The app retains one `PurchaseService(backend)` through `PurchaseScope`, initializes it after authentication/configuration, and keeps pending/late transactions subscribed across route changes. The app owner disposes it. An explicit `PurchasesScreen(..., purchases: service)` remains available for embedding. The default screen-only constructor subscribes while that screen is open; restore is available to retry undelivered transactions. Do not create multiple simultaneous purchase subscriptions. Do not map a demo teacher switch to these services. `loadRole()` reads a server role table for the authenticated ID; failures must not enable teacher controls. No role is read from `user_metadata`.

## Backend contract

[backend.md](backend.md) and the migrations/Edge Functions are authoritative. All calls are centralized in `backend_service.dart`. Server IDs are UUIDs: do not send local legacy lesson slugs without a catalog mapping.

| Surface | Client behavior |
| --- | --- |
| Profile | SMS OTP, then `save_profile(p_display_name,p_consent:true)` records server consent time; failure signs the new session out locally. Name is not stored as role-bearing auth metadata. |
| Role | `server_roles(user_id,role)` read own rows; failure never enables teacher controls. |
| Catalog | Published `courses`; lessons scoped through `levels → books → units → lessons`; lesson blocks/vocabulary/grammar fetched under RLS. |
| Progress | `syncProgress(eventId,lessonId,payload,kind)` calls `record_event(p_idempotency_key,p_kind,p_payload)`. Caller retains the same UUID/payload in its durable queue until acknowledgement. It never turns telemetry into completion; `completeLesson` calls server-validated `complete_lesson`. |
| Media | `media-upload` begin receives `{filename,byte_size,mime_type,lesson_id,consent_stt}` and returns `{media_id,bucket_id,object_path,mime_type,token}`. Signed upload grants no public read. Complete receives `{action:'complete',media_id}` and must return `{media}` with `upload_state:'ready'` after storage metadata validation. |
| Signing | `protected-media({media_id}) → {url,expires_in}`; server-authorized, at most 60 seconds. Save **media ID** into content, never signed URL. |
| Retry | Successful transfer/signing are separate stages. Lost transfer response is finalized first; signing retries do not upload bytes again. Incomplete/expired ticket is deleted through `delete-media` and replaced. File size is checked before reading the picker stream and bounded to 50 MiB while reading. Transfer indicator is indeterminate because SDK exposes no byte progress. |
| Live | `groups` and RLS-filtered `live_sessions`; teacher scheduling calls `create_live_session` with group UUID and UTC times. `livekit-token({session_id,recording_consent})` returns `{url,token,can_publish,expires_at}`. Recording requires separate explicit entry consent, updates `user_settings.recording_consent`, and is off for newly created sessions. |
| Room | Device capture starts off; server `can_publish` governs microphone/camera controls and token enforces permissions. Chat/raise-hand packets use reliable LiveKit data channel; ephemeral, bounded to 100 displayed messages, not stored as privileged data. Learners currently receive viewing/data access only. Background/exit stops capture and disposes room/listeners. |
| Purchase | `verify-purchase`: Apple `{provider:'apple',transaction_id}`; Google `{provider:'google',purchase_token,product_id,kind}`. Product kind comes from server `products`. Accept only returned verified purchase bound to current user, product and provider. Verify before completing purchase; never unlock locally. |
| Access | Read own `entitlements` with no revocation, started time and active expiry. RLS continues to enforce content access. |
| STT | Auth + `STT_ENABLED` + local/per-recording consent → update `user_settings.stt_consent`, upload private owned audio through the same ticket flow, call `transcribe({media_id})`, require `assessment:'transcription_only'`. Delete uploaded media afterwards via `delete-media`; cleanup failures are visible errors. |
| Push | Only when Firebase is already initialized and `FIREBASE_PUSH_ENABLED`; explicit button + native permission, `register_push_token`, token refresh, `unregister_push_token` and native deletion when disabled/signed out. No synthetic counts. |
| Export/delete | `account-export({})` returns own JSON; `account-delete({confirm:true})` must return `{deleted:true}`. UI offers export/copy and a separate irreversible deletion confirmation. |

The backend agent has added `save_profile`, media begin/complete/deletion, and push registration/unregistration in migration 005. The backend handoff explicitly leaves account export/deletion endpoints unimplemented; until added/deployed those paths fail with an actionable error. This is a remaining server implementation gap, not just a missing key. The Flutter worker cannot change backend files.

Never install service_role, LiveKit secret, store verification credentials, or STT provider keys in Flutter. Client checks do not replace RLS. A signed upload ticket cannot be used as a read URL.

## Activation / permissions

Pass `--dart-define=SUPABASE_URL=https://<project>.supabase.co` and `--dart-define=SUPABASE_ANON_KEY=<public-anon-or-publishable-key>`. Missing, malformed or server-secret configuration fails closed. Enable Supabase phone auth and a real SMS provider; deploy migrations and Edge Functions before exercising these paths. No SMS or remote readiness is claimed merely by initializing the SDK.

Audio needs Android `RECORD_AUDIO` and iOS `NSMicrophoneUsageDescription`. Camera/live calls also need Android `CAMERA` / network permissions and iOS `NSCameraUsageDescription`, and the LiveKit platform setup for this version. Configure Android minimum SDK and iOS deployment target to meet dependency constraints. Coordinator owns native files. File picking uses native system UI. Local audio is mobile-only; web returns an explicit unsupported message. Recordings are limited to three minutes and deleted when leaving the screen; no background audio/upload occurs automatically.

Optional STT additionally needs `--dart-define=STT_ENABLED=true`, an authenticated session, a deployed provider function, and a separate per-recording opt-in plus explicit send button. Transcription is displayed as text and never labelled as pronunciation accuracy.

Purchases need App Store / Play Console products, store test accounts, provider credentials on the backend, and `--dart-define=IAP_PRODUCT_IDS=id1,id2`. Non-consumable course products and subscriptions use the store purchase flow; consumable products are not supported. Purchase stream starts before loading products. Purchased/restored receipts go to server verification before completing the store transaction. Unverified transactions remain pending for later restoration, and access is always reloaded from server entitlements. Test owner binding and restore on a different device/account before release. The current backend verifier rejects Apple sandbox receipts, so Apple sandbox activation requires an explicitly isolated server test configuration; never treat a rejected sandbox receipt as access.

Push is off by default. Only after the coordinator explicitly initializes Firebase with valid platform options can `FIREBASE_PUSH_ENABLED=true` and user permission enable Messaging. This integration does not call `Firebase.initializeApp`, so an unconfigured offline launch does not require Firebase. Configure APNs/FCM, Android 13 permission, and optional background handler at app level; no unread counts or delivery statistics are fabricated.

## Validation status

Validation on the coordinator's resolved SDK/dependencies: scoped analyzer passed without issues and all 22 integration tests passed with `source /workspace/academy-env.sh`. This verifies the client adapters/configuration, not provider activation. Tests cover configuration/secret rejection, consent/input/file validation, server-role lookup despite teacher metadata, authorization failure, stable event payload/UUID, scoped purchase verification, pending/restore completion gate, account binding, and private upload retries/stream limits.

```sh
source /workspace/academy-env.sh
flutter analyze --no-pub lib/services lib/features/integrations test/integration_config_test.dart
flutter test --no-pub test/integration_config_test.dart --reporter expanded
```

Live SMS, storage, room connections, store verification, STT and push require owner configuration and real devices/provider accounts. No remote activation has been verified in this credential-free environment.
