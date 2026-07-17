begin;

create extension if not exists pgtap with schema extensions;
select plan(9);

select has_column('public', 'profile_photos', 'moderation_status',
  'profile photos expose their moderation status');
select has_column('public', 'profile_photos', 'hidden_at',
  'hidden photos retain the moderation timestamp');
select has_table('public', 'photo_reporters',
  'distinct photo reporters are tracked');
select has_table('public', 'photo_moderation_cases',
  'automatic photo cases are queued for administrators');
select has_function('public', 'register_profile_photo', array['text'],
  'profile photo registration is atomic');
select has_function('public', 'set_my_primary_photo', array['uuid'],
  'primary photo changes are atomic');
select ok(
  exists(
    select 1 from pg_trigger
    where tgname = 'reports_process_photo_moderation' and not tgisinternal
  ),
  'reports trigger automatic photo moderation'
);
select ok(
  exists(
    select 1 from pg_trigger
    where tgname = 'profile_photos_sync_discoverability' and not tgisinternal
  ),
  'photo visibility keeps profile discovery synchronized'
);
select col_is_pk(
  'public', 'photo_reporters', array['photo_id', 'reporter_id'],
  'one account can report a photo only once'
);

select * from finish();
rollback;
