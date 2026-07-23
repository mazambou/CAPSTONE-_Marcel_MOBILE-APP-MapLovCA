-- Durable store billing lifecycle: verified subscriptions, transaction history,
-- idempotent Google/Apple server events, renewals and cancellations.

begin;

alter table public.subscriptions
  add column if not exists product_id text,
  add column if not exists original_transaction_id text,
  add column if not exists auto_renew_enabled boolean not null default true,
  add column if not exists cancelled_at timestamptz,
  add column if not exists last_verified_at timestamptz;

create index if not exists subscriptions_original_transaction_idx
  on public.subscriptions(provider, original_transaction_id)
  where original_transaction_id is not null;

create table if not exists public.store_billing_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null check (provider in ('apple', 'google')),
  provider_event_id text not null,
  event_type text not null,
  external_subscription_id text,
  payload jsonb not null default '{}'::jsonb,
  processed_at timestamptz not null default now(),
  unique (provider, provider_event_id)
);

create table if not exists public.payment_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  subscription_id uuid references public.subscriptions(id) on delete set null,
  provider text not null check (provider in ('apple', 'google')),
  provider_transaction_id text not null,
  original_transaction_id text,
  product_id text not null,
  tier public.subscription_tier not null,
  event_type text not null check (
    event_type in (
      'purchase', 'restore', 'renewal', 'cancellation', 'expiration',
      'refund', 'billing_issue', 'recovery', 'plan_change'
    )
  ),
  status text not null check (
    status in (
      'pending', 'active', 'past_due', 'cancelled', 'expired',
      'refunded'
    )
  ),
  amount_minor bigint check (amount_minor is null or amount_minor >= 0),
  currency_code varchar(3),
  period_start timestamptz,
  period_end timestamptz,
  environment text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (provider, provider_transaction_id, event_type)
);

create index if not exists payment_transactions_user_created_idx
  on public.payment_transactions(user_id, created_at desc);

alter table public.store_billing_events enable row level security;
alter table public.payment_transactions enable row level security;

create policy payment_transactions_owner_or_admin_read
on public.payment_transactions for select to authenticated
using (user_id = auth.uid() or private.is_admin());

-- Only Edge Functions using the service role can record store lifecycle data.
revoke all on public.store_billing_events from anon, authenticated;
revoke all on public.payment_transactions from anon, authenticated;
grant select on public.payment_transactions to authenticated;

