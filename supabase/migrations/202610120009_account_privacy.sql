begin;
alter table public.groups alter column teacher_id drop not null;
alter table public.assignments alter column created_by drop not null;
alter table public.grades alter column teacher_id drop not null;
alter table public.media drop constraint media_check;
create or replace function public.has_server_role(p_role text) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.server_roles r join public.profiles p on p.id=r.user_id where r.user_id=auth.uid() and r.role=p_role and p.deletion_requested_at is null)
$$;
create function private.require_active_account() returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.profiles where id=auth.uid() and deletion_requested_at is null) then raise exception 'account_unavailable' using errcode='42501';end if;
end $$;
-- A trigger running as the direct caller blocks new FK rows while deletion is pending.
create function private.guard_personal_write() returns trigger language plpgsql set search_path='' as $$
begin
 if current_user in ('authenticated','anon') and exists(select 1 from public.profiles where id=auth.uid() and deletion_requested_at is not null) then raise exception 'account_deletion_pending' using errcode='42501';end if;return new;
end $$;
create trigger guard_settings before insert or update on public.user_settings for each row execute function private.guard_personal_write();
create trigger guard_bookmarks before insert or update on public.bookmarks for each row execute function private.guard_personal_write();
create trigger guard_reviews before insert or update on public.vocabulary_reviews for each row execute function private.guard_personal_write();
create trigger guard_profiles before update on public.profiles for each row execute function private.guard_personal_write();
create function private.export_collection(p_table regclass,p_columns text,p_where text,p_user_id uuid,p_max int) returns jsonb
language plpgsql security definer set search_path='' as $$
declare items jsonb;begin
 execute format('select coalesce(jsonb_agg(to_jsonb(r)),''[]''::jsonb) from (select %s from %s where %s limit %s)r',p_columns,p_table,p_where,p_max+1) into items using p_user_id;
 if jsonb_array_length(items)>p_max then raise exception 'account_export_requires_support' using errcode='55000';end if;return items;
end $$;
create function public.account_export(p_max_rows int default 5000) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();data jsonb:='{}';t text;begin
 if uid is null or not exists(select 1 from public.profiles where id=uid) then raise exception 'authentication_required' using errcode='42501';end if;
 if p_max_rows is null or p_max_rows not between 1 and 5000 then raise exception 'invalid_export_limit';end if;
 foreach t in array array['profiles','teachers','students'] loop data:=data||jsonb_build_object(t,private.export_collection(('public.'||t)::regclass,'*','id=$1',uid,p_max_rows));end loop;
 foreach t in array array['server_roles','user_settings','events','notifications','purchases','subscriptions','entitlements','bookmarks','study_sessions'] loop data:=data||jsonb_build_object(t,private.export_collection(('public.'||t)::regclass,'*','user_id=$1',uid,p_max_rows));end loop;
 foreach t in array array['attempts','enrollments','study_progress','vocabulary_reviews','submissions','group_members'] loop data:=data||jsonb_build_object(t,private.export_collection(('public.'||t)::regclass,'*','student_id=$1',uid,p_max_rows));end loop;
 foreach t in array array['submission_history','grades','revision_requests','submission_status_history'] loop data:=data||jsonb_build_object(t,private.export_collection(('public.'||t)::regclass,'*','submission_id in (select id from public.submissions where student_id=$1)',uid,p_max_rows));end loop;
 data:=data||jsonb_build_object('feedback',private.export_collection('public.feedback','*','grade_id in (select g.id from public.grades g join public.submissions s on s.id=g.submission_id where s.student_id=$1)',uid,p_max_rows));
 data:=data||jsonb_build_object('media',private.export_collection('public.media','*','owner_id=$1',uid,p_max_rows));
 data:=data||jsonb_build_object('session_participants',private.export_collection('public.session_participants','*','user_id=$1',uid,p_max_rows));
 data:=data||jsonb_build_object('push_registrations',private.export_collection('public.push_tokens','created_at','user_id=$1',uid,p_max_rows));
 data:=data||jsonb_build_object('audit',private.export_collection('public.audit_log','id,action,created_at','actor_id=$1',uid,p_max_rows));
 return jsonb_build_object('schema_version',1,'account_id',uid,'exported_at',now(),'max_rows_per_collection',p_max_rows,'data',data);
