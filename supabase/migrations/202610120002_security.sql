begin;
create function public.has_server_role(p_role text) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.server_roles where user_id=auth.uid() and role=p_role)
$$;
create function public.teaches_course(p_course uuid) returns boolean language sql stable security definer set search_path='' as $$
 select public.has_server_role('admin') or (public.has_server_role('teacher') and exists(select 1 from public.course_teachers where course_id=p_course and teacher_id=auth.uid()))
$$;
create function public.can_access_course(p_course uuid) returns boolean language sql stable security definer set search_path='' as $$
 select public.teaches_course(p_course) or exists(select 1 from public.courses c where c.id=p_course and c.status='published' and
 (c.access_tier='free' or exists(select 1 from public.entitlements e where e.course_id=c.id and e.user_id=auth.uid() and e.revoked_at is null and e.starts_at<=now() and (e.expires_at is null or e.expires_at>now()))))
$$;
create function public.lesson_course_id(p_lesson uuid) returns uuid language sql stable security definer set search_path='' as $$
 select lv.course_id from public.lessons l join public.units u on u.id=l.unit_id join public.books b on b.id=u.book_id join public.levels lv on lv.id=b.level_id where l.id=p_lesson
$$;
create function public.can_read_lesson(p_lesson uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.lessons l join public.courses c on c.id=public.lesson_course_id(l.id) where l.id=p_lesson and
 (public.teaches_course(c.id) or (l.status='published' and c.status='published' and (l.is_free_sample or public.can_access_course(c.id)))))
$$;
create function public.manages_group(p_group uuid) returns boolean language sql stable security definer set search_path='' as $$
 select public.has_server_role('admin') or exists(select 1 from public.groups g where g.id=p_group and g.teacher_id=auth.uid() and g.archived_at is null and public.teaches_course(g.course_id))
$$;
create function public.is_group_member(p_group uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.group_members m join public.groups g on g.id=m.group_id where m.group_id=p_group and m.student_id=auth.uid() and m.left_at is null and g.archived_at is null and public.has_server_role('student'))
$$;
create function public.teaches_student(p_student uuid,p_course uuid default null) returns boolean language sql stable security definer set search_path='' as $$
 select public.has_server_role('admin') or exists(select 1 from public.group_members m join public.groups g on g.id=m.group_id where m.student_id=p_student and m.left_at is null and g.archived_at is null and (p_course is null or g.course_id=p_course) and public.manages_group(g.id))
$$;
create function public.exercise_course_id(p_exercise uuid) returns uuid language sql stable security definer set search_path='' as $$
 select public.lesson_course_id(lesson_id) from public.exercises where id=p_exercise
$$;
create function public.can_read_exercise(p_exercise uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.exercises e where e.id=p_exercise and public.can_read_lesson(e.lesson_id) and (e.published or public.teaches_course(public.lesson_course_id(e.lesson_id))))
$$;
create function public.can_read_assignment(p_assignment uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.assignments a where a.id=p_assignment and (public.manages_group(a.group_id) or (public.is_group_member(a.group_id) and public.can_read_exercise(a.exercise_id))))
$$;
create function public.can_read_submission(p_submission uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.submissions s join public.assignments a on a.id=s.assignment_id where s.id=p_submission and (s.student_id=auth.uid() or public.manages_group(a.group_id)))
$$;
create function public.can_join_session(p_session uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.live_sessions s join public.groups g on g.id=s.group_id where s.id=p_session and s.cancelled_at is null and g.archived_at is null and (public.manages_group(g.id) or (public.is_group_member(g.id) and public.can_access_course(g.course_id))))
$$;
create function public.can_read_media(p_media uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.media m where m.id=p_media and
 (m.owner_id=auth.uid() or (m.lesson_id is not null and public.can_read_lesson(m.lesson_id)) or exists(select 1 from public.recordings r where r.media_id=m.id and r.available_at<=now() and public.can_join_session(r.session_id))))
$$;

