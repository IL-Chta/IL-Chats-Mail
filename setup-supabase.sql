-- IL Chats Mail v5 — executar UMA VEZ no SQL Editor do projeto IL Chats Mail.
-- Não execute no projeto IL Chats/Bate-papos IL.

create extension if not exists pgcrypto;

alter table public.messages add column if not exists sender_email text;
alter table public.messages add column if not exists recipient_email text;
alter table public.messages add column if not exists body text;

alter table public.messages enable row level security;
drop policy if exists "mail participants read" on public.messages;
create policy "mail participants read" on public.messages for select to authenticated
using (sender_id=auth.uid() or recipient_id=auth.uid());

-- Estados individuais por usuário: inbox/sent/trash, lida e favorita.
create table if not exists public.message_states (
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  folder text not null check (folder in ('inbox','sent','trash','spam')),
  previous_folder text,
  is_starred boolean not null default false,
  is_read boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (message_id,user_id)
);
alter table public.message_states enable row level security;
drop policy if exists "mail state select own" on public.message_states;
create policy "mail state select own" on public.message_states for select to authenticated using (user_id=auth.uid());
drop policy if exists "mail state update own" on public.message_states;
create policy "mail state update own" on public.message_states for update to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
drop policy if exists "mail state delete own" on public.message_states;
create policy "mail state delete own" on public.message_states for delete to authenticated using (user_id=auth.uid());

-- Rascunhos ficam privados ao dono.
create table if not exists public.drafts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  to_email text,
  subject text,
  body text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.drafts enable row level security;
drop policy if exists "drafts own all" on public.drafts;
create policy "drafts own all" on public.drafts for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());

-- Envio interno seguro: somente para outro usuário cadastrado no IL Chats Mail.
create or replace function public.send_internal_mail(p_to_email text,p_subject text,p_body text)
returns uuid
language plpgsql
security definer
set search_path=public,auth
as $$
declare
  v_sender uuid:=auth.uid();
  v_recipient uuid;
  v_sender_email text;
  v_message uuid;
begin
  if v_sender is null then raise exception 'NOT_AUTHENTICATED'; end if;
  select id into v_recipient from auth.users where lower(email)=lower(trim(p_to_email)) and email_confirmed_at is not null limit 1;
  if v_recipient is null then raise exception 'RECIPIENT_NOT_FOUND'; end if;
  select email into v_sender_email from auth.users where id=v_sender;
  insert into public.messages(sender_id,recipient_id,sender_email,recipient_email,subject,body)
  values(v_sender,v_recipient,v_sender_email,lower(trim(p_to_email)),coalesce(nullif(trim(p_subject),''),'(sem assunto)'),coalesce(p_body,''))
  returning id into v_message;
  insert into public.message_states(message_id,user_id,folder,is_read) values
    (v_message,v_sender,'sent',true),
    (v_message,v_recipient,'inbox',false);
  return v_message;
end;$$;
revoke all on function public.send_internal_mail(text,text,text) from public;
grant execute on function public.send_internal_mail(text,text,text) to authenticated;

create or replace function public.delete_message_for_me(p_message_id uuid)
returns void language plpgsql security definer set search_path=public
as $$
begin
  delete from public.message_states where message_id=p_message_id and user_id=auth.uid();
  if not exists(select 1 from public.message_states where message_id=p_message_id) then
    delete from public.messages where id=p_message_id;
  end if;
end;$$;
revoke all on function public.delete_message_for_me(uuid) from public;
grant execute on function public.delete_message_for_me(uuid) to authenticated;

-- Índices.
create index if not exists idx_message_states_user_folder on public.message_states(user_id,folder,updated_at desc);
create index if not exists idx_messages_sender on public.messages(sender_id,created_at desc);
create index if not exists idx_messages_recipient on public.messages(recipient_id,created_at desc);
create index if not exists idx_drafts_user on public.drafts(user_id,updated_at desc);

-- Administração. Para tornar sua conta administradora, após descobrir seu UUID em Authentication > Users,
-- execute: insert into public.admins(user_id) values ('SEU-UUID-AQUI') on conflict do nothing;
create table if not exists public.admins(user_id uuid primary key references auth.users(id) on delete cascade);
alter table public.admins enable row level security;
drop policy if exists "admins see self" on public.admins;
create policy "admins see self" on public.admins for select to authenticated using(user_id=auth.uid());

