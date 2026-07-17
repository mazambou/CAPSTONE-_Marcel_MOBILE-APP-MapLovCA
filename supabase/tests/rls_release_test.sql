begin;

create extension if not exists pgtap with schema extensions;
select plan(5);

select has_function('public', 'export_my_data', array[]::text[],
  'authenticated users have a data export RPC');
select has_function('public', 'process_due_account_deletions', array['integer'],
  'a final account-erasure processor exists');
select has_table('public', 'data_export_requests',
  'data export requests are audited');
select is(
  (select count(*)::integer from information_schema.routine_privileges
   where routine_schema = 'public'
     and routine_name = 'process_due_account_deletions'
     and grantee = 'authenticated'),
  0,
  'authenticated clients cannot execute final erasure jobs'
);
select ok(
  exists(select 1 from cron.job where jobname = 'maplov-account-erasure'),
  'the hourly account-erasure job is scheduled'
);

select * from finish();
rollback;
