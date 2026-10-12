begin;
create function public.live_session_access(p_session_id uuid,p_recording_consent boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s public.live_sessions; can_publish boolean; settings public.user_settings; begin
 select * into s from public.live_sessions where id=p_session_id;
 if s.id is null or not public.can_join_session(s.id) or now()<s.starts_at-interval '15 minutes' or now()>=s.ends_at then raise exception 'session_denied' using errcode='42501'; end if;
 select * into settings from public.user_settings where user_id=auth.uid();
 if s.recording_enabled and (not p_recording_consent or not coalesce(settings.recording_consent,false)) then raise exception 'recording_consent_required' using errcode='42501'; end if;
 can_publish:=public.manages_group(s.group_id);
 insert into public.session_participants(session_id,user_id,recording_consent) values(s.id,auth.uid(),p_recording_consent)
 on conflict(session_id,user_id) do update set recording_consent=excluded.recording_consent;
 return jsonb_build_object('session_id',s.id,'room_name',s.room_name,'user_id',auth.uid(),'can_publish',can_publish,'expires_at',least(s.ends_at,now()+interval '5 minutes'));
end $$;
create function public.create_live_session(p_group_id uuid,p_title text,p_starts_at timestamptz,p_ends_at timestamptz,p_recording_enabled boolean default false) returns public.live_sessions
language plpgsql security definer set search_path='' as $$
declare s public.live_sessions; session_id uuid:=gen_random_uuid(); begin
 if not public.manages_group(p_group_id) then raise exception 'teacher_assignment_required' using errcode='42501'; end if;
 insert into public.live_sessions(id,group_id,title,room_name,starts_at,ends_at,recording_enabled) values(session_id,p_group_id,p_title,'academy_'||session_id::text,p_starts_at,p_ends_at,p_recording_enabled) returning * into s; return s;
end $$;
create function public.media_access(p_media_id uuid,p_for_stt boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare m public.media; o private.media_objects; ttl int:=60; remaining numeric; begin
 select * into m from public.media where id=p_media_id;
 if m.id is null or not public.can_read_media(m.id) then raise exception 'media_denied' using errcode='42501'; end if;
 if p_for_stt and (m.owner_id is distinct from auth.uid() or not m.consent_stt or m.kind<>'audio' or m.byte_size>25000000 or not exists(select 1 from public.user_settings where user_id=auth.uid() and stt_consent)) then raise exception 'stt_consent_required' using errcode='42501'; end if;
 select * into o from private.media_objects where media_id=m.id;
 if o.media_id is null then raise exception 'media_unconfigured' using errcode='55000'; end if;
 if m.lesson_id is not null and not public.teaches_course(public.lesson_course_id(m.lesson_id)) and not exists(select 1 from public.lessons l join public.courses c on c.id=public.lesson_course_id(l.id) where l.id=m.lesson_id and (l.is_free_sample or c.access_tier='free')) then
 select max(extract(epoch from (coalesce(e.expires_at,now()+interval '60 seconds')-now()))) into remaining from public.entitlements e where e.user_id=auth.uid() and e.course_id=public.lesson_course_id(m.lesson_id) and e.revoked_at is null and e.starts_at<=now() and (e.expires_at is null or e.expires_at>now());
 ttl:=greatest(1,least(60,floor(coalesce(remaining,0))::int));
 end if;
 return jsonb_build_object('media_id',m.id,'bucket_id',o.bucket_id,'object_path',o.object_path,'mime_type',m.mime_type,'byte_size',m.byte_size,'expires_in',ttl);
end $$;
-- Only a server verifier may call this; values originate in verified store responses.
create function public.apply_verified_purchase(p_user_id uuid,p_provider text,p_transaction_id text,p_product_external_id text,p_account_binding text,p_purchased_at timestamptz,p_expires_at timestamptz,p_payload jsonb) returns public.purchases
language plpgsql security definer set search_path='' as $$
declare prod public.products; pur public.purchases; claim private.purchase_claims; c record; expiry timestamptz;
begin
 if not exists(select 1 from public.profiles where id=p_user_id and deletion_requested_at is null) then raise exception 'account_unavailable' using errcode='42501';end if;
 if p_user_id is null or p_account_binding is distinct from p_user_id::text or p_transaction_id is null or length(p_transaction_id)=0 then raise exception 'purchase_claim_mismatch' using errcode='42501'; end if;
 if p_purchased_at is null or p_purchased_at>now()+interval '5 minutes' then raise exception 'invalid_purchase_time'; end if;
 select * into prod from public.products where provider=p_provider and external_id=p_product_external_id and active;
 if prod.id is null or not exists(select 1 from public.product_courses where product_id=prod.id) then raise exception 'unknown_product' using errcode='42501'; end if;
 if prod.kind='subscription' and (p_expires_at is null or p_expires_at<=now()) then raise exception 'subscription_inactive' using errcode='42501'; end if;
 if prod.kind='course' and p_expires_at is not null then raise exception 'product_kind_mismatch'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_provider||p_transaction_id,0));
 select * into claim from private.purchase_claims where provider=p_provider and transaction_id=p_transaction_id;
 if claim.user_id is not null and (claim.user_id<>p_user_id or claim.account_binding<>p_account_binding) then raise exception 'purchase_already_claimed' using errcode='42501'; end if;
 select * into pur from public.purchases where provider=p_provider and transaction_id=p_transaction_id;
 if pur.id is not null and (pur.user_id<>p_user_id or pur.product_id<>prod.id) then raise exception 'purchase_claim_mismatch' using errcode='42501'; end if;
 if pur.status='revoked' then raise exception 'purchase_revoked' using errcode='42501'; end if;
 insert into private.purchase_claims(provider,transaction_id,user_id,account_binding,verified_payload) values(p_provider,p_transaction_id,p_user_id,p_account_binding,p_payload)
 on conflict(provider,transaction_id) do update set verified_payload=excluded.verified_payload;
 if pur.id is null then
 insert into public.purchases(user_id,product_id,provider,transaction_id,status,purchased_at) values(p_user_id,prod.id,p_provider,p_transaction_id,'verified',p_purchased_at) returning * into pur;
 insert into public.audit_log(actor_id,action,entity_id,details) values(p_user_id,'purchase_verified',pur.id,jsonb_build_object('provider',p_provider));
 end if;
 expiry:=p_expires_at;
 if prod.kind='subscription' then
 insert into public.subscriptions(purchase_id,user_id,expires_at) values(pur.id,p_user_id,p_expires_at)
 on conflict(purchase_id) do update set expires_at=greatest(subscriptions.expires_at,excluded.expires_at) returning expires_at into expiry;
 end if;
 for c in select course_id from public.product_courses where product_id=prod.id loop
 insert into public.entitlements(user_id,course_id,purchase_id,starts_at,expires_at) values(p_user_id,c.course_id,pur.id,p_purchased_at,expiry)
 on conflict(user_id,course_id,purchase_id) do update set expires_at=excluded.expires_at;
 end loop;
 return pur;
