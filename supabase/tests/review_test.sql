begin;
create temp table review_failures(label text,message text);
create function pg_temp.review_case(label text,statement text) returns void language plpgsql as $$declare ok boolean;begin
 begin execute statement into ok;if ok is distinct from true then raise exception 'behavior assertion false';end if;
 exception when others then insert into review_failures values(label,sqlstate||': '||sqlerrm);end;end$$;
create function pg_temp.rejected(statement text,expected text) returns boolean language plpgsql as $$begin begin execute statement;exception when others then return sqlstate=expected;end;return false;end$$;
grant execute on function pg_temp.review_case(text,text),pg_temp.rejected(text,text) to authenticated,service_role;
grant select,insert on review_failures to authenticated,service_role;
create temp table review_ids(key text primary key,id uuid);
grant select,insert on review_ids to authenticated,service_role;
insert into auth.users(id) values('60000000-0000-0000-0000-000000000001'),('60000000-0000-0000-0000-000000000002'),('60000000-0000-0000-0000-000000000003'),('60000000-0000-0000-0000-000000000004'),('60000000-0000-0000-0000-000000000005');
insert into public.server_roles values('60000000-0000-0000-0000-000000000001','teacher'),('60000000-0000-0000-0000-000000000003','teacher');
update public.profiles set consent_at=now() where id in ('60000000-0000-0000-0000-000000000002','60000000-0000-0000-0000-000000000004');
set local request.jwt.claim.sub='60000000-0000-0000-0000-000000000001';set local role authenticated;
insert into review_ids select 'course',(public.create_course('Paid review fixture','paid')).id;
insert into review_ids select 'group',(public.create_group((select id from review_ids where key='course'),'Review group')).id;
reset role;
update public.courses set status='published';
insert into public.group_members(group_id,student_id) select id,'60000000-0000-0000-0000-000000000002' from review_ids where key='group';
insert into public.push_tokens(user_id,token) values('60000000-0000-0000-0000-000000000002','review-private-push-token');
update public.user_settings set stt_consent=true,recording_consent=true,preferences='{"unknown":{"keep":7},"notification_categories":{"Новые уроки":false,"lesson":false,"assignment":false,"live":false,"feedback":false,"message":false,"review":false,"future":false}}' where user_id='60000000-0000-0000-0000-000000000002';
-- Insert realistic known kinds through the server fixture, so mappings can be tested independently of the new UI factory.
insert into public.notifications(id,user_id,created_by,group_id,kind,body) select ('60000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'60000000-0000-0000-0000-000000000002','60000000-0000-0000-0000-000000000001',(select id from review_ids where key='group'),kind,'{}' from (values(101,'lesson'),(102,'assignment'),(103,'live_session'),(104,'revision_requested'),(105,'teacher_message'),(106,'review'))k(n,kind);
set local request.jwt.claim.sub='60000000-0000-0000-0000-000000000001';set local role authenticated;
-- Sender has no received rows: use fixture UUIDs, not sender table visibility.
select pg_temp.review_case('category status denies before OAuth '||n,format('select pg_temp.rejected(%L,''42501'')',format('select public.notification_dispatch_status(%L)',('60000000-0000-0000-0000-'||lpad(n::text,12,'0'))))) from generate_series(101,106)n;
reset role;set local request.jwt.claim.sub='';set local role service_role;
select pg_temp.review_case('category disabled cannot reserve '||n,format('select pg_temp.rejected(%L,''42501'')',format('select public.claim_notification_dispatch(%L,''60000000-0000-0000-0000-000000000001'')',('60000000-0000-0000-0000-'||lpad(n::text,12,'0'))))) from generate_series(101,106)n;
select pg_temp.review_case('no off-category reservations','select count(*)=0 from private.notification_dispatches');
reset role;set local request.jwt.claim.sub='60000000-0000-0000-0000-000000000002';set local role authenticated;
select pg_temp.review_case('atomic preferences merge preserves other values', $q$select (public.update_user_preferences('{"preferences":{"notification_categories":{"assignment":true},"unknown":{"extra":9}}}')).preferences @> '{"unknown":{"keep":7,"extra":9},"notification_categories":{"lesson":false,"assignment":true,"future":false}}'$q$);
select pg_temp.review_case('preferences does not reset consent',$q$select stt_consent and recording_consent and notifications_enabled from public.user_settings where user_id=auth.uid()$q$);
select pg_temp.review_case('account_id patch forbidden',$q$select pg_temp.rejected('select public.update_user_preferences(''{"user_id":"60000000-0000-0000-0000-000000000001"}'')','42501')$q$);
select pg_temp.review_case('legacy alias merge preserves canonical category',$q$select (public.update_user_preferences('{"preferences":{"notification_categories":{"Новые уроки":true}}}')).preferences @> '{"notification_categories":{"lesson":true,"Новые уроки":true,"assignment":true}}'$q$);
select pg_temp.review_case('malformed boolean cannot reset settings',$q$select pg_temp.rejected('select public.update_user_preferences(''{"notifications_enabled":null}'')','P0001')$q$);
select pg_temp.review_case('category nonboolean fails closed',$q$select pg_temp.rejected('select public.update_user_preferences(''{"preferences":{"notification_categories":{"lesson":"yes"}}}'')','P0001')$q$);
select pg_temp.review_case('new nested preference object retained',$q$select (public.update_user_preferences('{"preferences":{"new_object":{"keep":[1,2]}}}')).preferences @> '{"new_object":{"keep":[1,2]}}'$q$);
select pg_temp.review_case('old namespace event cannot bind current account',$q$select pg_temp.rejected('select public.record_event(gen_random_uuid(),''draft_saved'',''{"origin":"local_author_learning","account_id":"60000000-0000-0000-0000-000000000001"}'')','42501')$q$);
select pg_temp.review_case('missing account affinity rejected',$q$select pg_temp.rejected('select public.record_event(gen_random_uuid(),''draft_saved'',''{"origin":"local_author_learning"}'')','42501')$q$);
select pg_temp.review_case('matching affinity accepted',$q$select (public.record_event(gen_random_uuid(),'draft_saved','{"origin":"local_author_learning","account_id":"60000000-0000-0000-0000-000000000002"}')).user_id=auth.uid()$q$);
select pg_temp.review_case('generic event stays compatible',$q$select (public.record_event(gen_random_uuid(),'study_reviewed','{"unknown":true}')).user_id=auth.uid()$q$);
reset role;
select pg_temp.review_case('failed-affinity events never insert',$q$select count(*)=0 from public.events where payload->>'origin'='local_author_learning' and payload->>'account_id' is distinct from user_id::text$q$);
-- Each invite case runs in a subtransaction, so the missing API is a behavior failure in the red run.
create function pg_temp.invite_flow_inner(mode text) returns boolean language plpgsql as $$declare token jsonb;gid uuid;joined jsonb;begin
 perform set_config('request.jwt.claim.sub','60000000-0000-0000-0000-000000000001',true);
 select id into gid from review_ids where key='group';token:=public.create_group_invite(gid);
 if token->>'code' !~ '^[a-f0-9]{32}$' or (token->>'expires_at')::timestamptz<=now() then return false;end if;
 if mode='expired' then update private.group_invites set expires_at=now()-interval '1 second' where group_id=gid;end if;
 if mode='archived' then update public.groups set archived_at=now() where id=gid;end if;
 if mode='scope_revoked' then delete from public.course_teachers where course_id=(select id from review_ids where key='course');end if;
 perform set_config('request.jwt.claim.sub',case when mode='no_consent' then '60000000-0000-0000-0000-000000000005' else '60000000-0000-0000-0000-000000000004' end,true);
 if mode in ('expired','scope_revoked','no_consent','archived') then
 return pg_temp.rejected(format('select public.claim_group_invite(%L)',token->>'code'),'42501');end if;
 joined:=public.claim_group_invite(upper(token->>'code'));
 if (joined->>'group_id')::uuid<>gid or public.can_access_course((joined->>'course_id')::uuid) then return false;end if;
 if exists(select 1 from public.entitlements where user_id=auth.uid()) or exists(select 1 from public.enrollments where student_id=auth.uid()) or public.has_server_role('teacher') then return false;end if;
 if not pg_temp.rejected(format('select public.claim_group_invite(%L)',token->>'code'),'42501') then return false;end if;
 -- Account deletion must not revive the used code. The normal purge removes restrictive FKs.
 perform public.request_account_deletion(true);perform public.purge_account_data(auth.uid());
 delete from auth.users where id=auth.uid();
 perform set_config('request.jwt.claim.sub','60000000-0000-0000-0000-000000000002',true);
 return pg_temp.rejected(format('select public.claim_group_invite(%L)',token->>'code'),'42501');
end$$;
create function pg_temp.invite_flow(mode text) returns boolean language plpgsql as $$declare outcome boolean;begin
 begin outcome:=pg_temp.invite_flow_inner(mode);raise exception 'fixture rollback' using errcode='ZX001';
 exception when sqlstate 'ZX001' then null;end;return outcome;end$$;
select pg_temp.review_case('invite claim single use and no paid unlock','select pg_temp.invite_flow(''normal'')');
select pg_temp.review_case('invite expired rejected','select pg_temp.invite_flow(''expired'')');
select pg_temp.review_case('invite revoked scope rejected','select pg_temp.invite_flow(''scope_revoked'')');
select pg_temp.review_case('invite archived group rejected','select pg_temp.invite_flow(''archived'')');
select pg_temp.review_case('invite consent required','select pg_temp.invite_flow(''no_consent'')');
set local request.jwt.claim.sub='60000000-0000-0000-0000-000000000003';set local role authenticated;
select pg_temp.review_case('wrong teacher cannot invite',$q$select pg_temp.rejected('select public.create_group_invite((select id from review_ids where key=''group''))','42501')$q$);
select pg_temp.review_case('invalid invite code rejected',$q$select pg_temp.rejected('select public.claim_group_invite(''ffffffffffffffffffffffffffffffff'')','42501')$q$);
select pg_temp.review_case('invite hashes not client readable',$q$select pg_temp.rejected('select * from private.group_invites','42501')$q$);
reset role;
select * from review_failures;
do $$begin if exists(select 1 from review_failures) then raise exception 'review regressions: % failures',(select count(*) from review_failures);end if;end$$;
rollback;
