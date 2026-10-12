begin;
alter table public.profiles add column consent_at timestamptz;
alter table public.vocabulary add column retired_at timestamptz;
alter table public.vocabulary drop constraint vocabulary_lesson_id_position_key;
create unique index vocabulary_active_position_idx on public.vocabulary(lesson_id,position) where retired_at is null;
alter policy content_read on public.vocabulary using(public.can_read_lesson(lesson_id) and (retired_at is null or public.teaches_course(public.lesson_course_id(lesson_id))));
alter table public.media add column upload_state text not null default 'ready' check(upload_state in ('pending','ready','deleted'));
create function public.save_profile(p_display_name text,p_consent boolean) returns public.profiles
language plpgsql security definer set search_path='' as $$
declare p public.profiles; begin
 perform private.require_active_account();
 if auth.uid() is null or p_consent is distinct from true then raise exception 'consent_required' using errcode='42501'; end if;
 if p_display_name is null or length(btrim(p_display_name))=0 or length(p_display_name)>120 then raise exception 'invalid_display_name'; end if;
 update public.profiles set display_name=btrim(p_display_name),consent_at=coalesce(consent_at,now()) where id=auth.uid() returning * into p;
 return p;
end $$;
create or replace function public.can_read_media(p_media uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.media m join public.profiles actor on actor.id=auth.uid() where actor.deletion_requested_at is null and m.id=p_media and m.upload_state='ready' and
 case when exists(select 1 from public.recordings r where r.media_id=m.id) then
 exists(select 1 from public.recordings r where r.media_id=m.id and r.available_at<=now() and public.can_join_session(r.session_id))
 else ((m.lesson_id is null and m.owner_id=auth.uid()) or (m.lesson_id is not null and public.can_read_lesson(m.lesson_id))) end)
$$;
create function private.can_manage_media(p_media_id uuid,p_actor_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.media m where m.id=p_media_id and
 ((m.lesson_id is null and m.owner_id=p_actor_id) or (m.lesson_id is not null and
 (exists(select 1 from public.server_roles where user_id=p_actor_id and role='admin') or
 (exists(select 1 from public.server_roles where user_id=p_actor_id and role='teacher') and exists(select 1 from public.course_teachers where course_id=public.lesson_course_id(m.lesson_id) and teacher_id=p_actor_id))))))
