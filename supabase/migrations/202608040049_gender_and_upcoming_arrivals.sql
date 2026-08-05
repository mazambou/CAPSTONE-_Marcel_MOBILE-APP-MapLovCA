-- Immutable registration gender, mandatory single dating-gender preference,
-- and privacy-scoped VIP "Arrive bientôt" destinations.

begin;

-- Legacy incomplete values must return through profile setup and choose one of
-- the three supported registration genders.
update public.profiles
set gender = null
where gender is not null
  and gender not in ('Man', 'Woman', 'Non-binary');

alter table public.profiles
  drop constraint if exists profiles_gender_values;
alter table public.profiles
  add constraint profiles_gender_values check (
    gender is null or gender in ('Man', 'Woman', 'Non-binary')
  );

drop trigger if exists profiles_sync_default_gender_preference
  on public.profiles;
drop function if exists private.sync_default_gender_preference();

create or replace function private.protect_registration_gender()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.gender in ('Man', 'Woman', 'Non-binary')
     and new.gender is distinct from old.gender then
    raise exception 'Registration gender cannot be changed';
  end if;
  if new.gender is not null
     and new.gender not in ('Man', 'Woman', 'Non-binary') then
    raise exception 'Unsupported registration gender';
  end if;
  return new;
end;
$$;

create trigger profiles_protect_registration_gender
before update of gender on public.profiles
for each row execute function private.protect_registration_gender();

-- Existing completed accounts receive one valid choice. The historical
-- opposite-gender default is preserved; members can change this preference.
update public.dating_preferences preference
set genders = array[
      case profile.gender
        when 'Man' then 'Woman'
        when 'Woman' then 'Man'
        else 'Non-binary'
      end
    ],
    required_genders = true
from public.profiles profile
where profile.id = preference.user_id
  and cardinality(preference.genders) = 0
  and profile.gender in ('Man', 'Woman', 'Non-binary');

update public.dating_preferences
set required_genders = true
where cardinality(genders) = 1;

create or replace function private.enforce_required_single_gender_preference()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if cardinality(new.genders) > 1
     or not new.genders <@ array['Woman', 'Man', 'Non-binary']::text[] then
    raise exception 'Choose exactly one supported gender preference';
  end if;
  if tg_op = 'UPDATE'
     and cardinality(old.genders) = 1
     and cardinality(new.genders) <> 1 then
    raise exception 'A gender preference must always remain selected';
  end if;
  if cardinality(new.genders) = 1 then
    new.required_genders := true;
  end if;
  return new;
end;
$$;

drop trigger if exists dating_preferences_required_single_gender
  on public.dating_preferences;
create trigger dating_preferences_required_single_gender
before insert or update of genders, required_genders
on public.dating_preferences
for each row execute function private.enforce_required_single_gender_preference();

create table public.upcoming_arrival_destinations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  country_name text not null check (char_length(trim(country_name)) between 2 and 100),
  region_name text check (
    region_name is null or char_length(trim(region_name)) between 2 and 120
  ),
  city_name text check (
    city_name is null or char_length(trim(city_name)) between 2 and 120
  ),
  arrival_month date check (
    arrival_month is null or arrival_month = date_trunc('month', arrival_month)::date
  ),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique nulls not distinct (user_id, country_name, region_name, city_name)
);

create index upcoming_arrival_destination_lookup_idx
  on public.upcoming_arrival_destinations(
    lower(country_name), lower(region_name), lower(city_name)
  ) where is_active;

alter table public.upcoming_arrival_destinations enable row level security;

create policy upcoming_arrivals_owner_read
on public.upcoming_arrival_destinations for select to authenticated
using (user_id = auth.uid() or private.is_admin(auth.uid()));

revoke all on public.upcoming_arrival_destinations from anon, authenticated;
grant select on public.upcoming_arrival_destinations to authenticated;

create trigger upcoming_arrivals_set_updated_at
before update on public.upcoming_arrival_destinations
for each row execute function private.set_updated_at();