end $$;
-- HMAC-verified server gateway events revoke existing bound claims only. Unknown claims fail.
create function public.apply_purchase_webhook(p_provider text,p_event_id text,p_transaction_id text,p_account_binding text,p_action text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare pur public.purchases; ev private.webhook_events; begin
 if p_action is distinct from 'revoke' or p_event_id is null or length(p_event_id)=0 then raise exception 'unsupported_webhook'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_provider||p_transaction_id,0));
 select * into pur from public.purchases where provider=p_provider and transaction_id=p_transaction_id for update;
 if pur.id is null or p_account_binding is distinct from pur.user_id::text then raise exception 'purchase_claim_mismatch' using errcode='42501'; end if;
 select * into ev from private.webhook_events where provider=p_provider and event_id=p_event_id;
 if ev.event_id is not null then
 if ev.payload<>p_payload then raise exception 'idempotency_conflict' using errcode='23505'; end if;
 return jsonb_build_object('duplicate',true,'purchase_id',pur.id); end if;
 insert into private.webhook_events(provider,event_id,payload) values(p_provider,p_event_id,p_payload);
 update public.purchases set status='revoked' where id=pur.id;
 update public.entitlements set revoked_at=coalesce(revoked_at,now()) where purchase_id=pur.id;
 update public.subscriptions set revoked_at=coalesce(revoked_at,now()) where purchase_id=pur.id;
 insert into public.audit_log(actor_id,action,entity_id,details) values(pur.user_id,'purchase_revoked',pur.id,jsonb_build_object('event_id',p_event_id));
 return jsonb_build_object('duplicate',false,'purchase_id',pur.id);
end $$;
grant execute on function public.live_session_access(uuid,boolean),public.media_access(uuid,boolean),public.create_live_session(uuid,text,timestamptz,timestamptz,boolean) to authenticated;
grant execute on function public.apply_verified_purchase(uuid,text,text,text,text,timestamptz,timestamptz,jsonb),public.apply_purchase_webhook(text,text,text,text,text,jsonb) to service_role;
-- Private buckets deliberately have no authenticated storage.objects policies.
-- Signed URLs are issued only after media_access; ingestion is a server job.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
 ('course-media','course-media',false,104857600,array['image/png','image/jpeg','image/webp','audio/mpeg','audio/mp4','video/mp4','application/pdf']),
 ('student-media','student-media',false,25000000,array['audio/mpeg','audio/mp4','audio/wav','audio/webm','audio/ogg']),
 ('session-recordings','session-recordings',false,1073741824,array['video/mp4'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
commit;
