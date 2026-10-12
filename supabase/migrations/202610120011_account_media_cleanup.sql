begin;
create table private.account_media_cleanup_jobs (
 id uuid primary key default gen_random_uuid(), user_id uuid unique,
 objects jsonb not null check(jsonb_typeof(objects)='array' and jsonb_array_length(objects)<=200),
 requested_at timestamptz not null default now(), not_before timestamptz not null,
 lease_expires_at timestamptz, completed_at timestamptz, attempt_count int not null default 0
);
alter table private.account_media_cleanup_jobs enable row level security;
revoke all on private.account_media_cleanup_jobs from anon,authenticated;
grant all on private.account_media_cleanup_jobs to service_role;
create index account_cleanup_due_idx on private.account_media_cleanup_jobs(not_before) where completed_at is null;
create function public.claim_account_media_cleanup(p_limit int default 5) returns jsonb
language plpgsql security definer set search_path='' as $$
declare jobs jsonb;begin
 if p_limit is null or p_limit not between 1 and 5 then raise exception 'invalid_cleanup_limit';end if;
 with due as (select id from private.account_media_cleanup_jobs where completed_at is null and not_before<=now() and (lease_expires_at is null or lease_expires_at<=now()) order by not_before for update skip locked limit p_limit),
 claimed as (update private.account_media_cleanup_jobs j set lease_expires_at=now()+interval '5 minutes',attempt_count=attempt_count+1 from due where j.id=due.id returning j.id,j.objects)
 select coalesce(jsonb_agg(jsonb_build_object('job_id',id,'objects',objects)),'[]') into jobs from claimed;return jobs;
end $$;
create function public.finish_account_media_cleanup(p_job_id uuid,p_success boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
 if p_success is null then raise exception 'invalid_cleanup_result';end if;
 if p_success then
 update private.account_media_cleanup_jobs set user_id=null,objects='[]',completed_at=now(),lease_expires_at=null where id=p_job_id and completed_at is null;
 else update private.account_media_cleanup_jobs set lease_expires_at=now()+interval '10 minutes' where id=p_job_id and completed_at is null;end if;
end $$;
grant execute on function public.claim_account_media_cleanup(int),public.finish_account_media_cleanup(uuid,boolean) to service_role;
commit;
