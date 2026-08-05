begin;

create extension if not exists pgtap with schema extensions;
select plan(19);

select has_table(
  'public',
  'external_checkout_sessions',
  'external checkout attempts are linked to authenticated accounts'
);
select has_column(
  'public',
  'external_checkout_sessions',
  'provider_product_id',
  'provider products are selected on the server'
);
select has_column(
  'public',
  'external_checkout_sessions',
  'status',
  'checkout lifecycle state is retained'
);
select has_function(
  'public',
  'apply_external_subscription_event',
  array[
    'text', 'text', 'text', 'text', 'text', 'text', 'text', 'text',
    'timestamp with time zone', 'timestamp with time zone', 'boolean',
    'bigint', 'text', 'text', 'jsonb'
  ],
  'verified external events update subscriptions atomically'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.apply_external_subscription_event('
      || 'text,text,text,text,text,text,text,text,'
      || 'timestamp with time zone,timestamp with time zone,'
      || 'boolean,bigint,text,text,jsonb)',
    'EXECUTE'
  ),
  'anonymous callers cannot grant an external subscription'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.apply_external_subscription_event('
      || 'text,text,text,text,text,text,text,text,'
      || 'timestamp with time zone,timestamp with time zone,'
      || 'boolean,bigint,text,text,jsonb)',
    'EXECUTE'
  ),
  'authenticated clients cannot grant their own subscription'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.apply_external_subscription_event('
      || 'text,text,text,text,text,text,text,text,'
      || 'timestamp with time zone,timestamp with time zone,'
      || 'boolean,bigint,text,text,jsonb)',
    'EXECUTE'
  ),
  'only the trusted server can apply verified external events'
);

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-4000-8000-000000000045',
  'authenticated',
  'authenticated',
  'external-billing@maplov.test',
  '',
  now(),
  '{}',
  '{"first_name":"Billing Test","date_of_birth":"1990-01-01"}',
  now(),
  now()
);

insert into public.external_checkout_sessions (
  user_id,
  provider,
  tier,
  product_id,
  provider_product_id,
  checkout_reference,
  status
) values (
  '00000000-0000-4000-8000-000000000045',
  'stripe',
  'plus',
  'maplov_plus_monthly',
  'price_maplov_plus_test',
  'maplov_external_billing_test_reference',
  'pending'
);

set local role service_role;
select set_config(
  'request.jwt.claims',
  '{"role":"service_role"}',
  true
);

select lives_ok(
  $$
    select public.apply_external_subscription_event(
      'stripe',
      'evt_external_billing_test',
      'purchase',
      'maplov_external_billing_test_reference',
      'sub_external_billing_test',
      'txn_external_billing_test',
      'price_maplov_plus_test',
      'active',
      now(),
      now() + interval '1 month',
      true,
      1999,
      'CAD',
      'sandbox',
      '{"source":"pgtap"}'::jsonb
    )
  $$,
  'a verified hosted checkout activates the linked account'
);
select lives_ok(
  $$
    select public.apply_external_subscription_event(
      'stripe',
      'evt_external_billing_test',
      'purchase',
      'maplov_external_billing_test_reference',
      'sub_external_billing_test',
      'txn_external_billing_test',
      'price_maplov_plus_test',
      'active',
      now(),
      now() + interval '1 month',
      true,
      1999,
      'CAD',
      'sandbox',
      '{"source":"pgtap-retry"}'::jsonb
    )
  $$,
  'replaying the same provider event succeeds idempotently'
);
select is(
  (
    select tier::text
      from public.subscriptions
     where user_id = '00000000-0000-4000-8000-000000000045'
       and is_current
  ),
  'plus',
  'the tier comes from the server-created checkout'
);
select is(
  (
    select count(*)::integer
      from public.store_billing_events
     where provider = 'stripe'
       and provider_event_id = 'evt_external_billing_test'
  ),
  1,
  'a webhook retry is recorded only once'
);
select is(
  (
    select count(*)::integer
      from public.payment_transactions
     where provider = 'stripe'
       and provider_transaction_id = 'txn_external_billing_test'
  ),
  1,
  'a webhook retry creates only one payment history row'
);
select lives_ok(
  $$
    select public.apply_external_subscription_event(
      'stripe',
      'evt_external_billing_renewal_test',
      'renewal',
      null,
      'sub_external_billing_test',
      'txn_external_billing_renewal_test',
      'price_maplov_plus_test',
      'active',
      now() + interval '1 month',
      now() + interval '2 months',
      true,
      1999,
      'CAD',
      'sandbox',
      '{"source":"pgtap-renewal"}'::jsonb
    )
  $$,
  'a verified renewal can update the existing external subscription'
);
select is(
  (
    select receipt_metadata ->> 'checkout_reference'
      from public.subscriptions
     where provider = 'stripe'
       and external_subscription_id = 'sub_external_billing_test'
  ),
  'maplov_external_billing_test_reference',
  'renewals retain the original server checkout reference'
);

select has_function(
  'public',
  'cancel_own_external_checkout',
  array['text'],
  'an authenticated user can record an abandoned checkout'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.cancel_own_external_checkout(text)',
    'EXECUTE'
  ),
  'anonymous callers cannot cancel checkout sessions'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.cancel_own_external_checkout(text)',
    'EXECUTE'
  ),
  'authenticated callers can cancel only through the guarded RPC'
);

insert into public.external_checkout_sessions (
  user_id, provider, tier, product_id, provider_product_id,
  checkout_reference, status
) values (
  '00000000-0000-4000-8000-000000000045', 'stripe', 'plus',
  'maplov_plus_monthly', 'price_maplov_plus_test',
  'maplov_external_cancel_test_reference', 'pending'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"role":"authenticated","sub":"00000000-0000-4000-8000-000000000045"}',
  true
);
select is(
  public.cancel_own_external_checkout(
    'maplov_external_cancel_test_reference'
  ),
  true,
  'the checkout owner can cancel a pending attempt'
);
select is(
  (
    select status from public.external_checkout_sessions
    where checkout_reference = 'maplov_external_cancel_test_reference'
  ),
  'cancelled',
  'the abandoned checkout reaches a terminal cancelled state'
);

select * from finish(true);
rollback;
