# Backend, API and deployment contract

All identifiers are UUIDs unless stated otherwise. Tables use snake_case and authenticated Supabase clients. Roles come only from `server_roles(user_id, role)`, where role is `student`, `teacher`, or `admin`. Newly authenticated accounts are students; user metadata is ignored for roles. Phone OTP/SMS is configured in the Supabase dashboard, not simulated here.

## Client endpoints

All Edge functions accept POST JSON and `Authorization: Bearer <Supabase user access token>`. Errors use `{ "error": "code" }` with a non-2xx HTTP status. No server secrets belong in Flutter.

| Endpoint | Request | Response |
|---|---|---|
| `livekit-token` | `session_id`, optional `recording_consent` boolean | `token`, `url`, `expires_at`, `can_publish` |
| `protected-media` | `media_id` | `url`, `expires_in` (at most 60 seconds) |
| `grade-attempt` | `exercise_id`, UUID `idempotency_key`, `answers` object keyed by question UUID | `attempt` row |
| `verify-purchase` | `provider`: apple/google; Apple `transaction_id`; Google `purchase_token`, `product_id`, `kind`: course/subscription | `purchase` row from a verified store result |
| `transcribe` | `media_id` for own uploaded audio | `text`, `language`, `provider`, `assessment`: transcription_only |

RPC argument names must be passed exactly as listed:

| RPC | Arguments | Return |
|---|---|---|
| `record_event` | `p_idempotency_key` UUID, `p_kind` text, `p_payload` JSON object | `events` row |
| `submit_attempt` | `p_exercise_id`, `p_idempotency_key`, `p_answers` JSON object | `attempts` row |
| `complete_lesson` | `p_lesson_id` | `study_progress` row; requires current-version passing attempts for every published exercise |
| `enroll_course` | `p_course_id` | `enrollments` row; enrollment never grants paid access |
| `create_group` | `p_course_id`, `p_title` | `groups` row |
| `set_group_member` | `p_group_id`, `p_student_id`, `p_active` boolean | void |
| `create_assignment` | `p_group_id`, `p_exercise_id`, `p_title`, optional `p_due_at` timestamptz | `assignments` row |
| `submit_assignment` | `p_assignment_id`, `p_expected_revision` (0 for first submission), `p_idempotency_key`, `p_body` JSON object | `submissions` row |
| `grade_submission` | `p_submission_id`, `p_revision`, `p_score` (0–100), `p_feedback` text | `grades` row |
| `review_attempt` | `p_attempt_id`, `p_score` (0–max_score) | `attempts` row for a manual attempt |
| `create_lesson` | `p_unit_id`, `p_title`, `p_position` | draft `lessons` row |
| `save_lesson` | `p_lesson_id`, `p_expected_version`, `p_patch` JSON object, optional `p_content` JSON object | incremented `lessons` row |
| `save_exercise` | `p_exercise_id`, `p_lesson_id`, `p_expected_version` (0 for create), `p_definition`, `p_questions` array | `exercises` row |
| `create_live_session` | `p_group_id`, `p_title`, `p_starts_at`, `p_ends_at`, optional `p_recording_enabled` | `live_sessions` row |

Event kinds: `lesson_opened`, `draft_saved`, `study_reviewed`, `settings_changed`. Event delivery is append-only and idempotent per account/key; changed payload with a reused key fails. Events are telemetry/drafts, never completion or payment evidence. Store server confirmation before clearing the local outbox. Content/version conflicts use SQLSTATE `40001`; authorization failures `42501`; idempotency conflicts `23505`.

`profiles`: `id`, `display_name`, `locale`, `created_at`; own `display_name` and `locale` are writable. `user_settings`: `user_id`, `notifications_enabled`, `stt_consent`, `recording_consent`, `preferences`. Only the owner writes settings. Own progress survives entitlement revocation.

Catalog chain: `courses` → `levels(course_id)` → `books(level_id)` → `units(book_id)` → `lessons(unit_id)`. Course metadata is browseable when published, but lesson bodies, blocks, exercises, vocabulary and media are server protected. A published free sample is explicitly `lessons.is_free_sample=true`. Query RLS-filtered tables; an empty result does not mean a missing table.

`attempts`: `id`, `student_id`, `exercise_id`, `exercise_version`, `idempotency_key`, `answers`, `status` (graded/pending_review), nullable `score`, `max_score`, `passed`, `created_at`. Client scores and pass flags are never accepted. Answer keys are private and unavailable even to a teacher's table queries. Teacher writes keys through `save_exercise`.

`save_lesson.p_patch` allows only `title`, `title_ar`, `goal`, `status`, `is_free_sample`, `position`, `source_locator`. `p_content` may contain replacement arrays `blocks`, `dialogues`, `vocabulary`, `grammar`. Omitted arrays are unchanged; an empty array removes that section. Blocks contain `id?`, `step`, `kind`, `body` object, `position`. Dialogues contain `id?`, `title`, `lines` (`id?`, `speaker`, `text_ar`, `translation`, `position`). Vocabulary contains `id?`, `text_ar`, `translation`, `transliteration?`, `position`; preserve existing IDs for review history. Grammar contains `id?`, `title`, `explanation`, `examples`, `position`.

