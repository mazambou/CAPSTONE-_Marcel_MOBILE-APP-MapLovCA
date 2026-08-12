begin;

create extension if not exists pgtap with schema extensions;
select plan(11);

select has_function(
  'public',
  'discover_profiles_page',
  array['text', 'jsonb', 'jsonb', 'integer'],
  'Discover uses one paginated server RPC'
);
select has_table(
  'private',
  'profile_discovery_stats',
  'Discover card aggregates are maintained privately'
);
select has_index(
  'private',
  'user_locations',
  'user_locations_geography_gist_idx',
  'Nearby coordinates use a GiST geography index'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'private.profile_discovery_stats',
    'SELECT'
  ),
  'clients cannot read private discovery aggregates directly'
);

create temporary table discover_test_users(
  ordinal integer primary key,
  id uuid not null unique
) on commit drop;

insert into discover_test_users(ordinal, id)
select value, gen_random_uuid() from generate_series(0, 45) value;
grant select on discover_test_users to authenticated;

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
select
  '00000000-0000-0000-0000-000000000000', test_user.id,
  'authenticated', 'authenticated',
  'discover-' || test_user.ordinal || '@maplov.test', '', now(), '{}', '{}',
  now() - interval '90 days', now()
from discover_test_users test_user;

select set_config('request.jwt.claims', '{"role":"service_role"}', true);
select set_config('maplov.location_country_sync', 'true', true);
update public.profiles profile
set first_name = 'Discover ' || test_user.ordinal,
    date_of_birth = date '1990-01-01',
    gender = case when test_user.ordinal = 0 then 'Man' else 'Woman' end,
    country_name = 'Canada',
    residence_country_name = 'Canada',
    residence_region = 'Ontario',
    city = 'Toronto',
    residence_city = 'Toronto',
    origin_country_name = 'Canada',
    origin_region = 'Ontario',
    origin_city = 'Toronto',
    spoken_languages = array['English'],
    relationship_goal = 'Long-term relationship',
    is_verified = test_user.ordinal % 2 = 0,
    is_photo_verified = true,
    is_discoverable = true,
    profile_completed_at = now() - interval '80 days',
    created_at = now() - interval '90 days'
from discover_test_users test_user
where profile.id = test_user.id;

update public.dating_preferences preference
set genders = array['Woman'], required_genders = true
from discover_test_users test_user
where preference.user_id = test_user.id and test_user.ordinal = 0;

insert into private.user_locations(
  user_id, latitude, longitude, accuracy_meters, updated_at
)
select test_user.id,
       43.6532 + test_user.ordinal * 0.0001,
       -79.3832, 5, now()
from discover_test_users test_user;

insert into public.profile_photos(
  id, user_id, storage_path, display_order, is_primary,
  moderation_status, created_at
)
select gen_random_uuid(), test_user.id,
       test_user.id || '/primary.jpg', 0, true, 'visible',
       now() - interval '2 days'
from discover_test_users test_user
where test_user.ordinal > 0;

-- Candidate 1 has a non-primary photo with more likes. Discover must retain it
-- for the existing Most liked photos section while using the primary for cards.
insert into public.profile_photos(
  id, user_id, storage_path, display_order, is_primary,
  moderation_status, created_at
)
select gen_random_uuid(), test_user.id,
       test_user.id || '/popular.jpg', 1, false, 'visible', now()
from discover_test_users test_user where test_user.ordinal = 1;

insert into public.photo_likes(photo_id, user_id)
select photo.id, viewer.id
from public.profile_photos photo
join discover_test_users candidate on candidate.id = photo.user_id
join discover_test_users viewer on viewer.ordinal = 0
where candidate.ordinal = 1 and photo.display_order = 1;

-- Block one candidate to verify that RLS/business visibility is applied
-- before page selection.
insert into public.blocks(blocker_id, blocked_id)
select viewer.id, blocked.id
from discover_test_users viewer
join discover_test_users blocked on blocked.ordinal = 2
where viewer.ordinal = 0;

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from discover_test_users where ordinal = 0),
    'role', 'authenticated'
  )::text,
  true
);
set local role authenticated;

create temporary table first_discover_page on commit drop as
select * from public.discover_profiles_page(
  'Discover',
  jsonb_build_object(
    'genders', jsonb_build_array('Woman'),
    'minimum_age', 18,
    'maximum_age', 80,
    'distance_km', 50,
    'location_mode', 'near_me',
    'required_location', false
  ),
  null,
  30
);

select is(
  (select count(*)::integer from first_discover_page),
  30,
  'the first Discover page contains 30 profiles'
);
select ok(
  (select bool_and(has_more) from first_discover_page),
  'the first page announces another page'
);
select ok(
  not exists (
    select 1 from first_discover_page page
    join discover_test_users blocked
      on blocked.id = (page.item->>'id')::uuid
    where blocked.ordinal = 2
  ),
  'blocked profiles are excluded before pagination'
);
select ok(
  exists (
    select 1 from first_discover_page page
    join discover_test_users candidate
      on candidate.id = (page.item->>'id')::uuid
    where candidate.ordinal = 1
      and page.item->'primary_photo'->>'storage_path' like '%/primary.jpg'
      and page.item->'popular_photo'->>'storage_path' like '%/popular.jpg'
  ),
  'the primary and distinct most-liked photos are returned together'
);

create temporary table second_discover_page on commit drop as
select * from public.discover_profiles_page(
  'Discover',
  jsonb_build_object(
    'genders', jsonb_build_array('Woman'),
    'minimum_age', 18,
    'maximum_age', 80,
    'distance_km', 50,
    'location_mode', 'near_me',
    'required_location', false
  ),
  (select item_cursor from first_discover_page
   order by (item_cursor->>'popularity')::bigint,
            (item_cursor->>'new')::integer,
            (item_cursor->>'engagement')::integer,
            (item_cursor->>'compatibility')::integer,
            (item_cursor->>'created')::bigint,
            item_cursor->>'id'
   limit 1),
  30
);

select is(
  (select count(*)::integer from second_discover_page),
  14,
  'the cursor returns the remaining profiles'
);
select ok(
  not exists (
    select 1 from first_discover_page first_page
    join second_discover_page second_page
      on first_page.item->>'id' = second_page.item->>'id'
  ),
  'cursor pages never overlap'
);

select is(
  (
    select count(*)::integer
    from public.discover_profiles_page(
      'Discover',
      jsonb_build_object(
        'genders', jsonb_build_array('Woman'),
        'minimum_age', 18,
        'maximum_age', 80,
        'verified_only', true,
        'location_mode', 'near_me',
        'required_location', false
      ),
      null,
      30
    )
  ),
  21,
  'verified-only filtering happens before LIMIT'
);

select * from finish();
rollback;
