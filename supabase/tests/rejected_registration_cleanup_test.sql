begin;

create extension if not exists pgtap with schema extensions;
select plan(3);

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000e9","role":"service_role"}',
  true
);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-4000-8000-0000000000e9',
    'authenticated', 'authenticated', 'existing-selfie@maplov.test', '', now(),
    '{}', '{"first_name":"Existing"}', now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-4000-8000-0000000000ea',
    'authenticated', 'authenticated', 'rejected-selfie@maplov.test', '', now(),
    '{}', '{"first_name":"Rejected"}', now(), now()
  );

insert into public.face_references (
  user_id, storage_path, face_confidence, consent_version, consented_at
) values (
  '00000000-0000-4000-8000-0000000000e9',
  '00000000-0000-4000-8000-0000000000e9/reference.jpg',
  100, 'test-consent', now()
);

update public.profiles
set status = 'suspended',
    is_discoverable = false
where id = '00000000-0000-4000-8000-0000000000ea';

insert into public.duplicate_account_checks (
  candidate_user_id, matched_user_id, residence_country, similarity, threshold
) values (
  '00000000-0000-4000-8000-0000000000ea',
  '00000000-0000-4000-8000-0000000000e9',
  'Canada', 99, 98
);

select is(
  public.cleanup_rejected_duplicate_registrations(100),
  1,
  'one rejected provisional registration is permanently cleaned'
);
select ok(
  not exists(
    select 1
    from auth.users
    where id = '00000000-0000-4000-8000-0000000000ea'
  ),
  'the rejected provisional Auth user no longer remains'
);
select ok(
  exists(
    select 1
    from auth.users
    where id = '00000000-0000-4000-8000-0000000000e9'
  ),
  'the existing account with its unique selfie is preserved'
);

select * from finish();
rollback;
