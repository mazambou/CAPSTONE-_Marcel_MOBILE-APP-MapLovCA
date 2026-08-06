begin;

do $$
declare
  invalid_active_count integer;
  invalid_hierarchy_count integer;
  duplicate_geoname_count integer;
  duplicate_natural_key_count integer;
  required_city_count integer;
  forbidden_canadian_entry_count integer;
  woodbine_replacement_count integer;
begin
  select count(*) into invalid_active_count
  from public.cities
  where is_active
    and classification_status <> 'verified_city';
  if invalid_active_count <> 0 then
    raise exception 'Found % active entries not classified as cities',
      invalid_active_count;
  end if;

  select count(*) into invalid_active_count
  from public.cities
  where is_active
    and feature_code in (
      'PPLCH', 'PPLF', 'PPLH', 'PPLL', 'PPLQ', 'PPLR', 'PPLS', 'PPLW',
      'PPLX', 'STLMT'
    );
  if invalid_active_count <> 0 then
    raise exception 'Found % active non-city GeoNames features',
      invalid_active_count;
  end if;

  select count(*) into invalid_hierarchy_count
  from public.cities city
  left join public.regions region on region.id = city.region_id
  left join public.countries country on country.id = city.country_id
  where region.id is null
     or country.id is null
     or region.country_id <> city.country_id;
  if invalid_hierarchy_count <> 0 then
    raise exception 'Found % invalid city hierarchies', invalid_hierarchy_count;
  end if;

  select count(*) into duplicate_geoname_count
  from (
    select geoname_id
    from public.cities
    where geoname_id is not null
    group by geoname_id
    having count(*) > 1
  ) duplicates;
  if duplicate_geoname_count <> 0 then
    raise exception 'Found % duplicate GeoNames city identifiers',
      duplicate_geoname_count;
  end if;

  select count(*) into duplicate_natural_key_count
  from (
    select region_id, lower(btrim(name))
    from public.cities
    group by region_id, lower(btrim(name))
    having count(*) > 1
  ) duplicates;
  if duplicate_natural_key_count <> 0 then
    raise exception 'Found % duplicate city natural keys',
      duplicate_natural_key_count;
  end if;

  select count(*) into required_city_count
  from public.cities city
  join public.countries country on country.id = city.country_id
  where country.iso2 = 'CA'
    and city.name in ('Hamilton', 'Ottawa', 'Toronto')
    and city.is_active;
  if required_city_count <> 3 then
    raise exception 'Hamilton, Ottawa and Toronto must remain active';
  end if;

  select count(*) into forbidden_canadian_entry_count
  from public.cities city
  join public.countries country on country.id = city.country_id
  where country.iso2 = 'CA'
    and city.name in (
      'Woodbine Corridor', 'North York', 'Etobicoke',
      'Etobicoke West Mall', 'Scarborough Village',
      'Centennial Scarborough'
    )
    and city.is_active;
  if forbidden_canadian_entry_count <> 0 then
    raise exception 'Found % forbidden Canadian subdivisions still active',
      forbidden_canadian_entry_count;
  end if;

  select count(*) into woodbine_replacement_count
  from public.geography_city_classification_audit audit
  join public.cities old_city on old_city.id = audit.city_id
  join public.cities replacement on replacement.id = audit.replacement_city_id
  where audit.migration_key = '202608060053_city_only_catalog'
    and old_city.geoname_id = 7871312
    and replacement.geoname_id = 6167865;
  if woodbine_replacement_count <> 1 then
    raise exception 'Woodbine Corridor must be reported as remapped to Toronto';
  end if;
end;
$$;

rollback;