create policy profiles_read on public.profiles for select to authenticated using (id=auth.uid() or public.teaches_student(id) or exists(select 1 from public.groups g where g.teacher_id=profiles.id and public.is_group_member(g.id)));
create policy profiles_update on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
grant select,update(display_name,locale) on public.profiles to authenticated;
create policy roles_own on public.server_roles for select to authenticated using(user_id=auth.uid());
grant select on public.server_roles to authenticated;
create policy teachers_read on public.teachers for select to authenticated using(id=auth.uid() or public.has_server_role('admin') or exists(select 1 from public.groups g where g.teacher_id=teachers.id and public.is_group_member(g.id)));
create policy students_read on public.students for select to authenticated using(id=auth.uid() or public.teaches_student(id));
grant select on public.teachers,public.students to authenticated;
create policy courses_read on public.courses for select to anon,authenticated using(status='published' or public.teaches_course(id));
grant select on public.courses to anon,authenticated;
create policy course_teachers_read on public.course_teachers for select to authenticated using(teacher_id=auth.uid() or public.teaches_course(course_id));
create policy groups_read on public.groups for select to authenticated using(public.manages_group(id) or public.is_group_member(id));
create policy members_read on public.group_members for select to authenticated using(student_id=auth.uid() or public.manages_group(group_id));
grant select on public.course_teachers,public.groups,public.group_members to authenticated;
-- Hierarchy metadata may be browsed for published courses; lesson payload remains protected.
create policy levels_read on public.levels for select to anon,authenticated using(exists(select 1 from public.courses c where c.id=course_id and (c.status='published' or public.teaches_course(c.id))));
create policy books_read on public.books for select to anon,authenticated using(exists(select 1 from public.levels l where l.id=level_id));
create policy units_read on public.units for select to anon,authenticated using(exists(select 1 from public.books b where b.id=book_id));
create policy lessons_read on public.lessons for select to anon,authenticated using(public.can_read_lesson(id));
grant select on public.levels,public.books,public.units,public.lessons to anon,authenticated;

do $$ declare t text; begin
 foreach t in array array['lesson_blocks','dialogues','vocabulary','grammar'] loop
 execute format('create policy content_read on public.%I for select to anon,authenticated using(public.can_read_lesson(lesson_id))',t);
 execute format('create policy content_write on public.%I for all to authenticated using(public.teaches_course(public.lesson_course_id(lesson_id))) with check(public.teaches_course(public.lesson_course_id(lesson_id)))',t);
 execute format('grant select on public.%I to anon,authenticated',t);
 execute format('grant insert,update,delete on public.%I to authenticated',t);
 end loop;
end $$;
create policy lines_read on public.dialogue_lines for select to anon,authenticated using(exists(select 1 from public.dialogues d where d.id=dialogue_id));
create policy lines_write on public.dialogue_lines for all to authenticated using(exists(select 1 from public.dialogues d where d.id=dialogue_id and public.teaches_course(public.lesson_course_id(d.lesson_id)))) with check(exists(select 1 from public.dialogues d where d.id=dialogue_id and public.teaches_course(public.lesson_course_id(d.lesson_id))));
grant select on public.dialogue_lines to anon,authenticated;
grant insert,update,delete on public.dialogue_lines to authenticated;
create policy media_read on public.media for select to authenticated using(public.can_read_media(id));
grant select on public.media to authenticated;
create policy exercises_read on public.exercises for select to authenticated using(public.can_read_exercise(id));
create policy questions_read on public.questions for select to authenticated using(public.can_read_exercise(exercise_id));
create policy options_read on public.question_options for select to authenticated using(exists(select 1 from public.questions q where q.id=question_id));
grant select on public.exercises,public.questions,public.question_options to authenticated;
create policy attempts_read on public.attempts for select to authenticated using(student_id=auth.uid() or public.teaches_student(student_id,public.exercise_course_id(exercise_id)));
create policy assignments_read on public.assignments for select to authenticated using(public.can_read_assignment(id));
create policy submissions_read on public.submissions for select to authenticated using(public.can_read_submission(id));
create policy history_read on public.submission_history for select to authenticated using(public.can_read_submission(submission_id));
create policy grades_read on public.grades for select to authenticated using(public.can_read_submission(submission_id));
create policy feedback_read on public.feedback for select to authenticated using(exists(select 1 from public.grades g where g.id=grade_id and public.can_read_submission(g.submission_id)));
grant select on public.attempts,public.assignments,public.submissions,public.submission_history,public.grades,public.feedback to authenticated;
create policy enrollments_read on public.enrollments for select to authenticated using(student_id=auth.uid() or public.teaches_student(student_id,course_id));
grant select on public.enrollments to authenticated;
create policy products_read on public.products for select to authenticated using(active);
create policy product_courses_read on public.product_courses for select to authenticated using(exists(select 1 from public.products p where p.id=product_id and p.active));
grant select on public.products,public.product_courses to authenticated;
do $$ declare t text; begin
 foreach t in array array['purchases','subscriptions','entitlements','notifications','events','user_settings'] loop
 execute format('create policy own_read on public.%I for select to authenticated using(user_id=auth.uid())',t);
 execute format('grant select on public.%I to authenticated',t);
 end loop;
