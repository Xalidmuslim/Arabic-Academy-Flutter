begin;
create function private.valid_source_locator(p_locator jsonb) returns boolean language plpgsql immutable set search_path='' as $$
declare k text;n numeric;begin
 if p_locator is null then return true;end if;
 if jsonb_typeof(p_locator)<>'object' or pg_column_size(p_locator)>4096 then return false;end if;
 foreach k in array array['page','page_start','page_end'] loop
 if p_locator?k then
 if jsonb_typeof(p_locator->k)<>'number' then return false;end if;
 n:=(p_locator->>k)::numeric;if n<=0 or n<>trunc(n) or n>1000000 then return false;end if;
 end if;end loop;
 if p_locator?'page_start' and p_locator?'page_end' and (p_locator->>'page_end')::numeric<(p_locator->>'page_start')::numeric then return false;end if;
 if p_locator?'edition' and (jsonb_typeof(p_locator->'edition')<>'string' or length(btrim(p_locator->>'edition')) not between 1 and 200) then return false;end if;
 if p_locator?'pdf_sha256' and (jsonb_typeof(p_locator->'pdf_sha256')<>'string' or (p_locator->>'pdf_sha256')!~'^[a-fA-F0-9]{64}$') then return false;end if;
 return true;
 exception when others then return false;
end $$;
alter table public.books add column source_locator jsonb check(private.valid_source_locator(source_locator));
alter table public.lessons add column source_locator jsonb check(private.valid_source_locator(source_locator));
do $$declare t text;begin
 foreach t in array array['vocabulary','grammar'] loop
 execute format('alter table public.%I add column root text check(length(root)<=80), add column part_of_speech text check(length(part_of_speech)<=100), add column gender text check(length(gender)<=32), add column number text check(length(number)<=32), add column forms jsonb check(forms is null or jsonb_typeof(forms) in (''object'',''array'')), add column example_ar text, add column example_translation text, add column level text check(length(level)<=80)',t);
 end loop;
end $$;
alter table public.lesson_blocks drop constraint lesson_blocks_step_check;
alter table public.lesson_blocks add constraint lesson_blocks_step_check check(step in ('introduction','dialogue','vocabulary','grammar','practice','test','homework'));
create function public.set_book_source(p_book_id uuid,p_source_locator jsonb) returns public.books
language plpgsql security definer set search_path='' as $$
declare r public.books;cid uuid;begin
 select l.course_id into cid from public.books b join public.levels l on l.id=b.level_id where b.id=p_book_id;
 if cid is null or not public.teaches_course(cid) then raise exception 'teacher_required' using errcode='42501';end if;
 if not private.valid_source_locator(p_source_locator) then raise exception 'invalid_source_locator';end if;
 update public.books set source_locator=p_source_locator where id=p_book_id returning * into r;return r;
end $$;
grant execute on function public.set_book_source(uuid,jsonb) to authenticated;
create or replace function public.save_lesson(p_lesson_id uuid,p_expected_version int,p_patch jsonb,p_content jsonb default null) returns public.lessons
language plpgsql security definer set search_path='' as $$
declare l public.lessons; item jsonb; line jsonb; d uuid;
begin
 select * into l from public.lessons where id=p_lesson_id for update;
 if l.id is null or not public.teaches_course(public.lesson_course_id(l.id)) then raise exception 'teacher_required' using errcode='42501'; end if;
 if l.version is distinct from p_expected_version then raise exception 'version_conflict' using errcode='40001'; end if;
 if jsonb_typeof(p_patch)<>'object' or p_patch is null or exists(select 1 from jsonb_object_keys(p_patch) k where k not in ('title','title_ar','goal','status','is_free_sample','position','source_locator')) then raise exception 'invalid_patch'; end if;
 if p_patch ? 'source_locator' and not private.valid_source_locator(nullif(p_patch->'source_locator','null'::jsonb)) then raise exception 'invalid_source_locator';end if;
 update public.lessons set source_locator=case when p_patch?'source_locator' then nullif(p_patch->'source_locator','null'::jsonb) else source_locator end,title=coalesce(p_patch->>'title',title),title_ar=coalesce(p_patch->>'title_ar',title_ar),goal=coalesce(p_patch->>'goal',goal),status=coalesce(p_patch->>'status',status),is_free_sample=coalesce((p_patch->>'is_free_sample')::boolean,is_free_sample),position=coalesce((p_patch->>'position')::int,position),version=version+1,updated_at=now() where id=l.id returning * into l;
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
 insert into public.vocabulary(id,lesson_id,text_ar,translation,transliteration,position,root,part_of_speech,gender,number,forms,example_ar,example_translation,level) values(coalesce((item->>'id')::uuid,gen_random_uuid()),l.id,item->>'text_ar',item->>'translation',item->>'transliteration',(item->>'position')::int,item->>'root',item->>'part_of_speech',item->>'gender',item->>'number',nullif(item->'forms','null'::jsonb),item->>'example_ar',item->>'example_translation',item->>'level')
 on conflict(id) do update set text_ar=excluded.text_ar,translation=excluded.translation,transliteration=excluded.transliteration,position=excluded.position,retired_at=null,root=excluded.root,part_of_speech=excluded.part_of_speech,gender=excluded.gender,number=excluded.number,forms=excluded.forms,example_ar=excluded.example_ar,example_translation=excluded.example_translation,level=excluded.level where vocabulary.lesson_id=l.id;
 if not found then raise exception 'foreign_content_id' using errcode='42501'; end if;
 end loop;
 end if;
 if p_content ? 'grammar' then
 delete from public.grammar where lesson_id=l.id;
 for item in select value from jsonb_array_elements(p_content->'grammar') loop
 insert into public.grammar(id,lesson_id,title,explanation,examples,position,root,part_of_speech,gender,number,forms,example_ar,example_translation,level) values(coalesce((item->>'id')::uuid,gen_random_uuid()),l.id,item->>'title',item->>'explanation',coalesce(item->'examples','[]'),(item->>'position')::int,item->>'root',item->>'part_of_speech',item->>'gender',item->>'number',nullif(item->'forms','null'::jsonb),item->>'example_ar',item->>'example_translation',item->>'level'); end loop;
 end if;
 end if;
 insert into public.audit_log(actor_id,action,entity_id,details) values(auth.uid(),'lesson_saved',l.id,jsonb_build_object('version',l.version));
 return l;
end $$;
commit;
