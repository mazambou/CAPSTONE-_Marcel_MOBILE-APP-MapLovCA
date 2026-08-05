begin;

create extension if not exists pgtap with schema extensions;
select plan(8);

select has_function(
  'public',
  'admin_user_details',
  array['uuid'],
  'the protected user details function exists'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.admin_user_details(uuid)',
    'EXECUTE'
  ),
  'anonymous callers cannot request private account details'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.admin_user_details(uuid)',
    'EXECUTE'
  ),
  'authenticated administrators can invoke the guarded function'
);

insert into private.permanent_admin_emails(email)
values ('details-admin@maplov.test');

insert into auth.users (
  instance_id, id, aud, role, email, phone, encrypted_password,
  email_confirmed_at, phone_confirmed_at, last_sign_in_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-4000-8000-000000000043',
  'authenticated', 'authenticated', 'details-admin@maplov.test', null, '',
  now(), null, now(), '{}',
  '{"first_name":"Details Admin","date_of_birth":"1990-01-01"}',
  now(), now()
), (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-4000-8000-000000000044',
  'authenticated', 'authenticated', 'details-target@maplov.test',
  '+14165550123', '', now(), now(), now(),
  '{}', '{"first_name":"Details Target","date_of_birth":"1992-02-03"}',
  now(), now()
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000043","role":"authenticated"}',
  true
);

select is(
  public.admin_user_details(
    '00000000-0000-4000-8000-000000000044'
  ) ->> 'email',
  'details-target@maplov.test',
  'administrators can see the exact Auth email'
);
select is(
  public.admin_user_details(
    '00000000-0000-4000-8000-000000000044'
  ) ->> 'phone',
  '+14165550123',
  'administrators can see the exact Auth phone number'
);
select is(
  public.admin_user_details(
    '00000000-0000-4000-8000-000000000044'
  ) ->> 'first_name',
  'Details Target',
  'Auth identity is combined with the correct profile'
);
select ok(
  (
    public.admin_user_details(
      '00000000-0000-4000-8000-000000000044'
    ) ->> 'last_sign_in_at'
  ) is not null,
  'the last Auth sign-in is available to the administrator'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000044","role":"authenticated"}',
  true
);
select throws_ok(
  $$
    select public.admin_user_details(
      '00000000-0000-4000-8000-000000000043'
    )
  $$,
  'P0001',
  'Admin required',
  'ordinary members cannot read another account details'
);

select * from finish(true);
rollback;