create or replace function public.save_my_upcoming_arrival(
  destination_id_value uuid,
  country_name_value text,
  region_name_value text default null,
  city_name_value text default null,
  arrival_month_value date default null,
  is_active_value boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  resolved_id uuid;
  active_count integer;
  residence_country text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if private.current_subscription_tier(auth.uid()) not in ('elite', 'vip') then
    raise exception 'Arrive bientôt requires MapLov VIP';
  end if;
  if char_length(trim(country_name_value)) < 2 then
    raise exception 'Destination country is required';
  end if;
  if arrival_month_value is not null
     and arrival_month_value <> date_trunc('month', arrival_month_value)::date then
    raise exception 'Arrival month must use the first day of the month';
  end if;

  select country_name into residence_country
  from public.profiles where id = auth.uid();
  if lower(trim(country_name_value)) = lower(trim(coalesce(residence_country, ''))) then
    raise exception 'Destination must differ from the current country of residence';
  end if;

  select count(*) into active_count
  from public.upcoming_arrival_destinations
  where user_id = auth.uid() and is_active
    and (destination_id_value is null or id <> destination_id_value);
  if is_active_value and active_count >= 3 then
    raise exception 'A maximum of three active destinations is allowed';
  end if;

  if destination_id_value is null then
    insert into public.upcoming_arrival_destinations(
      user_id, country_name, region_name, city_name, arrival_month, is_active
    ) values (
      auth.uid(), trim(country_name_value), nullif(trim(region_name_value), ''),
      nullif(trim(city_name_value), ''), arrival_month_value, is_active_value
    ) returning id into resolved_id;
  else
    update public.upcoming_arrival_destinations
    set country_name = trim(country_name_value),
        region_name = nullif(trim(region_name_value), ''),
        city_name = nullif(trim(city_name_value), ''),
        arrival_month = arrival_month_value,
        is_active = is_active_value
    where id = destination_id_value and user_id = auth.uid()
    returning id into resolved_id;
    if resolved_id is null then raise exception 'Destination not found'; end if;
  end if;
  return resolved_id;
end;
$$;

create or replace function public.delete_my_upcoming_arrival(
  destination_id_value uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare removed integer;
begin
  delete from public.upcoming_arrival_destinations
  where id = destination_id_value and user_id = auth.uid();
  get diagnostics removed = row_count;
  return removed > 0;
end;
$$;

create or replace function public.upcoming_arrivals_for_discovery(
  search_country_value text,
  search_region_value text default null,
  search_city_value text default null
)
returns table(
  profile_id uuid,
  destination_country text,
  destination_region text,
  destination_city text,
  arrival_month date
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  viewer_country text;
  international_allowed boolean;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if coalesce(length(trim(search_country_value)), 0) < 2 then return; end if;

  select country_name into viewer_country
  from public.profiles where id = auth.uid();
  international_allowed :=
    private.current_subscription_tier(auth.uid()) in ('elite', 'vip')
    or exists (
      select 1 from public.payment_entitlements entitlement
      where entitlement.user_id = auth.uid()
        and entitlement.entitlement_kind = 'international_pass'
        and entitlement.expires_at > now()
    );
  if lower(trim(search_country_value)) <>
       lower(trim(coalesce(viewer_country, '')))
     and not international_allowed then
    raise exception 'International discovery requires VIP or an active pass';
  end if;

  return query
  select destination.user_id, destination.country_name,
         destination.region_name, destination.city_name,
         destination.arrival_month
  from public.upcoming_arrival_destinations destination
  join public.profiles profile on profile.id = destination.user_id
  where destination.is_active
    and destination.user_id <> auth.uid()
    and profile.status = 'active'
    and profile.is_discoverable
    and profile.allow_international_discovery
    and private.current_subscription_tier(destination.user_id) in ('elite', 'vip')
    and private.can_view_profile(destination.user_id)
    and lower(trim(destination.country_name)) = lower(trim(search_country_value))
    and (
      destination.region_name is null
      or (
        nullif(trim(search_region_value), '') is not null
        and lower(trim(destination.region_name)) = lower(trim(search_region_value))
      )
    )
    and (
      destination.city_name is null
      or (
        nullif(trim(search_city_value), '') is not null
        and lower(trim(destination.city_name)) = lower(trim(search_city_value))
      )
    );
end;
$$;

revoke all on function public.save_my_upcoming_arrival(
  uuid, text, text, text, date, boolean
) from public, anon;
revoke all on function public.delete_my_upcoming_arrival(uuid)
  from public, anon;
revoke all on function public.upcoming_arrivals_for_discovery(text, text, text)
  from public, anon;
grant execute on function public.save_my_upcoming_arrival(
  uuid, text, text, text, date, boolean
) to authenticated;
grant execute on function public.delete_my_upcoming_arrival(uuid)
  to authenticated;
grant execute on function public.upcoming_arrivals_for_discovery(text, text, text)
  to authenticated;

commit;
