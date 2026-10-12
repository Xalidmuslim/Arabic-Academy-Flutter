begin;
create function public.record_event(p_idempotency_key uuid,p_kind text,p_payload jsonb) returns public.events
language plpgsql security definer set search_path='' as $$
declare r public.events; begin
 perform private.require_active_account();
 if pg_column_size(p_payload)>65536 then raise exception 'payload_too_large'; end if;
 insert into public.events(user_id,idempotency_key,kind,payload) values(auth.uid(),p_idempotency_key,p_kind,p_payload) on conflict(user_id,idempotency_key) do nothing returning * into r;
 if r.id is null then
 select * into r from public.events where user_id=auth.uid() and idempotency_key=p_idempotency_key;
 if r.kind<>p_kind or r.payload<>p_payload then raise exception 'idempotency_conflict' using errcode='23505'; end if;
 end if;
 return r;
end $$;
create function public.submit_attempt(p_exercise_id uuid,p_idempotency_key uuid,p_answers jsonb) returns public.attempts
language plpgsql security definer set search_path='' as $$
declare e public.exercises; r public.attempts; q record; total numeric:=0; earned numeric:=0; question_count int:=0; actual jsonb;
begin
 if not public.has_server_role('student') then raise exception 'student_required' using errcode='42501'; end if;
 if jsonb_typeof(p_answers)<>'object' or p_answers is null or pg_column_size(p_answers)>65536 then raise exception 'invalid_answers'; end if;
 -- Serialize duplicate deliveries and content edits; the replay never changes the recorded result.
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||p_idempotency_key::text,0));
 select * into r from public.attempts where student_id=auth.uid() and idempotency_key=p_idempotency_key;
 if r.id is not null then
 if r.exercise_id<>p_exercise_id or r.answers<>p_answers then raise exception 'idempotency_conflict' using errcode='23505'; end if;
 return r; end if;
 select * into e from public.exercises where id=p_exercise_id for share;
 if e.id is null or not e.published or not public.can_read_lesson(e.lesson_id) then raise exception 'exercise_denied' using errcode='42501'; end if;
 if exists(select 1 from jsonb_object_keys(p_answers) k where not exists(select 1 from public.questions where exercise_id=e.id and id::text=k)) then raise exception 'unknown_question'; end if;
 for q in select qu.*,ak.accepted_answers,ak.comparison from public.questions qu left join private.answer_keys ak on ak.question_id=qu.id where qu.exercise_id=e.id loop
 question_count:=question_count+1; total:=total+q.points; actual:=p_answers->q.id::text;
 if e.grading_mode='automatic' then
 if q.accepted_answers is null then raise exception 'answer_key_unconfigured' using errcode='55000'; end if;
 if actual is not null and actual<>'null'::jsonb and exists(select 1 from jsonb_array_elements(q.accepted_answers) a where
 (q.comparison='exact' and a=actual) or (q.comparison='text_trim' and jsonb_typeof(a)='string' and jsonb_typeof(actual)='string' and btrim(a#>>'{}')=btrim(actual#>>'{}'))) then earned:=earned+q.points; end if;
 end if;
 end loop;
 if question_count=0 then raise exception 'exercise_unconfigured' using errcode='55000'; end if;
 insert into public.attempts(student_id,exercise_id,exercise_version,idempotency_key,answers,status,score,max_score,passed)
 values(auth.uid(),e.id,e.version,p_idempotency_key,p_answers,case when e.grading_mode='automatic' then 'graded' else 'pending_review' end,
 case when e.grading_mode='automatic' then earned end,total,e.grading_mode='automatic' and earned*100/total>=e.pass_percent) returning * into r;
 return r;
end $$;
create function public.complete_lesson(p_lesson_id uuid) returns public.study_progress
language plpgsql security definer set search_path='' as $$
declare r public.study_progress; begin
 if not public.has_server_role('student') or not public.can_read_lesson(p_lesson_id) then raise exception 'lesson_denied' using errcode='42501'; end if;
 if not exists(select 1 from public.exercises where lesson_id=p_lesson_id and published) or exists(
 select 1 from public.exercises e where e.lesson_id=p_lesson_id and e.published and not exists(
 select 1 from public.attempts a where a.exercise_id=e.id and a.exercise_version=e.version and a.student_id=auth.uid() and a.status='graded' and a.passed)) then
 raise exception 'passing_attempts_required' using errcode='42501'; end if;
 insert into public.study_progress(student_id,lesson_id,completed_at) values(auth.uid(),p_lesson_id,now()) on conflict do nothing;
 select * into r from public.study_progress where student_id=auth.uid() and lesson_id=p_lesson_id;
 return r;
end $$;
create function public.create_assignment(p_group_id uuid,p_exercise_id uuid,p_title text,p_due_at timestamptz default null) returns public.assignments
language plpgsql security definer set search_path='' as $$
declare r public.assignments; begin
 if not public.manages_group(p_group_id) or not exists(select 1 from public.groups g join public.exercises e on public.lesson_course_id(e.lesson_id)=g.course_id where g.id=p_group_id and e.id=p_exercise_id and e.published) then raise exception 'assignment_denied' using errcode='42501'; end if;
 insert into public.teachers(id) values(auth.uid()) on conflict do nothing;
 insert into public.assignments(group_id,exercise_id,title,due_at,created_by) values(p_group_id,p_exercise_id,p_title,p_due_at,auth.uid()) returning * into r;
 return r;
end $$;
create function public.submit_assignment(p_assignment_id uuid,p_expected_revision int,p_idempotency_key uuid,p_body jsonb) returns public.submissions
language plpgsql security definer set search_path='' as $$
declare a public.assignments; s public.submissions; h public.submission_history;
begin
 select * into a from public.assignments where id=p_assignment_id;
 if a.id is null or not public.is_group_member(a.group_id) or not public.can_read_exercise(a.exercise_id) then raise exception 'submission_denied' using errcode='42501'; end if;
 if p_body is null or jsonb_typeof(p_body)<>'object' or pg_column_size(p_body)>65536 then raise exception 'invalid_body'; end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||p_assignment_id::text,0));
 select * into s from public.submissions where assignment_id=p_assignment_id and student_id=auth.uid() for update;
 if s.id is not null then
 select * into h from public.submission_history where submission_id=s.id and idempotency_key=p_idempotency_key;
 if h.id is not null then
 if h.body<>p_body then raise exception 'idempotency_conflict' using errcode='23505'; end if;
 return s; end if;
 end if;
 if a.due_at is not null and a.due_at<now() and (s.id is null or s.status<>'revision_requested') then raise exception 'assignment_closed'; end if;
 if s.id is null then
 if p_expected_revision is distinct from 0 then raise exception 'revision_conflict' using errcode='40001'; end if;
 insert into public.submissions(assignment_id,student_id,body) values(a.id,auth.uid(),p_body) returning * into s;
 else
 if s.revision is distinct from p_expected_revision then raise exception 'revision_conflict' using errcode='40001'; end if;
 update public.submissions set body=p_body,revision=revision+1,status='submitted',updated_at=now() where id=s.id returning * into s;
 end if;
 insert into public.submission_history(submission_id,revision,body,idempotency_key) values(s.id,s.revision,p_body,p_idempotency_key);
 update public.revision_requests set resolved_at=now() where submission_id=s.id and revision<s.revision and resolved_at is null;
 insert into public.submission_status_history(submission_id,revision,status,actor_id) values(s.id,s.revision,'submitted',auth.uid());
 return s;
end $$;
create function public.grade_submission(p_submission_id uuid,p_revision int,p_score numeric,p_feedback text) returns public.grades
language plpgsql security definer set search_path='' as $$
declare s public.submissions; g public.grades; old_feedback text;
begin
 select * into s from public.submissions where id=p_submission_id for share;
 if s.id is null or not exists(select 1 from public.assignments a where a.id=s.assignment_id and public.manages_group(a.group_id)) then raise exception 'teacher_assignment_required' using errcode='42501'; end if;
 if s.revision is distinct from p_revision then raise exception 'revision_conflict' using errcode='40001'; end if;
 if s.status='revision_requested' then raise exception 'revision_required' using errcode='55000'; end if;
 select * into g from public.grades where submission_id=s.id and revision=p_revision;
 if g.id is not null then
 select body into old_feedback from public.feedback where grade_id=g.id;
 if g.score<>p_score or old_feedback is distinct from p_feedback then raise exception 'grade_already_recorded' using errcode='23505'; end if;
 return g; end if;
 insert into public.teachers(id) values(auth.uid()) on conflict do nothing;
 insert into public.grades(submission_id,revision,teacher_id,score) values(s.id,p_revision,auth.uid(),p_score) returning * into g;
 insert into public.feedback(grade_id,body) values(g.id,p_feedback);
 update public.submissions set status='graded',updated_at=now() where id=s.id;
 insert into public.submission_status_history(submission_id,revision,status,actor_id) values(s.id,p_revision,'graded',auth.uid());
 insert into public.audit_log(actor_id,action,entity_id,details) values(auth.uid(),'submission_graded',s.id,jsonb_build_object('revision',p_revision,'score',p_score));
 return g;
end $$;
create function public.review_attempt(p_attempt_id uuid,p_score numeric) returns public.attempts
language plpgsql security definer set search_path='' as $$
declare a public.attempts; e public.exercises; begin
 select * into a from public.attempts where id=p_attempt_id for update;
 select * into e from public.exercises where id=a.exercise_id;
 if a.id is null or not public.teaches_student(a.student_id,public.lesson_course_id(e.lesson_id)) then raise exception 'teacher_assignment_required' using errcode='42501'; end if;
 if a.status<>'pending_review' or e.version<>a.exercise_version or e.grading_mode<>'manual' then raise exception 'attempt_not_reviewable'; end if;
 if p_score is null or p_score<0 or p_score>a.max_score then raise exception 'invalid_score'; end if;
 update public.attempts set status='graded',score=p_score,passed=p_score*100/max_score>=e.pass_percent where id=a.id returning * into a;
 insert into public.audit_log(actor_id,action,entity_id,details) values(auth.uid(),'attempt_reviewed',a.id,jsonb_build_object('score',p_score));
 return a;
end $$;
create function public.enroll_course(p_course_id uuid) returns public.enrollments
language plpgsql security definer set search_path='' as $$
declare r public.enrollments; begin
 if not public.has_server_role('student') or not public.can_access_course(p_course_id) then raise exception 'course_denied' using errcode='42501'; end if;
 insert into public.enrollments(student_id,course_id) values(auth.uid(),p_course_id) on conflict do nothing;
 select * into r from public.enrollments where student_id=auth.uid() and course_id=p_course_id; return r;
end $$;
-- Membership assignment is administrative: teachers cannot self-assign students.
create function public.set_group_member(p_group_id uuid,p_student_id uuid,p_active boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
 if not public.has_server_role('admin') or not public.manages_group(p_group_id) or not exists(select 1 from public.server_roles where user_id=p_student_id and role='student') then raise exception 'group_denied' using errcode='42501'; end if;
 insert into public.group_members(group_id,student_id,left_at) values(p_group_id,p_student_id,case when not p_active then now() end)
 on conflict(group_id,student_id) do update set left_at=excluded.left_at;
 insert into public.audit_log(actor_id,action,entity_id,details) values(auth.uid(),'group_membership',p_group_id,jsonb_build_object('student_id',p_student_id,'active',p_active));
end $$;
create function public.create_group(p_course_id uuid,p_title text) returns public.groups
language plpgsql security definer set search_path='' as $$
declare r public.groups; begin
 if not(public.has_server_role('teacher') or public.has_server_role('admin')) or not public.teaches_course(p_course_id) then raise exception 'teacher_required' using errcode='42501'; end if;
 insert into public.teachers(id) values(auth.uid()) on conflict do nothing;
 insert into public.groups(course_id,teacher_id,title) values(p_course_id,auth.uid(),p_title) returning * into r; return r;
end $$;
create function public.create_lesson(p_unit_id uuid,p_title text,p_position int) returns public.lessons
language plpgsql security definer set search_path='' as $$
declare r public.lessons; c uuid; begin
 select lv.course_id into c from public.units u join public.books b on b.id=u.book_id join public.levels lv on lv.id=b.level_id where u.id=p_unit_id;
 if c is null or not public.teaches_course(c) then raise exception 'teacher_required' using errcode='42501'; end if;
 insert into public.lessons(unit_id,title,position) values(p_unit_id,p_title,p_position) returning * into r; return r;
end $$;
-- All lesson body editing goes through one optimistic transaction.
revoke insert,update,delete on public.lesson_blocks,public.dialogues,public.dialogue_lines,public.vocabulary,public.grammar from authenticated;
create function public.save_lesson(p_lesson_id uuid,p_expected_version int,p_patch jsonb,p_content jsonb default null) returns public.lessons
language plpgsql security definer set search_path='' as $$
declare l public.lessons; item jsonb; line jsonb; d uuid;
begin
 select * into l from public.lessons where id=p_lesson_id for update;
 if l.id is null or not public.teaches_course(public.lesson_course_id(l.id)) then raise exception 'teacher_required' using errcode='42501'; end if;
 if l.version is distinct from p_expected_version then raise exception 'version_conflict' using errcode='40001'; end if;
 if jsonb_typeof(p_patch)<>'object' or p_patch is null or exists(select 1 from jsonb_object_keys(p_patch) k where k not in ('title','title_ar','goal','status','is_free_sample','position')) then raise exception 'invalid_patch'; end if;
 update public.lessons set title=coalesce(p_patch->>'title',title),title_ar=coalesce(p_patch->>'title_ar',title_ar),goal=coalesce(p_patch->>'goal',goal),status=coalesce(p_patch->>'status',status),is_free_sample=coalesce((p_patch->>'is_free_sample')::boolean,is_free_sample),position=coalesce((p_patch->>'position')::int,position),version=version+1,updated_at=now() where id=l.id returning * into l;
 if p_content is not null then
 if jsonb_typeof(p_content)<>'object' or pg_column_size(p_content)>1048576 or exists(select 1 from jsonb_object_keys(p_content) k where k not in ('blocks','dialogues','vocabulary','grammar')) then raise exception 'invalid_content'; end if;
 if exists(select 1 from jsonb_each(p_content) entry where jsonb_typeof(entry.value)<>'array') then raise exception 'invalid_content'; end if;
 if p_content ? 'blocks' then
 delete from public.lesson_blocks where lesson_id=l.id;
 for item in select value from jsonb_array_elements(p_content->'blocks') loop
 insert into public.lesson_blocks(id,lesson_id,step,kind,body,position) values(coalesce((item->>'id')::uuid,gen_random_uuid()),l.id,item->>'step',item->>'kind',item->'body',(item->>'position')::int); end loop;
 end if;
 if p_content ? 'dialogues' then
 delete from public.dialogues where lesson_id=l.id;
 for item in select value from jsonb_array_elements(p_content->'dialogues') loop
 d:=coalesce((item->>'id')::uuid,gen_random_uuid());
 insert into public.dialogues(id,lesson_id,title) values(d,l.id,coalesce(item->>'title',''));
 for line in select value from jsonb_array_elements(item->'lines') loop
 insert into public.dialogue_lines(id,dialogue_id,speaker,text_ar,translation,position) values(coalesce((line->>'id')::uuid,gen_random_uuid()),d,coalesce(line->>'speaker',''),line->>'text_ar',coalesce(line->>'translation',''),(line->>'position')::int); end loop;
 end loop;
 end if;
 if p_content ? 'vocabulary' then
 -- IDs preserve bookmarks/reviews; delete only removed entries, upsert the retained set.
 update public.vocabulary set retired_at=now() where lesson_id=l.id;
 for item in select value from jsonb_array_elements(p_content->'vocabulary') loop
 insert into public.vocabulary(id,lesson_id,text_ar,translation,transliteration,position) values(coalesce((item->>'id')::uuid,gen_random_uuid()),l.id,item->>'text_ar',item->>'translation',item->>'transliteration',(item->>'position')::int)
 on conflict(id) do update set text_ar=excluded.text_ar,translation=excluded.translation,transliteration=excluded.transliteration,position=excluded.position,retired_at=null where vocabulary.lesson_id=l.id;
 if not found then raise exception 'foreign_content_id' using errcode='42501'; end if;
 end loop;
 end if;
 if p_content ? 'grammar' then
 delete from public.grammar where lesson_id=l.id;
 for item in select value from jsonb_array_elements(p_content->'grammar') loop
 insert into public.grammar(id,lesson_id,title,explanation,examples,position) values(coalesce((item->>'id')::uuid,gen_random_uuid()),l.id,item->>'title',item->>'explanation',coalesce(item->'examples','[]'),(item->>'position')::int); end loop;
 end if;
 end if;
 insert into public.audit_log(actor_id,action,entity_id,details) values(auth.uid(),'lesson_saved',l.id,jsonb_build_object('version',l.version));
 return l;
end $$;
create function public.save_exercise(p_exercise_id uuid,p_lesson_id uuid,p_expected_version int,p_definition jsonb,p_questions jsonb) returns public.exercises
language plpgsql security definer set search_path='' as $$
declare e public.exercises; item jsonb; opt jsonb; qid uuid; begin
 if not public.teaches_course(public.lesson_course_id(p_lesson_id)) then raise exception 'teacher_required' using errcode='42501'; end if;
 if p_questions is null or jsonb_typeof(p_questions)<>'array' or jsonb_array_length(p_questions)=0 or pg_column_size(p_questions)>1048576 then raise exception 'invalid_questions'; end if;
 select * into e from public.exercises where id=p_exercise_id for update;
 if e.id is null then
 if p_expected_version is distinct from 0 then raise exception 'version_conflict' using errcode='40001'; end if;
 insert into public.exercises(id,lesson_id,kind,title,grading_mode,pass_percent,published) values(p_exercise_id,p_lesson_id,p_definition->>'kind',p_definition->>'title',p_definition->>'grading_mode',coalesce((p_definition->>'pass_percent')::numeric,100),coalesce((p_definition->>'published')::boolean,false)) returning * into e;
 else
 if e.lesson_id<>p_lesson_id then raise exception 'foreign_exercise' using errcode='42501'; end if;
 if e.version is distinct from p_expected_version then raise exception 'version_conflict' using errcode='40001'; end if;
 update public.exercises set kind=p_definition->>'kind',title=p_definition->>'title',grading_mode=p_definition->>'grading_mode',pass_percent=coalesce((p_definition->>'pass_percent')::numeric,100),published=coalesce((p_definition->>'published')::boolean,false),version=version+1 where id=e.id returning * into e;
 delete from public.questions where exercise_id=e.id;
 end if;
 for item in select value from jsonb_array_elements(p_questions) loop
 qid:=coalesce((item->>'id')::uuid,gen_random_uuid());
 insert into public.questions(id,exercise_id,prompt,position,points) values(qid,e.id,item->'prompt',(item->>'position')::int,coalesce((item->>'points')::numeric,1));
 for opt in select value from jsonb_array_elements(coalesce(item->'options','[]')) loop
 insert into public.question_options(id,question_id,label,position) values(coalesce((opt->>'id')::uuid,gen_random_uuid()),qid,opt->>'label',(opt->>'position')::int); end loop;
 if e.grading_mode='automatic' then
 insert into private.answer_keys(question_id,accepted_answers,comparison) values(qid,item->'accepted_answers',coalesce(item->>'comparison','exact')); end if;
 end loop;
 insert into public.audit_log(actor_id,action,entity_id,details) values(auth.uid(),'exercise_saved',e.id,jsonb_build_object('version',e.version));
 return e;
end $$;
grant execute on function public.record_event(uuid,text,jsonb),public.submit_attempt(uuid,uuid,jsonb),public.complete_lesson(uuid),public.create_assignment(uuid,uuid,text,timestamptz),public.submit_assignment(uuid,int,uuid,jsonb),public.grade_submission(uuid,int,numeric,text),public.review_attempt(uuid,numeric),public.enroll_course(uuid),public.set_group_member(uuid,uuid,boolean),public.create_group(uuid,text),public.create_lesson(uuid,text,int),public.save_lesson(uuid,int,jsonb,jsonb),public.save_exercise(uuid,uuid,int,jsonb,jsonb) to authenticated;
commit;
