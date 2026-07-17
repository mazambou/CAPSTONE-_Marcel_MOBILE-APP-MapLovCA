-- Clearing a chat hides its existing history only for the user who clears it.
-- The other participant keeps their copy and future messages remain visible.
create table if not exists public.conversation_clears (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  cleared_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

alter table public.conversation_clears enable row level security;

create policy conversation_clears_owner_read
on public.conversation_clears for select to authenticated
using (user_id = auth.uid());

grant select on public.conversation_clears to authenticated;

create or replace function public.clear_my_conversation(target_conversation uuid)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  cleared_time timestamptz := now();
begin
  if auth.uid() is null
     or not private.is_conversation_member(target_conversation) then
    raise exception 'Conversation unavailable';
  end if;

  insert into public.conversation_clears (conversation_id, user_id, cleared_at)
  values (target_conversation, auth.uid(), cleared_time)
  on conflict (conversation_id, user_id)
  do update set cleared_at = excluded.cleared_at;

  return cleared_time;
end;
$$;

revoke execute on function public.clear_my_conversation(uuid) from public, anon;
grant execute on function public.clear_my_conversation(uuid) to authenticated;