`save_exercise.p_definition`: `kind`, `title`, `grading_mode` (automatic/manual), `pass_percent` (default 100), `published` (default false). Questions: `id?`, `prompt` object, `position`, `points` (default 1), `options` array (`id?`, `label`, `position`), and for automatic grading `accepted_answers` array plus `comparison` (exact/text_trim). Each array member of accepted_answers is a complete accepted JSON value; order matters in arrays. Only explicit text_trim trims surrounding whitespace. Arabic diacritics are preserved. All other exercise kinds may use exact structured JSON or manual review; STT is never phonetic grading.

Purchases require the store's account binding to equal the authenticated Supabase user UUID: Apple `appAccountToken`; Google `obfuscatedAccountId` / `obfuscatedExternalAccountId`. Configure that field when launching billing. Store product IDs map through `products` and `product_courses`; no client-provided course list grants access. Provisioning is server-only. Paid content cached offline needs a separately managed license; these signed URL APIs grant short online access only.

## Additional client prerequisites

`save_profile(p_display_name text, p_consent boolean)` returns the own profile and records `consent_at` using server time. Consent must be true; it is independent of recording/STT consent. A profile update accepts no role. Existing IDs and local material keys are not rewritten.

`media-upload` POST begin: `{action:"begin",filename,byte_size,mime_type,lesson_id?:UUID|null,consent_stt?:boolean}` returns `{media_id,bucket_id,object_path,mime_type,byte_size,upload_state:"pending",token}`. Use Supabase Storage `uploadBinaryToSignedUrl(object_path,token,bytes,FileOptions(contentType:mime_type,upsert:false))`. The filename is display-only; the server assigns every path. Only assigned teachers/admins upload course media; an authenticated account can upload only its own private audio without a lesson. Maximum audio size: 25,000,000 bytes; course files: 104,857,600. Begin rejects STT consent without global opt-in. `media-upload` POST complete: `{action:"complete",media_id}` returns `{media:<row>}` only after actual Storage metadata matches registered size and MIME type. Pending/deleted uploads cannot be read or transcribed. Completion can be retried.

`delete-media` POST `{media_id}` removes the authorized object before setting its metadata to deleted, withdrawing per-recording STT consent, and returning `{deleted:true,media_id}`. A failed Storage operation returns an error. The client uses this after temporary STT; ordinary playback stays local unless explicitly uploaded. Signed upload tokens expire on Storage's standard lifetime (currently two hours); schedule an orphan cleanup job for pending/deleted objects. A remaining upload token never restores readable metadata after deletion.

Supporting RPCs: `prepare_media_upload(p_lesson_id,p_mime_type,p_byte_size,p_consent_stt=false)` and `media_upload_access(p_media_id)` return ticket metadata; `set_media_stt_consent(p_media_id,p_consent)` withdraws/sets own per-recording consent. Global `user_settings.stt_consent` and the per-recording flag must both permit every transcription. `reserve_stt_request(p_media_id)` reserves one server-metered request, with at most five requests per account per ten minutes, including failed provider calls. Revocation is checked again after download and before sending audio. Responses are transcripts, never pronunciation scores. Raw audio/transcripts are not logged or retained by the Edge function; the selected provider has its own retention policy.

`register_push_token(p_token)` and `unregister_push_token(p_token)` bind/remove a token for the authenticated account. A token already owned by another account is rejected. Call unregister before signout on shared devices. Push dispatch and account export/deletion now have server endpoints, described below. Background delivery workers and live APNs/FCM credential setup remain deployment work.

Group membership changes through `set_group_member` require a server-assigned administrator. Teachers cannot self-assign arbitrary students. Administrators/service jobs provision course-teacher assignments and student-group membership; teachers can create groups for their assigned courses. The client should query `vocabulary` with `retired_at IS NULL` for the current catalog. Replacing/reordering vocabulary preserves existing IDs and review history; removed words are retired rather than deleted.

## Runtime and deployment

Run from the repository root:

```sh
scripts/test_backend.sh
POSTGRES_IMAGE=postgres:17-alpine scripts/test_backend.sh
scripts/test_backend_edge.sh
```

