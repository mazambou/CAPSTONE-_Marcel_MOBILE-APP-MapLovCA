begin;

create extension if not exists pgtap with schema extensions;
select plan(16);

select has_table(
  'private',
  'permanent_admin_emails',
  'permanent owner administrators are stored outside the exposed schema'
);
select ok(
  exists (
    select 1
    from private.permanent_admin_emails
    where email = 'mazambou@gmail.com'
  ),
  'the requested owner email is permanently protected'
);
select has_function(
  'public',
  'admin_schedule_account_deletion',
  array['uuid', 'text'],
  'full administrators can schedule deletion'
);
select has_function(
  'public',
  'admin_prepare_immediate_account_deletion',
  array['uuid', 'text'],
  'full administrators can prepare immediate deletion'
);
select has_function(
  'public',
  'claim_due_account_deletions',
  array['integer'],
  'the Edge Function can claim due deletion work'
);
select has_function(
  'public',
  'purge_account_relations_before_auth_delete',
  array['uuid'],
  'the Edge Function can purge generic account references'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.claim_due_account_deletions(integer)',
    'EXECUTE'
  ),
  'members cannot claim scheduled deletions'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.purge_account_relations_before_auth_delete(uuid)',
    'EXECUTE'
  ),
  'members cannot invoke the final purge'
);
select unalike(
  pg_get_functiondef(
    'public.process_due_account_deletions(integer)'::regprocedure
  ),
  '%delete from storage.objects%',
  'the legacy processor no longer deletes Storage metadata directly'
);
select ok(
  exists (
    select 1
    from cron.job
    where jobname = 'maplov-account-erasure'
      and command like '%net.http_post%'
      and command like '%admin-delete-account%'
  ),
  'scheduled deletion calls the physical-erasure Edge Function'
);

insert into private.permanent_admin_emails(email)
values ('owner-admin-test@maplov.test');

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-4000-8000-000000000041',
  'authenticated', 'authenticated', 'owner-admin-test@maplov.test', '', now(),
  '{}', '{"first_name":"Owner Admin","date_of_birth":"1990-01-01"}',
  now(), now()
), (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-4000-8000-000000000042',
  'authenticated', 'authenticated', 'deletion-target@maplov.test', '', now(),
  '{}', '{"first_name":"Deletion Target","date_of_birth":"1990-01-01"}',
  now(), now()
);

select is(
  (
    select role::text
    from public.profiles
    where id = '00000000-0000-4000-8000-000000000041'
  ),
  'admin',
  'a protected email is promoted after Auth signup'
);
select is(
  (
    select status::text
    from public.profiles
    where id = '00000000-0000-4000-8000-000000000041'
  ),
  'active',
  'a permanent administrator remains active'
);
select throws_ok(
  $$
    update public.profiles
    set role = 'user'
    where id = '00000000-0000-4000-8000-000000000041'
  $$,
  'P0001',
  'The permanent owner administrator cannot be demoted or disabled',
  'even a backend update cannot demote a protected owner without removing protection'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000041","role":"authenticated"}',
  true
);

select lives_ok(
  $$
    select public.admin_schedule_account_deletion(
      '00000000-0000-4000-8000-000000000042',
      'Automated security test'
    )
  $$,
  'a full administrator can schedule a normal account'
);
select is(
  (
    select status
    from public.account_deletion_requests
    where user_id = '00000000-0000-4000-8000-000000000042'
  ),
  'pending',
  'scheduled deletion remains reversible during the 30-day window'
);
select is(
  (
    select scheduled_for::date - requested_at::date
    from public.account_deletion_requests
    where user_id = '00000000-0000-4000-8000-000000000042'
  ),
  30,
  'the administrative grace period is exactly 30 days'
);

select * from finish(true);
rollback;
