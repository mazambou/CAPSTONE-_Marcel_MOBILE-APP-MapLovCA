begin;

create extension if not exists pgtap with schema extensions;
select plan(11);

select ok(
  exists(
    select 1
    from pg_constraint
    where conname = 'profiles_body_type_values'
      and conrelid = 'public.profiles'::regclass
      and contype = 'c'
  ),
  'profile body types use the normalized visual-option constraint'
);

select ok(
  exists(
    select 1
    from pg_constraint
    where conname = 'dating_preferences_body_type_values'
      and conrelid = 'public.dating_preferences'::regclass
      and contype = 'c'
  ),
  'preference body types use the normalized visual-option constraint'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000f6","role":"service_role"}',
  true
);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-4000-8000-0000000000f6',
  'authenticated', 'authenticated', 'body-types@maplov.test', '', now(), '{}',
  '{"first_name":"Body Type Test","date_of_birth":"1990-01-01"}',
  now(), now()
);

select lives_ok(
  $$update public.profiles
    set gender = 'Woman',
        body_type = 'women_very_round'
    where id = '00000000-0000-4000-8000-0000000000f6'$$,
  'a normalized profile body type is accepted'
);

select lives_ok(
  $$update public.dating_preferences
    set genders = array['Woman'],
        body_types = array['women_slim', 'women_athletic', 'women_round']
    where user_id = '00000000-0000-4000-8000-0000000000f6'$$,
  'multiple normalized preference body types are accepted'
);

select throws_ok(
  $$update public.profiles
    set body_type = 'obese'
    where id = '00000000-0000-4000-8000-0000000000f6'$$,
  '23514',
  'new row for relation "profiles" violates check constraint "profiles_body_type_values"',
  'an obsolete profile body-type label is rejected'
);

select throws_ok(
  $$update public.dating_preferences
    set body_types = array['slim', 'strong fat']
    where user_id = '00000000-0000-4000-8000-0000000000f6'$$,
  '23514',
  'new row for relation "dating_preferences" violates check constraint "dating_preferences_body_type_values"',
  'an obsolete preference body-type label is rejected'
);

select throws_ok(
  $$update public.dating_preferences
    set genders = array['Woman', 'Man']
    where user_id = '00000000-0000-4000-8000-0000000000f6'$$,
  '23514',
  'new row for relation "dating_preferences" violates check constraint "dating_preferences_single_gender"',
  'dating preferences accept only one gender'
);

select throws_ok(
  $$update public.dating_preferences
    set genders = array['Everyone']
    where user_id = '00000000-0000-4000-8000-0000000000f6'$$,
  '23514',
  'new row for relation "dating_preferences" violates check constraint "dating_preferences_gender_values"',
  'dating preferences reject values outside the three supported genders'
);

select throws_ok(
  $$update public.profiles
    set gender = 'Woman',
        body_type = 'men_slim'
    where id = '00000000-0000-4000-8000-0000000000f6'$$,
  '23514',
  'new row for relation "profiles" violates check constraint "profiles_body_type_matches_gender"',
  'a personal silhouette must match the profile gender'
);

select throws_ok(
  $$update public.dating_preferences
    set genders = array['Woman'],
        body_types = array['men_slim']
    where user_id = '00000000-0000-4000-8000-0000000000f6'$$,
  '23514',
  'new row for relation "dating_preferences" violates check constraint "dating_preferences_body_types_match_gender"',
  'searched silhouettes must match the chosen gender preference'
);

select is(
  (
    select column_default
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'dating_preferences'
      and column_name = 'maximum_age'
  ),
  '80',
  'new filters default to a maximum age of 80'
);

select * from finish();
rollback;
