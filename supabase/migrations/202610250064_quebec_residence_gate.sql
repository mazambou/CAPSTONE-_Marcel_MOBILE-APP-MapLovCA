-- The non-biometric route is offered only after a fresh device location has
-- been reverse-geocoded by the trusted Edge Function to Québec.

begin;

create table if not exists private.quebec_residence_checks (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  location_updated_at timestamptz not null,
  checked_at timestamptz not null default now(),
  eligible boolean not null,
  detected_country_code text not null,
  detected_region text not null
);

alter table private.quebec_residence_checks enable row level security;
revoke all on private.quebec_residence_checks from public, anon, authenticated;
grant select, insert, update, delete on private.quebec_residence_checks
  to service_role;

create or replace function public.get_quebec_residence_check_context(owner_user uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  if auth.role() <> 'service_role' then
    raise exception 'Service role required';
  end if;
  select jsonb_build_object(
    'latitude', location.latitude,
    'longitude', location.longitude,
    'accuracyMeters', location.accuracy_meters,
    'updatedAt', location.updated_at,
    'cachedEligible', case
      when check_result.location_updated_at = location.updated_at
        and location.updated_at >= now() - interval '10 minutes'
        then check_result.eligible
      else null
    end
  ) into result
  from private.user_locations as location
  left join private.quebec_residence_checks as check_result
    on check_result.user_id = location.user_id
  where location.user_id = owner_user;
  return result;
end;
$$;

revoke all on function public.get_quebec_residence_check_context(uuid)
  from public, anon, authenticated;
grant execute on function public.get_quebec_residence_check_context(uuid)
  to service_role;

create or replace function public.record_quebec_residence_check(
  owner_user uuid,
  location_updated_at_value timestamptz,
  eligible_value boolean,
  country_code_value text,
  region_value text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() <> 'service_role' then
    raise exception 'Service role required';
  end if;
  if owner_user is null
     or location_updated_at_value is null
     or eligible_value is null
     or nullif(btrim(country_code_value), '') is null
     or nullif(btrim(region_value), '') is null
     or not exists (
       select 1 from private.user_locations as location
       where location.user_id = owner_user
         and location.updated_at = location_updated_at_value
         and location.updated_at >= now() - interval '10 minutes'
     ) then
    raise exception 'A recent matching device location is required';
  end if;

  insert into private.quebec_residence_checks (
    user_id, location_updated_at, checked_at, eligible,
    detected_country_code, detected_region
  ) values (
    owner_user, location_updated_at_value, now(), eligible_value,
    upper(btrim(country_code_value)), btrim(region_value)
  ) on conflict (user_id) do update set
    location_updated_at = excluded.location_updated_at,
    checked_at = excluded.checked_at,
    eligible = excluded.eligible,
    detected_country_code = excluded.detected_country_code,
    detected_region = excluded.detected_region;
end;
$$;

revoke all on function public.record_quebec_residence_check(
  uuid, timestamptz, boolean, text, text
) from public, anon, authenticated;
grant execute on function public.record_quebec_residence_check(
  uuid, timestamptz, boolean, text, text
) to service_role;

create or replace function public.has_my_account_verification()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null and exists (
    select 1 from auth.users as account
    join public.profiles as profile on profile.id = account.id
    join private.user_locations as location on location.user_id = account.id
    join private.quebec_residence_checks as check_result
      on check_result.user_id = account.id
     and check_result.location_updated_at = location.updated_at
     and location.updated_at >= now() - interval '10 minutes'
    where account.id = auth.uid()
      and account.email_confirmed_at is not null
      and account.phone_confirmed_at is not null
      and profile.country_code = 'CA'
      and profile.residence_location_verified_at is not null
      and check_result.eligible
      and check_result.detected_country_code = 'CA'
  );
$$;

create or replace function private.require_quebec_for_account_photo()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.verification_method = 'account_checks'
     and (tg_op = 'INSERT'
       or new.verification_method is distinct from old.verification_method)
     and not exists (
       select 1 from private.quebec_residence_checks as check_result
       join private.user_locations as location
         on location.user_id = check_result.user_id
        and location.updated_at = check_result.location_updated_at
        and location.updated_at >= now() - interval '10 minutes'
       where check_result.user_id = new.user_id
         and check_result.eligible
         and check_result.detected_country_code = 'CA'
     ) then
    raise exception 'The Québec residence check is required';
  end if;
  return new;
end;
$$;

drop trigger if exists profile_photos_require_quebec on public.profile_photos;
create trigger profile_photos_require_quebec
before insert or update of verification_method on public.profile_photos
for each row execute function private.require_quebec_for_account_photo();

commit;
