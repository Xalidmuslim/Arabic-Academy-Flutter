begin;
create function pg_temp.check(ok boolean,label text) returns void language plpgsql as $$begin if ok is distinct from true then raise exception 'Assertion failed: %',label;end if;end$$;
grant execute on function pg_temp.check(boolean,text) to authenticated;
insert into auth.users values('30000000-0000-0000-0000-000000000001','{}'),('30000000-0000-0000-0000-000000000002','{}');
insert into public.teachers(id) values('30000000-0000-0000-0000-000000000001');
insert into public.server_roles values('30000000-0000-0000-0000-000000000001','teacher');
insert into public.courses(id,slug,title,access_tier,status,source_policy) values
 ('30000000-0000-0000-0000-000000000100','assigned-course','Assigned','paid','published','fixture'),
 ('30000000-0000-0000-0000-000000000101','unassigned-course','Unassigned','paid','published','fixture');
insert into public.course_teachers values('30000000-0000-0000-0000-000000000100','30000000-0000-0000-0000-000000000001');
insert into public.groups(id,course_id,teacher_id,title) values('30000000-0000-0000-0000-000000000200','30000000-0000-0000-0000-000000000100','30000000-0000-0000-0000-000000000001','Assigned group');
insert into public.group_members(group_id,student_id) values('30000000-0000-0000-0000-000000000200','30000000-0000-0000-0000-000000000002');
insert into public.levels(id,course_id,title,position) values('30000000-0000-0000-0000-000000000300','30000000-0000-0000-0000-000000000101','Hidden level',0);
insert into public.books(id,level_id,title,position) values('30000000-0000-0000-0000-000000000400','30000000-0000-0000-0000-000000000300','Hidden book',0);
insert into public.units(id,book_id,title,position) values('30000000-0000-0000-0000-000000000500','30000000-0000-0000-0000-000000000400','Hidden unit',0);
insert into public.lessons(id,unit_id,title,status,position) values('30000000-0000-0000-0000-000000000600','30000000-0000-0000-0000-000000000500','Hidden lesson','published',0);
insert into public.exercises(id,lesson_id,kind,title,grading_mode,published) values('30000000-0000-0000-0000-000000000700','30000000-0000-0000-0000-000000000600','text','Hidden exercise','manual',true);
-- A retained historical attempt in a different course must not become visible through a NULL lookup.
insert into public.attempts(student_id,exercise_id,exercise_version,idempotency_key,answers,status,max_score) values('30000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000700',1,gen_random_uuid(),'{"personal":"private-other-course"}','pending_review',1);
set local request.jwt.claim.sub='30000000-0000-0000-0000-000000000001';
set local role authenticated;
select pg_temp.check(public.teaches_student('30000000-0000-0000-0000-000000000002'),'teacher has student in assigned course');
select pg_temp.check((select count(*)=0 from public.exercises),'other paid exercise hidden');
select pg_temp.check((select count(*)=0 from public.attempts),'hidden parent cannot widen teacher attempt scope');
reset role;
insert into public.course_teachers values('30000000-0000-0000-0000-000000000101','30000000-0000-0000-0000-000000000001');
set local role authenticated;
select pg_temp.check((select count(*)=1 from public.exercises),'teacher now assigned to other course content');
select pg_temp.check((select count(*)=0 from public.attempts),'content assignment alone does not assign student in other course');
reset role;
insert into public.groups(id,course_id,teacher_id,title) values('30000000-0000-0000-0000-000000000201','30000000-0000-0000-0000-000000000101','30000000-0000-0000-0000-000000000001','Second assigned group');
insert into public.group_members(group_id,student_id) values('30000000-0000-0000-0000-000000000201','30000000-0000-0000-0000-000000000002');
set local role authenticated;
select pg_temp.check((select count(*)=1 from public.attempts),'teacher only reads after explicit student/course assignment');
reset role;
rollback;
