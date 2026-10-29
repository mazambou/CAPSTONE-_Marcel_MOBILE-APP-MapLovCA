begin;

create extension if not exists pgtap with schema extensions;
select plan(21);

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000f1","role":"service_role"}',
  true
);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-4000-8000-0000000000f1',
  'authenticated', 'authenticated', 'nonbio@maplov.test', '', now(), '{}',
  '{"first_name":"Account Test","date_of_birth":"1990-01-01","country_code":"CA","country_name":"Canada"}',
  now(), now()
);

update public.profiles
set country_code = 'CA',
    residence_location_verified_at = now(),
    first_name = 'Account Test',
    date_of_birth = date '1990-01-01',
    gender = 'Woman',
    city = 'Toronto',
    country_name = 'Canada',
    residence_region = 'Ontario',
    origin_country_name = 'Canada',
    origin_region = 'Ontario',
    origin_city = 'Toronto',
    spoken_languages = array['English']
where id = '00000000-0000-4000-8000-0000000000f1';

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000f1","role":"authenticated"}',
  true
);

select is(public.has_my_account_verification(), false,
  'email and residence alone do not enable the alternative');
select ok(
  not has_function_privilege(
    'authenticated',
    'public.register_account_checked_profile_photo(uuid,text)',
    'EXECUTE'
  ),
  'members cannot directly register photos'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000f1","role":"service_role"}',
  true
);
update auth.users
set phone = '+14165550101', phone_confirmed_at = now()
where id = '00000000-0000-4000-8000-0000000000f1';

insert into private.user_locations (
  user_id, latitude, longitude, accuracy_meters
) values (
  '00000000-0000-4000-8000-0000000000f1', 43.65, -79.38, 20
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000f1","role":"authenticated"}',
  true
);
select is(public.has_my_account_verification(), false,
  'confirmed email and phone outside Québec do not enable the alternative');
select throws_ok(
  $$update public.profiles set profile_completed_at = now()
    where id = '00000000-0000-4000-8000-0000000000f1'$$,
  'P0001',
  'A verified account and accepted primary photo are required',
  'a client cannot complete registration before adding an accepted photo'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000f1","role":"service_role"}',
  true
);
select throws_ok(
  $$select public.register_account_checked_profile_photo(
    '00000000-0000-4000-8000-0000000000f1',
    '00000000-0000-4000-8000-0000000000f1/rejected.jpg'
  )$$,
  'P0001',
  'The Québec residence check is required',
  'the server rejects an account-check photo without a Québec result'
);
select public.record_quebec_residence_check(
  '00000000-0000-4000-8000-0000000000f1',
  (select updated_at from private.user_locations
   where user_id = '00000000-0000-4000-8000-0000000000f1'),
  true, 'CA', 'Québec'
);
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000f1","role":"authenticated"}',
  true
);
select is(public.has_my_account_verification(), true,
  'a confirmed account with a Québec server check can use the alternative');