$$;
create function public.prepare_media_upload(p_lesson_id uuid,p_mime_type text,p_byte_size bigint,p_consent_stt boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare mid uuid:=gen_random_uuid(); bucket text; k text; ext text; begin
 perform private.require_active_account();
 if p_lesson_id is not null and not public.teaches_course(public.lesson_course_id(p_lesson_id)) then raise exception 'teacher_required' using errcode='42501'; end if;
 if p_byte_size is null or p_byte_size<=0 or p_byte_size>(case when p_lesson_id is null then 25000000 else 104857600 end) then raise exception 'invalid_media_size'; end if;
 case p_mime_type
 when 'image/png' then k:='image';ext:='png';when 'image/jpeg' then k:='image';ext:='jpg';when 'image/webp' then k:='image';ext:='webp';
 when 'audio/mpeg' then k:='audio';ext:='mp3';when 'audio/mp4' then k:='audio';ext:='m4a';when 'audio/wav' then k:='audio';ext:='wav';when 'audio/webm' then k:='audio';ext:='webm';when 'audio/ogg' then k:='audio';ext:='ogg';
 when 'video/mp4' then k:='video';ext:='mp4';when 'application/pdf' then k:='document';ext:='pdf';else raise exception 'unsupported_media_type';end case;
 if p_lesson_id is null and k<>'audio' then raise exception 'student_audio_only' using errcode='42501'; end if;
 if coalesce(p_consent_stt,false) and (p_lesson_id is not null or not exists(select 1 from public.user_settings where user_id=auth.uid() and stt_consent)) then raise exception 'stt_consent_required' using errcode='42501'; end if;
 bucket:=case when p_lesson_id is null then 'student-media' else 'course-media' end;
 insert into public.media(id,lesson_id,owner_id,kind,mime_type,byte_size,consent_stt,upload_state) values(mid,p_lesson_id,auth.uid(),k,p_mime_type,p_byte_size,coalesce(p_consent_stt,false),'pending');
 insert into private.media_objects(media_id,bucket_id,object_path) values(mid,bucket,auth.uid()::text||'/'||mid::text||'.'||ext);
 return public.media_upload_access(mid);
end $$;
create function public.media_upload_access(p_media_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare m public.media; o private.media_objects; begin
 if not private.can_manage_media(p_media_id,auth.uid()) then raise exception 'media_denied' using errcode='42501'; end if;
 select * into m from public.media where id=p_media_id;
 select * into o from private.media_objects where media_id=p_media_id;
 return jsonb_build_object('media_id',m.id,'bucket_id',o.bucket_id,'object_path',o.object_path,'mime_type',m.mime_type,'byte_size',m.byte_size,'upload_state',m.upload_state);
end $$;
create function public.finalize_media_upload(p_media_id uuid,p_actor_id uuid) returns public.media
language plpgsql security definer set search_path='' as $$
declare m public.media; obj private.media_objects; observed jsonb; begin
 if not private.can_manage_media(p_media_id,p_actor_id) then raise exception 'media_denied' using errcode='42501'; end if;
 select * into m from public.media where id=p_media_id for update;
 if m.upload_state='deleted' then raise exception 'media_deleted'; end if;
 select * into obj from private.media_objects where media_id=m.id;
 select metadata into observed from storage.objects where bucket_id=obj.bucket_id and name=obj.object_path;
 if observed is null then raise exception 'upload_not_found' using errcode='55000'; end if;
 if (observed->>'size')::bigint is distinct from m.byte_size or observed->>'mimetype' is distinct from m.mime_type then raise exception 'upload_metadata_mismatch' using errcode='42501'; end if;
 update public.media set upload_state='ready' where id=m.id returning * into m;return m;
end $$;
create function public.mark_media_deleted(p_media_id uuid,p_actor_id uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 if not private.can_manage_media(p_media_id,p_actor_id) then raise exception 'media_denied' using errcode='42501'; end if;
 update public.media set upload_state='deleted',consent_stt=false where id=p_media_id;
 insert into public.audit_log(actor_id,action,entity_id) values(p_actor_id,'media_deleted',p_media_id);
end $$;
-- Consent can be withdrawn on an individual owned recording independently of global settings.
create function public.set_media_stt_consent(p_media_id uuid,p_consent boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.media where id=p_media_id and lesson_id is null and owner_id=auth.uid() and upload_state='ready') then raise exception 'media_denied' using errcode='42501'; end if;
 if p_consent is null then raise exception 'invalid_consent'; end if;
 update public.media set consent_stt=p_consent where id=p_media_id;
end $$;
create table public.push_tokens (
 user_id uuid not null references public.profiles, token text not null unique check(length(token) between 16 and 2048),
 created_at timestamptz not null default now(), primary key(user_id,token)
);
alter table public.push_tokens enable row level security;
revoke all on public.push_tokens from anon,authenticated;
grant all on public.push_tokens to service_role;
create policy push_own on public.push_tokens for select to authenticated using(user_id=auth.uid());
grant select on public.push_tokens to authenticated;
create function public.register_push_token(p_token text) returns void language plpgsql security definer set search_path='' as $$
begin
 perform private.require_active_account();
 insert into public.push_tokens(user_id,token) values(auth.uid(),p_token) on conflict(token) do nothing;
 if not exists(select 1 from public.push_tokens where token=p_token and user_id=auth.uid()) then raise exception 'push_token_already_bound' using errcode='42501'; end if;
end $$;
create function public.unregister_push_token(p_token text) returns void language sql security definer set search_path='' as $$
 delete from public.push_tokens where user_id=auth.uid() and token=p_token
$$;
grant execute on function public.save_profile(text,boolean),public.prepare_media_upload(uuid,text,bigint,boolean),public.media_upload_access(uuid),public.set_media_stt_consent(uuid,boolean),public.register_push_token(text),public.unregister_push_token(text) to authenticated;
grant execute on function public.finalize_media_upload(uuid,uuid),public.mark_media_deleted(uuid,uuid) to service_role;
update storage.buckets set allowed_mime_types=array['image/png','image/jpeg','image/webp','audio/mpeg','audio/mp4','audio/wav','audio/webm','audio/ogg','video/mp4','application/pdf'] where id='course-media';
-- Supporting indexes for ownership, parent lookups and RLS predicates.
create index groups_teacher_idx on public.groups(teacher_id,course_id);
create index group_members_student_idx on public.group_members(student_id,group_id) where left_at is null;
create index course_teachers_teacher_idx on public.course_teachers(teacher_id,course_id);
create index lessons_unit_idx on public.lessons(unit_id,status);
create index exercises_lesson_idx on public.exercises(lesson_id,published);
create index attempts_exercise_student_idx on public.attempts(exercise_id,student_id,exercise_version) where passed;
create index assignments_group_idx on public.assignments(group_id);
create index submissions_student_idx on public.submissions(student_id,assignment_id);
create index media_lesson_idx on public.media(lesson_id);
create index media_owner_idx on public.media(owner_id);
create index dialogues_lesson_idx on public.dialogues(lesson_id);
create index live_sessions_group_idx on public.live_sessions(group_id,ends_at);
create index purchases_user_idx on public.purchases(user_id);
create index subscriptions_user_idx on public.subscriptions(user_id);
create index notifications_user_idx on public.notifications(user_id,created_at desc);
create index progress_lesson_idx on public.study_progress(lesson_id);
commit;