create table if not exists public.visits(
  id bigint generated always as identity primary key,
  user_id uuid references auth.users(id) on delete cascade,
  country_code text,
  locale text,
  visited_at timestamptz not null default now()
);
alter table public.visits enable row level security;
drop policy if exists "visits insert self" on public.visits;
create policy "visits insert self" on public.visits for insert to authenticated with check(user_id=auth.uid());

create or replace function public.admin_dashboard()
returns jsonb language plpgsql security definer set search_path=public,auth
as $$
declare result jsonb;
begin
  if not exists(select 1 from public.admins where user_id=auth.uid()) then raise exception 'ADMIN_ONLY'; end if;
  select jsonb_build_object(
    'registered_accounts',(select count(*) from auth.users),
    'active_7d',(select count(*) from auth.users where last_sign_in_at>=now()-interval '7 days'),
    'messages_sent',(select count(*) from public.messages),
    'visits',(select count(*) from public.visits),
    'countries',coalesce((select jsonb_agg(x order by (x->>'count')::int desc) from (select jsonb_build_object('country_code',coalesce(country_code,'--'),'count',count(*)) x from public.visits group by country_code) s),'[]'::jsonb)
  ) into result;
  return result;
end;$$;
revoke all on function public.admin_dashboard() from public;
grant execute on function public.admin_dashboard() to authenticated;

-- v6 — funil de leads/clientes e base para entrega externa.
create table if not exists public.leads (
  id uuid primary key default gen_random_uuid(),
  email text,
  name text,
  status text not null default 'lead' check (status in ('lead','qualified','customer','lost')),
  source text,
  created_at timestamptz not null default now(),
  converted_at timestamptz
);
alter table public.leads enable row level security;
-- Nenhuma policy pública: acesso somente por funções administrativas/backend confiável.

alter table public.messages add column if not exists direction text default 'internal' check (direction in ('internal','outbound','inbound'));
alter table public.messages add column if not exists provider text;
alter table public.messages add column if not exists provider_message_id text;
alter table public.messages add column if not exists delivery_status text default 'stored';
alter table public.messages add column if not exists in_reply_to text;

create table if not exists public.email_attachments (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages(id) on delete cascade,
  owner_id uuid references auth.users(id) on delete cascade,
  filename text not null,
  content_type text,
  storage_path text not null,
  size_bytes bigint,
  created_at timestamptz not null default now()
);
alter table public.email_attachments enable row level security;
drop policy if exists "attachments participants read" on public.email_attachments;
create policy "attachments participants read" on public.email_attachments for select to authenticated
using (exists(select 1 from public.messages m where m.id=message_id and (m.sender_id=auth.uid() or m.recipient_id=auth.uid())));

create or replace function public.admin_dashboard()
returns jsonb language plpgsql security definer set search_path=public,auth
as $$
declare result jsonb;
begin
  if not exists(select 1 from public.admins where user_id=auth.uid()) then raise exception 'ADMIN_ONLY'; end if;
  select jsonb_build_object(
    'registered_accounts',(select count(*) from auth.users),
    'active_7d',(select count(*) from auth.users where last_sign_in_at>=now()-interval '7 days'),
    'messages_sent',(select count(*) from public.messages),
    'visits',(select count(*) from public.visits),
    'leads',(select count(*) from public.leads),
    'customers',(select count(*) from public.leads where status='customer'),
    'lead_conversion',case when (select count(*) from public.leads)>0 then round(100.0*(select count(*) from public.leads where status='customer')/(select count(*) from public.leads),1) else 0 end,
    'countries',coalesce((select jsonb_agg(x order by (x->>'count')::int desc) from (select jsonb_build_object('country_code',coalesce(country_code,'--'),'count',count(*)) x from public.visits group by country_code) s),'[]'::jsonb)
  ) into result;
  return result;
end;$$;
revoke all on function public.admin_dashboard() from public;
grant execute on function public.admin_dashboard() to authenticated;
