begin;

create extension if not exists pgtap with schema extensions;
select plan(7);

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000e5","role":"service_role"}',
  true
);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-4000-8000-0000000000e5',
  'authenticated', 'authenticated', 'location@maplov.test', '', now(), '{}',
  '{"first_name":"Location Test","date_of_birth":"1990-01-01","country_code":"CA","country_name":"Canada","residence_region":"Ontario","city":"Toronto"}',
  now(), now()
);

insert into private.user_locations (
  user_id, latitude, longitude, accuracy_meters, updated_at
) values (
  '00000000-0000-4000-8000-0000000000e5',
  48.8566, 2.3522, 8, now()
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000e5","role":"authenticated"}',
  true
);

select lives_ok(
  $$select public.sync_my_residence_from_location(
    'France', 'FR', 'Île-de-France', 'Paris'
  )$$,
  'a recent device location can update the residence country'
);
select is(
  (select country_name from public.profiles
    where id = '00000000-0000-4000-8000-0000000000e5'),
  'France',
  'the detected country becomes the profile residence country'
);
select is(
  (select residence_region from public.profiles
    where id = '00000000-0000-4000-8000-0000000000e5'),
  'Île-de-France',
  'region is initialized after a detected country change'
);
select ok(
  (select residence_location_verified_at >= now() - interval '1 minute'
   from public.profiles
   where id = '00000000-0000-4000-8000-0000000000e5'),
  'the server records a recent GPS-backed residence verification'
);

update public.profiles
set residence_region = 'Adjusted region',
    city = 'Adjusted city',
    residence_city = 'Adjusted city'
where id = '00000000-0000-4000-8000-0000000000e5';

select lives_ok(
  $$select public.sync_my_residence_from_location(
    'France', 'FR', 'Another region', 'Another city'
  )$$,
  'automatic refresh accepts the same detected country'
);
select is(
  (select residence_region || '|' || residence_city
   from public.profiles
   where id = '00000000-0000-4000-8000-0000000000e5'),
  'Adjusted region|Adjusted city',
  'manual region and city corrections survive same-country refreshes'
);
select throws_ok(
  $$update public.profiles
    set country_name = 'Canada', residence_country_name = 'Canada'
    where id = '00000000-0000-4000-8000-0000000000e5'$$,
  'Residence country is controlled by verified device location',
  'an authenticated user cannot directly change the residence country'
);

select * from finish();
rollback;
