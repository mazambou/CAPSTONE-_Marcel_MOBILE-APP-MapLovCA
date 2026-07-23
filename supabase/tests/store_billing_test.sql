begin;

create extension if not exists pgtap with schema extensions;
select plan(8);

select has_table('public', 'payment_transactions',
  'verified payment transactions are retained');
select has_table('public', 'store_billing_events',
  'store notifications are processed idempotently');
select has_column('public', 'subscriptions', 'auto_renew_enabled',
  'subscriptions retain automatic renewal state');
select has_column('public', 'subscriptions', 'cancelled_at',
  'subscriptions retain their cancellation timestamp');
select has_column('public', 'subscriptions', 'last_verified_at',
  'subscriptions retain their last server verification timestamp');
select has_function(
  'public', 'apply_store_subscription_event',
  array[
    'uuid', 'text', 'text', 'text', 'text', 'text', 'text', 'text',
    'text', 'text', 'timestamp with time zone', 'timestamp with time zone',
    'boolean', 'bigint', 'text', 'text', 'jsonb'
  ],
  'store events update subscriptions atomically'
);
select col_is_unique(
  'public', 'store_billing_events', array['provider', 'provider_event_id'],
  'store event retries cannot be applied twice'
);
select col_is_unique(
  'public', 'payment_transactions',
  array['provider', 'provider_transaction_id', 'event_type'],
  'payment history cannot duplicate a store transaction event'
);

select * from finish();
rollback;
