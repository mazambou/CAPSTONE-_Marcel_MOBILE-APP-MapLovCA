-- Paginated, set-based Discover pipeline. The RPC preserves the existing
-- visibility, subscription, geography and filter rules while avoiding client
-- N+1 hydration and global compatibility refreshes.

begin;

create extension if not exists postgis with schema extensions;

alter table private.user_locations
  add column if not exists location extensions.geography(point, 4326);

update private.user_locations
set location = extensions.st_setsrid(
  extensions.st_makepoint(longitude, latitude), 4326
)::extensions.geography
where location is null;

create or replace function private.sync_user_location_geography()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.location := extensions.st_setsrid(
    extensions.st_makepoint(new.longitude, new.latitude), 4326
  )::extensions.geography;
  return new;
end;
$$;

drop trigger if exists user_locations_sync_geography
  on private.user_locations;
create trigger user_locations_sync_geography
before insert or update of latitude, longitude on private.user_locations
for each row execute function private.sync_user_location_geography();

alter table private.user_locations alter column location set not null;
create index if not exists user_locations_geography_gist_idx
  on private.user_locations using gist(location);

create table if not exists private.profile_discovery_stats (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  primary_photo_id uuid,
  primary_photo_path text,
  primary_photo_created_at timestamptz,
  primary_photo_likes integer not null default 0,
  primary_photo_super_likes integer not null default 0,
  primary_photo_comments integer not null default 0,
  popular_photo_id uuid,
  popular_photo_path text,
  popular_photo_created_at timestamptz,
  popular_photo_likes integer not null default 0,
  popular_photo_super_likes integer not null default 0,
  popular_photo_comments integer not null default 0,
  engagement_score integer not null default 0,
  popularity_score bigint not null default 0,
  updated_at timestamptz not null default now()
);

revoke all on private.profile_discovery_stats from public, anon, authenticated;

create index if not exists profile_discovery_stats_rank_idx
  on private.profile_discovery_stats(
    popularity_score desc, engagement_score desc, profile_id desc
  );