The database script launches a disposable PostgreSQL container on the managed local Docker socket, waits for readiness, installs test-only auth/storage mocks, applies every migration, runs every SQL suite with `ON_ERROR_STOP`, and removes only its own container. PostgreSQL data use a 256 MiB tmpfs, so test databases leave no persistent volumes and do not fill the workspace disk. It exposes no host ports and mounts no production data. Docker pulls the selected image if necessary. Edge tests use Deno (or npm's Deno package), type-check every endpoint, then run adapter tests with mocked HTTP/store responses. Caches live in `/tmp`; no app dependencies or CI files are changed. These checks do not require Supabase CLI, provider credentials or SMS. Never deploy `supabase/tests/bootstrap.sql`.

For a real Supabase project, review the SQL, use `supabase db push` against the intended project, and deploy each function with `supabase functions deploy <name>`. `config.toml` disables the legacy JWT gateway for these functions; every user endpoint independently validates its bearer token using Supabase Auth `/auth/v1/user`. The webhook independently verifies HMAC. Deploy code and configuration together. Keep `private` out of exposed API schemas. Set server secrets through the Supabase secret manager; `.env.example` lists names without values. Enable phone OTP and an actual SMS provider separately in Supabase Auth. Confirm live Supabase Storage signed upload/download behavior before release; local PostgreSQL mocks do not exercise Storage's HTTP service.

Secrets/configuration:

| Integration | Required server variables | External destinations |
|---|---|---|
| Supabase | `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, optional comma-separated `ALLOWED_ORIGINS` | configured Supabase HTTPS project |
| LiveKit | `LIVEKIT_URL` (wss), `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET` | configured LiveKit WebSocket endpoint |
| Apple production | `APPLE_BUNDLE_ID`, numeric `APPLE_APP_ID`, `APPLE_ISSUER_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY_P8`, `APPLE_ROOT_CA_PEMS_JSON` | `api.storekit.itunes.apple.com`; Apple OCSP/PKI hosts used by the verifier |
| Google production | `GOOGLE_PLAY_PACKAGE_NAME`, `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` with Android Publisher permissions | `oauth2.googleapis.com`, `androidpublisher.googleapis.com` |
| Store sandbox/test (separate test project only) | `DEPLOYMENT_ENVIRONMENT=test`, `STORE_TEST_ENVIRONMENT=true` plus real store credentials; default false | Apple sandbox StoreKit API; Google Android Publisher API |
| Verified billing gateway | `PURCHASE_WEBHOOK_HMAC_SECRET` (at least 32 characters) | owner-operated gateway → Supabase Edge |
| Optional STT | `STT_OPENAI_API_KEY` | `api.openai.com` |
| FCM dispatch | `FCM_SERVICE_ACCOUNT_JSON` | `oauth2.googleapis.com`, `fcm.googleapis.com` |

Apple verification uses a short ES256 App Store Server API JWT, fetches the transaction, then verifies Apple's signed transaction and certificate chain with the official Apple library, including online certificate checks. By default only production, purchased non-consumables or unexpired auto-renewable subscriptions bound to this account qualify; sandbox, consumables, family-shared, revoked, expired or unbound claims fail. A separate test deployment can enable licensed sandbox purchases with server-only `STORE_TEST_ENVIRONMENT=true` and `DEPLOYMENT_ENVIRONMENT=test`. Any other deployment with that flag fails `invalid_store_test_configuration` before provider access. Apple then uses `api.storekit-sandbox.itunes.apple.com` and the official verifier’s Sandbox environment; credentials, trusted certificate chain, bundle/product/transaction binding and ownership checks still apply. Clients cannot select this mode. Google exchanges a server service-account assertion for Android Publisher OAuth, verifies the package/product/token/state/account against Play's API, then acknowledges a verified purchase before granting access. Verified Google subscriptions in `ACTIVE`, `CANCELED` or `IN_GRACE_PERIOD` qualify only with a matching account/product and future expiry. Paused, pending, on-hold, expired, revoked/refunded-expired and unknown states fail closed. Test purchases require the trusted test-deployment flag; pending, consumed and unsupported multi-product purchases fail closed. Google transaction IDs in this backend are lowercase SHA-256 hashes of the purchase token; raw purchase tokens and store receipt blobs are not persisted or returned. Live credentials and real store purchases were unavailable during local validation.

Provision `products(provider,external_id,kind,active)` and explicit `product_courses(product_id,course_id)` mappings on the server before verification. Lifetime course purchases grant only mapped courses; subscriptions grant only mapped courses until provider expiry. Purchase verification never infers a course from client state. Administrative entitlement revocation does not erase progress. Teacher/admin assignment grants editing access without a course purchase; students must satisfy publication and access checks.

## Billing webhook and server-only RPCs

`purchase-webhook` is a **verified gateway contract**, not a native Apple ASN/Google RTDN endpoint. The gateway must validate the upstream provider notification and derive the transaction/account from verified store data before signing. Native provider notification subscriptions, verification ingress, automatic renewals/reconciliation, LiveKit recording egress, licensed content ingestion and notification delivery require separate deployment work. Google renewals extend the existing token-bound subscription when reverified. Apple renewal transaction IDs are separate verified purchases. Without configured notification/reconciliation jobs, do not claim automatic refund handling or unattended subscription renewal.

POST raw JSON `{provider:"apple"|"google",action:"revoke",transaction_id,account_binding:<bound account UUID>}` with headers `x-event-id` (1–128 alphanumeric/underscore/hyphen characters), `x-timestamp` (Unix seconds), `x-signature` (lowercase HMAC-SHA256 hex). Sign the exact UTF-8 string `timestamp.event_id.raw_body`. Timestamps must be within 300 seconds. Event IDs and payloads are persisted in one transaction with revocation. Duplicate identical events are harmless; changed payloads with the same ID fail. Unknown/unbound transactions fail. The endpoint cannot grant access. Re-sign delayed retries with a fresh timestamp but the same event ID/body. Revoked purchases cannot be reopened by replaying a verification request.

Only `service_role` can execute:

- `apply_verified_purchase(p_user_id uuid,p_provider text,p_transaction_id text,p_product_external_id text,p_account_binding text,p_purchased_at timestamptz,p_expires_at timestamptz,p_payload jsonb)` → `purchases` row.
- `apply_purchase_webhook(p_provider text,p_event_id text,p_transaction_id text,p_account_binding text,p_action text,p_payload jsonb)` → `{duplicate,purchase_id}`.
- `finalize_media_upload(p_media_id uuid,p_actor_id uuid)` → `media` row, after Storage metadata validation.
- `mark_media_deleted(p_media_id uuid,p_actor_id uuid)` → void.

The Edge code derives actor/account IDs from a validated Supabase user, never request claims. Client roles and entitlement mutations have no INSERT/UPDATE/DELETE privileges. Every application table has RLS; private tables have no client schema privileges/policies. A restrictive Storage policy prevents broad pre-existing client policies from granting access to these private buckets. All SECURITY DEFINER functions use an empty search_path and fully qualified tables. Functions do not inherit PostgreSQL's default PUBLIC execute grant. Answer keys remain private even for teacher table queries; controlled editing is write-only through `save_exercise`.

Signed downloads remain valid for their issuance lifetime (at most 60 seconds) after later revocation; a downloadable copy cannot be recalled. Course media TTL is also bounded by the current entitlement's remaining lifetime. LiveKit tokens expire within five minutes or session end; existing room connections require LiveKit-side participant removal for immediate revocation. Students receive subscribe-only audio/video grants and can publish room data for chat/hand-raising. Audio/video publication is limited to the assigned teacher/admin. Tokens have no room administration, recording or room-creation grants. Record-enabled sessions require global and per-join consent. No recording job is started by this backend.

Authorization changes to roles, course-teacher assignments, group members and entitlements are audited without tokens/answer keys. Use short retention for private STT reservation records and orphan uploads, and a documented retention policy for educational history/audit/billing records. Account deletion uses the confirmed purge/anonymization workflow below; it does not approximate success when external Auth or Storage operations fail.

## Exact table columns

Column names and PostgreSQL types below are the public contract. Nullable/default/FK/check/uniqueness constraints are defined in the migrations. Table writes are through the documented RPCs unless expressly allowed above.

| Table | Columns |
|---|---|
| `public.profiles` | `id: uuid`, `display_name: text`, `locale: text`, `created_at: timestamptz`, `deletion_requested_at: timestamptz`, `consent_at: timestamptz` |
| `public.server_roles` | `user_id: uuid`, `role: text` |
| `public.teachers` | `id: uuid`, `bio: text` |
| `public.students` | `id: uuid`, `joined_at: timestamptz` |
| `public.courses` | `id: uuid`, `slug: text`, `title: text`, `description: text`, `access_tier: text`, `status: text`, `source_policy: text`, `created_at: timestamptz`, `created_by: uuid` |
| `public.course_teachers` | `course_id: uuid`, `teacher_id: uuid` |
| `public.groups` | `id: uuid`, `course_id: uuid`, `teacher_id: uuid`, `title: text`, `archived_at: timestamptz` |
| `public.group_members` | `group_id: uuid`, `student_id: uuid`, `joined_at: timestamptz`, `left_at: timestamptz` |
| `public.levels` | `id: uuid`, `course_id: uuid`, `title: text`, `position: int` |
| `public.books` | `id: uuid`, `level_id: uuid`, `title: text`, `edition: text`, `license_reference: text`, `position: int`, `source_locator: jsonb` |
| `public.units` | `id: uuid`, `book_id: uuid`, `legacy_id: text`, `title: text`, `position: int` |
| `public.lessons` | `id: uuid`, `unit_id: uuid`, `legacy_id: text`, `title: text`, `title_ar: text`, `goal: text`, `status: text`, `is_free_sample: boolean`, `position: int`, `version: int`, `updated_at: timestamptz`, `source_locator: jsonb` |
| `public.lesson_blocks` | `id: uuid`, `lesson_id: uuid`, `step: text`, `kind: text`, `body: jsonb`, `position: int` |
| `public.dialogues` | `id: uuid`, `lesson_id: uuid`, `title: text` |
| `public.dialogue_lines` | `id: uuid`, `dialogue_id: uuid`, `speaker: text`, `text_ar: text`, `translation: text`, `position: int` |
| `public.vocabulary` | `id: uuid`, `lesson_id: uuid`, `text_ar: text`, `translation: text`, `transliteration: text`, `position: int`, `retired_at: timestamptz`, `root: text`, `part_of_speech: text`, `gender: text`, `number: text`, `forms: jsonb`, `example_ar: text`, `example_translation: text`, `level: text` |
| `public.grammar` | `id: uuid`, `lesson_id: uuid`, `title: text`, `explanation: text`, `examples: jsonb`, `position: int`, `root: text`, `part_of_speech: text`, `gender: text`, `number: text`, `forms: jsonb`, `example_ar: text`, `example_translation: text`, `level: text` |
| `public.media` | `id: uuid`, `lesson_id: uuid`, `owner_id: uuid`, `kind: text`, `mime_type: text`, `byte_size: bigint`, `consent_stt: boolean`, `consent_recording: boolean`, `created_at: timestamptz`, `upload_state: text` |
| `private.media_objects` | `media_id: uuid`, `bucket_id: text`, `object_path: text` |
| `public.exercises` | `id: uuid`, `lesson_id: uuid`, `kind: text`, `title: text`, `grading_mode: text`, `pass_percent: numeric`, `version: int`, `published: boolean` |
| `public.questions` | `id: uuid`, `exercise_id: uuid`, `prompt: jsonb`, `position: int`, `points: numeric` |
| `public.question_options` | `id: uuid`, `question_id: uuid`, `label: text`, `position: int` |
| `private.answer_keys` | `question_id: uuid`, `accepted_answers: jsonb`, `comparison: text` |
| `public.attempts` | `id: uuid`, `student_id: uuid`, `exercise_id: uuid`, `exercise_version: int`, `idempotency_key: uuid`, `answers: jsonb`, `status: text`, `score: numeric`, `max_score: numeric`, `passed: boolean`, `created_at: timestamptz` |
| `public.assignments` | `id: uuid`, `group_id: uuid`, `exercise_id: uuid`, `title: text`, `due_at: timestamptz`, `created_by: uuid`, `created_at: timestamptz` |
| `public.submissions` | `id: uuid`, `assignment_id: uuid`, `student_id: uuid`, `revision: int`, `body: jsonb`, `updated_at: timestamptz`, `status: text` |
| `public.submission_history` | `id: uuid`, `submission_id: uuid`, `revision: int`, `body: jsonb`, `idempotency_key: uuid`, `created_at: timestamptz` |
| `public.grades` | `id: uuid`, `submission_id: uuid`, `revision: int`, `teacher_id: uuid`, `score: numeric`, `created_at: timestamptz` |
| `public.feedback` | `id: uuid`, `grade_id: uuid`, `body: text`, `created_at: timestamptz` |
| `public.enrollments` | `student_id: uuid`, `course_id: uuid`, `enrolled_at: timestamptz` |
| `public.products` | `id: uuid`, `provider: text`, `external_id: text`, `kind: text`, `active: boolean` |
| `public.product_courses` | `product_id: uuid`, `course_id: uuid` |
| `public.purchases` | `id: uuid`, `user_id: uuid`, `product_id: uuid`, `provider: text`, `transaction_id: text`, `status: text`, `purchased_at: timestamptz`, `verified_at: timestamptz` |
| `public.subscriptions` | `id: uuid`, `purchase_id: uuid`, `user_id: uuid`, `expires_at: timestamptz`, `revoked_at: timestamptz` |
| `public.entitlements` | `id: uuid`, `user_id: uuid`, `course_id: uuid`, `purchase_id: uuid`, `starts_at: timestamptz`, `expires_at: timestamptz`, `revoked_at: timestamptz` |
| `private.purchase_claims` | `provider: text`, `transaction_id: text`, `user_id: uuid`, `account_binding: text`, `verified_payload: jsonb` |
| `private.webhook_events` | `provider: text`, `event_id: text`, `payload: jsonb`, `received_at: timestamptz` |
| `public.live_sessions` | `id: uuid`, `group_id: uuid`, `title: text`, `room_name: text`, `starts_at: timestamptz`, `ends_at: timestamptz`, `cancelled_at: timestamptz`, `recording_enabled: boolean` |
| `public.session_participants` | `session_id: uuid`, `user_id: uuid`, `joined_at: timestamptz`, `recording_consent: boolean` |
| `public.recordings` | `id: uuid`, `session_id: uuid`, `media_id: uuid`, `available_at: timestamptz` |
| `public.notifications` | `id: uuid`, `user_id: uuid`, `kind: text`, `body: jsonb`, `read_at: timestamptz`, `created_at: timestamptz`, `created_by: uuid`, `group_id: uuid`, `idempotency_key: uuid` |
| `public.events` | `id: uuid`, `user_id: uuid`, `idempotency_key: uuid`, `kind: text`, `payload: jsonb`, `received_at: timestamptz` |
| `public.study_progress` | `student_id: uuid`, `lesson_id: uuid`, `completed_at: timestamptz` |
| `public.vocabulary_reviews` | `student_id: uuid`, `vocabulary_id: uuid`, `rating: int`, `reviewed_at: timestamptz`, `next_review_at: timestamptz` |
| `public.bookmarks` | `user_id: uuid`, `lesson_id: uuid`, `created_at: timestamptz` |
| `public.user_settings` | `user_id: uuid`, `notifications_enabled: boolean`, `stt_consent: boolean`, `recording_consent: boolean`, `preferences: jsonb` |
| `public.audit_log` | `id: bigint`, `actor_id: uuid`, `action: text`, `entity_id: uuid`, `details: jsonb`, `created_at: timestamptz` |
| `public.push_tokens` | `user_id: uuid`, `token: text`, `created_at: timestamptz` |
| `private.integration_requests` | `id: uuid`, `user_id: uuid`, `media_id: uuid`, `kind: text`, `reserved_at: timestamptz` |
| `public.revision_requests` | `id: uuid`, `submission_id: uuid`, `revision: int`, `teacher_id: uuid`, `reason: text`, `created_at: timestamptz`, `resolved_at: timestamptz` |
| `public.submission_status_history` | `id: uuid`, `submission_id: uuid`, `revision: int`, `status: text`, `actor_id: uuid`, `note: text`, `created_at: timestamptz` |
| `public.study_sessions` | `id: uuid`, `user_id: uuid`, `lesson_id: uuid`, `idempotency_key: uuid`, `started_at: timestamptz`, `ended_at: timestamptz`, `reviewed_count: int` |
| `private.notification_dispatches` | `notification_id: uuid`, `state: text`, `token_count: int`, `accepted_count: int`, `failed_count: int`, `reserved_at: timestamptz`, `completed_at: timestamptz` |
| `private.group_invites` | `id: uuid`, `group_id: uuid`, `created_by: uuid` (nullable), `code_hash: bytea` (SHA-256 only), `expires_at: timestamptz`, `claimed_by: uuid` (nullable), `claimed_at: timestamptz`, `created_at: timestamptz` |
| `private.account_media_cleanup_jobs` | `id: uuid`, `user_id: uuid` (temporary, nullable after completion), `objects: jsonb`, `requested_at: timestamptz`, `not_before: timestamptz`, `lease_expires_at: timestamptz`, `completed_at: timestamptz`, `attempt_count: int` |

## Access helper RPCs

These return a boolean for the caller and are primarily used inside RLS: `has_server_role(p_role text)`, `teaches_course(p_course uuid)`, `can_access_course(p_course uuid)`, `can_read_lesson(p_lesson uuid)`, `manages_group(p_group uuid)`, `is_group_member(p_group uuid)`, `teaches_student(p_student uuid,p_course uuid=null)`, `can_read_exercise(p_exercise uuid)`, `can_read_assignment(p_assignment uuid)`, `can_read_submission(p_submission uuid)`, `can_join_session(p_session uuid)`, `can_read_media(p_media uuid)`. The nullable course in `teaches_student` intentionally means any assigned course for profile visibility; attempt/review policies always resolve the real course through a definer lookup, so an RLS-hidden parent cannot broaden access. `lesson_course_id(p_lesson uuid)` and `exercise_course_id(p_exercise uuid)` return catalog course UUIDs, never content or answer keys. `live_session_access(p_session_id uuid,p_recording_consent boolean=false)` returns `{session_id,room_name,user_id,can_publish,expires_at}` after enforcing membership, time and consent. `media_access(p_media_id uuid,p_for_stt boolean=false)` returns `{media_id,bucket_id,object_path,mime_type,byte_size,expires_in}` after authorization. Paths alone grant no Storage access. Do not cache authorization decisions as client entitlement flags.

## Local validation evidence

Thirteen migrations define 55 RLS-protected application tables (47 public, eight private). Six SQL suites (`content_test`, `isolation_test`, `media_test`, `review_test`, `security_test`, `workflow_test`) exercised real PostgreSQL 16 and 17 containers. They cover every application table's RLS, function privilege/search-path checks, role spoofing, paid and draft content, hidden-parent teacher isolation, grading/manual review/current exercise versions, append-only event delivery, submission revisions/history, purchases/account binding/replays/revocation/expiry, consent, upload metadata, private Storage guards and push-token isolation. Twelve Edge endpoints type-check with a frozen Deno lockfile (npm integrity/checksum validation enabled); 35 Deno adapter tests passed with mocked HTTP/store responses. The race harness uses actual competing PostgreSQL sessions for both upload/deletion orderings and concurrent preference merging, and confirms queued cleanup paths survive personal-data purge. External SMS, Supabase Auth deletion/Storage HTTP, LiveKit connections, production/sandbox store verification, FCM delivery and STT calls were not run because their credentials/services were not configured. No migration or function was deployed remotely, and no commit was created.

## Coordinator update: catalog and school workflows

The following RPCs require a real server teacher/admin role and never accept an owner ID:

| RPC | Exact arguments | Return |
|---|---|---|
| `create_course` | `p_title text`, `p_access_tier text='free'`, `p_source_policy text='original_editorial'` | draft `courses` row; assigns authenticated teacher and `created_by` automatically |
| `create_level` | `p_course_id uuid`, `p_title text`, `p_position int` | `levels` row |
| `create_book` | `p_level_id uuid`, `p_title text`, `p_position int`, `p_edition text=null`, `p_license_reference text=null` | `books` row |
| `create_unit` | `p_book_id uuid`, `p_title text`, `p_position int` | `units` row |
| `publish_course` | `p_course_id uuid` | `courses` row with status published; requires at least one published lesson |
| `request_submission_revision` | `p_submission_id uuid`, `p_revision int`, `p_reason text` | `revision_requests` row |
| `start_study_session` | `p_lesson_id uuid|null`, `p_idempotency_key uuid` | `study_sessions` row |
| `end_study_session` | `p_session_id uuid`, `p_reviewed_count int` | `study_sessions` row |

Course creation uses a server-generated UUID/slug and the authenticated user; direct client INSERTs into courses/hierarchy remain forbidden. Teacher rows are ensured only after verifying a server role, including administrators. Source policy is an editorial declaration, not proof of a textbook license. Publish lessons with `save_lesson` and patch `status:"published"`; archive with the same RPC and `status:"archived"`. All existing block step labels remain valid; `introduction` is now also accepted. The client owns its six-step presentation mapping.

`submissions.status` is server-controlled. Initial/new revisions are `submitted`; a teacher request sets `revision_requested`; grading sets `graded`. `revision_requests` columns: `id`, `submission_id`, `revision`, nullable `teacher_id`, nullable `reason`, `created_at`, `resolved_at`; same-reason replay for the same submission/revision returns the existing request, conflicting reason fails. A requested revision permits resubmission after the original due date. Submitting a new revision resolves the old request, preserves body/grade history, and resets status to submitted. Grading a revision still awaiting requested changes fails `revision_required`. `submission_status_history` columns: `id`, `submission_id`, `revision`, `status`, nullable `actor_id`, nullable `note`, `created_at`. Both tables are read-only to clients and use the same owner/assigned-teacher RLS as submissions.

`study_sessions` columns: `id`, `user_id`, nullable `lesson_id`, `idempotency_key`, `started_at`, nullable `ended_at`, `reviewed_count`. Timing is server-controlled and capped at four hours. Reviewed count is bounded telemetry, not correctness or completion evidence. Replays cannot alter the recorded lesson/count. RLS permits only the owner to read their sessions.

## Coordinator update: privacy endpoints and FCM

`account-export` POST `{max_rows?:5000}` authenticates the caller and invokes `account_export(p_max_rows int=5000)`. It returns `{schema_version:1,account_id,exported_at,max_rows_per_collection,data,identity}`. Data contains only own profile/roles/settings, learning/session/assignment/billing history, notifications and media metadata. Push exports contain registration timestamps only; audit exports contain action/time only. No private answer keys, receipt/verification payloads, Storage paths/tokens, FCM tokens, OAuth data or server credentials are exported. Collections exceeding the selected limit (1–5000) fail explicitly `account_export_requires_support`; they are not silently truncated.

`account-delete` POST `{confirm:true}` uses the authenticated user ID exclusively. It requests a bounded deletion plan, disables account writes/roles, removes every owned uploaded object, including course/recording uploads, transactionally purges personal platform records, then calls Supabase Auth's server admin hard-delete API. It returns `{deleted:true,account_id,store_subscriptions_cancelled:false,storage_cleanup_pending:true,cleanup_not_before}` only after Auth deletion succeeds. Failed Storage/Auth calls return an error; a pending deletion can be retried. `request_account_deletion(p_confirm boolean)` is owner-only; `purge_account_data(p_user_id uuid)` is service-only and requires a recorded confirmed request. Object cleanup is bounded to 200 owned live objects, in batches of at most 50. A conservative 50,000-row bound on personal histories/teaching references rejects larger accounts for operator processing; previously deleted media older than the upload-token lifetime do not consume the 200-object bound; recent deleted paths are included to cover late uploads. Shared course text, assignment and grade history remain with attribution removed; every uploaded object owned by the departing account is deleted, including course/recording assets. Referenced shared media metadata becomes an unreadable tombstone. Other users' uploaded objects remain. Teaching groups are archived and sessions cancelled until an administrator reassigns them. Own submissions/history/billing/roles/tokens/consents are purged; other students' submissions/grades remain with teacher attribution removed. Auth owns phone/email/session deletion through its admin API. This does not cancel subscriptions at Apple/Google; users must manage store billing separately. Live Auth/Storage deletion still requires deployment validation.

`create_notification(p_student_id uuid,p_group_id uuid,p_kind text,p_body jsonb,p_idempotency_key uuid)` returns a `notifications` row and permits only the assigned teacher/admin to target an active student in that group. Kinds map to stable categories: `lesson`/`new_lesson` → `lesson`; `assignment` → `assignment`; `live`/`live_session` → `live`; `feedback`/`revision_requested`/`grade` → `feedback`; `message`/`teacher_message` → `message`; `review` → `review`. Unknown kinds are rejected. Body is an object of at most 4096 bytes; use `{title:"...",text:"..."}` for push display. Repeated keys/payloads are idempotent; changed recipient/group/kind/body fails. New notification columns: nullable `created_by`, `group_id`, `idempotency_key`. Clients still read only their own received notifications and may update only `read_at`.

`dispatch-notification` POST `{notification_id}` authenticates the sender, checks current teacher/group/recipient scope, respects recipient `notifications_enabled` and category settings before requesting OAuth and again under row locks before reserving dispatch, and uses registered FCM tokens with server OAuth. Require `FCM_SERVICE_ACCOUNT_JSON` (project_id/client_email/private_key), Google Firebase Messaging API/IAM permissions, and destinations `oauth2.googleapis.com`, `fcm.googleapis.com`. Missing credentials fail closed before reserving dispatch. `notification_dispatch_status(p_notification_id uuid)` returns `{notification_id,state,accepted_count,failed_count}` for an authorized sender. States: `not_dispatched`, `reserved`, `accepted`, `failed`. The endpoint returns that summary plus `duplicate`; acceptance means FCM accepted the messages, never confirmed device delivery. A private atomic claim prevents repeat sends; failed/uncertain/crashed reserved dispatches require explicit operator reconciliation rather than automatic duplicate transmission. Fan-out is bounded to 20 registered device tokens. Tokens and OAuth credentials never reach the sender response. Only `service_role` can call `claim_notification_dispatch(p_notification_id,p_actor_id)` and `finish_notification_dispatch(p_notification_id,p_accepted_count,p_failed_count)`.

## Coordinator update: linguistic metadata and provenance

The additive content migration introduces nullable `root`, `part_of_speech`, `gender`, `number`, `forms`, `example_ar`, `example_translation`, and `level` on both `vocabulary` and `grammar`. Text labels are editorial metadata; the actual course/level hierarchy remains normalized separately. `forms` is a JSON object/array and preserves supplied inflection structures. Include these fields in the corresponding `save_lesson.p_content` entries. Existing entries are unchanged until explicitly replaced by an editor. No linguistic forms, page numbers or textbook structure are generated by the backend.

`books.source_locator` and `lessons.source_locator` are nullable JSON objects, bounded to 4096 bytes. `save_lesson.p_patch` now also accepts `source_locator`; JSON null clears it. `set_book_source(p_book_id uuid,p_source_locator jsonb|null)` returns the updated book for an assigned teacher/admin. Locators preserve unknown manifest keys. If supplied, `edition` must be a nonempty string, `page`, `page_start` and `page_end` must be positive integers, end must be >= start, and `pdf_sha256` must be a 64-character hexadecimal string. These are declared locators, not proof that a PDF exists or is licensed; the importer must verify the actual source manifest, edition, checksum and rights. Unknown page provenance stays null. `lesson_blocks.step` accepts `introduction`, `dialogue`, `vocabulary`, `grammar`, `practice`, `test`, `homework`; all previous values remain valid and no existing content is migrated destructively.

## Deletion follow-up for signed upload expiry

Supabase signed upload tokens remain valid for two hours even after the issuing account is deleted. Deletion therefore records a private cleanup job before removing platform records, performs immediate object removal, and reports `storage_cleanup_pending:true` with `cleanup_not_before` (request time + two hours five minutes). The grace period covers in-flight ticket issuance. It does not claim irrevocable physical purge before that final pass. Pending account roles and new upload preparation are disabled; any late upload has no readable media metadata.

Deploy `cleanup-account-media` and trigger it periodically from a trusted scheduler. Require `ACCOUNT_CLEANUP_HMAC_SECRET` (at least 32 characters). POST raw JSON `{max_jobs?:5}` using the same timestamp/event/raw-body HMAC protocol as the billing gateway (`x-event-id`, `x-timestamp`, `x-signature`, freshness ±300 seconds). A user JWT is insufficient. The endpoint calls service-only `claim_account_media_cleanup(p_limit int=5)` and `finish_account_media_cleanup(p_job_id uuid,p_success boolean)`, processes at most five jobs of 200 paths each, and returns `{completed,failed}` counts without identities or paths. Claims lease work atomically; failed operations remain retryable. Successful final cleanup erases the temporary opaque user UUID and stored object paths. The queue has no Auth FK so it survives Auth deletion, is private/RLS-protected, and never appears in exports. Scheduler deployment is required before production deletion can claim completed storage cleanup; this environment has not run a live scheduled pass.

## Invitations, preferences and review security

`create_group_invite(p_group_id uuid)` → `{code,expires_at}`. Code is exactly 32 hexadecimal characters (hyphens omitted), cryptographically random, expires after 24 hours, single-use. Only the group's active assigned teacher or a server administrator may create it. Only a consenting active server student may call `claim_group_invite(p_code text)` → `{group_id,course_id,title}`. Membership does not grant a teacher role, course entitlement, purchase or paid enrollment. An already consumed/expired/invalid code fails; shared raw invite codes are never stored in a table. Invitation metadata is private and RLS protected.

`update_user_preferences(p_patch jsonb)` → full own `user_settings` row. Allowed outer keys: `preferences` object and boolean `notifications_enabled`, `stt_consent`, `recording_consent`. Example: `{preferences:{notification_categories:{lesson:false}}}`. Atomic recursive merge preserves unrelated/unknown preferences and other categories. Stable category IDs: `lesson`, `assignment`, `live`, `feedback`, `message`, `review`. Their respective legacy aliases are `Новые уроки`, `Домашние задания`, `Прямые эфиры`, `Проверка работ`, `Сообщения`, `Повторение слов`. Legacy patches populate the matching stable key, preserving the raw alias; an explicit stable key wins a same-patch conflict. Dispatch uses stable values first, then legacy aliases; absent categories default to enabled. Any nonboolean category value fails closed. Role/account fields cannot be patched. Existing consent flags and the global notification switch remain unless explicitly patched.

Dispatch responses always include `notification_id` on first send, prior replay and concurrent-claim replay. Learner LiveKit grants permit room data for chat/hand-raising while `canPublish` for audio/video remains false. Local author-learning events must carry `payload.account_id` equal to the authenticated account whenever `payload.origin == "local_author_learning"`; wrong/missing account affinity is rejected before any event insertion.


The upload preparation RPC locks the profile `FOR UPDATE` before checking its active state, via `private.require_active_account()`. The deletion RPC takes the same lock before capturing paths. An upload registered first is included in both the immediate deletion plan and the delayed cleanup job; an upload waiting behind confirmed deletion fails `account_unavailable` (`42501`). The cleanup job intentionally retains its bounded locators after database/Auth purge until the required scheduled final pass succeeds.

Validation commands: `scripts/test_backend.sh`, `POSTGRES_IMAGE=postgres:17-alpine scripts/test_backend.sh`, `scripts/test_backend_edge.sh`, and `python3 scripts/test_backend_mutations.py`. Containers use tmpfs, expose no ports, and are removed on exit. Mutation tests use disposable database functions and a temporary Edge copy; they never weaken repository code. Current evidence files: `/tmp/bayna-review-final-sql16.log`, `/tmp/bayna-review-final-sql17.log`, `/tmp/bayna-review-final-edge.log`, `/tmp/bayna-review-mutations.log`.

All eleven deliberate security mutations were detected: five SQL/race mutations (category delivery, event account affinity, invite replay, preference preservation, upload/deletion profile locking) and six Edge mutations (learner data, canceled/grace access, sandbox isolation, first-send ID, cached-replay ID, concurrent-replay ID). Baselines pass before mutation; unrelated startup/type errors are not accepted as a detected regression.
