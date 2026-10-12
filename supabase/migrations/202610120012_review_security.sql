begin;
-- Held through the enclosing RPC transaction. Deletion uses this same profile lock.
-- In particular, prepare_media_upload cannot register a path after deletion's snapshot.
create or replace function private.require_active_account() returns void
language plpgsql security definer set search_path='' as $$
declare deleting timestamptz;begin
 select deletion_requested_at into deleting from public.profiles where id=auth.uid() for update;
 if not found or deleting is not null then raise exception 'account_unavailable' using errcode='42501';end if;
end $$;
create or replace function public.record_event(p_idempotency_key uuid,p_kind text,p_payload jsonb) returns public.events
language plpgsql security definer set search_path='' as $$
declare r public.events;begin
 perform private.require_active_account();
 if p_payload->>'origin'='local_author_learning' and p_payload->>'account_id' is distinct from auth.uid()::text then
 raise exception 'event_account_mismatch' using errcode='42501';end if;
 if pg_column_size(p_payload)>65536 then raise exception 'payload_too_large';end if;
 insert into public.events(user_id,idempotency_key,kind,payload) values(auth.uid(),p_idempotency_key,p_kind,p_payload) on conflict(user_id,idempotency_key) do nothing returning * into r;
 if r.id is null then
 select * into r from public.events where user_id=auth.uid() and idempotency_key=p_idempotency_key;
 if r.kind<>p_kind or r.payload<>p_payload then raise exception 'idempotency_conflict' using errcode='23505';end if;end if;return r;
end $$;
create function private.merge_preferences(p_base jsonb,p_patch jsonb,p_depth int default 0) returns jsonb
language plpgsql immutable set search_path='' as $$
declare result jsonb:=p_base;k text;v jsonb;begin
 if p_depth>16 then raise exception 'preferences_too_deep';end if;
 if result is null or jsonb_typeof(result)<>'object' then result:='{}';end if;
 for k,v in select * from jsonb_each(p_patch) loop
 if jsonb_typeof(v)='object' then v:=private.merge_preferences(result->k,v,p_depth+1);end if;
 result:=jsonb_set(result,array[k],v,true);end loop;return result;
end $$;
create function private.notification_category(p_kind text) returns text language sql immutable set search_path='' as $$
 select case p_kind when 'lesson' then 'lesson' when 'new_lesson' then 'lesson'
 when 'assignment' then 'assignment' when 'live' then 'live' when 'live_session' then 'live'
 when 'feedback' then 'feedback' when 'revision_requested' then 'feedback' when 'grade' then 'feedback'
 when 'message' then 'message' when 'teacher_message' then 'message' when 'review' then 'review' end
$$;
create function private.notification_category_alias(p_category text) returns text language sql immutable set search_path='' as $$
 select case p_category when 'lesson' then 'Новые уроки' when 'assignment' then 'Домашние задания'
 when 'live' then 'Прямые эфиры' when 'feedback' then 'Проверка работ' when 'message' then 'Сообщения'
 when 'review' then 'Повторение слов' end
$$;
create function public.update_user_preferences(p_patch jsonb) returns public.user_settings
language plpgsql security definer set search_path='' as $$
declare s public.user_settings;patch jsonb;categories jsonb;k text;alias text;begin
 perform private.require_active_account();
 if p_patch is null or jsonb_typeof(p_patch)<>'object' or pg_column_size(p_patch)>65536 then raise exception 'invalid_preferences';end if;
 if exists(select 1 from jsonb_object_keys(p_patch) fields(key) where fields.key not in ('preferences','notifications_enabled','stt_consent','recording_consent')) then raise exception 'preferences_field_denied' using errcode='42501';end if;
 foreach k in array array['notifications_enabled','stt_consent','recording_consent'] loop
 if p_patch ? k and jsonb_typeof(p_patch->k)<>'boolean' then raise exception 'invalid_preferences';end if;end loop;
 patch:=coalesce(p_patch->'preferences','{}');
 if jsonb_typeof(patch)<>'object' then raise exception 'invalid_preferences';end if;
 if patch ? 'notification_categories' then
 categories:=patch->'notification_categories';
 if jsonb_typeof(categories)<>'object' then raise exception 'invalid_notification_categories';end if;
 if exists(select 1 from jsonb_each(categories) c where jsonb_typeof(c.value)<>'boolean') then raise exception 'invalid_notification_categories';end if;
 foreach k in array array['lesson','assignment','live','feedback','message','review'] loop
 alias:=private.notification_category_alias(k);
 if not categories ? k and categories ? alias then categories:=categories||jsonb_build_object(k,categories->alias);end if;
 end loop;patch:=jsonb_set(patch,'{notification_categories}',categories);
 end if;
 select * into s from public.user_settings where user_id=auth.uid() for update;
 if not found then raise exception 'settings_unavailable' using errcode='42501';end if;
 patch:=private.merge_preferences(s.preferences,patch);
 if pg_column_size(patch)>65536 then raise exception 'preferences_too_large';end if;
 update public.user_settings set preferences=patch,
 notifications_enabled=coalesce((p_patch->>'notifications_enabled')::boolean,s.notifications_enabled),
 stt_consent=coalesce((p_patch->>'stt_consent')::boolean,s.stt_consent),
 recording_consent=coalesce((p_patch->>'recording_consent')::boolean,s.recording_consent)
 where user_id=auth.uid() returning * into s;return s;