select throws_ok(
  $$update public.profiles set is_photo_verified = true
    where id = '00000000-0000-4000-8000-0000000000f1'$$,
  'P0001',
  'Protected profile fields cannot be changed by the user',
  'the owner cannot award a photo verification badge'
);
reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000f1","role":"service_role"}',
  true
);
select lives_ok(
  $$select public.register_account_checked_profile_photo(
    '00000000-0000-4000-8000-0000000000f1',
    '00000000-0000-4000-8000-0000000000f1/test.jpg'
  )$$,
  'the trusted function registers a photo without a face reference'
);
select ok(
  exists (
    select 1 from public.profile_photos
    where user_id = '00000000-0000-4000-8000-0000000000f1'
      and verification_method = 'account_checks'
      and is_verified = false
      and moderation_status = 'visible'
  ),
  'the photo has no face verification badge'
);
select ok(
  not exists (
    select 1 from public.face_references
    where user_id = '00000000-0000-4000-8000-0000000000f1'
  ),
  'the alternative does not create a biometric reference'
);
select ok(
  not exists (
    select 1 from public.profile_photo_face_checks
    where user_id = '00000000-0000-4000-8000-0000000000f1'
  ),
  'the alternative does not run a face comparison'
);
select ok(
  (select is_photo_verified from public.profiles
   where id = '00000000-0000-4000-8000-0000000000f1') = false,
  'the account-check route has no photo badge'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000f1","role":"authenticated"}',
  true
);
select lives_ok(
  $$update public.profiles set profile_completed_at = now()
    where id = '00000000-0000-4000-8000-0000000000f1'$$,
  'the account-check route can complete the profile with its accepted photo'
);
select throws_ok(
  $$update public.profile_photos
    set verification_method = 'face_match'
    where user_id = '00000000-0000-4000-8000-0000000000f1'$$,
  'P0001',
  'Photo identity and moderation fields are server-controlled',
  'the owner cannot change the server-recorded verification method'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000f1","role":"service_role"}',
  true
);
select public.try_acquire_face_enrollment_lock(
  'maplov_test_ca', '00000000-0000-4000-8000-0000000000a1', 300
);
select throws_ok(
  $$select public.register_indexed_face_reference_upgrade(
    '00000000-0000-4000-8000-0000000000f1',
    '00000000-0000-4000-8000-0000000000a2',
    '00000000-0000-4000-8000-0000000000f1/test.jpg',
    (select id from public.countries where iso2 = 'CA'),
    '00000000-0000-4000-8000-0000000000f1/selfie.jpg',
    'face-test', 'maplov_test_ca',
    '00000000-0000-4000-8000-0000000000f1',
    99.5, 98, 95, 'face-verification-v3-global-dedup',
    'detect-test', 'compare-test', 'index-test', 'model-test',
    '00000000-0000-4000-8000-0000000000a1'
  )$$,
  'P0001',
  'The primary photo changed during verification',
  'a stale primary-photo ID cannot receive a badge'
);
select lives_ok(
  $$select public.register_indexed_face_reference_upgrade(
    '00000000-0000-4000-8000-0000000000f1',
    (select id from public.profile_photos
     where user_id = '00000000-0000-4000-8000-0000000000f1' and is_primary),
    '00000000-0000-4000-8000-0000000000f1/test.jpg',
    (select id from public.countries where iso2 = 'CA'),
    '00000000-0000-4000-8000-0000000000f1/selfie.jpg',
    'face-test', 'maplov_test_ca',
    '00000000-0000-4000-8000-0000000000f1',
    99.5, 98, 95, 'face-verification-v3-global-dedup',
    'detect-test', 'compare-test', 'index-test', 'model-test',
    '00000000-0000-4000-8000-0000000000a1'
  )$$,
  'voluntary selfie verification upgrades the accepted primary photo'
);
select ok(
  exists (select 1 from public.profile_photos
    where user_id = '00000000-0000-4000-8000-0000000000f1'
      and is_primary and is_verified
      and verification_method = 'face_match'),
  'the primary photo becomes face verified'
);
select ok(
  (select is_photo_verified from public.profiles
   where id = '00000000-0000-4000-8000-0000000000f1'),
  'the profile photo badge is enabled by the trusted upgrade'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000f1","role":"service_role"}',
  true
);

update public.profiles
set country_code = 'FR'
where id = '00000000-0000-4000-8000-0000000000f1';
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000f1","role":"authenticated"}',
  true
);
select is(public.has_my_account_verification(), false,
  'the account-check route is limited to Canadian residence');

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000f1","role":"service_role"}',
  true
);
update private.user_locations set latitude = 45.50, longitude = -73.57,
  updated_at = now() + interval '1 second'
where user_id = '00000000-0000-4000-8000-0000000000f1';
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000f1","role":"authenticated"}',
  true
);
select is(public.has_my_account_verification(), false,
  'moving the device invalidates the cached Québec check');

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000f2","role":"service_role"}',
  true
);
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-4000-8000-0000000000f2',
  'authenticated', 'authenticated', 'face-route@maplov.test', '', now(), '{}',
  '{"first_name":"Face Test","date_of_birth":"1990-01-01","country_code":"CA","country_name":"Canada"}',
  now(), now()
);
update public.profiles
set first_name = 'Face Test',
    date_of_birth = date '1990-01-01',
    gender = 'Woman',
    city = 'Toronto',
    country_name = 'Canada',
    residence_region = 'Ontario',
    origin_country_name = 'Canada',
    origin_region = 'Ontario',
    origin_city = 'Toronto',
    spoken_languages = array['English']
where id = '00000000-0000-4000-8000-0000000000f2';
insert into public.face_references (
  user_id, storage_path, consent_version, consented_at
) values (
  '00000000-0000-4000-8000-0000000000f2',
  '00000000-0000-4000-8000-0000000000f2/reference.jpg',
  'face-verification-v3-global-dedup', now()
);
insert into public.profile_photos (
  user_id, storage_path, is_primary, is_verified,
  verification_method, moderation_status
) values (
  '00000000-0000-4000-8000-0000000000f2',
  '00000000-0000-4000-8000-0000000000f2/profile.jpg',
  true, true, 'face_match', 'visible'
);
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000f2","role":"authenticated"}',
  true
);
select lives_ok(
  $$update public.profiles set profile_completed_at = now(),
    is_discoverable = true
    where id = '00000000-0000-4000-8000-0000000000f2'$$,
  'the existing face-verified route can still complete registration'
);

select * from finish();
rollback;
