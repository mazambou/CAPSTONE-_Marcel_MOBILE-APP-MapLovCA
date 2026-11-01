-- Serialize block changes with shared-message deletion. A deletion that starts
-- after a block commits can never change the other participant's copy.
create or replace function private.lock_conversation_pair(first_id uuid, second_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
begin
  perform pg_advisory_xact_lock(
    hashtextextended(
      least(first_id::text, second_id::text) || ':' ||
      greatest(first_id::text, second_id::text), 0
    )
  );
end;
$$;

create or replace function private.lock_block_pair()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  perform private.lock_conversation_pair(
    coalesce(new.blocker_id, old.blocker_id),
    coalesce(new.blocked_id, old.blocked_id)
  );
  return coalesce(new, old);
end;
$$;

create trigger lock_block_pair
before insert or delete on public.blocks
for each row execute function private.lock_block_pair();

create or replace function public.chat_block_state(other_user uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  mine boolean;
  theirs boolean;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select exists(select 1 from public.blocks where blocker_id=auth.uid() and blocked_id=other_user),
         exists(select 1 from public.blocks where blocker_id=other_user and blocked_id=auth.uid())
    into mine, theirs;
  if mine and theirs then return 'mutual'; end if;
  if mine then return 'outgoing'; end if;
  if theirs then return 'incoming'; end if;
  return 'none';
end;
$$;
revoke execute on function public.chat_block_state(uuid) from public, anon;
grant execute on function public.chat_block_state(uuid) to authenticated;

create or replace function public.delete_my_message_with_scope(
  target_message uuid, delete_for_everyone boolean default false
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  message_row public.messages%rowtype;
  other_user uuid;
  other_read_at timestamptz;
  user_tier text;
begin
  select * into message_row from public.messages
  where id=target_message
  for update;
  if not found or not private.is_conversation_member(message_row.conversation_id) then
    raise exception 'Message unavailable';
  end if;
  if not delete_for_everyone then
    insert into public.message_deletions(message_id,user_id)
    values(target_message,auth.uid())
    on conflict(message_id,user_id) do update set deleted_at=excluded.deleted_at;
    return;
  end if;
  if message_row.sender_id <> auth.uid() then
    raise exception 'Only the sender can delete this message for everyone';
  end if;
  select cm.user_id into other_user from public.conversation_members cm
  where cm.conversation_id=message_row.conversation_id and cm.user_id<>auth.uid()
    and cm.left_at is null limit 1;
  if other_user is not null then
    perform private.lock_conversation_pair(auth.uid(),other_user);
    if private.is_blocked_between(auth.uid(),other_user) then
      raise exception 'SHARED_DELETION_BLOCKED';
    end if;
  end if;
  user_tier:=private.current_subscription_tier(auth.uid())::text;
  select max(cr.last_read_at) into other_read_at from public.conversation_reads cr
  where cr.conversation_id=message_row.conversation_id and cr.user_id<>auth.uid();
  if user_tier not in ('elite','vip') and other_read_at is not null
    and message_row.created_at<=other_read_at then
    raise exception 'Only Premium Elite can delete a message after it has been read';
  end if;
  update public.messages set body=null,media_path=null,deleted_at=now()
  where id=target_message and sender_id=auth.uid();
end;
$$;

create or replace function public.clear_my_conversation_with_scope(
  target_conversation uuid, clear_for_everyone boolean default false
)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  cleared_time timestamptz:=now();
  other_user uuid;
  other_read_at timestamptz;
  user_tier text;
begin
  if auth.uid() is null or not private.is_conversation_member(target_conversation) then
    raise exception 'Conversation unavailable';
  end if;
  if not clear_for_everyone then
    insert into public.conversation_clears(conversation_id,user_id,cleared_at)
    values(target_conversation,auth.uid(),cleared_time)
    on conflict(conversation_id,user_id) do update set cleared_at=excluded.cleared_at;
    return cleared_time;
  end if;
  select cm.user_id into other_user from public.conversation_members cm
  where cm.conversation_id=target_conversation and cm.user_id<>auth.uid()
    and cm.left_at is null limit 1;
  if other_user is not null then
    perform private.lock_conversation_pair(auth.uid(),other_user);
    if private.is_blocked_between(auth.uid(),other_user) then
      raise exception 'SHARED_DELETION_BLOCKED';
    end if;
  end if;
  user_tier:=private.current_subscription_tier(auth.uid())::text;
  if user_tier='free' then raise exception 'Premium Plus is required to clear a chat for everyone'; end if;
  if user_tier='plus' then
    insert into public.conversation_clears(conversation_id,user_id,cleared_at)
    values(target_conversation,auth.uid(),cleared_time)
    on conflict(conversation_id,user_id) do update set cleared_at=excluded.cleared_at;
    select max(cr.last_read_at) into other_read_at from public.conversation_reads cr
    where cr.conversation_id=target_conversation and cr.user_id<>auth.uid();
    update public.messages set body=null,media_path=null,deleted_at=cleared_time
    where conversation_id=target_conversation and sender_id=auth.uid()
      and deleted_at is null and (other_read_at is null or created_at>other_read_at);
    return cleared_time;
  end if;
  update public.messages set body=null,media_path=null,deleted_at=cleared_time
  where conversation_id=target_conversation and deleted_at is null;
  insert into public.conversation_clears(conversation_id,user_id,cleared_at)
  select target_conversation,cm.user_id,cleared_time from public.conversation_members cm
  where cm.conversation_id=target_conversation and cm.left_at is null
  on conflict(conversation_id,user_id) do update set cleared_at=excluded.cleared_at;
  return cleared_time;
end;
$$;
