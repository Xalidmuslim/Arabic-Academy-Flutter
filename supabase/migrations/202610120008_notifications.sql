begin;
alter table public.notifications add column created_by uuid references public.profiles on delete set null;
alter table public.notifications add column group_id uuid references public.groups;
alter table public.notifications add column idempotency_key uuid;
create unique index notifications_delivery_key_idx on public.notifications(created_by,idempotency_key);
create function public.create_notification(p_student_id uuid,p_group_id uuid,p_kind text,p_body jsonb,p_idempotency_key uuid) returns public.notifications
language plpgsql security definer set search_path='' as $$
declare n public.notifications;begin
 if not public.manages_group(p_group_id) or not exists(select 1 from public.group_members m join public.profiles p on p.id=m.student_id where m.group_id=p_group_id and m.student_id=p_student_id and m.left_at is null and p.deletion_requested_at is null) then raise exception 'teacher_assignment_required' using errcode='42501';end if;
 if p_kind is null or p_kind not in ('assignment','revision_requested','live_session','teacher_message') or p_body is null or jsonb_typeof(p_body)<>'object' or pg_column_size(p_body)>4096 or p_idempotency_key is null then raise exception 'invalid_notification';end if;
 insert into public.notifications(user_id,created_by,group_id,idempotency_key,kind,body) values(p_student_id,auth.uid(),p_group_id,p_idempotency_key,p_kind,p_body) on conflict(created_by,idempotency_key) do nothing returning * into n;
 if n.id is null then
 select * into n from public.notifications where created_by=auth.uid() and idempotency_key=p_idempotency_key;
 if n.user_id<>p_student_id or n.group_id<>p_group_id or n.kind<>p_kind or n.body<>p_body then raise exception 'idempotency_conflict' using errcode='23505';end if;end if;return n;
end $$;
create table private.notification_dispatches (
 notification_id uuid primary key references public.notifications on delete cascade,
 state text not null check(state in ('reserved','accepted','failed')), token_count int not null,
 accepted_count int not null default 0, failed_count int not null default 0,
 reserved_at timestamptz not null default now(), completed_at timestamptz
);
alter table private.notification_dispatches enable row level security;
revoke all on private.notification_dispatches from anon,authenticated;
grant all on private.notification_dispatches to service_role;
create function private.can_dispatch_notification(p_notification_id uuid,p_actor_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.notifications n join public.profiles p on p.id=p_actor_id where n.id=p_notification_id and p.deletion_requested_at is null and
 (exists(select 1 from public.server_roles where user_id=p_actor_id and role='admin') or
 (n.created_by=p_actor_id and exists(select 1 from public.server_roles where user_id=p_actor_id and role='teacher') and exists(select 1 from public.groups g join public.course_teachers ct on ct.course_id=g.course_id and ct.teacher_id=p_actor_id where g.id=n.group_id and g.teacher_id=p_actor_id and g.archived_at is null))) and
 (n.group_id is null or exists(select 1 from public.group_members where group_id=n.group_id and student_id=n.user_id and left_at is null)))
$$;
create function public.notification_dispatch_status(p_notification_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare d private.notification_dispatches;begin
 if not private.can_dispatch_notification(p_notification_id,auth.uid()) then raise exception 'notification_denied' using errcode='42501';end if;
 select * into d from private.notification_dispatches where notification_id=p_notification_id;
 return jsonb_build_object('notification_id',p_notification_id,'state',coalesce(d.state,'not_dispatched'),'accepted_count',coalesce(d.accepted_count,0),'failed_count',coalesce(d.failed_count,0));
end $$;
create function public.claim_notification_dispatch(p_notification_id uuid,p_actor_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare n public.notifications;d private.notification_dispatches;tokens jsonb;begin
 if not private.can_dispatch_notification(p_notification_id,p_actor_id) then raise exception 'notification_denied' using errcode='42501';end if;
 select * into n from public.notifications where id=p_notification_id;
 if not exists(select 1 from public.user_settings s join public.profiles p on p.id=s.user_id where s.user_id=n.user_id and s.notifications_enabled and p.deletion_requested_at is null) then raise exception 'notifications_disabled' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended('notify:'||n.id::text,0));
 select * into d from private.notification_dispatches where notification_id=n.id;
 if d.notification_id is not null then return jsonb_build_object('duplicate',true,'state',d.state,'accepted_count',d.accepted_count,'failed_count',d.failed_count);end if;
 select coalesce(jsonb_agg(token),'[]') into tokens from (select token from public.push_tokens where user_id=n.user_id limit 21)t;
 if jsonb_array_length(tokens)=0 then raise exception 'push_token_unavailable' using errcode='55000';end if;
 if jsonb_array_length(tokens)>20 then raise exception 'too_many_push_tokens' using errcode='55000';end if;
 insert into private.notification_dispatches(notification_id,state,token_count) values(n.id,'reserved',jsonb_array_length(tokens));
 return jsonb_build_object('duplicate',false,'notification_id',n.id,'kind',n.kind,'body',n.body,'tokens',tokens);
end $$;
create function public.finish_notification_dispatch(p_notification_id uuid,p_accepted_count int,p_failed_count int) returns jsonb
language plpgsql security definer set search_path='' as $$
declare d private.notification_dispatches;begin
 select * into d from private.notification_dispatches where notification_id=p_notification_id for update;
 if d.notification_id is null or p_accepted_count is null or p_failed_count is null or p_accepted_count<0 or p_failed_count<0 or p_accepted_count+p_failed_count<>d.token_count then raise exception 'invalid_dispatch_result';end if;
 if d.state<>'reserved' then
 if d.accepted_count<>p_accepted_count or d.failed_count<>p_failed_count then raise exception 'idempotency_conflict' using errcode='23505';end if;
 else update private.notification_dispatches set state=case when p_failed_count=0 then 'accepted' else 'failed' end,accepted_count=p_accepted_count,failed_count=p_failed_count,completed_at=now() where notification_id=p_notification_id returning * into d;end if;
 return jsonb_build_object('state',d.state,'accepted_count',d.accepted_count,'failed_count',d.failed_count);
end $$;
grant execute on function public.create_notification(uuid,uuid,text,jsonb,uuid),public.notification_dispatch_status(uuid) to authenticated;
grant execute on function public.claim_notification_dispatch(uuid,uuid),public.finish_notification_dispatch(uuid,int,int) to service_role;
commit;