end $$;
create function private.account_row_count(p_table regclass,p_where text,p_user_id uuid,p_limit int) returns int language plpgsql security definer set search_path='' as $$
declare n int;begin
 execute format('select count(*) from (select 1 from %s where %s limit %s)t',p_table,p_where,p_limit+1) into n using p_user_id;return n;
end $$;
create function public.request_account_deletion(p_confirm boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p public.profiles;objects jsonb;t text;n int:=0;cleanup_at timestamptz;begin
 if p_confirm is distinct from true or auth.uid() is null then raise exception 'deletion_confirmation_required' using errcode='42501';end if;
 select * into p from public.profiles where id=auth.uid() for update;
 if p.id is null then raise exception 'account_unavailable' using errcode='42501';end if;
 select coalesce(jsonb_agg(to_jsonb(o)),'[]') into objects from (
 select mo.bucket_id,mo.object_path from private.media_objects mo join public.media m on m.id=mo.media_id where m.owner_id=p.id and (m.upload_state<>'deleted' or m.created_at>now()-interval '2 hours 5 minutes') limit 201)o;
 if jsonb_array_length(objects)>200 then raise exception 'account_deletion_requires_support' using errcode='55000';end if;
 foreach t in array array['events','notifications','study_sessions','push_tokens','bookmarks','entitlements','purchases','subscriptions'] loop
 n:=n+private.account_row_count(('public.'||t)::regclass,'user_id=$1',p.id,50000-n);
 if n>50000 then raise exception 'account_deletion_requires_support' using errcode='55000';end if;end loop;
 foreach t in array array['attempts','submissions','group_members','study_progress','vocabulary_reviews','enrollments'] loop
 n:=n+private.account_row_count(('public.'||t)::regclass,'student_id=$1',p.id,50000-n);
 if n>50000 then raise exception 'account_deletion_requires_support' using errcode='55000';end if;end loop;
 foreach t in array array['submission_history','grades','revision_requests','submission_status_history'] loop
 n:=n+private.account_row_count(('public.'||t)::regclass,'submission_id in(select id from public.submissions where student_id=$1)',p.id,50000-n);
 if n>50000 then raise exception 'account_deletion_requires_support' using errcode='55000';end if;end loop;
 n:=n+private.account_row_count('public.media','owner_id=$1',p.id,50000-n);
 if n>50000 then raise exception 'account_deletion_requires_support' using errcode='55000';end if;
 n:=n+private.account_row_count('public.groups','teacher_id=$1',p.id,50000-n);
 if n>50000 then raise exception 'account_deletion_requires_support' using errcode='55000';end if;
 n:=n+private.account_row_count('public.assignments','created_by=$1',p.id,50000-n);
 if n>50000 then raise exception 'account_deletion_requires_support' using errcode='55000';end if;
 n:=n+private.account_row_count('public.grades','teacher_id=$1',p.id,50000-n);
 if n>50000 then raise exception 'account_deletion_requires_support' using errcode='55000';end if;
 n:=n+private.account_row_count('public.revision_requests','teacher_id=$1',p.id,50000-n);
 if n>50000 then raise exception 'account_deletion_requires_support' using errcode='55000';end if;
 n:=n+private.account_row_count('public.submission_status_history','actor_id=$1',p.id,50000-n);
 if n>50000 then raise exception 'account_deletion_requires_support' using errcode='55000';end if;
 n:=n+private.account_row_count('public.notifications','created_by=$1',p.id,50000-n);
 if n>50000 then raise exception 'account_deletion_requires_support' using errcode='55000';end if;
 n:=n+private.account_row_count('private.purchase_claims','user_id=$1',p.id,50000-n);
 if n>50000 then raise exception 'account_deletion_requires_support' using errcode='55000';end if;
 n:=n+private.account_row_count('private.integration_requests','user_id=$1',p.id,50000-n);
 if n>50000 then raise exception 'account_deletion_requires_support' using errcode='55000';end if;
 n:=n+private.account_row_count('public.feedback','grade_id in(select id from public.grades where teacher_id=$1 or submission_id in(select id from public.submissions where student_id=$1))',p.id,50000-n);
 if n>50000 then raise exception 'account_deletion_requires_support' using errcode='55000';end if;

 if p.deletion_requested_at is null then update public.profiles set deletion_requested_at=now() where id=p.id;end if;
 insert into private.account_media_cleanup_jobs(user_id,objects,not_before) values(p.id,objects,now()+interval '2 hours 5 minutes') on conflict(user_id) do nothing;
 select j.objects,j.not_before into objects,cleanup_at from private.account_media_cleanup_jobs j where j.user_id=p.id;
 return jsonb_build_object('account_id',p.id,'objects',objects,'cleanup_not_before',cleanup_at,'store_subscriptions_cancelled',false);
end $$;
create function public.purge_account_data(p_user_id uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.profiles where id=p_user_id and deletion_requested_at is not null for update;
 if not found then raise exception 'deletion_confirmation_required' using errcode='42501';end if;
 delete from private.integration_requests where user_id=p_user_id;
 delete from public.study_sessions where user_id=p_user_id;
 delete from public.push_tokens where user_id=p_user_id;
 delete from public.notifications where user_id=p_user_id or created_by=p_user_id;
 delete from public.events where user_id=p_user_id;
 delete from public.bookmarks where user_id=p_user_id;
 delete from public.vocabulary_reviews where student_id=p_user_id;
 delete from public.study_progress where student_id=p_user_id;
 delete from public.enrollments where student_id=p_user_id;
 delete from public.feedback where grade_id in(select id from public.grades where teacher_id=p_user_id or submission_id in(select id from public.submissions where student_id=p_user_id));
 delete from public.grades where submission_id in(select id from public.submissions where student_id=p_user_id);
 update public.grades set teacher_id=null where teacher_id=p_user_id;
 delete from public.revision_requests where submission_id in(select id from public.submissions where student_id=p_user_id);
 update public.revision_requests set teacher_id=null,reason=null where teacher_id=p_user_id;
 delete from public.submission_status_history where submission_id in(select id from public.submissions where student_id=p_user_id);
 update public.submission_status_history set actor_id=null,note=null where actor_id=p_user_id;
 delete from public.submission_history where submission_id in(select id from public.submissions where student_id=p_user_id);
 delete from public.submissions where student_id=p_user_id;
 delete from public.attempts where student_id=p_user_id;
 delete from public.group_members where student_id=p_user_id;
 delete from public.session_participants where user_id=p_user_id;
 update public.live_sessions set cancelled_at=coalesce(cancelled_at,now()) where group_id in(select id from public.groups where teacher_id=p_user_id);
 update public.groups set teacher_id=null,archived_at=coalesce(archived_at,now()) where teacher_id=p_user_id;
 update public.assignments set created_by=null where created_by=p_user_id;
 delete from public.course_teachers where teacher_id=p_user_id;
 delete from private.media_objects where media_id in(select id from public.media where owner_id=p_user_id);
 delete from public.media m where m.owner_id=p_user_id and m.lesson_id is null and not exists(select 1 from public.recordings r where r.media_id=m.id);
 update public.media set owner_id=null,upload_state='deleted',consent_stt=false,consent_recording=false where owner_id=p_user_id;
 delete from public.entitlements where user_id=p_user_id;
 delete from public.subscriptions where user_id=p_user_id;
 delete from private.purchase_claims where user_id=p_user_id;
 delete from private.webhook_events where payload::text like '%'||p_user_id::text||'%';
 delete from public.purchases where user_id=p_user_id;
 delete from public.user_settings where user_id=p_user_id;
 delete from public.server_roles where user_id=p_user_id;
 delete from public.teachers where id=p_user_id;
 delete from public.students where id=p_user_id;
 -- This runs after authorization triggers so their deletion records cannot retain the identity.
 delete from public.audit_log where actor_id=p_user_id or entity_id=p_user_id or details::text like '%'||p_user_id::text||'%';
 update public.profiles set display_name='',locale='ru',consent_at=null where id=p_user_id;
 -- The Edge function next uses Auth's admin DELETE API; true is returned only after that succeeds.
end $$;
create index grades_teacher_idx on public.grades(teacher_id);
create index assignments_creator_idx on public.assignments(created_by);
create index submission_status_actor_idx on public.submission_status_history(actor_id);
create index purchase_claims_user_idx on private.purchase_claims(user_id);
grant execute on function public.account_export(int),public.request_account_deletion(boolean) to authenticated;
grant execute on function public.purge_account_data(uuid) to service_role;
commit;
