begin;
alter table public.courses add column created_by uuid references public.profiles on delete set null;
create function public.create_course(p_title text,p_access_tier text default 'free',p_source_policy text default 'original_editorial') returns public.courses
language plpgsql security definer set search_path='' as $$
declare c public.courses; cid uuid:=gen_random_uuid();begin
 if not(public.has_server_role('teacher') or public.has_server_role('admin')) then raise exception 'teacher_required' using errcode='42501';end if;
 if p_title is null or length(btrim(p_title)) not between 1 and 200 or p_access_tier not in ('free','paid') or p_source_policy is null then raise exception 'invalid_course';end if;
 insert into public.teachers(id) values(auth.uid()) on conflict do nothing;
 insert into public.courses(id,slug,title,access_tier,source_policy,created_by) values(cid,'course_'||cid::text,btrim(p_title),p_access_tier,p_source_policy,auth.uid()) returning * into c;
 insert into public.course_teachers(course_id,teacher_id) values(cid,auth.uid());
 insert into public.audit_log(actor_id,action,entity_id) values(auth.uid(),'course_created',cid);return c;
end $$;
create function public.create_level(p_course_id uuid,p_title text,p_position int) returns public.levels
language plpgsql security definer set search_path='' as $$
declare r public.levels;begin
 if not public.teaches_course(p_course_id) then raise exception 'teacher_required' using errcode='42501';end if;
 if p_title is null or length(btrim(p_title)) not between 1 and 200 then raise exception 'invalid_title';end if;
 insert into public.levels(course_id,title,position) values(p_course_id,btrim(p_title),p_position) returning * into r;return r;
end $$;
create function public.create_book(p_level_id uuid,p_title text,p_position int,p_edition text default null,p_license_reference text default null) returns public.books
language plpgsql security definer set search_path='' as $$
declare r public.books;cid uuid;begin
 select course_id into cid from public.levels where id=p_level_id;
 if cid is null or not public.teaches_course(cid) then raise exception 'teacher_required' using errcode='42501';end if;
 if p_title is null or length(btrim(p_title)) not between 1 and 200 then raise exception 'invalid_title';end if;
 insert into public.books(level_id,title,position,edition,license_reference) values(p_level_id,btrim(p_title),p_position,p_edition,p_license_reference) returning * into r;return r;
end $$;
create function public.create_unit(p_book_id uuid,p_title text,p_position int) returns public.units
language plpgsql security definer set search_path='' as $$
declare r public.units;cid uuid;begin
 select l.course_id into cid from public.books b join public.levels l on l.id=b.level_id where b.id=p_book_id;
 if cid is null or not public.teaches_course(cid) then raise exception 'teacher_required' using errcode='42501';end if;
 if p_title is null or length(btrim(p_title)) not between 1 and 200 then raise exception 'invalid_title';end if;
 insert into public.units(book_id,title,position) values(p_book_id,btrim(p_title),p_position) returning * into r;return r;
end $$;
create function public.publish_course(p_course_id uuid) returns public.courses
language plpgsql security definer set search_path='' as $$
declare r public.courses;begin
 if not public.teaches_course(p_course_id) then raise exception 'teacher_required' using errcode='42501';end if;
 if not exists(select 1 from public.lessons where public.lesson_course_id(id)=p_course_id and status='published') then raise exception 'published_lesson_required' using errcode='55000';end if;
 update public.courses set status='published' where id=p_course_id returning * into r;
 insert into public.audit_log(actor_id,action,entity_id) values(auth.uid(),'course_published',p_course_id);return r;
