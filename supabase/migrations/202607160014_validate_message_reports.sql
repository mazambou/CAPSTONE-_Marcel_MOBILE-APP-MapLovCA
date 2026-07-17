create or replace function private.validate_report_submission()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  recent_count integer;
  target_exists boolean := false;
begin
  if new.reporter_id <> auth.uid() then raise exception 'Invalid reporter'; end if;
  if new.target_type = 'user' then
    select exists(select 1 from public.profiles where id = new.target_id) into target_exists;
  elsif new.target_type = 'post' then
    select exists(select 1 from public.posts where id = new.target_id) into target_exists;
  elsif new.target_type = 'comment' then
    select exists(select 1 from public.post_comments where id = new.target_id) into target_exists;
  elsif new.target_type = 'photo' then
    select exists(select 1 from public.profile_photos where id = new.target_id) into target_exists;
  elsif new.target_type = 'message' then
    select exists(
      select 1 from public.messages m
      where m.id = new.target_id
        and private.is_conversation_member(m.conversation_id)
    ) into target_exists;
  end if;
  if not target_exists then raise exception 'Reported content is unavailable'; end if;
  if new.target_type = 'user' and new.target_id = auth.uid() then
    raise exception 'You cannot report your own account';
  end if;
  select count(*) into recent_count from public.reports
  where reporter_id = auth.uid() and created_at > now() - interval '24 hours';
  if recent_count >= 20 then raise exception 'Daily report limit reached'; end if;
  if exists (
    select 1 from public.reports
    where reporter_id = auth.uid() and target_type = new.target_type
      and target_id = new.target_id and status in ('open', 'under_review')
  ) then raise exception 'This content is already under review'; end if;
  return new;
end;
$$;
