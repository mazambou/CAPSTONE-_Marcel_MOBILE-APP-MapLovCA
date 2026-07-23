-- Complete the country -> region -> city hierarchy for residence and origin.

begin;

alter table public.profiles
  add column if not exists origin_region text;

alter table public.dating_preferences
  add column if not exists origin_regions text[] not null default '{}';

with cameroon_regions(region_name, cities) as (
  values
    ('Adamawa', array['Ngaoundéré','Meiganga','Banyo','Tibati','Tignère']),
    ('Centre', array['Yaoundé','Mbalmayo','Bafia','Obala','Mfou','Nanga-Eboko','Akonolinga','Eséka','Monatélé','Ntui']),
    ('East', array['Bertoua','Batouri','Yokadouma','Abong-Mbang','Garoua-Boulaï','Bélabo','Kétté','Lomié']),
    ('Far North', array['Maroua','Kousséri','Mokolo','Yagoua','Mora','Kaélé','Bogo','Maga','Waza']),
    ('Littoral', array['Douala','Nkongsamba','Edéa','Loum','Manjo','Melong','Mbanga','Dibombari']),
    ('North', array['Garoua','Guider','Figuil','Pitoa','Poli','Lagdo','Touboro','Rey-Bouba','Tcholliré']),
    ('North-West', array['Bamenda','Kumbo','Wum','Nkambe','Fundong','Ndop','Bali','Bafut','Batibo','Mbengwi']),
    ('South', array['Ebolowa','Kribi','Sangmélima','Ambam','Lolodorf','Akom II','Djoum','Zoétélé','Meyomessala']),
    ('South-West', array['Buea','Limbe','Kumba','Tiko','Mamfe','Muyuka','Mutengene','Bangem','Mundemba','Tombel','Ekondo-Titi']),
    ('West', array['Bafoussam','Dschang','Foumban','Mbouda','Bafang','Bangangté','Foumbot','Bandjoun','Baham','Tonga','Batcham'])
)
update public.profiles as profile
set residence_region = mapping.region_name
from cameroon_regions as mapping
where coalesce(profile.residence_country_name, profile.country_name) = 'Cameroon'
  and coalesce(profile.residence_city, profile.city) = any(mapping.cities)
  and profile.residence_region is null;

with cameroon_regions(region_name, cities) as (
  values
    ('Adamawa', array['Ngaoundéré','Meiganga','Banyo','Tibati','Tignère']),
    ('Centre', array['Yaoundé','Mbalmayo','Bafia','Obala','Mfou','Nanga-Eboko','Akonolinga','Eséka','Monatélé','Ntui']),
    ('East', array['Bertoua','Batouri','Yokadouma','Abong-Mbang','Garoua-Boulaï','Bélabo','Kétté','Lomié']),
    ('Far North', array['Maroua','Kousséri','Mokolo','Yagoua','Mora','Kaélé','Bogo','Maga','Waza']),
    ('Littoral', array['Douala','Nkongsamba','Edéa','Loum','Manjo','Melong','Mbanga','Dibombari']),
    ('North', array['Garoua','Guider','Figuil','Pitoa','Poli','Lagdo','Touboro','Rey-Bouba','Tcholliré']),
    ('North-West', array['Bamenda','Kumbo','Wum','Nkambe','Fundong','Ndop','Bali','Bafut','Batibo','Mbengwi']),
    ('South', array['Ebolowa','Kribi','Sangmélima','Ambam','Lolodorf','Akom II','Djoum','Zoétélé','Meyomessala']),
    ('South-West', array['Buea','Limbe','Kumba','Tiko','Mamfe','Muyuka','Mutengene','Bangem','Mundemba','Tombel','Ekondo-Titi']),
    ('West', array['Bafoussam','Dschang','Foumban','Mbouda','Bafang','Bangangté','Foumbot','Bandjoun','Baham','Tonga','Batcham'])
)
update public.profiles as profile
set origin_region = mapping.region_name
from cameroon_regions as mapping
where profile.origin_country_name = 'Cameroon'
  and profile.origin_city = any(mapping.cities)
  and profile.origin_region is null;

create index if not exists profiles_origin_geography_idx
  on public.profiles(origin_country_name, origin_region, origin_city)
  where status = 'active' and is_discoverable;

create or replace function private.protect_profile_geography()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() = 'service_role'
     or private.is_admin(auth.uid())
     or current_setting('maplov.phone_country_sync', true) = 'true'
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
    raise exception 'Residence country is controlled by the verified phone number';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_protect_geography on public.profiles;
create trigger profiles_protect_geography
before update of country_name, residence_country_name, country_code,
  origin_country_name, origin_region, origin_city on public.profiles
for each row execute function private.protect_profile_geography();

create or replace function private.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  supplied_name text;
  accepted_documents jsonb := coalesce(
    new.raw_user_meta_data -> 'accepted_legal_documents',
    '{}'::jsonb
  );
  accepted_time timestamptz := coalesce(
    nullif(new.raw_user_meta_data ->> 'legal_accepted_at', '')::timestamptz,
    now()
  );
begin
  supplied_name := coalesce(
    nullif(btrim(new.raw_user_meta_data ->> 'first_name'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'name'), '')
  );

  insert into public.profiles (
    id,
    first_name,
    date_of_birth,
    country_code,
    country_name,
    city,
    residence_country_name,
    residence_region,
    residence_city,
    origin_country_name,
    origin_region,
    origin_city
  ) values (
    new.id,
    supplied_name,
    private.safe_date(new.raw_user_meta_data ->> 'date_of_birth'),
    nullif(upper(btrim(new.raw_user_meta_data ->> 'country_code')), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'country_name'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'city'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'country_name'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'residence_region'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'city'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'origin_country_name'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'origin_region'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'origin_city'), '')
  );

  insert into public.dating_preferences (user_id) values (new.id);
  insert into public.notification_preferences (user_id) values (new.id);

  insert into public.user_legal_acceptances (
    user_id,
    document_key,
    document_version,
    accepted_at
  )
  select new.id, document.document_key, document.version, accepted_time
  from public.legal_documents document
  where document.is_required
    and accepted_documents ->> document.document_key = document.version;

  return new;
end;
$$;

comment on column public.profiles.origin_region is
  'Origin region selected after country and immutable once populated.';
comment on column public.dating_preferences.origin_regions is
  'Selected origin regions, evaluated after the selected origin country.';

commit;
