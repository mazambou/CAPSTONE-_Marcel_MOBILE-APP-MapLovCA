-- Let members opt out of the International discovery mode while remaining
-- eligible for local, country and Nearby discovery.

begin;

alter table public.profiles
  add column if not exists allow_international_discovery boolean not null default true;

comment on column public.profiles.allow_international_discovery is
  'When false, the profile is excluded from International discovery searches.';

create index if not exists profiles_international_discovery_idx
  on public.profiles(country_name, city)
  where status = 'active'
    and is_discoverable
    and allow_international_discovery;

commit;
