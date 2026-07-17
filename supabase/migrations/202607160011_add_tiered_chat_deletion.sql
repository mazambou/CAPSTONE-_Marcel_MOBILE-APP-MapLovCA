-- WhatsApp-style deletion scopes, enforced by the database.
create table if not exists public.message_deletions (
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  deleted_at timestamptz not null default now(),
  primary key (message_id, user_id)
);

alter table public.message_deletions enable row level security;

create policy message_deletions_owner_read
on public.message_deletions for select to authenticated
using (user_id = auth.uid());

grant select on public.message_deletions to authenticated;

create or replace function public.delete_my_message_with_scope(
  target_message uuid,
  delete_for_everyone boolean default false
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  message_row public.messages%rowtype;
  other_read_at timestamptz;
  user_tier text;
begin
  select * into message_row
  from public.messages
  where id = target_message and sender_id = auth.uid();

  if not found or not private.is_conversation_member(message_row.conversation_id) then
    raise exception 'Message unavailable';
  end if;

  if not delete_for_everyone then
    insert into public.message_deletions (message_id, user_id)
    values (target_message, auth.uid())
    on conflict (message_id, user_id)
    do update set deleted_at = excluded.deleted_at;
    return;
  end if;

  user_tier := private.current_subscription_tier(auth.uid())::text;
  select max(cr.last_read_at) into other_read_at
  from public.conversation_reads cr
  where cr.conversation_id = message_row.conversation_id
    and cr.user_id <> auth.uid();

  if user_tier not in ('elite', 'vip')
     and other_read_at is not null
     and message_row.created_at <= other_read_at then
    raise exception 'Only Premium Elite can delete a message after it has been read';
  end if;

  update public.messages
  set body = null, media_path = null, deleted_at = now()
  where id = target_message and sender_id = auth.uid();
end;
$$;

revoke execute on function public.delete_my_message(uuid) from authenticated;
revoke execute on function public.delete_my_message_with_scope(uuid, boolean) from public, anon;
grant execute on function public.delete_my_message_with_scope(uuid, boolean) to authenticated;

create or replace function public.clear_my_conversation_with_scope(
  target_conversation uuid,
  clear_for_everyone boolean default false
)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  cleared_time timestamptz := now();
  other_read_at timestamptz;
  user_tier text;
begin
  if auth.uid() is null
     or not private.is_conversation_member(target_conversation) then
    raise exception 'Conversation unavailable';
  end if;

  if not clear_for_everyone then
    insert into public.conversation_clears (conversation_id, user_id, cleared_at)
    values (target_conversation, auth.uid(), cleared_time)
    on conflict (conversation_id, user_id)
    do update set cleared_at = excluded.cleared_at;
    return cleared_time;
  end if;

  user_tier := private.current_subscription_tier(auth.uid())::text;
  if user_tier = 'free' then
    raise exception 'Premium Plus is required to clear a chat for everyone';
  end if;

  if user_tier = 'plus' then
    insert into public.conversation_clears (conversation_id, user_id, cleared_at)
    values (target_conversation, auth.uid(), cleared_time)
    on conflict (conversation_id, user_id)
    do update set cleared_at = excluded.cleared_at;

    select max(cr.last_read_at) into other_read_at
    from public.conversation_reads cr
    where cr.conversation_id = target_conversation
      and cr.user_id <> auth.uid();

    update public.messages
    set body = null, media_path = null, deleted_at = cleared_time
    where conversation_id = target_conversation
      and sender_id = auth.uid()
      and deleted_at is null
      and (other_read_at is null or created_at > other_read_at);
    return cleared_time;
  end if;

  -- Elite and VIP clear the whole history on both accounts.
  update public.messages
  set body = null, media_path = null, deleted_at = cleared_time
  where conversation_id = target_conversation and deleted_at is null;

  insert into public.conversation_clears (conversation_id, user_id, cleared_at)
  select target_conversation, cm.user_id, cleared_time
  from public.conversation_members cm
  where cm.conversation_id = target_conversation and cm.left_at is null
  on conflict (conversation_id, user_id)
  do update set cleared_at = excluded.cleared_at;

  return cleared_time;
end;
$$;

revoke execute on function public.clear_my_conversation(uuid) from authenticated;
revoke execute on function public.clear_my_conversation_with_scope(uuid, boolean) from public, anon;
grant execute on function public.clear_my_conversation_with_scope(uuid, boolean) to authenticated;
