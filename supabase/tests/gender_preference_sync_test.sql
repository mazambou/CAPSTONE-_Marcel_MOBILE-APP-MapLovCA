begin;

create extension if not exists pgtap with schema extensions;
select plan(6);

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000d8","role":"service_role"}',
  true
);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-4000-8000-0000000000d8',
  'authenticated', 'authenticated', 'gender-sync@maplov.test', '', now(), '{}',
  '{"first_name":"Gender Sync","date_of_birth":"1990-01-01"}',
  now(), now()
);

select ok(
  exists(
    select 1
    from pg_trigger
    where tgname = 'profiles_sync_default_gender_preference'
      and not tgisinternal
  ),
  'profile gender changes trigger dating-preference synchronization'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000d8","role":"authenticated"}',
  true
);

update public.profiles
set gender = 'Man'
where id = '00000000-0000-4000-8000-0000000000d8';

select is(
  (
    select genders
    from public.dating_preferences
    where user_id = '00000000-0000-4000-8000-0000000000d8'
  ),
  array['Woman']::text[],
  'a man defaults to meeting women'
);

update public.dating_preferences
set genders = array['Non-binary'],
    required_genders = true
where user_id = '00000000-0000-4000-8000-0000000000d8';
update public.profiles
set bio = 'An unrelated profile edit'
where id = '00000000-0000-4000-8000-0000000000d8';

select is(
  (
    select genders
    from public.dating_preferences
    where user_id = '00000000-0000-4000-8000-0000000000d8'
  ),
  array['Non-binary']::text[],
  'unrelated profile edits preserve a manual dating preference'
);

update public.dating_preferences
set body_types = array['women_slim', 'men_athletic']
where user_id = '00000000-0000-4000-8000-0000000000d8';
update public.profiles
set gender = 'Woman'
where id = '00000000-0000-4000-8000-0000000000d8';

select is(
  (
    select genders
    from public.dating_preferences
    where user_id = '00000000-0000-4000-8000-0000000000d8'
  ),
  array['Man']::text[],
  'a woman defaults to meeting men'
);

select is(
  (
    select body_types
    from public.dating_preferences
    where user_id = '00000000-0000-4000-8000-0000000000d8'
  ),
  array['men_athletic']::text[],
  'a gender change removes silhouettes incompatible with the new preference'
);

update public.profiles
set gender = 'Non-binary'
where id = '00000000-0000-4000-8000-0000000000d8';

select is(
  (
    select genders
    from public.dating_preferences
    where user_id = '00000000-0000-4000-8000-0000000000d8'
  ),
  array['Non-binary']::text[],
  'a non-binary member defaults to meeting non-binary members'
);

select * from finish();
rollback;
