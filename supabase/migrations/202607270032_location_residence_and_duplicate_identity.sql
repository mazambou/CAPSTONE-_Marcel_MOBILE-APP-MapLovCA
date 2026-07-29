-- GPS-controlled residence country and private duplicate-account review.

begin;

create table if not exists public.duplicate_account_checks (
  id uuid primary key default gen_random_uuid(),
  candidate_user_id uuid not null references public.profiles(id)
    on delete cascade,
  matched_user_id uuid not null references public.profiles(id)
    on delete cascade,
  residence_country text not null,
  similarity numeric(6,3) not null,
  threshold numeric(6,3) not null,
  provider text not null default 'aws_rekognition'
    check (provider = 'aws_rekognition'),
  provider_request_id text,
  status text not null default 'blocked'
    check (status in ('blocked', 'approved', 'confirmed')),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete set null,
  review_notes text,
  created_at timestamptz not null default now(),
  constraint duplicate_account_check_distinct_users
    check (candidate_user_id <> matched_user_id)
);

create index if not exists duplicate_account_checks_candidate_idx
  on public.duplicate_account_checks(candidate_user_id, created_at desc);

alter table public.duplicate_account_checks enable row level security;
revoke all on public.duplicate_account_checks
  from public, anon, authenticated;
grant select, insert, update, delete on public.duplicate_account_checks
  to service_role;

create or replace function private.protect_profile_geography()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() = 'service_role'
     or private.is_admin(auth.uid())
     or current_setting('maplov.location_country_sync', true) = 'true'
     or current_setting('maplov.system_operation', true) = 'account_deletion' then
    return new;
  end if;

  if old.origin_country_name is not null
     and btrim(old.origin_country_name) <> ''
     and new.origin_country_name is distinct from old.origin_country_name then
    raise exception 'Country of origin can only be chosen once';
  end if;
  if old.origin_region is not null
     and btrim(old.origin_region) <> ''
     and new.origin_region is distinct from old.origin_region then
    raise exception 'Region of origin can only be chosen once';
  end if;
  if old.origin_city is not null
     and btrim(old.origin_city) <> ''
     and new.origin_city is distinct from old.origin_city then
    raise exception 'City of origin can only be chosen once';
  end if;
  if new.country_name is distinct from old.country_name
     or new.residence_country_name is distinct from old.residence_country_name
     or new.country_code is distinct from old.country_code then
    raise exception 'Residence country is controlled by verified device location';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_protect_geography on public.profiles;
create trigger profiles_protect_geography
before update of country_name, residence_country_name, country_code,
  origin_country_name, origin_region, origin_city on public.profiles
for each row execute function private.protect_profile_geography();

create or replace function public.sync_my_residence_from_location(
  detected_country text,
  detected_country_code text,
  detected_region text default null,
  detected_city text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_profile public.profiles%rowtype;
  country_changed boolean;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if detected_country is null or btrim(detected_country) = ''
     or detected_country_code is null
     or upper(btrim(detected_country_code)) !~ '^[A-Z]{2}$' then
    raise exception 'A valid detected country is required';
  end if;
  if not exists (
    select 1
    from private.user_locations location
    where location.user_id = auth.uid()
      and location.updated_at >= now() - interval '10 minutes'
  ) then
    raise exception 'A recent verified device location is required';
  end if;

  select * into current_profile
  from public.profiles
  where id = auth.uid()
  for update;
  if current_profile.id is null then raise exception 'Profile not found'; end if;

  country_changed :=
    current_profile.residence_country_name is distinct from btrim(detected_country)
    or current_profile.country_code is distinct from upper(btrim(detected_country_code));

  perform set_config('maplov.location_country_sync', 'true', true);
  update public.profiles
  set country_code = upper(btrim(detected_country_code)),
      country_name = btrim(detected_country),
      residence_country_name = btrim(detected_country),
      residence_region = case
        when country_changed
          then nullif(btrim(coalesce(detected_region, '')), '')
        else coalesce(
          nullif(btrim(residence_region), ''),
          nullif(btrim(coalesce(detected_region, '')), '')
        )
      end,
      city = case
        when country_changed
          then nullif(btrim(coalesce(detected_city, '')), '')
        else coalesce(
          nullif(btrim(city), ''),
          nullif(btrim(coalesce(detected_city, '')), '')
        )
      end,
      residence_city = case
        when country_changed
          then nullif(btrim(coalesce(detected_city, '')), '')
        else coalesce(
          nullif(btrim(residence_city), ''),
          nullif(btrim(coalesce(detected_city, '')), '')
        )
      end
  where id = auth.uid();
end;
$$;

revoke execute on function public.sync_my_residence_from_location(
  text, text, text, text
) from public, anon;
grant execute on function public.sync_my_residence_from_location(
  text, text, text, text
) to authenticated;

-- Phone verification remains part of account security, but it no longer
-- controls residence geography.
revoke execute on function public.sync_my_residence_from_verified_phone(
  text, text
) from authenticated;

comment on column public.profiles.residence_country_name is
  'Derived from the latest verified device location; never user-editable.';
comment on table public.duplicate_account_checks is
  'Server-only AWS face matches used to block multiple accounts in one residence country.';

commit;
