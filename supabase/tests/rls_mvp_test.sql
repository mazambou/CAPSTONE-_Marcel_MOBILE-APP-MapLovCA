begin;

create extension if not exists pgtap with schema extensions;
select plan(9);

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"service_role"}',
  true
);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-4000-8000-0000000000a1',
    'authenticated', 'authenticated', 'rls-a@maplov.test', '', now(), '{}',
    '{"first_name":"RLS A","date_of_birth":"1990-01-01"}', now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-4000-8000-0000000000b2',
    'authenticated', 'authenticated', 'rls-b@maplov.test', '', now(), '{}',
    '{"first_name":"RLS B","date_of_birth":"1991-01-01"}', now(), now()
  );

update public.profiles
set is_discoverable = true, profile_completed_at = now(), status = 'active'
where id in (
  '00000000-0000-4000-8000-0000000000a1',
  '00000000-0000-4000-8000-0000000000b2'
);

insert into public.garden_albums (id, owner_id, title)
values (
  '00000000-0000-4000-8000-0000000000c3',
  '00000000-0000-4000-8000-0000000000b2',
  'RLS private album'
);
insert into public.garden_photos (
  id, album_id, owner_id, storage_path, display_order
) values (
  '00000000-0000-4000-8000-0000000000d4',
  '00000000-0000-4000-8000-0000000000c3',
  '00000000-0000-4000-8000-0000000000b2',
  'rls-b/private-test.jpg',
  0
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}',
  true
);

select lives_ok(
  $$insert into public.blocks (blocker_id, blocked_id)
    values (
      '00000000-0000-4000-8000-0000000000a1',
      '00000000-0000-4000-8000-0000000000b2'
    )$$,
  'an authenticated user can block another user'
);

select is(
  (select count(*)::integer from public.profiles
    where id = '00000000-0000-4000-8000-0000000000b2'),
  0,
  'a blocked profile disappears from discovery'
);

select throws_ok(
  $$insert into public.profile_likes (liker_id, liked_id)
    values (
      '00000000-0000-4000-8000-0000000000a1',
      '00000000-0000-4000-8000-0000000000b2'
    )$$,
  'new row violates row-level security policy for table "profile_likes"',
  'a block prevents a profile like'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000b2","role":"authenticated"}',
  true
);
select throws_ok(
  $$insert into public.friendships (requester_id, addressee_id)
    values (
      '00000000-0000-4000-8000-0000000000b2',
      '00000000-0000-4000-8000-0000000000a1'
    )$$,
  'new row violates row-level security policy for table "friendships"',
  'a block prevents a friend request in either direction'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"authenticated"}',
  true
);
delete from public.blocks
where blocker_id = '00000000-0000-4000-8000-0000000000a1'
  and blocked_id = '00000000-0000-4000-8000-0000000000b2';

select is(
  (select count(*)::integer from public.garden_album_summaries(
    '00000000-0000-4000-8000-0000000000b2'
  )),
  1,
  'album metadata is visible before requesting access'
);

select lives_ok(
  $$insert into public.garden_access_requests (
      album_id, requester_id, requested_duration_seconds
    ) values (
      '00000000-0000-4000-8000-0000000000c3',
      '00000000-0000-4000-8000-0000000000a1',
      600
    )$$,
  'a user can request time-limited Garden access'
);

select throws_ok(
  $$insert into public.garden_access_requests (
      album_id, requester_id, requested_duration_seconds
    ) values (
      '00000000-0000-4000-8000-0000000000c3',
      '00000000-0000-4000-8000-0000000000a1',
      600
    )$$,
  'An active Secret Garden request already exists',
  'duplicate active Garden requests are rejected'
);

select is(
  (select count(*)::integer from public.garden_photos
    where album_id = '00000000-0000-4000-8000-0000000000c3'),
  0,
  'album photos stay inaccessible while the request is pending'
);

set local role postgres;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000a1","role":"service_role"}',
  true
);
update public.profiles set status = 'suspended'
where id = '00000000-0000-4000-8000-0000000000b2';

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-0000000000b2","role":"authenticated"}',
  true
);
select throws_ok(
  $$insert into public.posts (author_id, body)
    values (
      '00000000-0000-4000-8000-0000000000b2',
      'A suspended account must not publish'
    )$$,
  'This account is not active',
  'a session suspended after login cannot keep publishing'
);

select * from finish();
rollback;