create or replace function private.refresh_profile_discovery_stats(
  profile_id_value uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into private.profile_discovery_stats (
    profile_id,
    primary_photo_id, primary_photo_path, primary_photo_created_at,
    primary_photo_likes, primary_photo_super_likes,
    primary_photo_comments,
    popular_photo_id, popular_photo_path, popular_photo_created_at,
    popular_photo_likes, popular_photo_super_likes,
    popular_photo_comments,
    engagement_score, popularity_score, updated_at
  )
  with photo_metrics as (
    select
      photo.id,
      photo.storage_path,
      photo.created_at,
      photo.is_primary,
      photo.display_order,
      (select count(*)::integer from public.photo_likes value
       where value.photo_id = photo.id) as likes,
      (select count(*)::integer from public.photo_super_likes value
       where value.photo_id = photo.id) as super_likes,
      (select count(*)::integer from public.photo_comments value
       where value.photo_id = photo.id) as comments
    from public.profile_photos photo
    where photo.user_id = profile_id_value
      and photo.moderation_status = 'visible'
  ), aggregated as (
    select
      (array_agg(id order by is_primary desc, display_order, id)
        filter (where id is not null))[1] as primary_id,
      (array_agg(storage_path order by is_primary desc, display_order, id)
        filter (where id is not null))[1] as primary_path,
      (array_agg(created_at order by is_primary desc, display_order, id)
        filter (where id is not null))[1] as primary_created_at,
      (array_agg(likes order by is_primary desc, display_order, id)
        filter (where id is not null))[1] as primary_likes,
      (array_agg(super_likes order by is_primary desc, display_order, id)
        filter (where id is not null))[1] as primary_super_likes,
      (array_agg(comments order by is_primary desc, display_order, id)
        filter (where id is not null))[1] as primary_comments,
      (array_agg(id order by likes desc, created_at desc, id)
        filter (where id is not null))[1] as popular_id,
      (array_agg(storage_path order by likes desc, created_at desc, id)
        filter (where id is not null))[1] as popular_path,
      (array_agg(created_at order by likes desc, created_at desc, id)
        filter (where id is not null))[1] as popular_created_at,
      (array_agg(likes order by likes desc, created_at desc, id)
        filter (where id is not null))[1] as popular_likes,
      (array_agg(super_likes order by likes desc, created_at desc, id)
        filter (where id is not null))[1] as popular_super_likes,
      (array_agg(comments order by likes desc, created_at desc, id)
        filter (where id is not null))[1] as popular_comments,
      coalesce(max(likes + super_likes + comments), 0)::integer
        as engagement,
      coalesce(sum(likes), 0)::bigint as photo_like_total
    from photo_metrics
  )
  select
    profile.id,
    aggregated.primary_id, aggregated.primary_path,
    aggregated.primary_created_at,
    coalesce(aggregated.primary_likes, 0),
    coalesce(aggregated.primary_super_likes, 0),
    coalesce(aggregated.primary_comments, 0),
    aggregated.popular_id, aggregated.popular_path,
    aggregated.popular_created_at,
    coalesce(aggregated.popular_likes, 0),
    coalesce(aggregated.popular_super_likes, 0),
    coalesce(aggregated.popular_comments, 0),
    aggregated.engagement,
    (
      select count(*) from public.profile_likes value
      where value.liked_id = profile.id
    ) + (
      select count(*)
      from public.photo_likes value
      join public.profile_photos photo on photo.id = value.photo_id
      where photo.user_id = profile.id
    ),
    now()
  from public.profiles profile
  cross join aggregated
  where profile.id = profile_id_value
  on conflict (profile_id) do update set
    primary_photo_id = excluded.primary_photo_id,
    primary_photo_path = excluded.primary_photo_path,
    primary_photo_created_at = excluded.primary_photo_created_at,
    primary_photo_likes = excluded.primary_photo_likes,
    primary_photo_super_likes = excluded.primary_photo_super_likes,
    primary_photo_comments = excluded.primary_photo_comments,
    popular_photo_id = excluded.popular_photo_id,
    popular_photo_path = excluded.popular_photo_path,
    popular_photo_created_at = excluded.popular_photo_created_at,
    popular_photo_likes = excluded.popular_photo_likes,
    popular_photo_super_likes = excluded.popular_photo_super_likes,
    popular_photo_comments = excluded.popular_photo_comments,
    engagement_score = excluded.engagement_score,
    popularity_score = excluded.popularity_score,
    updated_at = excluded.updated_at;
end;
$$;

create or replace function private.refresh_discovery_stats_from_photo()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare owner_id uuid;
begin
  owner_id := case when tg_op = 'DELETE' then old.user_id else new.user_id end;
  perform private.refresh_profile_discovery_stats(owner_id);
  if tg_op = 'UPDATE' and old.user_id is distinct from new.user_id then
    perform private.refresh_profile_discovery_stats(old.user_id);
  end if;
  return coalesce(new, old);
end;
$$;

create or replace function private.refresh_discovery_stats_from_photo_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare affected_photo uuid;
declare owner_id uuid;
begin
  affected_photo := case when tg_op = 'DELETE' then old.photo_id else new.photo_id end;
  select photo.user_id into owner_id
  from public.profile_photos photo where photo.id = affected_photo;
  if owner_id is not null then
    perform private.refresh_profile_discovery_stats(owner_id);
  end if;
  return coalesce(new, old);
end;
$$;

create or replace function private.refresh_discovery_stats_from_profile_like()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.refresh_profile_discovery_stats(
    case when tg_op = 'DELETE' then old.liked_id else new.liked_id end
  );
  return coalesce(new, old);
end;
$$;

drop trigger if exists profile_photos_refresh_discovery_stats
  on public.profile_photos;
create trigger profile_photos_refresh_discovery_stats
after insert or update or delete on public.profile_photos
for each row execute function private.refresh_discovery_stats_from_photo();

drop trigger if exists photo_likes_refresh_discovery_stats
  on public.photo_likes;
create trigger photo_likes_refresh_discovery_stats
after insert or delete on public.photo_likes
for each row execute function private.refresh_discovery_stats_from_photo_event();

drop trigger if exists photo_super_likes_refresh_discovery_stats
  on public.photo_super_likes;
create trigger photo_super_likes_refresh_discovery_stats
after insert or delete on public.photo_super_likes
for each row execute function private.refresh_discovery_stats_from_photo_event();

drop trigger if exists photo_comments_refresh_discovery_stats
  on public.photo_comments;
create trigger photo_comments_refresh_discovery_stats
after insert or update or delete on public.photo_comments
for each row execute function private.refresh_discovery_stats_from_photo_event();

drop trigger if exists profile_likes_refresh_discovery_stats
  on public.profile_likes;
create trigger profile_likes_refresh_discovery_stats
after insert or delete on public.profile_likes
for each row execute function private.refresh_discovery_stats_from_profile_like();

-- One set-based backfill for existing members.
with photo_metrics as (
  select
    photo.user_id,
    photo.id,
    photo.storage_path,
    photo.created_at,
    photo.is_primary,
    photo.display_order,
    (select count(*)::integer from public.photo_likes value
     where value.photo_id = photo.id) as likes,
    (select count(*)::integer from public.photo_super_likes value
     where value.photo_id = photo.id) as super_likes,
    (select count(*)::integer from public.photo_comments value
     where value.photo_id = photo.id) as comments
  from public.profile_photos photo
  where photo.moderation_status = 'visible'
), aggregated as (
  select
    profile.id as profile_id,
    (array_agg(metric.id order by metric.is_primary desc,
      metric.display_order, metric.id) filter (where metric.id is not null))[1]
      as primary_id,
    (array_agg(metric.storage_path order by metric.is_primary desc,
      metric.display_order, metric.id) filter (where metric.id is not null))[1]
      as primary_path,
    (array_agg(metric.created_at order by metric.is_primary desc,
      metric.display_order, metric.id) filter (where metric.id is not null))[1]
      as primary_created_at,
    (array_agg(metric.likes order by metric.is_primary desc,
      metric.display_order, metric.id) filter (where metric.id is not null))[1]
      as primary_likes,
    (array_agg(metric.super_likes order by metric.is_primary desc,
      metric.display_order, metric.id) filter (where metric.id is not null))[1]
      as primary_super_likes,
    (array_agg(metric.comments order by metric.is_primary desc,
      metric.display_order, metric.id) filter (where metric.id is not null))[1]
      as primary_comments,
    (array_agg(metric.id order by metric.likes desc,
      metric.created_at desc, metric.id) filter (where metric.id is not null))[1]
      as popular_id,
    (array_agg(metric.storage_path order by metric.likes desc,
      metric.created_at desc, metric.id) filter (where metric.id is not null))[1]
      as popular_path,
    (array_agg(metric.created_at order by metric.likes desc,
      metric.created_at desc, metric.id) filter (where metric.id is not null))[1]
      as popular_created_at,
    (array_agg(metric.likes order by metric.likes desc,
      metric.created_at desc, metric.id) filter (where metric.id is not null))[1]
      as popular_likes,
    (array_agg(metric.super_likes order by metric.likes desc,
      metric.created_at desc, metric.id) filter (where metric.id is not null))[1]
      as popular_super_likes,
    (array_agg(metric.comments order by metric.likes desc,
      metric.created_at desc, metric.id) filter (where metric.id is not null))[1]
      as popular_comments,
    coalesce(max(metric.likes + metric.super_likes + metric.comments), 0)::integer
      as engagement,
    coalesce(sum(metric.likes), 0)::bigint as photo_like_total
  from public.profiles profile
  left join photo_metrics metric on metric.user_id = profile.id
  group by profile.id
)
insert into private.profile_discovery_stats (
  profile_id,
  primary_photo_id, primary_photo_path, primary_photo_created_at,
  primary_photo_likes, primary_photo_super_likes, primary_photo_comments,
  popular_photo_id, popular_photo_path, popular_photo_created_at,
  popular_photo_likes, popular_photo_super_likes, popular_photo_comments,
  engagement_score, popularity_score, updated_at
)
select
  aggregate.profile_id,
  aggregate.primary_id, aggregate.primary_path, aggregate.primary_created_at,
  coalesce(aggregate.primary_likes, 0),
  coalesce(aggregate.primary_super_likes, 0),
  coalesce(aggregate.primary_comments, 0),
  aggregate.popular_id, aggregate.popular_path, aggregate.popular_created_at,
  coalesce(aggregate.popular_likes, 0),
  coalesce(aggregate.popular_super_likes, 0),
  coalesce(aggregate.popular_comments, 0),
  aggregate.engagement,
  (
    select count(*) from public.profile_likes value
    where value.liked_id = aggregate.profile_id
  ) + (
    select count(*)
    from public.photo_likes value
    join public.profile_photos photo on photo.id = value.photo_id
    where photo.user_id = aggregate.profile_id
  ),
  now()
from aggregated aggregate
on conflict (profile_id) do update set
  primary_photo_id = excluded.primary_photo_id,
  primary_photo_path = excluded.primary_photo_path,
  primary_photo_created_at = excluded.primary_photo_created_at,
  primary_photo_likes = excluded.primary_photo_likes,
  primary_photo_super_likes = excluded.primary_photo_super_likes,
  primary_photo_comments = excluded.primary_photo_comments,
  popular_photo_id = excluded.popular_photo_id,
  popular_photo_path = excluded.popular_photo_path,
  popular_photo_created_at = excluded.popular_photo_created_at,
  popular_photo_likes = excluded.popular_photo_likes,
  popular_photo_super_likes = excluded.popular_photo_super_likes,
  popular_photo_comments = excluded.popular_photo_comments,
  engagement_score = excluded.engagement_score,
  popularity_score = excluded.popularity_score,
  updated_at = excluded.updated_at;

create or replace function private.discovery_body_type(value text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case replace(replace(lower(trim(coalesce(value, ''))), '-', '_'), ' ', '_')
    when 'lean_/_toned' then 'toned'
    when 'toned' then 'toned'
    when 'average' then 'fit'
    when 'fit' then 'fit'
    when 'muscular_/_built' then 'muscular'
    when 'muscular' then 'muscular'
    when 'stocky' then 'robust'
    when 'robust' then 'robust'
    when 'curvy' then 'round'
    when 'round' then 'round'
    when 'full_figured' then 'very_round'
    when 'plus_size' then 'very_round'
    when 'very_round' then 'very_round'
    else replace(replace(lower(trim(coalesce(value, ''))), '-', '_'), ' ', '_')
  end;
$$;

create or replace function private.discovery_profession_matches(
  profession_value text,
  categories text[]
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(cardinality(categories), 0) = 0 or exists (
    select 1
    from unnest(categories) category
    cross join lateral (
      select case lower(trim(category))
        when 'technology' then array['engineer','developer','software','technology','data','product','it ']
        when 'healthcare' then array['doctor','nurse','medical','health','pharmac']
        when 'education' then array['teacher','professor','educat','school']
        when 'business' then array['business','manager','finance','account','marketing','sales']
        when 'arts' then array['artist','designer','music','writer','photograph','creative']
        else array[lower(category)]
      end as keywords
    ) mapped
    where exists (
      select 1 from unnest(mapped.keywords) keyword
      where position(keyword in lower(trim(coalesce(profession_value, '')))) > 0
    )
  );
$$;

create index if not exists profiles_discover_page_idx
  on public.profiles(gender, created_at desc, id desc)
  where status = 'active' and is_discoverable;
create index if not exists profiles_discover_active_idx
  on public.profiles(last_active_at desc, id desc)
  where status = 'active' and is_discoverable;
create index if not exists profiles_spoken_languages_gin_idx
  on public.profiles using gin(spoken_languages);

create or replace function public.discover_profiles_page(
  tab_value text default 'Discover',
  filters_value jsonb default '{}'::jsonb,
  cursor_value jsonb default null,
  page_size_value integer default 30
)
returns table(item jsonb, item_cursor jsonb, has_more boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
  viewer_id uuid := auth.uid();
  viewer_tier public.subscription_tier;
  page_size integer := greatest(20, least(coalesce(page_size_value, 30), 40));
  genders text[] := array(select jsonb_array_elements_text(coalesce(filters_value->'genders', '[]'::jsonb)));
  countries text[] := array(select lower(trim(value)) from jsonb_array_elements_text(coalesce(filters_value->'country_codes', '[]'::jsonb)) value);
  regions text[] := array(select lower(trim(value)) from jsonb_array_elements_text(coalesce(filters_value->'regions', '[]'::jsonb)) value);
  cities text[] := array(select lower(trim(value)) from jsonb_array_elements_text(coalesce(filters_value->'cities', '[]'::jsonb)) value);
  country_ids uuid[] := array(select value::uuid from jsonb_array_elements_text(coalesce(filters_value->'country_ids', '[]'::jsonb)) value);
  region_ids uuid[] := array(select value::uuid from jsonb_array_elements_text(coalesce(filters_value->'region_ids', '[]'::jsonb)) value);
  city_ids uuid[] := array(select value::uuid from jsonb_array_elements_text(coalesce(filters_value->'city_ids', '[]'::jsonb)) value);
  origin_countries text[] := array(select lower(trim(value)) from jsonb_array_elements_text(coalesce(filters_value->'origin_country_names', '[]'::jsonb)) value);
  origin_regions text[] := array(select lower(trim(value)) from jsonb_array_elements_text(coalesce(filters_value->'origin_regions', '[]'::jsonb)) value);
  origin_cities text[] := array(select lower(trim(value)) from jsonb_array_elements_text(coalesce(filters_value->'origin_cities', '[]'::jsonb)) value);
  origin_country_ids uuid[] := array(select value::uuid from jsonb_array_elements_text(coalesce(filters_value->'origin_country_ids', '[]'::jsonb)) value);
  origin_region_ids uuid[] := array(select value::uuid from jsonb_array_elements_text(coalesce(filters_value->'origin_region_ids', '[]'::jsonb)) value);
  origin_city_ids uuid[] := array(select value::uuid from jsonb_array_elements_text(coalesce(filters_value->'origin_city_ids', '[]'::jsonb)) value);
  languages text[] := array(select lower(trim(value)) from jsonb_array_elements_text(coalesce(filters_value->'languages', '[]'::jsonb)) value);
  goals text[] := array(select lower(trim(value)) from jsonb_array_elements_text(coalesce(filters_value->'relationship_goals', '[]'::jsonb)) value);
  interests text[] := array(select lower(trim(value)) from jsonb_array_elements_text(coalesce(filters_value->'interest_slugs', '[]'::jsonb)) value);
  religions text[] := array(select lower(trim(value)) from jsonb_array_elements_text(coalesce(filters_value->'religions', '[]'::jsonb)) value);
  body_types text[] := array(select private.discovery_body_type(value) from jsonb_array_elements_text(coalesce(filters_value->'body_types', '[]'::jsonb)) value);
  eye_colors text[] := array(select lower(trim(value)) from jsonb_array_elements_text(coalesce(filters_value->'eye_colors', '[]'::jsonb)) value);
  hair_colors text[] := array(select lower(trim(value)) from jsonb_array_elements_text(coalesce(filters_value->'hair_colors', '[]'::jsonb)) value);
  children_values text[] := array(select lower(trim(value)) from jsonb_array_elements_text(coalesce(filters_value->'children_preferences', '[]'::jsonb)) value);
  relationship_values text[] := array(select lower(trim(value)) from jsonb_array_elements_text(coalesce(filters_value->'relationship_statuses', '[]'::jsonb)) value);
  education_values text[] := array(select lower(trim(value)) from jsonb_array_elements_text(coalesce(filters_value->'education_levels', '[]'::jsonb)) value);
  beard_values text[] := array(select lower(trim(value)) from jsonb_array_elements_text(coalesce(filters_value->'beard_styles', '[]'::jsonb)) value);
  smoking_values text[] := array(select lower(trim(value)) from jsonb_array_elements_text(coalesce(filters_value->'smoking_statuses', '[]'::jsonb)) value);
  profession_values text[] := array(select lower(trim(value)) from jsonb_array_elements_text(coalesce(filters_value->'profession_categories', '[]'::jsonb)) value);
  income_values text[] := array(select lower(trim(value)) from jsonb_array_elements_text(coalesce(filters_value->'income_levels', '[]'::jsonb)) value);
  location_mode text := coalesce(filters_value->>'location_mode', 'near_me');
  required_location boolean := coalesce((filters_value->>'required_location')::boolean, false);
  required_languages boolean := coalesce((filters_value->>'required_languages')::boolean, false);
  required_goal boolean := coalesce((filters_value->>'required_relationship_goal')::boolean, false);
  vip_only boolean := coalesce((filters_value->>'vip_only')::boolean, false);
  premium_only boolean := coalesce((filters_value->>'premium_only')::boolean, false);
  most_liked boolean := coalesce((filters_value->>'most_liked_first')::boolean, false);
  search_country text;
  search_region text;
  search_city text;
  has_country_pass boolean;
  has_international_pass boolean;
begin
  if viewer_id is null then raise exception 'Authentication required'; end if;
  if cardinality(genders) <> 1 then
    raise exception 'Choose exactly one gender before using Discover';
  end if;

  viewer_tier := private.current_subscription_tier(viewer_id);
  select exists (
    select 1 from public.payment_entitlements entitlement
    where entitlement.user_id = viewer_id
      and entitlement.entitlement_kind = 'country_pass'
      and entitlement.expires_at > now()
  ) into has_country_pass;
  select exists (
    select 1 from public.payment_entitlements entitlement
    where entitlement.user_id = viewer_id
      and entitlement.entitlement_kind = 'international_pass'
      and entitlement.expires_at > now()
  ) into has_international_pass;

  if vip_only and viewer_tier not in ('elite', 'vip') then
    raise exception 'VIP profiles require a VIP subscription';
  end if;
  if premium_only and viewer_tier not in ('plus', 'elite', 'vip') then
    raise exception 'Premium profile discovery requires Premium Plus';
  end if;
  if (cardinality(origin_countries) > 0 or cardinality(origin_regions) > 0
      or cardinality(origin_cities) > 0)
     and viewer_tier not in ('plus', 'elite', 'vip') then
    raise exception 'Origin filters require Premium Plus';
  end if;
  if location_mode = 'my_country' and not has_country_pass
     and viewer_tier not in ('plus', 'elite', 'vip') then
    raise exception 'Country search requires Premium Plus';
  end if;
  if location_mode in ('specific_country', 'worldwide')
     and not has_international_pass
     and viewer_tier not in ('elite', 'vip') then
    raise exception 'International search requires Premium VIP';
  end if;

  select
    coalesce(countries[1], lower(trim(profile.country_name))),
    coalesce(regions[1], case when location_mode in ('near_me', 'my_country') then lower(trim(profile.residence_region)) end),
    coalesce(cities[1], case when location_mode in ('near_me', 'my_country') then lower(trim(coalesce(profile.residence_city, profile.city))) end)
  into search_country, search_region, search_city
  from public.profiles profile where profile.id = viewer_id;

  return query
  with viewer_location as materialized (
    select location from private.user_locations where user_id = viewer_id
  ), base as materialized (
    select
      profile.*,
      stats.primary_photo_id,
      stats.primary_photo_path,
      stats.primary_photo_created_at,
      stats.primary_photo_likes,
      stats.primary_photo_super_likes,
      stats.primary_photo_comments,
      stats.popular_photo_id,
      stats.popular_photo_path,
      stats.popular_photo_created_at,
      stats.popular_photo_likes,
      stats.popular_photo_super_likes,
      stats.popular_photo_comments,
      stats.engagement_score,
      stats.popularity_score,
      candidate_subscription.tier in ('elite', 'vip') as is_vip,
      coalesce(cached.score, 80)::integer as cached_compatibility,
      (outgoing.liked_id is not null) as liked_by_me,
      arrival.country_name as arrival_country,
      arrival.region_name as arrival_region,
      arrival.city_name as arrival_city,
      arrival.arrival_month,
      case
        when candidate_location.location is null or viewer_location.location is null then null
        else extensions.st_distance(candidate_location.location, viewer_location.location) / 1000.0
      end as distance_km,
      profile.created_at > now() - interval '28 days' as is_new,
      profile.show_online_status and profile.is_online
        and profile.last_active_at > now() - interval '3 minutes'
        as discovery_is_online
    from public.profiles profile
    join private.profile_discovery_stats stats on stats.profile_id = profile.id
      and stats.primary_photo_path is not null
    left join public.compatibility_scores cached
      on cached.user_id = viewer_id and cached.candidate_id = profile.id
    left join public.profile_likes outgoing
      on outgoing.liker_id = viewer_id and outgoing.liked_id = profile.id
    left join private.user_locations candidate_location
      on candidate_location.user_id = profile.id
    left join viewer_location on true
    cross join lateral (
      select private.current_subscription_tier(profile.id) as tier
    ) candidate_subscription
    left join lateral (
      select destination.country_name, destination.region_name,
             destination.city_name, destination.arrival_month
      from public.upcoming_arrival_destinations destination
      where destination.user_id = profile.id
        and destination.is_active
        and profile.allow_international_discovery
        and candidate_subscription.tier in ('elite', 'vip')
        and lower(trim(destination.country_name)) = search_country
        and (
          destination.region_name is null
          or (search_region is not null
              and lower(trim(destination.region_name)) = search_region)
        )
        and (
          destination.city_name is null
          or (search_city is not null
              and lower(trim(destination.city_name)) = search_city)
        )
      order by destination.arrival_month nulls last, destination.created_at,
               destination.id
      limit 1
    ) arrival on true
    where profile.id <> viewer_id
      and profile.status = 'active'
      and profile.is_discoverable
      and private.can_view_profile(profile.id)
      and lower(trim(profile.gender)) = case lower(trim(genders[1]))
        when 'women' then 'woman' when 'woman' then 'woman'
        when 'men' then 'man' when 'man' then 'man'
        else lower(trim(genders[1])) end
      and extract(year from age(current_date, profile.date_of_birth))::integer
          between coalesce((filters_value->>'minimum_age')::integer, 18)
              and coalesce((filters_value->>'maximum_age')::integer, 80)
      and (location_mode not in ('specific_country', 'worldwide')
           or profile.allow_international_discovery)
      and (not vip_only or candidate_subscription.tier in ('elite', 'vip'))
      and (not premium_only or candidate_subscription.tier in ('plus', 'elite', 'vip'))
      and (cardinality(origin_countries) = 0 or lower(trim(coalesce(profile.origin_country_name, ''))) = any(origin_countries))
      and (cardinality(origin_regions) = 0 or lower(trim(coalesce(profile.origin_region, ''))) = any(origin_regions))
      and (cardinality(origin_cities) = 0 or lower(trim(coalesce(profile.origin_city, ''))) = any(origin_cities))
      and (cardinality(origin_country_ids) = 0 or profile.origin_country_id = any(origin_country_ids))
      and (cardinality(origin_region_ids) = 0 or profile.origin_region_id = any(origin_region_ids))
      and (cardinality(origin_city_ids) = 0 or profile.origin_city_id = any(origin_city_ids))
      and (not required_languages or cardinality(languages) = 0 or exists (
        select 1 from unnest(profile.spoken_languages) value
        where lower(trim(value)) = any(languages)
      ))
      and (not required_goal or cardinality(goals) = 0
           or lower(trim(coalesce(profile.relationship_goal, ''))) = any(goals))
      and (cardinality(interests) = 0 or exists (
        select 1 from unnest(profile.interest_slugs) value
        where lower(trim(value)) = any(interests)
      ))
      and (cardinality(religions) = 0 or lower(trim(coalesce(profile.religion, ''))) = any(religions))
      and (cardinality(body_types) = 0 or private.discovery_body_type(profile.body_type) = any(body_types))
      and (cardinality(eye_colors) = 0 or lower(trim(coalesce(profile.eye_color, ''))) = any(eye_colors))
      and (cardinality(hair_colors) = 0 or lower(trim(coalesce(profile.hair_color, ''))) = any(hair_colors))
      and (filters_value->>'minimum_height_cm' is null or coalesce(profile.height_cm, 0) >= (filters_value->>'minimum_height_cm')::integer)
      and (filters_value->>'maximum_height_cm' is null or coalesce(profile.height_cm, 1000) <= (filters_value->>'maximum_height_cm')::integer)
      and (cardinality(children_values) = 0 or lower(trim(coalesce(profile.children_preference, ''))) = any(children_values))
      and (cardinality(relationship_values) = 0 or lower(trim(coalesce(profile.relationship_status, ''))) = any(relationship_values))
      and (cardinality(education_values) = 0 or lower(trim(coalesce(profile.education_level, ''))) = any(education_values))
      and (cardinality(beard_values) = 0 or lower(trim(coalesce(profile.beard_style, ''))) = any(beard_values))
      and (cardinality(smoking_values) = 0 or lower(trim(coalesce(profile.smoking_status, ''))) = any(smoking_values))
      and (cardinality(income_values) = 0 or lower(trim(coalesce(profile.income_level, ''))) = any(income_values))
      and private.discovery_profession_matches(profile.profession, profession_values)
      and (not coalesce((filters_value->>'photo_verified_only')::boolean, false) or profile.is_photo_verified)
      and (not coalesce((filters_value->>'verified_only')::boolean, false) or profile.is_verified)
      and (not coalesce((filters_value->>'active_today_only')::boolean, false)
           or profile.last_active_at >= now() - interval '25 hours')
      and (
        not (tab_value = 'Nearby'
             or (location_mode = 'near_me' and required_location))
        or arrival.country_name is not null
        or (
          candidate_location.location is not null
          and viewer_location.location is not null
          and extensions.st_dwithin(
            candidate_location.location,
            viewer_location.location,
            coalesce((filters_value->>'distance_km')::integer, 50) * 1000.0
          )
        )
      )
  ), geographically_filtered as materialized (
    select base.*
    from base
    where (
      not required_location
      or (
        (cardinality(countries) = 0 or lower(trim(coalesce(base.arrival_country, base.country_name, ''))) = any(countries))
        and (cardinality(regions) = 0 or lower(trim(coalesce(base.arrival_region, base.residence_region, ''))) = any(regions))
        and (cardinality(cities) = 0 or lower(trim(coalesce(base.arrival_city, base.residence_city, base.city, ''))) = any(cities))
        and (base.arrival_country is not null or cardinality(country_ids) = 0 or base.residence_country_id = any(country_ids))
        and (base.arrival_country is not null or cardinality(region_ids) = 0 or base.residence_region_id = any(region_ids))
        and (base.arrival_country is not null or cardinality(city_ids) = 0 or base.residence_city_id = any(city_ids))
      )
    )
      and (tab_value <> 'Online' or base.discovery_is_online)
      and (tab_value <> 'New' or base.is_new)
  ), ranked as materialized (
    select
      geographically_filtered.*,
      case when most_liked then popularity_score else 0 end::bigint as sort_popularity,
      case when is_new then 1 else 0 end::integer as sort_new,
      extract(epoch from created_at)::bigint as sort_created
    from geographically_filtered
  ), after_cursor as materialized (
    select * from ranked
    where cursor_value is null or (
      sort_popularity, sort_new, engagement_score,
      cached_compatibility, sort_created, id
    ) < (
      (cursor_value->>'popularity')::bigint,
      (cursor_value->>'new')::integer,
      (cursor_value->>'engagement')::integer,
      (cursor_value->>'compatibility')::integer,
      (cursor_value->>'created')::bigint,
      (cursor_value->>'id')::uuid
    )
    order by sort_popularity desc, sort_new desc, engagement_score desc,
             cached_compatibility desc, sort_created desc, id desc
    limit page_size + 1
  ), selected as materialized (
    select * from after_cursor
    order by sort_popularity desc, sort_new desc, engagement_score desc,
             cached_compatibility desc, sort_created desc, id desc
    limit page_size
  ), enriched as materialized (
    select selected.*, calculated.score as calculated_score,
           calculated.breakdown as calculated_breakdown
    from selected
    cross join lateral public.calculate_compatibility(selected.id) calculated
  )
  select
    jsonb_build_object(
      'id', value.id,
      'first_name', value.first_name,
      'date_of_birth', value.date_of_birth,
      'gender', value.gender,
      'bio', value.bio,
      'country_name', value.country_name,
      'city', value.city,
      'residence_region', value.residence_region,
      'residence_country_id', value.residence_country_id,
      'residence_region_id', value.residence_region_id,
      'residence_city_id', value.residence_city_id,
      'origin_country_name', value.origin_country_name,
      'origin_region', value.origin_region,
      'origin_city', value.origin_city,
      'origin_country_id', value.origin_country_id,
      'origin_region_id', value.origin_region_id,
      'origin_city_id', value.origin_city_id,
      'profession', value.profession,
      'education_level', value.education_level,
      'height_cm', value.height_cm,
      'relationship_goal', value.relationship_goal,
      'spoken_languages', value.spoken_languages,
      'photo_display_style', value.photo_display_style,
      'last_active_at', value.last_active_at,
      'created_at', value.created_at
    ) || jsonb_build_object(
      'is_verified', value.is_verified,
      'is_photo_verified', value.is_photo_verified,
      'religion', value.religion,
      'children_preference', value.children_preference,
      'relationship_status', value.relationship_status,
      'body_type', value.body_type,
      'eye_color', value.eye_color,
      'hair_color', value.hair_color,
      'beard_style', value.beard_style,
      'smoking_status', value.smoking_status,
      'income_level', value.income_level,
      'interest_slugs', value.interest_slugs,
      'allow_international_discovery', value.allow_international_discovery,
      'show_origin_on_profile', value.show_origin_on_profile,
      'is_vip', value.is_vip,
      'liked_by_me', value.liked_by_me,
      'compatibility_score', value.calculated_score,
      'compatibility_breakdown', value.calculated_breakdown,
      'distance_km', case
        when tab_value = 'Nearby'
          or (location_mode = 'near_me' and required_location)
        then coalesce(round(value.distance_km)::integer, 0)
        else 5
      end,
      'is_online', value.discovery_is_online,
      'is_new', value.is_new,
      'arrival_country', value.arrival_country,
      'arrival_region', value.arrival_region,
      'arrival_city', value.arrival_city,
      'arrival_month', value.arrival_month,
      'primary_photo', jsonb_build_object(
        'id', value.primary_photo_id,
        'storage_path', value.primary_photo_path,
        'created_at', value.primary_photo_created_at,
        'likes', value.primary_photo_likes,
        'super_likes', value.primary_photo_super_likes,
        'comments', value.primary_photo_comments
      ),
      'popular_photo', jsonb_build_object(
        'id', value.popular_photo_id,
        'storage_path', value.popular_photo_path,
        'created_at', value.popular_photo_created_at,
        'likes', value.popular_photo_likes,
        'super_likes', value.popular_photo_super_likes,
        'comments', value.popular_photo_comments
      )
    ),
    jsonb_build_object(
      'popularity', value.sort_popularity,
      'new', value.sort_new,
      'engagement', value.engagement_score,
      'compatibility', value.cached_compatibility,
      'created', value.sort_created,
      'id', value.id
    ),
    (select count(*) > page_size from after_cursor)
  from enriched value
  order by value.sort_popularity desc, value.sort_new desc,
           value.engagement_score desc, value.cached_compatibility desc,
           value.sort_created desc, value.id desc;
end;
$$;

revoke execute on function public.discover_profiles_page(
  text, jsonb, jsonb, integer
) from public, anon;
grant execute on function public.discover_profiles_page(
  text, jsonb, jsonb, integer
) to authenticated;

comment on function public.discover_profiles_page(text, jsonb, jsonb, integer)
is 'Keyset-paginated Discover page with server-side filters, block/visibility rules, batched card metadata and compatibility limited to returned candidates.';

commit;
