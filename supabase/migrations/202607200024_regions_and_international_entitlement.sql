-- Store residence regions for filtering without exposing them in profile UI,
-- and enforce Premium Plus access for international search preferences.

begin;

alter table public.profiles
  add column if not exists residence_region text;

alter table public.dating_preferences
  add column if not exists regions text[] not null default '{}';

create index if not exists profiles_residence_geography_idx
  on public.profiles(country_name, residence_region, city)
  where status = 'active' and is_discoverable;

create or replace function private.enforce_international_search_entitlement()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() = 'service_role' or private.is_admin(auth.uid()) then
    return new;
  end if;
  if new.location_mode in ('specific_country', 'worldwide')
     and private.current_subscription_tier(auth.uid()) not in ('plus', 'elite', 'vip') then
    raise exception 'International search requires Premium Plus';
  end if;
  return new;
end;
$$;

drop trigger if exists preferences_international_entitlement
  on public.dating_preferences;
create trigger preferences_international_entitlement
before insert or update on public.dating_preferences
for each row execute function private.enforce_international_search_entitlement();

comment on column public.profiles.residence_region is
  'Residence region used for discovery filtering; intentionally omitted from public profile presentation.';
comment on column public.dating_preferences.regions is
  'Selected residence regions, evaluated after the selected country.';

commit;
