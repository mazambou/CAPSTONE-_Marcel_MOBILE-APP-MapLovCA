-- A blocked member's full profile remains hidden by RLS, while a minimal
-- name is available for retained chat history and the blocked-users list.
create or replace function public.conversation_partner_summary(target_user uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not exists (
    select 1 from public.conversation_members mine
    join public.conversation_members theirs
      on theirs.conversation_id=mine.conversation_id
    where mine.user_id=auth.uid() and theirs.user_id=target_user
  ) and not exists (
    select 1 from public.blocks
    where blocker_id=auth.uid() and blocked_id=target_user
  ) then raise exception 'Conversation partner unavailable'; end if;
  return (
    select jsonb_build_object(
      'id',p.id,
      'first_name',p.first_name,
      'city',p.city,
      'country_name',p.country_name
    )
    from public.profiles p where p.id=target_user
  );
end;
$$;
revoke execute on function public.conversation_partner_summary(uuid)
  from public,anon;
grant execute on function public.conversation_partner_summary(uuid)
  to authenticated;