create or replace function public.apply_store_subscription_event(
  user_id_value uuid,
  provider_value text,
  provider_event_id_value text,
  event_type_value text,
  external_subscription_id_value text,
  provider_transaction_id_value text,
  original_transaction_id_value text,
  product_id_value text,
  tier_value text,
  status_value text,
  period_start_value timestamptz,
  period_end_value timestamptz,
  auto_renew_enabled_value boolean,
  amount_minor_value bigint default null,
  currency_code_value text default null,
  environment_value text default null,
  metadata_value jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  resolved_user_id uuid := user_id_value;
  existing_subscription public.subscriptions%rowtype;
  subscription_id_value uuid;
  event_inserted uuid;
  remains_entitled boolean;
  notification_title text;
  notification_body text;
begin
  if auth.role() <> 'service_role' then
    raise exception 'Service role required';
  end if;
  if provider_value not in ('apple', 'google') then
    raise exception 'Unsupported store provider';
  end if;
  if event_type_value not in (
    'purchase', 'restore', 'renewal', 'cancellation', 'expiration',
    'refund', 'billing_issue', 'recovery', 'plan_change'
  ) then
    raise exception 'Unsupported store event type';
  end if;
  if status_value not in (
    'pending', 'active', 'past_due', 'cancelled', 'expired', 'refunded'
  ) then
    raise exception 'Unsupported subscription status';
  end if;
  if tier_value not in ('plus', 'elite', 'vip') then
    raise exception 'Unsupported subscription tier';
  end if;
  if nullif(btrim(provider_event_id_value), '') is null
     or nullif(btrim(external_subscription_id_value), '') is null
     or nullif(btrim(provider_transaction_id_value), '') is null
     or nullif(btrim(product_id_value), '') is null then
    raise exception 'Incomplete verified store event';
  end if;

  insert into public.store_billing_events(
    provider, provider_event_id, event_type, external_subscription_id, payload
  ) values (
    provider_value, provider_event_id_value, event_type_value,
    external_subscription_id_value, coalesce(metadata_value, '{}'::jsonb)
  )
  on conflict (provider, provider_event_id) do nothing
  returning id into event_inserted;

  select * into existing_subscription
  from public.subscriptions
  where provider = provider_value
    and external_subscription_id = external_subscription_id_value
  for update;

  -- A retry is successful and idempotent.
  if event_inserted is null then
    return existing_subscription.id;
  end if;

  if existing_subscription.id is not null then
    if resolved_user_id is not null
       and existing_subscription.user_id <> resolved_user_id then
      raise exception 'This store subscription belongs to another account';
    end if;
    resolved_user_id := existing_subscription.user_id;
  end if;

  if resolved_user_id is null and original_transaction_id_value is not null then
    select * into existing_subscription
    from public.subscriptions
    where provider = provider_value
      and original_transaction_id = original_transaction_id_value
    order by created_at desc
    limit 1
    for update;
    if existing_subscription.id is not null then
      resolved_user_id := existing_subscription.user_id;
    end if;
  end if;

  if resolved_user_id is null then
    raise exception 'No MapLov account is linked to this store subscription';
  end if;

  remains_entitled := status_value in ('active', 'cancelled')
    and (period_end_value is null or period_end_value > now());

  if remains_entitled then
    update public.subscriptions
    set is_current = false
    where user_id = resolved_user_id and is_current
      and id is distinct from existing_subscription.id;
  end if;

  if existing_subscription.id is null then
    insert into public.subscriptions(
      user_id, tier, provider, external_subscription_id, status,
      current_period_start, current_period_end, cancel_at_period_end,
      is_current, receipt_metadata, product_id, original_transaction_id,
      auto_renew_enabled, cancelled_at, last_verified_at
    ) values (
      resolved_user_id, tier_value::public.subscription_tier, provider_value,
      external_subscription_id_value, status_value,
      period_start_value, period_end_value, not auto_renew_enabled_value,
      remains_entitled, coalesce(metadata_value, '{}'::jsonb),
      product_id_value, original_transaction_id_value,
      auto_renew_enabled_value,
      case when status_value = 'cancelled' then now() else null end,
      now()
    ) returning id into subscription_id_value;
  else
    subscription_id_value := existing_subscription.id;
    update public.subscriptions
    set tier = tier_value::public.subscription_tier,
        external_subscription_id = external_subscription_id_value,
        status = status_value,
        current_period_start = period_start_value,
        current_period_end = period_end_value,
        cancel_at_period_end = not auto_renew_enabled_value,
        is_current = remains_entitled,
        receipt_metadata = coalesce(metadata_value, '{}'::jsonb),
        product_id = product_id_value,
        original_transaction_id = coalesce(
          original_transaction_id_value, original_transaction_id
        ),
        auto_renew_enabled = auto_renew_enabled_value,
        cancelled_at = case
          when status_value = 'cancelled' then coalesce(cancelled_at, now())
          when status_value = 'active' then null
          else cancelled_at
        end,
        last_verified_at = now(),
        updated_at = now()
    where id = subscription_id_value;
  end if;

  insert into public.payment_transactions(
    user_id, subscription_id, provider, provider_transaction_id,
    original_transaction_id, product_id, tier, event_type, status,
    amount_minor, currency_code, period_start, period_end, environment,
    metadata
  ) values (
    resolved_user_id, subscription_id_value, provider_value,
    provider_transaction_id_value, original_transaction_id_value,
    product_id_value, tier_value::public.subscription_tier,
    event_type_value, status_value, amount_minor_value,
    upper(nullif(currency_code_value, '')), period_start_value,
    period_end_value, environment_value, coalesce(metadata_value, '{}'::jsonb)
  )
  on conflict (provider, provider_transaction_id, event_type) do update
  set status = excluded.status,
      period_start = excluded.period_start,
      period_end = excluded.period_end,
      metadata = excluded.metadata;

  notification_title := case event_type_value
    when 'purchase' then 'Subscription activated'
    when 'restore' then 'Purchases restored'
    when 'renewal' then 'Subscription renewed'
    when 'cancellation' then 'Subscription cancellation recorded'
    when 'expiration' then 'Subscription expired'
    when 'refund' then 'Subscription refunded'
    when 'billing_issue' then 'Subscription billing issue'
    when 'recovery' then 'Subscription recovered'
    else 'Subscription updated'
  end;
  notification_body := case event_type_value
    when 'cancellation' then
      'Automatic renewal is off. Your benefits remain available until the current period ends.'
    when 'expiration' then 'Your paid subscription benefits have ended.'
    when 'refund' then 'The store refunded this subscription transaction.'
    when 'billing_issue' then
      'The store could not renew your subscription. Please update your payment method.'
    else 'Your MapLov subscription was securely updated by the app store.'
  end;

  insert into public.notifications(user_id, kind, title, body, entity_type, entity_id)
  values (
    resolved_user_id, 'system', notification_title, notification_body,
    'subscription', subscription_id_value
  );

  return subscription_id_value;
end;
$$;

revoke execute on function public.apply_store_subscription_event(
  uuid, text, text, text, text, text, text, text, text, text,
  timestamptz, timestamptz, boolean, bigint, text, text, jsonb
) from public, anon, authenticated;
grant execute on function public.apply_store_subscription_event(
  uuid, text, text, text, text, text, text, text, text, text,
  timestamptz, timestamptz, boolean, bigint, text, text, jsonb
) to service_role;

commit;
