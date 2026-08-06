begin;

do $$
declare
  target_iso2 text[] := array[
    'AE', 'AU', 'BE', 'BF', 'BI', 'BJ', 'BW', 'CA', 'CD', 'CF', 'CG', 'CH',
    'CI', 'CM', 'CV', 'DE', 'DJ', 'DK', 'DZ', 'EG', 'ER', 'ES', 'ET', 'FR',
    'GA', 'GB', 'GH', 'GM', 'GN', 'GQ', 'GW', 'IE', 'IT', 'KE', 'KM', 'LR',
    'LS', 'LY', 'MA', 'MG', 'ML', 'MR', 'MU', 'MW', 'MZ', 'NA', 'NE', 'NG',
    'NL', 'NO', 'NZ', 'PT', 'RW', 'SA', 'SC', 'SD', 'SE', 'SL', 'SN', 'SO',
    'SS', 'ST', 'SZ', 'TD', 'TG', 'TN', 'TZ', 'UG', 'US', 'ZA', 'ZM', 'ZW'
  ]::text[];
  target_country_count integer;
  geonames_region_count integer;
  geonames_city_count integer;
  orphan_city_count integer;
begin
  select count(*) into target_country_count
  from public.countries
  where iso2 = any(target_iso2);
  if target_country_count <> 72 then
    raise exception 'Expected 72 pre-existing countries, found %',
      target_country_count;
  end if;

  select count(*) into geonames_region_count
  from public.regions region
  join public.countries country on country.id = region.country_id
  where region.geoname_id is not null
    and country.iso2 = any(target_iso2);
  if geonames_region_count <> 1078 then
    raise exception 'Expected 1078 GeoNames regions, found %',
      geonames_region_count;
  end if;

  select count(*) into geonames_city_count
  from public.cities city
  join public.countries country on country.id = city.country_id
  where city.geoname_id is not null
    and country.iso2 = any(target_iso2);
  if geonames_city_count <> 105164 then
    raise exception 'Expected 105164 GeoNames cities, found %',
      geonames_city_count;
  end if;

  select count(*) into orphan_city_count
  from public.cities city
  left join public.regions region on region.id = city.region_id
  where region.id is null or city.country_id <> region.country_id;
  if orphan_city_count <> 0 then
    raise exception 'Found % cities outside their region/country hierarchy',
      orphan_city_count;
  end if;
end;
$$;

rollback;
