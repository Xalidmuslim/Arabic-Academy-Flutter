begin;
create function pg_temp.assert_true(ok boolean,label text) returns void language plpgsql as $$begin if ok is distinct from true then raise exception 'Assertion failed: %',label; end if; end$$;
create function pg_temp.expect_error(statement text,expected text,label text) returns void language plpgsql as $$
begin
 begin execute statement; exception when others then
 if sqlstate=expected then return; end if;
 raise exception 'Unexpected SQLSTATE % (expected %) for %: %',sqlstate,expected,label,sqlerrm;
 end;
 raise exception 'Expected rejection: %',label;
end$$;
grant execute on function pg_temp.assert_true(boolean,text),pg_temp.expect_error(text,text,text) to anon,authenticated,service_role;
insert into auth.users(id,raw_user_meta_data) values
 ('00000000-0000-0000-0000-000000000001','{"role":"admin"}'),
 ('00000000-0000-0000-0000-000000000002','{}'),
 ('00000000-0000-0000-0000-000000000003','{}'),
 ('00000000-0000-0000-0000-000000000004','{}'),
 ('00000000-0000-0000-0000-000000000005','{}');
insert into public.teachers(id) values('00000000-0000-0000-0000-000000000003'),('00000000-0000-0000-0000-000000000004'),('00000000-0000-0000-0000-000000000005');
insert into public.server_roles(user_id,role) values('00000000-0000-0000-0000-000000000003','teacher'),('00000000-0000-0000-0000-000000000004','teacher'),('00000000-0000-0000-0000-000000000005','admin');
insert into public.courses(id,slug,title,access_tier,status,source_policy) values
 ('00000000-0000-0000-0000-000000000100','paid','Paid course','paid','published','test fixture'),
 ('00000000-0000-0000-0000-000000000101','free','Free course','free','published','test fixture'),
 ('00000000-0000-0000-0000-000000000102','draft','Draft course','free','draft','test fixture');
insert into public.course_teachers values('00000000-0000-0000-0000-000000000100','00000000-0000-0000-0000-000000000003'),('00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000000004');
insert into public.groups(id,course_id,teacher_id,title) values('00000000-0000-0000-0000-000000000200','00000000-0000-0000-0000-000000000100','00000000-0000-0000-0000-000000000003','Assigned'),('00000000-0000-0000-0000-000000000201','00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000000004','Other');
insert into public.group_members(group_id,student_id) values('00000000-0000-0000-0000-000000000200','00000000-0000-0000-0000-000000000001'),('00000000-0000-0000-0000-000000000201','00000000-0000-0000-0000-000000000002');
insert into public.levels(id,course_id,title,position) values('00000000-0000-0000-0000-000000000300','00000000-0000-0000-0000-000000000100','Paid level',0),('00000000-0000-0000-0000-000000000301','00000000-0000-0000-0000-000000000101','Free level',0);
insert into public.books(id,level_id,title,position) values('00000000-0000-0000-0000-000000000400','00000000-0000-0000-0000-000000000300','Paid book',0),('00000000-0000-0000-0000-000000000401','00000000-0000-0000-0000-000000000301','Free book',0);
insert into public.units(id,book_id,title,position) values('00000000-0000-0000-0000-000000000500','00000000-0000-0000-0000-000000000400','Paid unit',0),('00000000-0000-0000-0000-000000000501','00000000-0000-0000-0000-000000000401','Free unit',0);
insert into public.lessons(id,unit_id,title,status,is_free_sample,position) values
 ('00000000-0000-0000-0000-000000000600','00000000-0000-0000-0000-000000000500','Paid lesson','published',false,0),
 ('00000000-0000-0000-0000-000000000601','00000000-0000-0000-0000-000000000500','Free sample','published',true,1),
 ('00000000-0000-0000-0000-000000000602','00000000-0000-0000-0000-000000000500','Draft lesson','draft',true,2),
 ('00000000-0000-0000-0000-000000000603','00000000-0000-0000-0000-000000000501','Free lesson','published',false,0);
insert into public.lesson_blocks(lesson_id,step,kind,body,position) values('00000000-0000-0000-0000-000000000600','dialogue','text','{"text":"paid secret"}',0),('00000000-0000-0000-0000-000000000601','dialogue','text','{"text":"free sample"}',0);
insert into public.exercises(id,lesson_id,kind,title,grading_mode,published) values
 ('00000000-0000-0000-0000-000000000700','00000000-0000-0000-0000-000000000600','single_choice','Paid test','automatic',true),
 ('00000000-0000-0000-0000-000000000701','00000000-0000-0000-0000-000000000601','text','Sample test','automatic',true),
 ('00000000-0000-0000-0000-000000000702','00000000-0000-0000-0000-000000000600','speaking','Manual test','manual',true);
