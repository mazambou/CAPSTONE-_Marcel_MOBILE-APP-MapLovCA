alter table public.message_reactions
  add column conversation_id uuid references public.conversations(id) on delete cascade;
update public.message_reactions reaction
set conversation_id=message.conversation_id
from public.messages message
where message.id=reaction.message_id;
alter table public.message_reactions alter column conversation_id set not null;
create index message_reactions_conversation_idx
  on public.message_reactions(conversation_id,message_id);

create or replace function private.set_reaction_conversation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.conversation_id := (
    select conversation_id from public.messages where id=new.message_id
  );
  if new.conversation_id is null then raise exception 'Message unavailable'; end if;
  return new;
end;
$$;
create trigger set_reaction_conversation
before insert or update on public.message_reactions
for each row execute function private.set_reaction_conversation();
