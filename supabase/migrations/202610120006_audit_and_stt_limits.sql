begin;
create table private.integration_requests (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles,
 media_id uuid not null references public.media, kind text not null check(kind='stt'),
 reserved_at timestamptz not null default now()
);
alter table private.integration_requests enable row level security;
revoke all on private.integration_requests from anon,authenticated;
grant all on private.integration_requests to service_role;
create index integration_requests_rate_idx on private.integration_requests(user_id,kind,reserved_at);
create function public.reserve_stt_request(p_media_id uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare request_id uuid; begin
 perform public.media_access(p_media_id,true);
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':stt',0));
 if (select count(*) from private.integration_requests where user_id=auth.uid() and kind='stt' and reserved_at>now()-interval '10 minutes')>=5 then raise exception 'stt_rate_limit' using errcode='54000'; end if;
 insert into private.integration_requests(user_id,media_id,kind) values(auth.uid(),p_media_id,'stt') returning id into request_id;return request_id;
end $$;
grant execute on function public.reserve_stt_request(uuid) to authenticated;
create function private.audit_authorization_change() returns trigger language plpgsql security definer set search_path='' as $$
declare before_row jsonb; after_row jsonb; entity uuid; begin
 if tg_op<>'INSERT' then before_row:=to_jsonb(old);end if;
 if tg_op<>'DELETE' then after_row:=to_jsonb(new);end if;
 entity:=coalesce((coalesce(after_row,before_row)->>'user_id')::uuid,(coalesce(after_row,before_row)->>'student_id')::uuid,(coalesce(after_row,before_row)->>'teacher_id')::uuid);
 insert into public.audit_log(actor_id,action,entity_id,details) values(auth.uid(),tg_table_name||'_'||lower(tg_op),entity,jsonb_build_object('old',before_row,'new',after_row));
 return coalesce(new,old);
end $$;
create trigger audit_server_roles after insert or update or delete on public.server_roles for each row execute function private.audit_authorization_change();
create trigger audit_course_teachers after insert or update or delete on public.course_teachers for each row execute function private.audit_authorization_change();
create trigger audit_group_members after insert or update or delete on public.group_members for each row execute function private.audit_authorization_change();
create trigger audit_entitlements after insert or update or delete on public.entitlements for each row execute function private.audit_authorization_change();
commit;
-- This guard also closes pre-existing broad authenticated storage policies for our buckets.
begin;
create policy academy_private_bucket_guard on storage.objects as restrictive for all to anon,authenticated
using(bucket_id not in ('course-media','student-media','session-recordings'))
with check(bucket_id not in ('course-media','student-media','session-recordings'));
commit;
