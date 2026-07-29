-- Dynamic unread-message badges and opt-in defaults for new profiles.

begin;

alter table public.profiles
  alter column allow_international_discovery set default true,
  alter column show_origin_on_profile set default true;

create or replace function public.my_unread_message_count()
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::bigint
  from public.conversation_members membership
  join public.messages message
    on message.conversation_id = membership.conversation_id
  left join public.conversation_reads reading
    on reading.conversation_id = membership.conversation_id
   and reading.user_id = membership.user_id
  left join public.conversation_clears clearing
    on clearing.conversation_id = membership.conversation_id
   and clearing.user_id = membership.user_id
  where membership.user_id = auth.uid()
    and membership.left_at is null
    and message.sender_id <> auth.uid()
    and message.deleted_at is null
    and message.created_at >= membership.joined_at
    and message.created_at > greatest(
      coalesce(reading.last_read_at, '-infinity'::timestamptz),
      coalesce(clearing.cleared_at, '-infinity'::timestamptz)
    )
    and not exists (
      select 1
      from public.message_deletions deletion
      where deletion.message_id = message.id
        and deletion.user_id = membership.user_id
    );
$$;

revoke execute on function public.my_unread_message_count()
  from public, anon;
grant execute on function public.my_unread_message_count()
  to authenticated;

alter table public.conversation_reads replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'conversation_reads'
  ) then
    alter publication supabase_realtime
      add table public.conversation_reads;
  end if;
end;
$$;

comment on function public.my_unread_message_count() is
  'Returns the authenticated user''s visible unread messages for navigation badges.';

commit;
