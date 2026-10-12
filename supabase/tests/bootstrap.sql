-- Test-only Supabase auth/storage facsimile; never deploy this file.
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
create schema auth;
create table auth.users(id uuid primary key, raw_user_meta_data jsonb not null default '{}');
create function auth.uid() returns uuid language sql stable as $$
 select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
grant usage on schema auth to anon,authenticated,service_role;
grant execute on function auth.uid() to anon,authenticated,service_role;
create schema storage;
create table storage.buckets(id text primary key,name text not null,public boolean not null default false,file_size_limit bigint,allowed_mime_types text[]);
create table storage.objects(id uuid primary key,bucket_id text references storage.buckets,name text,owner_id uuid,metadata jsonb);
alter table storage.objects enable row level security;
grant usage on schema storage to anon,authenticated,service_role;
grant select on storage.objects,storage.buckets to anon,authenticated;
grant all on storage.objects,storage.buckets to service_role;
