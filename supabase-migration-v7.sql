-- IL Chats Mail v7 — complementos necessários ao front-end atual.
-- Execute somente no projeto Supabase do IL Chats Mail, após revisar/ter backup.
create extension if not exists pgcrypto;

-- Colunas usadas pelo app.js e pela Edge Function de envio externo.
alter table public.messages add column if not exists thread_id uuid;
alter table public.messages add column if not exists to_emails text[] default '{}';
alter table public.messages add column if not exists cc_emails text[] default '{}';
alter table public.messages add column if not exists bcc_emails text[] default '{}';
alter table public.messages add column if not exists status text default 'stored';
alter table public.messages add column if not exists sent_at timestamptz;
alter table public.messages add column if not exists failed_at timestamptz;
alter table public.messages add column if not exists failure_reason text;
alter table public.messages add column if not exists external_message_id text;

-- Permite ao remetente criar seu próprio rascunho de mensagem.
drop policy if exists "sender insert message" on public.messages;
create policy "sender insert message" on public.messages for insert to authenticated
with check (sender_id=auth.uid());

drop policy if exists "sender update own message" on public.messages;
create policy "sender update own message" on public.messages for update to authenticated
using (sender_id=auth.uid()) with check (sender_id=auth.uid());

-- Anexos: tabela única usada pelo front-end e pelas funções.
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
drop policy if exists "attachment owner insert" on public.email_attachments;
create policy "attachment owner insert" on public.email_attachments for insert to authenticated with check(owner_id=auth.uid());
drop policy if exists "attachments participants read" on public.email_attachments;
create policy "attachments participants read" on public.email_attachments for select to authenticated using (
 owner_id=auth.uid() or exists(select 1 from public.messages m where m.id=message_id and (m.sender_id=auth.uid() or m.recipient_id=auth.uid()))
);

-- Verificação pública de disponibilidade do endereço sem expor usuários.
create or replace function public.is_mailbox_taken(p_handle text)
returns boolean language sql security definer set search_path=auth,public as $$
 select exists(select 1 from auth.users where lower(email)=lower(trim(p_handle)||'@ilchats.com'));
$$;
revoke all on function public.is_mailbox_taken(text) from public;
grant execute on function public.is_mailbox_taken(text) to anon,authenticated;

-- Credencial de recuperação (somente hash; nunca armazena o código em texto puro).
create table if not exists public.recovery_credentials(
 user_id uuid primary key references auth.users(id) on delete cascade,
 recovery_hash text not null,
 updated_at timestamptz not null default now()
);
alter table public.recovery_credentials enable row level security;
drop policy if exists "recovery owner insert" on public.recovery_credentials;
create policy "recovery owner insert" on public.recovery_credentials for insert to authenticated with check(user_id=auth.uid());
drop policy if exists "recovery owner update" on public.recovery_credentials;
create policy "recovery owner update" on public.recovery_credentials for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());

-- Finaliza uma mensagem interna já criada pelo próprio remetente.
create or replace function public.finalize_internal_message(p_message_id uuid)
returns void language plpgsql security definer set search_path=public,auth as $$
declare m public.messages%rowtype;
begin
 select * into m from public.messages where id=p_message_id and sender_id=auth.uid();
 if m.id is null then raise exception 'MESSAGE_NOT_FOUND'; end if;
 if m.recipient_id is null then raise exception 'RECIPIENT_NOT_FOUND'; end if;
 update public.messages set status='sent',sent_at=now(),direction='internal' where id=m.id;
 insert into public.message_states(message_id,user_id,folder,is_read) values
   (m.id,m.sender_id,'sent',true),(m.id,m.recipient_id,'inbox',false)
 on conflict(message_id,user_id) do update set folder=excluded.folder,is_read=excluded.is_read,updated_at=now();
end;$$;
revoke all on function public.finalize_internal_message(uuid) from public;
grant execute on function public.finalize_internal_message(uuid) to authenticated;
