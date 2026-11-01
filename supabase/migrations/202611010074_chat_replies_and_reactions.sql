create table public.message_reactions (
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  emoji text not null check (char_length(emoji) between 1 and 16),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (message_id,user_id)
);
create index message_reactions_user_idx on public.message_reactions(user_id);
alter table public.message_reactions enable row level security;

create or replace function private.can_react_to_message(target_message uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.messages m
    where m.id=target_message and m.deleted_at is null
      and private.is_conversation_member(m.conversation_id)
      and not exists (
        select 1 from public.conversation_members cm
        where cm.conversation_id=m.conversation_id and cm.user_id<>auth.uid()
          and private.is_blocked_between(auth.uid(),cm.user_id)
      )
  );
$$;

create policy message_reactions_member_read on public.message_reactions
  for select to authenticated using (
    exists(select 1 from public.messages m where m.id=message_id
           and private.is_conversation_member(m.conversation_id))
  );
create policy message_reactions_owner_insert on public.message_reactions
  for insert to authenticated with check (
    user_id=auth.uid() and private.can_react_to_message(message_id)
  );
create policy message_reactions_owner_update on public.message_reactions
  for update to authenticated using (
    user_id=auth.uid() and private.can_react_to_message(message_id)
  ) with check (
    user_id=auth.uid() and private.can_react_to_message(message_id)
  );
create policy message_reactions_owner_delete on public.message_reactions
  for delete to authenticated using (user_id=auth.uid());
grant select,insert,update,delete on public.message_reactions to authenticated;

create or replace function private.guard_chat_action()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  chat_id uuid;
  other_user uuid;
begin
  if tg_table_name='messages' then
    if auth.role()='service_role' or new.kind::text='system' then return new; end if;
    chat_id:=new.conversation_id;
    if new.reply_to_id is not null and not exists (
      select 1 from public.messages original
      where original.id=new.reply_to_id and original.conversation_id=chat_id
    ) then raise exception 'Reply target is unavailable'; end if;
  else
    select m.conversation_id into chat_id
    from public.messages m where m.id=new.message_id;
  end if;
  select cm.user_id into other_user from public.conversation_members cm
  where cm.conversation_id=chat_id and cm.user_id<>auth.uid()
    and cm.left_at is null limit 1;
  if other_user is not null then
    perform private.lock_conversation_pair(auth.uid(),other_user);
    if private.is_blocked_between(auth.uid(),other_user) then
      raise exception 'CHAT_BLOCKED';
    end if;
  end if;
  return new;
end;
$$;
create trigger guard_message_send
before insert on public.messages
for each row execute function private.guard_chat_action();
create trigger guard_message_reaction
before insert or update on public.message_reactions
for each row execute function private.guard_chat_action();