end $$;
create policy settings_insert on public.user_settings for insert to authenticated with check(user_id=auth.uid());
create policy settings_update on public.user_settings for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
grant insert,update on public.user_settings to authenticated;
create policy notifications_update on public.notifications for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
grant update(read_at) on public.notifications to authenticated;
create policy progress_read on public.study_progress for select to authenticated using(student_id=auth.uid() or public.teaches_student(student_id,public.lesson_course_id(lesson_id)));
create policy reviews_read on public.vocabulary_reviews for select to authenticated using(student_id=auth.uid());
create policy reviews_write on public.vocabulary_reviews for all to authenticated using(student_id=auth.uid()) with check(student_id=auth.uid() and exists(select 1 from public.vocabulary v where v.id=vocabulary_id and public.can_read_lesson(v.lesson_id)));
grant select on public.study_progress,public.vocabulary_reviews to authenticated;
grant insert,update,delete on public.vocabulary_reviews to authenticated;
create policy bookmarks_read on public.bookmarks for select to authenticated using(user_id=auth.uid());
create policy bookmarks_insert on public.bookmarks for insert to authenticated with check(user_id=auth.uid() and public.can_read_lesson(lesson_id));
create policy bookmarks_delete on public.bookmarks for delete to authenticated using(user_id=auth.uid());
grant select,insert,delete on public.bookmarks to authenticated;
create policy sessions_read on public.live_sessions for select to authenticated using(public.can_join_session(id));
create policy participants_read on public.session_participants for select to authenticated using(user_id=auth.uid() or exists(select 1 from public.live_sessions s where s.id=session_id and public.manages_group(s.group_id)));
create policy recordings_read on public.recordings for select to authenticated using(public.can_join_session(session_id) and available_at<=now());
grant select on public.live_sessions,public.session_participants,public.recordings to authenticated;
create policy audit_admin on public.audit_log for select to authenticated using(public.has_server_role('admin'));
grant select on public.audit_log to authenticated;

-- Auth metadata is never a role source. Every new account starts as a student.
create function private.on_user_created() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.profiles(id) values(new.id);
 insert into public.students(id) values(new.id);
 insert into public.server_roles(user_id,role) values(new.id,'student');
 insert into public.user_settings(user_id) values(new.id);
 return new;
end $$;
create trigger academy_new_user after insert on auth.users for each row execute function private.on_user_created();
insert into public.profiles(id) select id from auth.users on conflict do nothing;
insert into public.students(id) select id from public.profiles on conflict do nothing;
insert into public.server_roles(user_id,role) select id,'student' from public.profiles on conflict do nothing;
insert into public.user_settings(user_id) select id from public.profiles on conflict do nothing;
grant execute on all functions in schema public to authenticated;
grant execute on function public.has_server_role(text),public.teaches_course(uuid),public.can_access_course(uuid),public.lesson_course_id(uuid),public.can_read_lesson(uuid) to anon;
commit;
