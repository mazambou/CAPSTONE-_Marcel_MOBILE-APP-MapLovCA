-- Automatic profile-photo moderation and atomic album operations.

alter table public.profile_photos
  add column if not exists moderation_status text not null default 'visible',
  add column if not exists hidden_at timestamptz,
  add column if not exists moderation_notes text;

alter table public.profile_photos
  drop constraint if exists profile_photos_moderation_status_check;
alter table public.profile_photos
  add constraint profile_photos_moderation_status_check
  check (moderation_status in ('visible', 'under_review'));

create index if not exists profile_photos_visible_user_order_idx
  on public.profile_photos(user_id, display_order)
  where moderation_status = 'visible';

create table if not exists public.photo_reporters (
  photo_id uuid not null references public.profile_photos(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  report_id uuid not null unique references public.reports(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (photo_id, reporter_id)
);

create table if not exists public.photo_moderation_cases (
  photo_id uuid primary key references public.profile_photos(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  report_count integer not null default 0 check (report_count >= 0),
  status text not null default 'under_review'
    check (status in ('under_review', 'approved')),
  opened_at timestamptz not null default now(),
  decided_at timestamptz,
  decided_by uuid references public.profiles(id) on delete set null,
  decision_notes text,
  updated_at timestamptz not null default now()
);

alter table public.photo_reporters enable row level security;
alter table public.photo_moderation_cases enable row level security;

drop policy if exists photo_moderation_cases_admin_read
  on public.photo_moderation_cases;
create policy photo_moderation_cases_admin_read
on public.photo_moderation_cases for select to authenticated
using (private.is_admin());

drop policy if exists photo_moderation_cases_admin_update
  on public.photo_moderation_cases;
create policy photo_moderation_cases_admin_update
on public.photo_moderation_cases for update to authenticated
using (private.is_admin()) with check (private.is_admin());

drop policy if exists profile_photos_read on public.profile_photos;
create policy profile_photos_read
on public.profile_photos for select to authenticated
using (
  user_id = auth.uid()
  or private.is_admin()
  or (
    moderation_status = 'visible'
    and private.can_view_profile(user_id)
  )
);

drop policy if exists profile_photos_admin_update on public.profile_photos;
create policy profile_photos_admin_update
on public.profile_photos for update to authenticated
using (private.is_admin()) with check (private.is_admin());

create or replace function private.protect_photo_verification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() = 'service_role'
     or current_setting('maplov.system_operation', true) in (
       'account_deletion', 'photo_moderation'
     )
     or private.is_admin(auth.uid()) then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.is_verified := false;
    new.moderation_status := 'visible';
    new.hidden_at := null;
    new.moderation_notes := null;
  elsif new.is_verified is distinct from old.is_verified
     or new.moderation_status is distinct from old.moderation_status
     or new.hidden_at is distinct from old.hidden_at
     or new.moderation_notes is distinct from old.moderation_notes then
    raise exception 'Photo moderation fields are moderator-controlled';
  end if;
  return new;
end;
$$;

create or replace function public.register_profile_photo(storage_path_value text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_photo_id uuid;
  next_order smallint;
  first_photo boolean;
begin
  if auth.uid() is null or nullif(btrim(storage_path_value), '') is null then
    raise exception 'A signed-in user and storage path are required';
  end if;
  if storage_path_value not like (auth.uid()::text || '/%') then
    raise exception 'Invalid profile photo storage path';
  end if;

  perform pg_advisory_xact_lock(hashtext('profile_photos:' || auth.uid()::text));
  select
    coalesce(max(display_order), -1)::smallint + 1,
    count(*) = 0
  into next_order, first_photo
  from public.profile_photos
  where user_id = auth.uid();

  insert into public.profile_photos(
    user_id, storage_path, display_order, is_primary
  ) values (
    auth.uid(), storage_path_value, next_order, first_photo
  ) returning id into new_photo_id;
  return new_photo_id;
end;
$$;

create or replace function public.set_my_primary_photo(photo_id_value uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.profile_photos
    where id = photo_id_value
      and user_id = auth.uid()
      and moderation_status = 'visible'
  ) then
    raise exception 'The selected visible photo does not belong to this user';
  end if;
  perform pg_advisory_xact_lock(hashtext('profile_photos:' || auth.uid()::text));
  update public.profile_photos
  set is_primary = false
  where user_id = auth.uid() and is_primary;
  update public.profile_photos
  set is_primary = true
  where id = photo_id_value and user_id = auth.uid();
end;
$$;

revoke all on function public.register_profile_photo(text) from public, anon;
revoke all on function public.set_my_primary_photo(uuid) from public, anon;
grant execute on function public.register_profile_photo(text) to authenticated;
grant execute on function public.set_my_primary_photo(uuid) to authenticated;

create or replace function private.process_photo_report()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner_id_value uuid;
  owner_was_primary boolean;
  distinct_reporters integer;
  hidden_owner uuid;
begin
  if new.target_type::text <> 'photo' then return new; end if;

  select user_id, is_primary
  into owner_id_value, owner_was_primary
  from public.profile_photos
  where id = new.target_id;

  if owner_id_value is null then raise exception 'Reported photo not found'; end if;
  if owner_id_value = new.reporter_id then
    raise exception 'A user cannot report their own photo';
  end if;

  insert into public.photo_reporters(photo_id, reporter_id, report_id)
  values (new.target_id, new.reporter_id, new.id);

  select count(*) into distinct_reporters
  from public.photo_reporters
  where photo_id = new.target_id;

  if distinct_reporters >= 3 then
    perform set_config('maplov.system_operation', 'photo_moderation', true);
    update public.profile_photos
    set moderation_status = 'under_review',
        hidden_at = now(),
        is_primary = false
    where id = new.target_id and moderation_status = 'visible'
    returning user_id into hidden_owner;

    if hidden_owner is not null then
      if owner_was_primary then
        update public.profile_photos
        set is_primary = true
        where id = (
          select id from public.profile_photos
          where user_id = owner_id_value
            and moderation_status = 'visible'
          order by display_order
          limit 1
        );
      end if;

      insert into public.photo_moderation_cases(
        photo_id, owner_id, report_count, status, opened_at, updated_at
      ) values (
        new.target_id, owner_id_value, distinct_reporters,
        'under_review', now(), now()
      )
      on conflict (photo_id) do update
      set report_count = excluded.report_count,
          status = 'under_review',
          opened_at = now(),
          decided_at = null,
          decided_by = null,
          decision_notes = null,
          updated_at = now();

      insert into public.notifications(
        user_id, kind, title, body, entity_type, entity_id
      ) values (
        owner_id_value,
        'security',
        'Photo under review',
        'One of your photos is temporarily hidden while the administration reviews it.',
        'photo',
        new.target_id
      );
    end if;
  end if;
  return new;
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
  ) then raise exception 'This content is already under review'; end if;
  return new;
end;
$$;

drop trigger if exists reports_process_photo_moderation on public.reports;
create trigger reports_process_photo_moderation
after insert on public.reports
for each row execute function private.process_photo_report();

create or replace function private.sync_profile_photo_discoverability()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  affected_user uuid;
begin
  if tg_op = 'DELETE' then
    affected_user := old.user_id;
  else
    affected_user := new.user_id;
  end if;
  update public.profiles profile
  set is_discoverable = (
    profile.profile_completed_at is not null
    and exists (
      select 1 from public.profile_photos photo
      where photo.user_id = affected_user
        and photo.moderation_status = 'visible'
    )
  )
  where profile.id = affected_user;
  if exists (
    select 1 from public.profile_photos
    where user_id = affected_user and moderation_status = 'visible'
  ) and not exists (
    select 1 from public.profile_photos
    where user_id = affected_user
      and moderation_status = 'visible'
      and is_primary
  ) then
    update public.profile_photos
    set is_primary = true
    where id = (
      select id from public.profile_photos
      where user_id = affected_user and moderation_status = 'visible'
      order by display_order
      limit 1
    );
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

drop trigger if exists profile_photos_sync_discoverability
  on public.profile_photos;
create trigger profile_photos_sync_discoverability
after insert or update of moderation_status or delete on public.profile_photos
for each row execute function private.sync_profile_photo_discoverability();

revoke all on table public.photo_reporters from anon, authenticated;
grant select on table public.photo_moderation_cases to authenticated;