insert into public.questions(id,exercise_id,prompt,position) values('00000000-0000-0000-0000-000000000800','00000000-0000-0000-0000-000000000700','{"text":"paid prompt"}',0),('00000000-0000-0000-0000-000000000801','00000000-0000-0000-0000-000000000701','{"text":"Say yes"}',0),('00000000-0000-0000-0000-000000000802','00000000-0000-0000-0000-000000000702','{"text":"Speak"}',0);
insert into private.answer_keys(question_id,accepted_answers) values('00000000-0000-0000-0000-000000000800','["yes"]'),('00000000-0000-0000-0000-000000000801','["نَعَمْ"]');
insert into public.question_options(question_id,label,position) values('00000000-0000-0000-0000-000000000800','yes',0);
insert into public.media(id,lesson_id,owner_id,kind,mime_type,byte_size,consent_stt) values('00000000-0000-0000-0000-000000000900','00000000-0000-0000-0000-000000000600',null,'audio','audio/mpeg',50,false),('00000000-0000-0000-0000-000000000901',null,'00000000-0000-0000-0000-000000000001','audio','audio/mpeg',50,true);
insert into private.media_objects(media_id,bucket_id,object_path) values('00000000-0000-0000-0000-000000000900','course-media','paid/audio.mp3'),('00000000-0000-0000-0000-000000000901','student-media','one/audio.mp3');
insert into public.live_sessions(id,group_id,title,room_name,starts_at,ends_at) values('00000000-0000-0000-0000-000000001000','00000000-0000-0000-0000-000000000200','Lesson','fixture_room',now()-interval '1 minute',now()+interval '1 hour');
insert into public.products(id,provider,external_id,kind,active) values('00000000-0000-0000-0000-000000001100','apple','course.paid','course',true),('00000000-0000-0000-0000-000000001101','google','subscription.paid','subscription',true);
insert into public.product_courses values('00000000-0000-0000-0000-000000001100','00000000-0000-0000-0000-000000000100'),('00000000-0000-0000-0000-000000001101','00000000-0000-0000-0000-000000000100');
-- Assert every table's RLS and every SECURITY DEFINER's locked search path and EXECUTE scope.
select pg_temp.assert_true(not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','private') and c.relkind='r' and not c.relrowsecurity),'RLS on every app table');
select pg_temp.assert_true(not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private') and p.prosecdef and not coalesce(p.proconfig @> array['search_path=""'],false)),'fixed definer search paths');
select pg_temp.assert_true(not has_function_privilege('authenticated','public.apply_verified_purchase(uuid,text,text,text,text,timestamptz,timestamptz,jsonb)','execute'),'verifier RPC server-only');
select pg_temp.assert_true(not has_function_privilege('anon','public.submit_attempt(uuid,uuid,jsonb)','execute'),'grading RPC not anonymous');
select pg_temp.assert_true(not exists(select 1 from storage.buckets where public),'private buckets');

set local role anon;
select pg_temp.assert_true((select count(*)=2 from public.courses),'anonymous browse only published courses');
select pg_temp.assert_true((select count(*)=2 from public.lessons),'anonymous free sample and free course only');
select pg_temp.assert_true((select count(*)=1 from public.lesson_blocks),'anonymous paid blocks protected');
select pg_temp.expect_error('select * from private.answer_keys','42501','anonymous answer keys');
reset role;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
set local role authenticated;
select pg_temp.assert_true(not public.has_server_role('admin'),'metadata cannot elevate role');
select pg_temp.assert_true(not public.can_access_course('00000000-0000-0000-0000-000000000100'),'membership does not grant course');
select pg_temp.assert_true((select count(*)=2 from public.profiles),'only self and assigned teacher profile visible');
select pg_temp.assert_true((select count(*)=1 from public.students),'student own roster only');
select pg_temp.assert_true((select count(*)=1 from public.groups),'only own group');
select pg_temp.assert_true((select count(*)=1 from public.questions),'paid questions hidden');
select pg_temp.assert_true((select count(*)=0 from public.question_options),'paid options hidden');
select pg_temp.expect_error('insert into public.server_roles values(auth.uid(),''admin'')','42501','cannot self elevate');
select pg_temp.expect_error('insert into public.entitlements(user_id,course_id) values(auth.uid(),''00000000-0000-0000-0000-000000000100'')','42501','cannot mint entitlements');
select pg_temp.expect_error('update public.profiles set id=''00000000-0000-0000-0000-000000000005'' where id=auth.uid()','42501','profile ID immutable');
select pg_temp.expect_error('select * from private.answer_keys','42501','student answer keys');
select pg_temp.expect_error('select public.media_access(''00000000-0000-0000-0000-000000000900'')','42501','paid media denied');
select pg_temp.expect_error('select public.media_access(''00000000-0000-0000-0000-000000000901'',true)','42501','STT consent off');
select pg_temp.expect_error('select public.live_session_access(''00000000-0000-0000-0000-000000001000'')','42501','live paid course denied');
select pg_temp.expect_error('select public.submit_attempt(''00000000-0000-0000-0000-000000000700'',''00000000-0000-0000-0000-000000002000'',''{}'')','42501','paid grading denied');
select pg_temp.expect_error('select public.complete_lesson(''00000000-0000-0000-0000-000000000601'')','42501','cannot finish without passing');
select pg_temp.assert_true(not (public.submit_attempt('00000000-0000-0000-0000-000000000701','00000000-0000-0000-0000-000000002001','{"00000000-0000-0000-0000-000000000801":"نعم"}')).passed,'Arabic diacritics retained');
select pg_temp.assert_true(not (public.submit_attempt('00000000-0000-0000-0000-000000000701','00000000-0000-0000-0000-000000002002','{}')).passed,'empty answers fail');
select pg_temp.assert_true((public.submit_attempt('00000000-0000-0000-0000-000000000701','00000000-0000-0000-0000-000000002003','{"00000000-0000-0000-0000-000000000801":"نَعَمْ"}')).passed,'correct answer passes');
select pg_temp.assert_true((public.submit_attempt('00000000-0000-0000-0000-000000000701','00000000-0000-0000-0000-000000002003','{"00000000-0000-0000-0000-000000000801":"نَعَمْ"}')).passed,'identical replay passes');
select pg_temp.assert_true((select count(*)=3 from public.attempts),'attempt replay no duplicate');
select pg_temp.expect_error('select public.submit_attempt(''00000000-0000-0000-0000-000000000701'',''00000000-0000-0000-0000-000000002003'',''{}'')','23505','changed answer replay rejected');
select public.complete_lesson('00000000-0000-0000-0000-000000000601');
select public.record_event('00000000-0000-0000-0000-000000002004','draft_saved','{"legacy_id":"l1","unknown_field":"preserved"}');
select public.record_event('00000000-0000-0000-0000-000000002004','draft_saved','{"legacy_id":"l1","unknown_field":"preserved"}');
select pg_temp.assert_true((select count(*)=1 from public.events),'event deduplication');
select pg_temp.expect_error('select public.record_event(''00000000-0000-0000-0000-000000002004'',''draft_saved'',''{}'')','23505','changed event rejected');
select pg_temp.expect_error('select public.record_event(''00000000-0000-0000-0000-000000002005'',''lesson_completed'',''{}'')','23514','events cannot assert completion');
update public.user_settings set stt_consent=true where user_id=auth.uid();
select pg_temp.assert_true((public.media_access('00000000-0000-0000-0000-000000000901',true)->>'expires_in')::int=60,'own consented STT allowed');
select pg_temp.assert_true((select count(*)=0 from storage.objects),'raw private storage inaccessible');
reset role;
-- Validated store responses are seeded as service_role, never as a student.
set local role service_role;
select pg_temp.expect_error('select public.apply_verified_purchase(''00000000-0000-0000-0000-000000000001'',''apple'',''tx1'',''course.paid'',''00000000-0000-0000-0000-000000000002'',now(),null,''{}'')','42501','purchase account binding');
select public.apply_verified_purchase('00000000-0000-0000-0000-000000000001','apple','tx1','course.paid','00000000-0000-0000-0000-000000000001',now(),null,'{"verified_by":"fixture"}');
select public.apply_verified_purchase('00000000-0000-0000-0000-000000000001','apple','tx1','course.paid','00000000-0000-0000-0000-000000000001',now(),null,'{"verified_by":"fixture"}');
select pg_temp.assert_true((select count(*)=1 from public.purchases),'purchase idempotency');
select pg_temp.assert_true((select count(*)=1 from public.entitlements),'entitlement idempotency');
select pg_temp.expect_error('select public.apply_verified_purchase(''00000000-0000-0000-0000-000000000002'',''apple'',''tx1'',''course.paid'',''00000000-0000-0000-0000-000000000002'',now(),null,''{}'')','42501','store replay another user');
reset role;
set local role authenticated;
select pg_temp.assert_true(public.can_access_course('00000000-0000-0000-0000-000000000100'),'verified purchase unlocks');
select pg_temp.assert_true((select count(*)=3 from public.lessons),'paid published visible but draft denied');
select pg_temp.assert_true((public.media_access('00000000-0000-0000-0000-000000000900')->>'expires_in')::int<=60,'short paid media URL lifetime');
select pg_temp.assert_true((public.live_session_access('00000000-0000-0000-0000-000000001000')->>'can_publish')::boolean=false,'student cannot publish');
select public.submit_attempt('00000000-0000-0000-0000-000000000700','00000000-0000-0000-0000-000000002010','{"00000000-0000-0000-0000-000000000800":"yes"}');
select pg_temp.assert_true((public.submit_attempt('00000000-0000-0000-0000-000000000702','00000000-0000-0000-0000-000000002011','{"00000000-0000-0000-0000-000000000802":"audio-id"}')).status='pending_review','manual pending not fabricated grade');
select pg_temp.expect_error('select public.complete_lesson(''00000000-0000-0000-0000-000000000600'')','42501','manual review required');
select public.enroll_course('00000000-0000-0000-0000-000000000100');
reset role;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000002';
set local role authenticated;
select pg_temp.assert_true((select count(*)=0 from public.attempts),'cannot read another student attempts');
select pg_temp.assert_true((select count(*)=0 from public.purchases),'cannot read another student purchases');
select pg_temp.assert_true((select count(*)=0 from public.events),'cannot read another student events');
select pg_temp.expect_error('select public.media_access(''00000000-0000-0000-0000-000000000901'',true)','42501','cannot transcribe another student audio');
reset role;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000004';
set local role authenticated;
select pg_temp.assert_true((select count(*)=0 from public.attempts),'unassigned teacher cannot read attempts');
select pg_temp.expect_error('select public.live_session_access(''00000000-0000-0000-0000-000000001000'')','42501','unassigned teacher live denied');
select pg_temp.expect_error('select public.save_lesson(''00000000-0000-0000-0000-000000000600'',1,''{"title":"stolen"}'')','42501','unassigned teacher editor denied');
select pg_temp.expect_error('select public.set_group_member(''00000000-0000-0000-0000-000000000200'',''00000000-0000-0000-0000-000000000002'',true)','42501','unassigned group modification denied');
reset role;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000003';
set local role authenticated;
select pg_temp.assert_true((select count(*)=4 from public.lessons),'assigned teacher sees drafts');
select pg_temp.assert_true((select count(*)=5 from public.attempts),'assigned teacher sees own student attempts');
select pg_temp.assert_true((select count(*)=2 from public.students),'teacher sees self and assigned student');
select pg_temp.assert_true((public.live_session_access('00000000-0000-0000-0000-000000001000')->>'can_publish')::boolean,'assigned teacher publishes');
select pg_temp.expect_error('select * from private.answer_keys','42501','teacher direct answer key read denied');
select public.review_attempt((select id from public.attempts where exercise_id='00000000-0000-0000-0000-000000000702'),1);
select pg_temp.expect_error('select public.save_lesson(''00000000-0000-0000-0000-000000000600'',null,''{"title":"no version"}'')','40001','null version cannot bypass optimistic edit');
select pg_temp.expect_error('select public.set_group_member(''00000000-0000-0000-0000-000000000200'',''00000000-0000-0000-0000-000000000002'',true)','42501','teacher cannot self assign students');
select public.save_lesson('00000000-0000-0000-0000-000000000600',1,'{"title":"Updated"}','{"blocks":[{"step":"dialogue","kind":"text","body":{"text":"updated"},"position":0}]}');
select pg_temp.expect_error('select public.save_lesson(''00000000-0000-0000-0000-000000000600'',1,''{"title":"stale"}'')','40001','lesson optimistic conflict');
select public.create_assignment('00000000-0000-0000-0000-000000000200','00000000-0000-0000-0000-000000000700','Homework');
reset role;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
set local role authenticated;
select public.complete_lesson('00000000-0000-0000-0000-000000000600');
select public.submit_assignment((select id from public.assignments limit 1),0,'00000000-0000-0000-0000-000000002020','{"text":"draft"}');
select public.submit_assignment((select id from public.assignments limit 1),0,'00000000-0000-0000-0000-000000002020','{"text":"draft"}');
select pg_temp.assert_true((select count(*)=1 from public.submission_history),'submission replay one history');
select pg_temp.expect_error('select public.submit_assignment((select id from public.assignments limit 1),0,''00000000-0000-0000-0000-000000002021'',''{"text":"stale"}'')','40001','submission revision conflict');
select public.submit_assignment((select id from public.assignments limit 1),1,'00000000-0000-0000-0000-000000002021','{"text":"second"}');
select pg_temp.assert_true((select count(*)=2 from public.submission_history),'submission immutable history retained');
select pg_temp.expect_error('update public.submissions set body=''{}''','42501','student cannot bypass revisions');
select pg_temp.expect_error('insert into public.grades(submission_id,revision,teacher_id,score) select id,revision,auth.uid(),100 from public.submissions','42501','student cannot grade');
reset role;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000003';
set local role authenticated;
select public.grade_submission((select id from public.submissions limit 1),2,90,'Feedback');
select public.grade_submission((select id from public.submissions limit 1),2,90,'Feedback');
select pg_temp.assert_true((select count(*)=1 from public.grades),'grade replay idempotent');
select pg_temp.expect_error('select public.grade_submission((select id from public.submissions limit 1),2,100,''Changed'')','23505','grade immutable once issued');
reset role;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000004';
set local role authenticated;
select pg_temp.assert_true((select count(*)=0 from public.submissions),'unassigned teacher cannot read submissions');
select pg_temp.assert_true((select count(*)=0 from public.grades),'unassigned teacher cannot read grades');
reset role;
set local role service_role;
select pg_temp.expect_error('select public.apply_purchase_webhook(''apple'',''ev1'',''tx1'',''00000000-0000-0000-0000-000000000002'',''revoke'',''{}'')','42501','webhook binding mismatch');
select public.apply_purchase_webhook('apple','ev1','tx1','00000000-0000-0000-0000-000000000001','revoke','{"status":"revoked"}');
select pg_temp.assert_true((public.apply_purchase_webhook('apple','ev1','tx1','00000000-0000-0000-0000-000000000001','revoke','{"status":"revoked"}')->>'duplicate')::boolean,'webhook replay idempotent');
select pg_temp.expect_error('select public.apply_purchase_webhook(''apple'',''ev1'',''tx1'',''00000000-0000-0000-0000-000000000001'',''revoke'',''{}'')','23505','webhook event payload bound');
select pg_temp.expect_error('select public.apply_verified_purchase(''00000000-0000-0000-0000-000000000001'',''apple'',''tx1'',''course.paid'',''00000000-0000-0000-0000-000000000001'',now(),null,''{}'')','42501','revoked purchase cannot replay unlock');
reset role;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
set local role authenticated;
select pg_temp.assert_true(not public.can_access_course('00000000-0000-0000-0000-000000000100'),'revocation removes access');
select pg_temp.assert_true((select count(*)=2 from public.study_progress),'revocation preserves progress');
select pg_temp.assert_true((select count(*)=5 from public.attempts),'revocation preserves own attempts');
select pg_temp.expect_error('select public.media_access(''00000000-0000-0000-0000-000000000900'')','42501','revoked media denied');
reset role;
set local role service_role;
select public.apply_verified_purchase('00000000-0000-0000-0000-000000000001','google','token-hash','subscription.paid','00000000-0000-0000-0000-000000000001',now()-interval '1 hour',now()+interval '1 hour','{}');
update public.entitlements set expires_at=now()-interval '1 second' where purchase_id=(select id from public.purchases where provider='google');
reset role;
set local role authenticated;
select pg_temp.assert_true(not public.can_access_course('00000000-0000-0000-0000-000000000100'),'expired subscription denied');
reset role;
-- Revoking a teacher role invalidates permissions even if assignment rows remain.
delete from public.server_roles where user_id='00000000-0000-0000-0000-000000000003' and role='teacher';
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000003';
set local role authenticated;
select pg_temp.assert_true(not public.manages_group('00000000-0000-0000-0000-000000000200'),'revoked teacher cannot manage group');
select pg_temp.assert_true((select count(*)=0 from public.attempts),'revoked teacher cannot read students');
reset role;
rollback;
