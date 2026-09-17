-- IL Chats Mail v11 — complemento seguro para a cópia recuperada.
-- Execute SOMENTE no projeto Supabase IL Chats Mail, depois de backup.
create extension if not exists pgcrypto;

-- Perfil: a tabela profiles já existia no projeto-base.
alter table public.profiles add column if not exists name text;
alter table public.profiles add column if not exists email text;
alter table public.profiles add column if not exists avatar_url text;
alter table public.profiles add column if not exists signature_text text;
alter table public.profiles add column if not exists signature_logo_url text;
alter table public.profiles add column if not exists updated_at timestamptz not null default now();
alter table public.profiles enable row level security;
drop policy if exists "profile owner read" on public.profiles;
create policy "profile owner read" on public.profiles for select to authenticated using(id=auth.uid());
drop policy if exists "profile owner insert" on public.profiles;
create policy "profile owner insert" on public.profiles for insert to authenticated with check(id=auth.uid());
drop policy if exists "profile owner update" on public.profiles;
create policy "profile owner update" on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
-- O app precisa localizar destinatário pelo e-mail, sem expor a lista completa via UI.
drop policy if exists "authenticated lookup profiles" on public.profiles;
create policy "authenticated lookup profiles" on public.profiles for select to authenticated using(true);

-- Utilitários pessoais.
create table if not exists public.contacts(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,name text not null,email text not null,phone text,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(user_id,email));
alter table public.contacts enable row level security;
drop policy if exists "contacts own all" on public.contacts;
create policy "contacts own all" on public.contacts for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());

create table if not exists public.calendar_events(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,title text not null,description text,starts_at timestamptz not null,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
alter table public.calendar_events enable row level security;
drop policy if exists "calendar own all" on public.calendar_events;
create policy "calendar own all" on public.calendar_events for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());

create table if not exists public.notes(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,title text not null,body text not null default '',created_at timestamptz not null default now(),updated_at timestamptz not null default now());
alter table public.notes enable row level security;
drop policy if exists "notes own all" on public.notes;
create policy "notes own all" on public.notes for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());

-- Storage: anexos privados e avatar público. Buckets podem ser criados de forma idempotente.
insert into storage.buckets(id,name,public,file_size_limit) values('mail-attachments','mail-attachments',false,26214400) on conflict(id) do update set file_size_limit=excluded.file_size_limit;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('profile-avatars','profile-avatars',true,5242880,array['image/jpeg','image/png','image/webp','image/gif']) on conflict(id) do update set public=true,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "mail attachment owner upload" on storage.objects;
create policy "mail attachment owner upload" on storage.objects for insert to authenticated with check(bucket_id='mail-attachments' and exists(select 1 from public.messages m where m.id=(storage.foldername(name))[1]::uuid and m.sender_id=auth.uid()));
drop policy if exists "mail attachment participant read" on storage.objects;
create policy "mail attachment participant read" on storage.objects for select to authenticated using(bucket_id='mail-attachments' and exists(select 1 from public.email_attachments a join public.messages m on m.id=a.message_id where a.storage_path=name and (m.sender_id=auth.uid() or m.recipient_id=auth.uid())));
drop policy if exists "avatar owner upload" on storage.objects;
create policy "avatar owner upload" on storage.objects for insert to authenticated with check(bucket_id='profile-avatars' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "avatar owner update" on storage.objects;
create policy "avatar owner update" on storage.objects for update to authenticated using(bucket_id='profile-avatars' and (storage.foldername(name))[1]=auth.uid()::text) with check(bucket_id='profile-avatars' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "avatar public read" on storage.objects;
create policy "avatar public read" on storage.objects for select to public using(bucket_id='profile-avatars');

create index if not exists idx_contacts_user_name on public.contacts(user_id,name);
create index if not exists idx_calendar_user_start on public.calendar_events(user_id,starts_at);
create index if not exists idx_notes_user_updated on public.notes(user_id,updated_at desc);
