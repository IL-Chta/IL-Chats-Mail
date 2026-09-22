-- IL Chats Mail — padronização das novas caixas para @ilchats.com.br
-- NÃO altera nem apaga a conta administrativa antiga @ilchats.com.

create or replace function public.is_mailbox_taken(p_handle text)
returns boolean
language sql
security definer
set search_path=auth,public
as $$
  select exists(
    select 1 from auth.users
    where lower(email)=lower(trim(p_handle)||'@ilchats.com.br')
  );
$$;
revoke all on function public.is_mailbox_taken(text) from public;
grant execute on function public.is_mailbox_taken(text) to anon,authenticated;

create or replace function public.resolve_mail_recipient(p_email text)
returns uuid
language sql
security definer
set search_path=auth,public
as $$
  select u.id
  from auth.users u
  where lower(u.email)=lower(trim(p_email))
    and u.email_confirmed_at is not null
  limit 1
$$;
revoke all on function public.resolve_mail_recipient(text) from public;
grant execute on function public.resolve_mail_recipient(text) to authenticated;
