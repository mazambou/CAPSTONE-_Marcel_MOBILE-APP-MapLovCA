begin;

create extension if not exists pgtap with schema extensions;
select plan(12);

select has_function(
  'public',
  'has_completed_my_registration_gate',
  array[]::text[],
  'OAuth registration completion can be checked server-side'
);
select has_function(
  'public',
  'complete_my_social_registration_gate',
  array['date', 'jsonb', 'timestamp with time zone'],
  'OAuth users can complete the same age and legal gate'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.has_completed_my_registration_gate()',
    'EXECUTE'
  ),
  'authenticated OAuth users can inspect their registration gate'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.complete_my_social_registration_gate(date,jsonb,timestamptz)',
    'EXECUTE'
  ),
  'anonymous clients cannot complete an OAuth registration gate'
);

select has_function(
  'public',
  'enqueue_stale_incomplete_registrations',
  array[]::text[],
  'stale incomplete registrations have a cleanup scheduler'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.enqueue_stale_incomplete_registrations()',
    'EXECUTE'
  ),
  'members cannot queue account erasure work'
);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-4000-8000-000000000061',
    'authenticated', 'authenticated', 'stale-incomplete@maplov.test', '', now(),
    '{}', '{}', now() - interval '73 hours', now() - interval '73 hours'
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-4000-8000-000000000062',
    'authenticated', 'authenticated', 'recent-incomplete@maplov.test', '', now(),
    '{}', '{}', now() - interval '71 hours', now() - interval '71 hours'
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-4000-8000-000000000063',
    'authenticated', 'authenticated', 'completed-member@maplov.test', '', now(),
    '{}', '{}', now() - interval '10 days', now() - interval '10 days'
  );

update public.profiles
set created_at = now() - interval '73 hours'
where id = '00000000-0000-4000-8000-000000000061';
update public.profiles
set created_at = now() - interval '71 hours'
where id = '00000000-0000-4000-8000-000000000062';
update public.profiles
set created_at = now() - interval '10 days',
    profile_completed_at = now() - interval '9 days'
where id = '00000000-0000-4000-8000-000000000063';

set local role service_role;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);

select is(
  public.enqueue_stale_incomplete_registrations(),
  1,
  'only an incomplete registration older than 72 hours is queued'
);
reset role;
select is(
  (
    select request_origin
    from public.account_deletion_requests
    where user_id = '00000000-0000-4000-8000-000000000061'
  ),
  'incomplete_registration',
  'the cleanup reason is distinguished from member-requested deletion'
);
select is(
  (
    select status::text
    from public.profiles
    where id = '00000000-0000-4000-8000-000000000061'
  ),
  'deleted',
  'a queued incomplete profile is immediately hidden and disabled'
);
select ok(
  not exists (
    select 1 from public.account_deletion_requests
    where user_id = '00000000-0000-4000-8000-000000000062'
  ),
  'a registration younger than 72 hours is preserved'
);
select ok(
  not exists (
    select 1 from public.account_deletion_requests
    where user_id = '00000000-0000-4000-8000-000000000063'
  ),
  'an old completed member is preserved'
);
select ok(
  position(
    'profile_completed_at is not null' in
    pg_get_functiondef('public.admin_dashboard_statistics()'::regprocedure)
  ) > 0,
  'dashboard user totals require completed registration'
);

select * from finish();
rollback;
