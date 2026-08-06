-- Normalize the geographic catalog while retaining legacy text columns during
-- the transition. Catalog reads are progressive: countries first, then regions
-- by country_id, then cities by region_id.

begin;

create table public.countries (
  id uuid primary key default gen_random_uuid(),
  iso2 varchar(2) not null,
  iso3 varchar(3),
  name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint countries_iso2_format check (iso2 = upper(iso2) and char_length(iso2) = 2),
  constraint countries_iso3_format check (
    iso3 is null or (iso3 = upper(iso3) and char_length(iso3) = 3)
  ),
  constraint countries_name_not_blank check (btrim(name) <> '')
);

create unique index countries_iso2_unique on public.countries(iso2);
create unique index countries_iso3_unique
  on public.countries(iso3) where iso3 is not null;
create unique index countries_name_unique
  on public.countries(lower(btrim(name)));
create index countries_name_idx on public.countries(name);

create table public.regions (
  id uuid primary key default gen_random_uuid(),
  country_id uuid not null references public.countries(id) on delete cascade,
  code text,
  name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint regions_name_not_blank check (btrim(name) <> ''),
  constraint regions_id_country_unique unique (id, country_id)
);

create unique index regions_country_name_unique
  on public.regions(country_id, lower(btrim(name)));
create unique index regions_country_code_unique
  on public.regions(country_id, upper(btrim(code))) where code is not null;
create index regions_country_name_idx on public.regions(country_id, name);

create table public.cities (
  id uuid primary key default gen_random_uuid(),
  region_id uuid not null references public.regions(id) on delete cascade,
  country_id uuid not null references public.countries(id) on delete cascade,
  name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint cities_name_not_blank check (btrim(name) <> ''),
  constraint cities_region_country_fk foreign key (region_id, country_id)
    references public.regions(id, country_id) on delete cascade,
  constraint cities_id_region_country_unique unique (id, region_id, country_id)
);

create unique index cities_region_name_unique
  on public.cities(region_id, lower(btrim(name)));
create index cities_region_name_idx on public.cities(region_id, name);
create index cities_country_region_idx on public.cities(country_id, region_id);

alter table public.profiles
  add column residence_country_id uuid references public.countries(id) on delete set null,
  add column residence_region_id uuid references public.regions(id) on delete set null,
  add column residence_city_id uuid references public.cities(id) on delete set null,
  add column origin_country_id uuid references public.countries(id) on delete set null,
  add column origin_region_id uuid references public.regions(id) on delete set null,
  add column origin_city_id uuid references public.cities(id) on delete set null;

alter table public.profiles
  add constraint profiles_residence_region_country_fk
    foreign key (residence_region_id, residence_country_id)
    references public.regions(id, country_id) on delete set null,
  add constraint profiles_residence_city_hierarchy_fk
    foreign key (residence_city_id, residence_region_id, residence_country_id)
    references public.cities(id, region_id, country_id) on delete set null,
  add constraint profiles_origin_region_country_fk
    foreign key (origin_region_id, origin_country_id)
    references public.regions(id, country_id) on delete set null,
  add constraint profiles_origin_city_hierarchy_fk
    foreign key (origin_city_id, origin_region_id, origin_country_id)
    references public.cities(id, region_id, country_id) on delete set null;

create index profiles_residence_geography_ids_idx
  on public.profiles(residence_country_id, residence_region_id, residence_city_id)
  where status = 'active' and is_discoverable;
create index profiles_origin_geography_ids_idx
  on public.profiles(origin_country_id, origin_region_id, origin_city_id)
  where status = 'active' and is_discoverable;

alter table public.dating_preferences
  add column country_ids uuid[] not null default '{}',
  add column region_ids uuid[] not null default '{}',
  add column city_ids uuid[] not null default '{}',
  add column origin_country_ids uuid[] not null default '{}',
  add column origin_region_ids uuid[] not null default '{}',
  add column origin_city_ids uuid[] not null default '{}';

alter table public.countries enable row level security;
alter table public.regions enable row level security;
alter table public.cities enable row level security;

create policy countries_authenticated_read_active
on public.countries for select to authenticated
using (is_active);
create policy regions_authenticated_read_active
on public.regions for select to authenticated
using (is_active);
create policy cities_authenticated_read_active
on public.cities for select to authenticated
using (is_active);

-- Registration resolves the GPS residence before the account exists. The
-- catalog is public reference data, so anonymous users may also read active
-- rows; inactive rows and every write remain protected.
create policy countries_anon_read_active
on public.countries for select to anon
using (is_active);
create policy regions_anon_read_active
on public.regions for select to anon
using (is_active);
create policy cities_anon_read_active
on public.cities for select to anon
using (is_active);

create policy countries_admin_write
on public.countries for all to authenticated
using (private.is_admin(auth.uid()))
with check (private.is_admin(auth.uid()));
create policy regions_admin_write
on public.regions for all to authenticated
using (private.is_admin(auth.uid()))
with check (private.is_admin(auth.uid()));
create policy cities_admin_write
on public.cities for all to authenticated
using (private.is_admin(auth.uid()))
with check (private.is_admin(auth.uid()));

grant select on public.countries, public.regions, public.cities to authenticated;
grant select on public.countries, public.regions, public.cities to anon;
grant insert, update, delete on public.countries, public.regions, public.cities
  to authenticated;
revoke insert, update, delete on public.countries, public.regions, public.cities
  from anon;

comment on table public.countries is
  'ISO country catalog loaded before any child geography.';
comment on table public.regions is
  'Regions loaded only after filtering by country_id.';
comment on table public.cities is
  'Cities loaded only after filtering by region_id.';
comment on column public.profiles.residence_country_id is
  'Normalized geography identifier; legacy residence text remains during migration.';
comment on column public.profiles.origin_country_id is
  'Normalized geography identifier; legacy origin text remains during migration.';

commit;