end $$;
-- Lock recipient and preference rows before any reservation. Category checks also run
-- in the authenticated preflight RPC, before the Edge function requests FCM OAuth.
create function private.require_notification_delivery(p_notification_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare n public.notifications;s public.user_settings;category text;enabled jsonb;deleting timestamptz;begin
 select * into n from public.notifications where id=p_notification_id;
 select deletion_requested_at into deleting from public.profiles where id=n.user_id for share;
 if not found or deleting is not null then raise exception 'notifications_disabled' using errcode='42501';end if;
 select * into s from public.user_settings where user_id=n.user_id for share;
 if not found or not s.notifications_enabled then raise exception 'notifications_disabled' using errcode='42501';end if;
 category:=private.notification_category(n.kind);
 enabled:=coalesce(s.preferences->'notification_categories'->category,s.preferences->'notification_categories'->private.notification_category_alias(category),'true'::jsonb);
 if category is null or enabled is distinct from 'true'::jsonb then raise exception 'notification_category_disabled' using errcode='42501';end if;
end $$;
create or replace function public.notification_dispatch_status(p_notification_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare d private.notification_dispatches;begin
 if not private.can_dispatch_notification(p_notification_id,auth.uid()) then raise exception 'notification_denied' using errcode='42501';end if;
 perform private.require_notification_delivery(p_notification_id);
 select * into d from private.notification_dispatches where notification_id=p_notification_id;
 return jsonb_build_object('notification_id',p_notification_id,'state',coalesce(d.state,'not_dispatched'),'accepted_count',coalesce(d.accepted_count,0),'failed_count',coalesce(d.failed_count,0));
end $$;
create or replace function public.claim_notification_dispatch(p_notification_id uuid,p_actor_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare n public.notifications;d private.notification_dispatches;tokens jsonb;begin
 if not private.can_dispatch_notification(p_notification_id,p_actor_id) then raise exception 'notification_denied' using errcode='42501';end if;
 perform private.require_notification_delivery(p_notification_id);
 select * into n from public.notifications where id=p_notification_id;
 perform pg_advisory_xact_lock(hashtextextended('notify:'||n.id::text,0));
 select * into d from private.notification_dispatches where notification_id=n.id;
 if d.notification_id is not null then return jsonb_build_object('notification_id',n.id,'duplicate',true,'state',d.state,'accepted_count',d.accepted_count,'failed_count',d.failed_count);end if;
 select coalesce(jsonb_agg(token),'[]') into tokens from (select token from public.push_tokens where user_id=n.user_id limit 21)t;
 if jsonb_array_length(tokens)=0 then raise exception 'push_token_unavailable' using errcode='55000';end if;
 if jsonb_array_length(tokens)>20 then raise exception 'too_many_push_tokens' using errcode='55000';end if;
 insert into private.notification_dispatches(notification_id,state,token_count) values(n.id,'reserved',jsonb_array_length(tokens));
 return jsonb_build_object('duplicate',false,'notification_id',n.id,'kind',n.kind,'body',n.body,'tokens',tokens);
end $$;
create or replace function public.finish_notification_dispatch(p_notification_id uuid,p_accepted_count int,p_failed_count int) returns jsonb
language plpgsql security definer set search_path='' as $$
declare d private.notification_dispatches;begin
 select * into d from private.notification_dispatches where notification_id=p_notification_id for update;
 if d.notification_id is null or p_accepted_count is null or p_failed_count is null or p_accepted_count<0 or p_failed_count<0 or p_accepted_count+p_failed_count<>d.token_count then raise exception 'invalid_dispatch_result';end if;
 if d.state<>'reserved' then
 if d.accepted_count<>p_accepted_count or d.failed_count<>p_failed_count then raise exception 'idempotency_conflict' using errcode='23505';end if;
 else update private.notification_dispatches set state=case when p_failed_count=0 then 'accepted' else 'failed' end,accepted_count=p_accepted_count,failed_count=p_failed_count,completed_at=now() where notification_id=p_notification_id returning * into d;end if;
 return jsonb_build_object('notification_id',p_notification_id,'state',d.state,'accepted_count',d.accepted_count,'failed_count',d.failed_count);
end $$;
create or replace function public.create_notification(p_student_id uuid,p_group_id uuid,p_kind text,p_body jsonb,p_idempotency_key uuid) returns public.notifications
language plpgsql security definer set search_path='' as $$
declare n public.notifications;begin
 perform private.require_active_account();
 if not public.manages_group(p_group_id) or not exists(select 1 from public.group_members m join public.profiles p on p.id=m.student_id where m.group_id=p_group_id and m.student_id=p_student_id and m.left_at is null and p.deletion_requested_at is null) then raise exception 'teacher_assignment_required' using errcode='42501';end if;
 if private.notification_category(p_kind) is null or p_body is null or jsonb_typeof(p_body)<>'object' or pg_column_size(p_body)>4096 or p_idempotency_key is null then raise exception 'invalid_notification';end if;
 insert into public.notifications(user_id,created_by,group_id,idempotency_key,kind,body) values(p_student_id,auth.uid(),p_group_id,p_idempotency_key,p_kind,p_body) on conflict(created_by,idempotency_key) do nothing returning * into n;
 if n.id is null then
 select * into n from public.notifications where created_by=auth.uid() and idempotency_key=p_idempotency_key;
 if n.user_id<>p_student_id or n.group_id<>p_group_id or n.kind<>p_kind or n.body<>p_body then raise exception 'idempotency_conflict' using errcode='23505';end if;end if;return n;
end $$;
grant execute on function public.update_user_preferences(jsonb) to authenticated;
commit;
