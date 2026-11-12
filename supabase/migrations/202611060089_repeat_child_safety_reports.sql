-- A person may file a new report after an earlier one was closed. Keep one
-- row per distinct reporter for the automatic profile-moderation threshold,
-- but point that row at the newest report. Every report and evidence snapshot
-- remains a separate case.
create or replace function private.process_profile_report()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  reported_profile public.profiles%rowtype;
  distinct_reporters integer;
  case_was_open boolean;
  already_counted boolean;
begin
  if new.target_type::text <> 'user' then return new; end if;

  select * into reported_profile
  from public.profiles
  where id = new.target_id
  for update;

  if reported_profile.id is null then
    raise exception 'Reported profile not found';
  end if;
  if reported_profile.id = new.reporter_id then
    raise exception 'A user cannot report their own profile';
  end if;

  select exists(
    select 1 from public.profile_reporters
    where profile_id = new.target_id and reporter_id = new.reporter_id
  ) into already_counted;
  insert into public.profile_reporters(profile_id, reporter_id, report_id)
  values (new.target_id, new.reporter_id, new.id)
  on conflict (profile_id, reporter_id) do update
  set report_id = excluded.report_id,
      created_at = excluded.created_at;

  select count(*) into distinct_reporters
  from public.profile_reporters
  where profile_id = new.target_id;

  if distinct_reporters >= 3 and not already_counted then
    select exists(
      select 1 from public.profile_moderation_cases
      where profile_id = new.target_id and status = 'under_review'
    ) into case_was_open;

    perform set_config('maplov.system_operation', 'profile_moderation', true);
    update public.profiles
    set status = 'suspended', is_discoverable = false
    where id = new.target_id;

    insert into public.profile_moderation_cases(
      profile_id, report_count, status, previous_status, was_discoverable,
      opened_at, updated_at
    ) values (
      new.target_id, distinct_reporters, 'under_review',
      reported_profile.status, reported_profile.is_discoverable, now(), now()
    )
    on conflict (profile_id) do update
    set report_count = excluded.report_count,
        status = 'under_review',
        previous_status = case
          when public.profile_moderation_cases.status = 'under_review'
            then public.profile_moderation_cases.previous_status
          else excluded.previous_status
        end,
        was_discoverable = case
          when public.profile_moderation_cases.status = 'under_review'
            then public.profile_moderation_cases.was_discoverable
          else excluded.was_discoverable
        end,
        opened_at = case
          when public.profile_moderation_cases.status = 'under_review'
            then public.profile_moderation_cases.opened_at
          else now()
        end,
        decided_at = null,
        decided_by = null,
        decision_notes = null,
        updated_at = now();

    update public.reports
    set status = 'under_review'
    where target_type = 'user'
      and target_id = new.target_id
      and status = 'open';

    if not case_was_open then
      insert into public.notifications(
        user_id, kind, title, body, entity_type, entity_id
      ) values (
        new.target_id,
        'security',
        'Profile under review',
        'Your profile is temporarily frozen and removed from Discover while the administration reviews it.',
        'profile',
        new.target_id
      );
    end if;
  end if;

  return new;
end;
$$;

-- A new child-safety concern must become its own case even if the same
-- reporter already has a different open report about that profile.
create or replace function public.submit_conversation_report(
  target_type_value text,
  target_id_value uuid,
  reason_value text,
  comment_value text default null,
  conversation_id_value uuid default null
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  reporter uuid := auth.uid();
  reported_user uuid;
  selected_conversation uuid := conversation_id_value;
  existing_report uuid;
  new_report uuid;
begin
  if reporter is null then raise exception 'Authentication required'; end if;
  if target_type_value not in ('user', 'message') then
    raise exception 'Invalid report target';
  end if;
  if char_length(reason_value) not between 2 and 120
     or char_length(coalesce(comment_value, '')) > 4000 then
    raise exception 'Invalid report details';
  end if;

  if target_type_value = 'user' then
    select id into reported_user from public.profiles where id = target_id_value;
  else
    select sender_id, conversation_id into reported_user, selected_conversation
    from public.messages where id = target_id_value;
    if conversation_id_value is not null
       and selected_conversation is distinct from conversation_id_value then
      raise exception 'Reported conversation is unavailable';
    end if;
  end if;
  if reported_user is null or reported_user = reporter then
    raise exception 'Reported user is unavailable';
  end if;
  if selected_conversation is not null and (
    not exists (select 1 from public.conversation_members
      where conversation_id = selected_conversation and user_id = reporter)
    or not exists (select 1 from public.conversation_members
      where conversation_id = selected_conversation and user_id = reported_user)
  ) then raise exception 'Reported conversation is unavailable'; end if;

  select id into existing_report from public.reports
  where reporter_id = reporter
    and target_type::text = target_type_value
    and target_id = target_id_value
    and reason = reason_value
    and status in ('open', 'under_review')
  order by created_at desc limit 1;
  if existing_report is not null then return existing_report; end if;

  if reason_value not in (
    'Mineur présumé', 'Exploitation sexuelle d’un enfant',
    'Suspected minor', 'Child sexual exploitation'
  ) then
    select id into existing_report from public.reports
    where reporter_id = reporter
      and target_type::text = target_type_value
      and target_id = target_id_value
      and status in ('open', 'under_review')
    order by created_at desc limit 1;
    if existing_report is not null then return existing_report; end if;
  end if;

  insert into public.reports(
    reporter_id, target_type, target_id, reason, comment,
    reported_conversation_id
  ) values (
    reporter, target_type_value::public.report_target_type,
    target_id_value, reason_value, comment_value, selected_conversation
  ) returning id into new_report;
  return new_report;
end;
$$;

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
      select 1 from public.messages message
      where message.id = new.target_id
        and private.is_conversation_member(message.conversation_id)
    ) into target_exists;
  end if;
  if not target_exists then raise exception 'Reported content is unavailable'; end if;
  if new.target_type = 'user' and new.target_id = auth.uid() then
    raise exception 'You cannot report your own account';
  end if;
  select count(*) into recent_count from public.reports
  where reporter_id = auth.uid() and created_at > now() - interval '24 hours';
  if recent_count >= 20 then raise exception 'Daily report limit reached'; end if;
  if new.target_type <> 'photo' and exists (
    select 1 from public.reports
    where reporter_id = auth.uid() and target_type = new.target_type
      and target_id = new.target_id and status in ('open', 'under_review')
      and not (
        new.reason in (
          'Mineur présumé', 'Exploitation sexuelle d’un enfant',
          'Suspected minor', 'Child sexual exploitation'
        ) and reason is distinct from new.reason
      )
  ) then raise exception 'This content is already under review'; end if;
  return new;
end;
$$;