end $$;
alter table public.submissions add column status text not null default 'submitted' check(status in ('submitted','revision_requested','graded'));
update public.submissions s set status='graded' where exists(select 1 from public.grades g where g.submission_id=s.id and g.revision=s.revision);
create table public.revision_requests (
 id uuid primary key default gen_random_uuid(), submission_id uuid not null references public.submissions,
 revision int not null, teacher_id uuid references public.teachers on delete set null,
 reason text check(length(reason) between 1 and 10000), created_at timestamptz not null default now(), resolved_at timestamptz,
 unique(submission_id,revision), foreign key(submission_id,revision) references public.submission_history(submission_id,revision)
);
create table public.submission_status_history (
 id uuid primary key default gen_random_uuid(), submission_id uuid not null references public.submissions,
 revision int not null, status text not null check(status in ('submitted','revision_requested','graded')),
 actor_id uuid references public.profiles on delete set null, note text, created_at timestamptz not null default now(),
 foreign key(submission_id,revision) references public.submission_history(submission_id,revision)
);
create function public.request_submission_revision(p_submission_id uuid,p_revision int,p_reason text) returns public.revision_requests
language plpgsql security definer set search_path='' as $$
declare s public.submissions;r public.revision_requests;begin
 select * into s from public.submissions where id=p_submission_id for update;
 if s.id is null or not exists(select 1 from public.assignments a where a.id=s.assignment_id and public.manages_group(a.group_id)) then raise exception 'teacher_assignment_required' using errcode='42501';end if;
 if s.revision is distinct from p_revision then raise exception 'revision_conflict' using errcode='40001';end if;
 if p_reason is null or length(btrim(p_reason)) not between 1 and 10000 then raise exception 'invalid_revision_reason';end if;
 select * into r from public.revision_requests where submission_id=s.id and revision=p_revision;
 if r.id is not null then
 if r.reason is distinct from p_reason then raise exception 'revision_request_conflict' using errcode='23505';end if;return r;end if;
 insert into public.teachers(id) values(auth.uid()) on conflict do nothing;
 insert into public.revision_requests(submission_id,revision,teacher_id,reason) values(s.id,p_revision,auth.uid(),p_reason) returning * into r;
 update public.submissions set status='revision_requested',updated_at=now() where id=s.id;
 insert into public.submission_status_history(submission_id,revision,status,actor_id,note) values(s.id,p_revision,'revision_requested',auth.uid(),p_reason);
 insert into public.audit_log(actor_id,action,entity_id,details) values(auth.uid(),'revision_requested',s.id,jsonb_build_object('revision',p_revision));return r;
end $$;
create table public.study_sessions (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles,
 lesson_id uuid references public.lessons, idempotency_key uuid not null,
 started_at timestamptz not null default now(), ended_at timestamptz, reviewed_count int not null default 0 check(reviewed_count between 0 and 10000),
 unique(user_id,idempotency_key), check(ended_at is null or ended_at>=started_at)
);
create function public.start_study_session(p_lesson_id uuid,p_idempotency_key uuid) returns public.study_sessions
language plpgsql security definer set search_path='' as $$
declare r public.study_sessions;begin
 if not public.has_server_role('student') or (p_lesson_id is not null and not public.can_read_lesson(p_lesson_id)) then raise exception 'study_session_denied' using errcode='42501';end if;
 insert into public.study_sessions(user_id,lesson_id,idempotency_key) values(auth.uid(),p_lesson_id,p_idempotency_key) on conflict(user_id,idempotency_key) do nothing returning * into r;
 if r.id is null then
 select * into r from public.study_sessions where user_id=auth.uid() and idempotency_key=p_idempotency_key;
 if r.lesson_id is distinct from p_lesson_id then raise exception 'idempotency_conflict' using errcode='23505';end if;end if;return r;
end $$;
create function public.end_study_session(p_session_id uuid,p_reviewed_count int) returns public.study_sessions
language plpgsql security definer set search_path='' as $$
declare r public.study_sessions;begin
 if not public.has_server_role('student') then raise exception 'study_session_denied' using errcode='42501';end if;
 select * into r from public.study_sessions where id=p_session_id and user_id=auth.uid() for update;
 if r.id is null then raise exception 'study_session_denied' using errcode='42501';end if;
 if r.ended_at is not null then if r.reviewed_count is distinct from p_reviewed_count then raise exception 'idempotency_conflict' using errcode='23505';end if;return r;end if;
 update public.study_sessions set ended_at=least(now(),started_at+interval '4 hours'),reviewed_count=p_reviewed_count where id=r.id returning * into r;return r;
end $$;
do $$declare t text;begin
 foreach t in array array['revision_requests','submission_status_history','study_sessions'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from anon,authenticated',t);
 execute format('grant select on public.%I to authenticated',t);
 execute format('grant all on public.%I to service_role',t);
 end loop;
end $$;
create policy revisions_read on public.revision_requests for select to authenticated using(public.can_read_submission(submission_id));
create policy submission_status_read on public.submission_status_history for select to authenticated using(public.can_read_submission(submission_id));
create policy study_session_read on public.study_sessions for select to authenticated using(user_id=auth.uid());
create index revision_requests_submission_idx on public.revision_requests(submission_id);
create index submission_status_submission_idx on public.submission_status_history(submission_id,created_at);
grant execute on function public.create_course(text,text,text),public.create_level(uuid,text,int),public.create_book(uuid,text,int,text,text),public.create_unit(uuid,text,int),public.publish_course(uuid),public.request_submission_revision(uuid,int,text),public.start_study_session(uuid,uuid),public.end_study_session(uuid,int) to authenticated;
commit;
