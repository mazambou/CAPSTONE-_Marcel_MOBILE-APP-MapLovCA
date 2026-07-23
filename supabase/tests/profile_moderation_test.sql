begin;

create extension if not exists pgtap with schema extensions;
select plan(6);

select has_table('public', 'profile_reporters',
  'distinct profile reporters are tracked');
select has_table('public', 'profile_moderation_cases',
  'automatically frozen profiles are queued for administrators');
select has_function(
  'public', 'decide_profile_moderation', array['uuid', 'text', 'text'],
  'profile moderation decisions are atomic'
);
select ok(
  exists(
    select 1 from pg_trigger
    where tgname = 'reports_process_profile_moderation' and not tgisinternal
  ),
  'reports trigger automatic profile moderation'
);
select col_is_pk(
  'public', 'profile_reporters', array['profile_id', 'reporter_id'],
  'one account can report a profile only once'
);
select col_type_is(
  'public', 'profile_moderation_cases', 'report_count', 'integer',
  'profile cases keep their distinct report count'
);

select * from finish();
rollback;
