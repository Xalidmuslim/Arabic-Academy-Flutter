begin;
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
create extension if not exists pgcrypto;

create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null default '' check(length(display_name)<=120),
 locale text not null default 'ru' check(locale in ('ru','ar','en')),
 created_at timestamptz not null default now(), deletion_requested_at timestamptz
);
create table public.server_roles (
 user_id uuid references public.profiles on delete cascade,
 role text check(role in ('admin','teacher','student')),
 primary key(user_id,role)
);
create table public.teachers (id uuid primary key references public.profiles, bio text not null default '');
create table public.students (id uuid primary key references public.profiles, joined_at timestamptz not null default now());
create table public.courses (
 id uuid primary key default gen_random_uuid(), slug text not null unique, title text not null,
 description text not null default '', access_tier text not null default 'paid' check(access_tier in ('free','paid')),
 status text not null default 'draft' check(status in ('draft','published','archived')),
 source_policy text not null, created_at timestamptz not null default now()
);
create table public.course_teachers (
 course_id uuid references public.courses on delete cascade, teacher_id uuid references public.teachers,
 primary key(course_id,teacher_id)
);
create table public.groups (
 id uuid primary key default gen_random_uuid(), course_id uuid not null references public.courses,
 teacher_id uuid not null references public.teachers, title text not null, archived_at timestamptz
);
create table public.group_members (
 group_id uuid references public.groups on delete cascade, student_id uuid references public.students,
 joined_at timestamptz not null default now(), left_at timestamptz, primary key(group_id,student_id)
);
create table public.levels (
 id uuid primary key default gen_random_uuid(), course_id uuid not null references public.courses on delete cascade,
 title text not null, position int not null check(position>=0), unique(course_id,position)
);
create table public.books (
 id uuid primary key default gen_random_uuid(), level_id uuid not null references public.levels on delete cascade,
 title text not null, edition text, license_reference text, position int not null check(position>=0), unique(level_id,position)
);
create table public.units (
 id uuid primary key default gen_random_uuid(), book_id uuid not null references public.books on delete cascade,
 legacy_id text, title text not null, position int not null check(position>=0), unique(book_id,position)
);
create table public.lessons (
 id uuid primary key default gen_random_uuid(), unit_id uuid not null references public.units on delete cascade,
 legacy_id text, title text not null, title_ar text, goal text not null default '',
 status text not null default 'draft' check(status in ('draft','published','archived')),
 is_free_sample boolean not null default false, position int not null check(position>=0),
 version int not null default 1 check(version>0), updated_at timestamptz not null default now(), unique(unit_id,position)
);
create table public.lesson_blocks (
 id uuid primary key default gen_random_uuid(), lesson_id uuid not null references public.lessons on delete cascade,
 step text not null check(step in ('dialogue','vocabulary','grammar','practice','test','homework')),
 kind text not null check(kind in ('text','heading','image','audio','video','exercise')),
 body jsonb not null default '{}' check(jsonb_typeof(body)='object'), position int not null check(position>=0), unique(lesson_id,step,position)
);
create table public.dialogues (
 id uuid primary key default gen_random_uuid(), lesson_id uuid not null references public.lessons on delete cascade, title text not null default ''
);
create table public.dialogue_lines (
 id uuid primary key default gen_random_uuid(), dialogue_id uuid not null references public.dialogues on delete cascade,
 speaker text not null default '', text_ar text not null, translation text not null default '', position int not null check(position>=0), unique(dialogue_id,position)
);
create table public.vocabulary (
 id uuid primary key default gen_random_uuid(), lesson_id uuid not null references public.lessons on delete cascade,
 text_ar text not null, translation text not null, transliteration text, position int not null check(position>=0), unique(lesson_id,position)
);
create table public.grammar (
 id uuid primary key default gen_random_uuid(), lesson_id uuid not null references public.lessons on delete cascade,
 title text not null, explanation text not null, examples jsonb not null default '[]', position int not null check(position>=0), unique(lesson_id,position)
);
-- Paths live in a non-exposed schema; media metadata contains no reusable public URL.
create table public.media (
 id uuid primary key default gen_random_uuid(), lesson_id uuid references public.lessons on delete cascade,
 owner_id uuid references public.profiles, kind text not null check(kind in ('image','audio','video','document')),
 mime_type text not null, byte_size bigint not null check(byte_size>=0),
 consent_stt boolean not null default false, consent_recording boolean not null default false,
 created_at timestamptz not null default now(), check(lesson_id is not null or owner_id is not null)
);
create table private.media_objects (
 media_id uuid primary key references public.media on delete cascade,
 bucket_id text not null check(bucket_id in ('course-media','student-media','session-recordings')),
 object_path text not null, unique(bucket_id,object_path)
);
create table public.exercises (
 id uuid primary key default gen_random_uuid(), lesson_id uuid not null references public.lessons on delete cascade,
 kind text not null, title text not null, grading_mode text not null check(grading_mode in ('automatic','manual')),
 pass_percent numeric not null default 100 check(pass_percent>0 and pass_percent<=100),
 version int not null default 1 check(version>0), published boolean not null default false
);
create table public.questions (
 id uuid primary key default gen_random_uuid(), exercise_id uuid not null references public.exercises on delete cascade,
 prompt jsonb not null check(jsonb_typeof(prompt)='object'), position int not null check(position>=0),
 points numeric not null default 1 check(points>0 and points<=1000), unique(exercise_id,position)
);
create table public.question_options (
 id uuid primary key default gen_random_uuid(), question_id uuid not null references public.questions on delete cascade,
 label text not null, position int not null check(position>=0), unique(question_id,position)
);
create table private.answer_keys (
 question_id uuid primary key references public.questions on delete cascade,
 accepted_answers jsonb not null check(jsonb_typeof(accepted_answers)='array' and jsonb_array_length(accepted_answers)>0),
 comparison text not null default 'exact' check(comparison in ('exact','text_trim'))
);
create table public.attempts (
 id uuid primary key default gen_random_uuid(), student_id uuid not null references public.students,
 exercise_id uuid not null references public.exercises, exercise_version int not null,
 idempotency_key uuid not null, answers jsonb not null check(jsonb_typeof(answers)='object'),
 status text not null check(status in ('graded','pending_review')), score numeric, max_score numeric,
 passed boolean not null default false, created_at timestamptz not null default now(), unique(student_id,idempotency_key)
);
create table public.assignments (
 id uuid primary key default gen_random_uuid(), group_id uuid not null references public.groups,
 exercise_id uuid not null references public.exercises, title text not null,
 due_at timestamptz, created_by uuid not null references public.teachers, created_at timestamptz not null default now()
);
create table public.submissions (
 id uuid primary key default gen_random_uuid(), assignment_id uuid not null references public.assignments,
 student_id uuid not null references public.students, revision int not null default 1,
 body jsonb not null, updated_at timestamptz not null default now(), unique(assignment_id,student_id)
);
create table public.submission_history (
 id uuid primary key default gen_random_uuid(), submission_id uuid not null references public.submissions,
 revision int not null, body jsonb not null, idempotency_key uuid not null,
 created_at timestamptz not null default now(), unique(submission_id,revision), unique(submission_id,idempotency_key)
);
create table public.grades (
 id uuid primary key default gen_random_uuid(), submission_id uuid not null references public.submissions,
 revision int not null, teacher_id uuid not null references public.teachers,
 score numeric not null check(score>=0 and score<=100), created_at timestamptz not null default now(),
 unique(submission_id,revision), foreign key(submission_id,revision) references public.submission_history(submission_id,revision)
);
create table public.feedback (
 id uuid primary key default gen_random_uuid(), grade_id uuid not null references public.grades,
 body text not null check(length(body)<=10000), created_at timestamptz not null default now()
);
create table public.enrollments (
 student_id uuid references public.students, course_id uuid references public.courses,
 enrolled_at timestamptz not null default now(), primary key(student_id,course_id)
);
create table public.products (
 id uuid primary key default gen_random_uuid(), provider text not null check(provider in ('apple','google')),
 external_id text not null, kind text not null check(kind in ('course','subscription')),
 active boolean not null default false, unique(provider,external_id)
);
create table public.product_courses (
 product_id uuid references public.products on delete cascade, course_id uuid references public.courses, primary key(product_id,course_id)
);
create table public.purchases (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles,
 product_id uuid not null references public.products, provider text not null check(provider in ('apple','google')),
 transaction_id text not null, status text not null check(status in ('verified','revoked')),
 purchased_at timestamptz not null, verified_at timestamptz not null default now(), unique(provider,transaction_id)
);
create table public.subscriptions (
 id uuid primary key default gen_random_uuid(), purchase_id uuid not null unique references public.purchases,
 user_id uuid not null references public.profiles, expires_at timestamptz not null, revoked_at timestamptz
);
create table public.entitlements (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles,
 course_id uuid not null references public.courses, purchase_id uuid references public.purchases,
 starts_at timestamptz not null default now(), expires_at timestamptz, revoked_at timestamptz,
 unique(user_id,course_id,purchase_id), check(expires_at is null or expires_at>starts_at)
);
create index entitlements_access_idx on public.entitlements(user_id,course_id) where revoked_at is null;
create table private.purchase_claims (
 provider text not null, transaction_id text not null, user_id uuid not null references public.profiles,
 account_binding text not null, verified_payload jsonb not null, primary key(provider,transaction_id)
);
create table private.webhook_events (
 provider text not null, event_id text not null, payload jsonb not null,
 received_at timestamptz not null default now(), primary key(provider,event_id)
);
create table public.live_sessions (
 id uuid primary key default gen_random_uuid(), group_id uuid not null references public.groups,
 title text not null, room_name text not null unique, starts_at timestamptz not null, ends_at timestamptz not null,
 cancelled_at timestamptz, recording_enabled boolean not null default false, check(ends_at>starts_at)
);
create table public.session_participants (
 session_id uuid references public.live_sessions, user_id uuid references public.profiles,
 joined_at timestamptz not null default now(), recording_consent boolean not null default false, primary key(session_id,user_id)
);
create table public.recordings (
 id uuid primary key default gen_random_uuid(), session_id uuid not null references public.live_sessions,
 media_id uuid not null unique references public.media, available_at timestamptz not null default now()
);
create table public.notifications (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles,
 kind text not null, body jsonb not null, read_at timestamptz, created_at timestamptz not null default now()
);
create table public.events (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles,
 idempotency_key uuid not null, kind text not null check(kind in ('lesson_opened','draft_saved','study_reviewed','settings_changed')),
 payload jsonb not null check(jsonb_typeof(payload)='object'), received_at timestamptz not null default now(), unique(user_id,idempotency_key)
);
create table public.study_progress (
 student_id uuid references public.students, lesson_id uuid references public.lessons,
 completed_at timestamptz not null, primary key(student_id,lesson_id)
);
create table public.vocabulary_reviews (
 student_id uuid references public.students, vocabulary_id uuid references public.vocabulary,
 rating int not null check(rating between 0 and 5), reviewed_at timestamptz not null default now(), next_review_at timestamptz,
 primary key(student_id,vocabulary_id)
);
create table public.bookmarks (
 user_id uuid references public.profiles, lesson_id uuid references public.lessons,
 created_at timestamptz not null default now(), primary key(user_id,lesson_id)
);
create table public.user_settings (
 user_id uuid primary key references public.profiles, notifications_enabled boolean not null default true,
 stt_consent boolean not null default false, recording_consent boolean not null default false,
 preferences jsonb not null default '{}' check(jsonb_typeof(preferences)='object')
);
create table public.audit_log (
 id bigint generated always as identity primary key, actor_id uuid references public.profiles,
 action text not null, entity_id uuid, details jsonb not null default '{}', created_at timestamptz not null default now()
);
-- Every application table has RLS, including private tables. No client privileges by default.
do $$ declare r record; begin
 for r in select schemaname,tablename from pg_tables where schemaname in ('public','private') loop
 execute format('alter table %I.%I enable row level security',r.schemaname,r.tablename);
 execute format('revoke all on %I.%I from anon, authenticated',r.schemaname,r.tablename);
 end loop;
end $$;
revoke all on all functions in schema public from public;
revoke all on all functions in schema private from public;
alter default privileges revoke execute on functions from public;
alter default privileges in schema public revoke execute on functions from public;
alter default privileges in schema private revoke execute on functions from public;
grant usage on schema public to anon,authenticated,service_role;
grant usage on schema private to service_role;
grant all on all tables in schema public,private to service_role;
grant usage,select on all sequences in schema public to service_role;
commit;
