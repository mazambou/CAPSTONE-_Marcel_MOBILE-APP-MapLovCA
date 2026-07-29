begin;

create extension if not exists pgtap with schema extensions;
select plan(3);

select has_function(
  'public',
  'my_unread_message_count',
  array[]::text[],
  'the navigation badge has a server-side unread message counter'
);

select is(
  (
    select column_default
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'allow_international_discovery'
  ),
  'true',
  'international discovery is enabled by default'
);

select is(
  (
    select column_default
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name = 'show_origin_on_profile'
  ),
  'true',
  'origin display is enabled by default'
);

select * from finish();
rollback;
