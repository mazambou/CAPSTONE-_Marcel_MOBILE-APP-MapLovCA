-- Automatically freeze profiles reported by three distinct accounts and queue
-- them for an administrator decision.

begin;

create table if not exists public.profile_reporters (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  report_id uuid not null unique references public.reports(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (profile_id, reporter_id),
  constraint profile_reporters_distinct_users check (profile_id <> reporter_id)
);

create table if not exists public.profile_moderation_cases (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  report_count integer not null default 0 check (report_count >= 0),
  status text not null default 'under_review'
    check (status in ('under_review', 'approved', 'suspended')),
  previous_status public.account_status not null default 'active',
  was_discoverable boolean not null default false,
  opened_at timestamptz not null default now(),
  decided_at timestamptz,
  decided_by uuid references public.profiles(id) on delete set null,
  decision_notes text,
  updated_at timestamptz not null default now()
);

alter table public.profile_reporters enable row level security;
alter table public.profile_moderation_cases enable row level security;

create policy profile_moderation_cases_admin_read
on public.profile_moderation_cases for select to authenticated
using (private.is_admin());

-- Decisions are performed by the atomic RPC below. This policy also allows
-- administrators to inspect/update a case through trusted administration tools.
create policy profile_moderation_cases_admin_update
on public.profile_moderation_cases for update to authenticated
using (private.is_admin()) with check (private.is_admin());

-- Automatic moderation must be able to disable discovery for every package.
-- User-requested invisible mode remains restricted to VIP accounts.
create or replace function private.enforce_invisible_mode_entitlement()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() = 'service_role' or private.is_admin(auth.uid())
     or current_setting('maplov.system_operation', true) in (
       'account_deletion', 'profile_moderation'
     ) then
    return new;
  end if;
  if old.is_discoverable and not new.is_discoverable
     and new.profile_completed_at is not null
     and private.current_subscription_tier(auth.uid()) not in ('elite', 'vip') then
    raise exception 'Invisible navigation requires Premium VIP';
  end if;
  return new;
end;
$$;

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

  insert into public.profile_reporters(profile_id, reporter_id, report_id)
  values (new.target_id, new.reporter_id, new.id);

  select count(*) into distinct_reporters
  from public.profile_reporters
  where profile_id = new.target_id;

  if distinct_reporters >= 3 then
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

drop trigger if exists reports_process_profile_moderation on public.reports;
create trigger reports_process_profile_moderation
after insert on public.reports
for each row execute function private.process_profile_report();

create or replace function public.decide_profile_moderation(
  profile_id_value uuid,
  decision_value text,
  notes_value text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  moderation_case public.profile_moderation_cases%rowtype;
  restore_discoverability boolean;
begin
  if not private.is_admin(auth.uid()) then
    raise exception 'Administrator access required';
  end if;
  if decision_value not in ('approved', 'suspended') then
    raise exception 'Unsupported profile moderation decision';
  end if;

  select * into moderation_case
  from public.profile_moderation_cases
  where profile_id = profile_id_value and status = 'under_review'
  for update;

  if moderation_case.profile_id is null then
    raise exception 'No profile moderation case is awaiting review';
  end if;

  perform set_config('maplov.system_operation', 'profile_moderation', true);

  if decision_value = 'approved' then
    select moderation_case.was_discoverable
      and profile.profile_completed_at is not null
      and exists (
        select 1 from public.profile_photos photo
        where photo.user_id = profile_id_value
          and photo.moderation_status = 'visible'
      )
    into restore_discoverability
    from public.profiles profile
    where profile.id = profile_id_value;

    update public.profiles
    set status = moderation_case.previous_status,
        is_discoverable = coalesce(restore_discoverability, false)
    where id = profile_id_value;
  else
    update public.profiles
    set status = 'suspended', is_discoverable = false
    where id = profile_id_value;
  end if;

  update public.profile_moderation_cases
  set status = decision_value,
      decided_at = now(),
      decided_by = auth.uid(),
      decision_notes = nullif(btrim(notes_value), ''),
      updated_at = now()
  where profile_id = profile_id_value;

  update public.reports
  set status = case
        when decision_value = 'approved' then 'dismissed'::public.report_status
        else 'resolved'::public.report_status
      end,
      resolved_at = now(),
      resolution_notes = coalesce(
        nullif(btrim(notes_value), ''),
        case
          when decision_value = 'approved' then 'Profile approved by moderation.'
          else 'Profile suspension confirmed by moderation.'
        end
      )
  where target_type = 'user'
    and target_id = profile_id_value
    and status in ('open', 'under_review');

  insert into public.admin_actions(
    admin_id, action, target_type, target_id, reason
  ) values (
    auth.uid(), 'profile_' || decision_value, 'user', profile_id_value,
    nullif(btrim(notes_value), '')
  );

  insert into public.notifications(
    user_id, kind, title, body, entity_type, entity_id
  ) values (
    profile_id_value,
    'security',
    case
      when decision_value = 'approved' then 'Profile approved'
      else 'Profile suspended'
    end,
    case
      when decision_value = 'approved'
        then 'The administration approved your profile. Your account has been restored.'
      else 'The administration confirmed the suspension of your profile.'
    end,
    'profile',
    profile_id_value
  );
end;
$$;

revoke all on table public.profile_reporters from anon, authenticated;
grant select on table public.profile_moderation_cases to authenticated;
revoke execute on function public.decide_profile_moderation(uuid, text, text)
  from public, anon;
grant execute on function public.decide_profile_moderation(uuid, text, text)
  to authenticated;

commit;
