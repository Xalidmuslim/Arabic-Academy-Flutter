begin;
create table private.group_invites (
 id uuid primary key default gen_random_uuid(), group_id uuid not null references public.groups on delete cascade,
 created_by uuid references public.profiles on delete set null, code_hash bytea not null unique check(octet_length(code_hash)=32),
 expires_at timestamptz not null, claimed_by uuid references public.profiles on delete set null,
 claimed_at timestamptz, created_at timestamptz not null default now()
);
alter table private.group_invites enable row level security;
revoke all on private.group_invites from public,anon,authenticated;
grant all on private.group_invites to service_role;
create index group_invites_group_idx on private.group_invites(group_id);
create function private.invite_issuer_authorized(p_group uuid,p_issuer uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.groups g join public.profiles p on p.id=p_issuer
 where g.id=p_group and g.archived_at is null and p.deletion_requested_at is null and
 (exists(select 1 from public.server_roles where user_id=p_issuer and role='admin') or
 (g.teacher_id=p_issuer and exists(select 1 from public.server_roles where user_id=p_issuer and role='teacher')
 and exists(select 1 from public.course_teachers where course_id=g.course_id and teacher_id=p_issuer))))
$$;
create function public.create_group_invite(p_group_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare code text;expiry timestamptz:=now()+interval '24 hours';begin
 perform private.require_active_account();
 perform 1 from public.groups where id=p_group_id and archived_at is null for share;
 if not found or not private.invite_issuer_authorized(p_group_id,auth.uid()) then raise exception 'group_invite_denied' using errcode='42501';end if;
 code:=replace(gen_random_uuid()::text,'-','');
 insert into private.group_invites(group_id,created_by,code_hash,expires_at) values(p_group_id,auth.uid(),sha256(convert_to(code,'UTF8')),expiry);
 return jsonb_build_object('code',code,'expires_at',expiry);
end $$;
create function public.claim_group_invite(p_code text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare code text:=lower(btrim(p_code));i private.group_invites;g public.groups;begin
 perform private.require_active_account();
 if not public.has_server_role('student') or not exists(select 1 from public.profiles where id=auth.uid() and consent_at is not null) then raise exception 'student_consent_required' using errcode='42501';end if;
 if code is null or code !~ '^[a-f0-9]{32}$' then raise exception 'group_invite_denied' using errcode='42501';end if;
 select * into i from private.group_invites where code_hash=sha256(convert_to(code,'UTF8')) for update;
 if not found or i.claimed_at is not null or i.expires_at<=clock_timestamp() then raise exception 'group_invite_denied' using errcode='42501';end if;
 select * into g from public.groups where id=i.group_id for share;
 if not found or not private.invite_issuer_authorized(g.id,i.created_by) then raise exception 'group_invite_denied' using errcode='42501';end if;
 update private.group_invites set claimed_by=auth.uid(),claimed_at=now() where id=i.id;
 insert into public.group_members(group_id,student_id) values(g.id,auth.uid()) on conflict(group_id,student_id) do update set left_at=null,joined_at=now();
 -- Membership grants neither a role, enrollment nor a paid-content entitlement.
 return jsonb_build_object('group_id',g.id,'course_id',g.course_id,'title',g.title);
end $$;
grant execute on function public.create_group_invite(uuid),public.claim_group_invite(text) to authenticated;
commit;
