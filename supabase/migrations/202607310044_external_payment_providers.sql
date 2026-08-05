-- Prepare secure, server-controlled subscription billing through Stripe,
-- PayPal and Flutterwave. External checkout stays disabled until the related
-- Edge Function secrets and the client feature flag are configured.

begin;

alter table public.subscriptions
  drop constraint if exists subscriptions_provider_check;

alter table public.subscriptions
  add constraint subscriptions_provider_check
  check (
    provider in (
      'apple',
      'google',
      'manual',
      'stripe',
      'paypal',
      'flutterwave'
    )
  );

alter table public.store_billing_events
  drop constraint if exists store_billing_events_provider_check;

alter table public.store_billing_events
  add constraint store_billing_events_provider_check
  check (
    provider in (
      'apple',
      'google',
      'stripe',
      'paypal',
      'flutterwave'
    )
  );

alter table public.payment_transactions
  drop constraint if exists payment_transactions_provider_check;

alter table public.payment_transactions
  add constraint payment_transactions_provider_check
  check (
    provider in (
      'apple',
      'google',
      'stripe',
      'paypal',
      'flutterwave'
    )
  );

create table if not exists public.external_checkout_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  provider text not null check (provider in ('stripe', 'paypal', 'flutterwave')),
  tier public.subscription_tier not null check (tier in ('plus', 'elite', 'vip')),
  product_id text not null check (length(trim(product_id)) > 0),
  provider_product_id text not null check (length(trim(provider_product_id)) > 0),
  checkout_reference text not null unique
    check (length(trim(checkout_reference)) >= 16),
  provider_session_id text,
  status text not null default 'created'
    check (
      status in (
        'created',
        'pending',
        'completed',
        'expired',
        'cancelled',
        'failed'
      )
    ),
  amount_minor bigint check (amount_minor is null or amount_minor >= 0),
  currency_code text check (
    currency_code is null
    or currency_code ~ '^[A-Z]{3}$'
  ),
  expires_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists external_checkout_sessions_provider_session_uidx
  on public.external_checkout_sessions (provider, provider_session_id)
  where provider_session_id is not null;

create index if not exists external_checkout_sessions_user_created_idx
  on public.external_checkout_sessions (user_id, created_at desc);

create index if not exists external_checkout_sessions_pending_idx
  on public.external_checkout_sessions (provider, status, expires_at)
  where status in ('created', 'pending');

alter table public.external_checkout_sessions enable row level security;

drop policy if exists external_checkout_sessions_owner_read
  on public.external_checkout_sessions;
create policy external_checkout_sessions_owner_read
on public.external_checkout_sessions
for select
to authenticated
using (
  user_id = auth.uid()
  or private.is_admin(auth.uid())
);

revoke all on table public.external_checkout_sessions from anon, authenticated;
grant select on table public.external_checkout_sessions to authenticated;

create or replace function public.apply_external_subscription_event(
  provider_value text,
  provider_event_id_value text,
  event_type_value text,
  checkout_reference_value text,
  external_subscription_id_value text,
  provider_transaction_id_value text,
  provider_product_id_value text,
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
  checkout_row public.external_checkout_sessions%rowtype;
  existing_row public.subscriptions%rowtype;
  resolved_user_id uuid;
  resolved_tier public.subscription_tier;
  resolved_product_id text;
  expected_provider_product_id text;
  effective_period_start timestamptz;
  effective_period_end timestamptz;
  remains_entitled boolean;
  event_inserted uuid;
  subscription_id_value uuid;
  next_session_status text;
begin
  if auth.role() <> 'service_role' then
    raise exception 'Only the service role may apply external billing events';
  end if;

  if provider_value not in ('stripe', 'paypal', 'flutterwave') then
    raise exception 'Unsupported external billing provider';
  end if;

  if event_type_value not in (
    'purchase',
    'restore',
    'renewal',
    'cancellation',
    'expiration',
    'refund',
    'billing_issue',
    'recovery',
    'plan_change'
  ) then
    raise exception 'Unsupported billing event type';
  end if;

  if status_value not in (
    'pending',
    'active',
    'past_due',
    'cancelled',
    'expired',
    'refunded'
  ) then
    raise exception 'Unsupported subscription status';
  end if;

  if coalesce(length(trim(provider_event_id_value)), 0) = 0
    or coalesce(length(trim(external_subscription_id_value)), 0) = 0
    or coalesce(length(trim(provider_transaction_id_value)), 0) = 0
    or coalesce(length(trim(provider_product_id_value)), 0) = 0
  then
    raise exception 'External billing identifiers must not be empty';
  end if;

  if amount_minor_value is not null and amount_minor_value < 0 then
    raise exception 'Payment amount must not be negative';
  end if;

  if currency_code_value is not null
    and upper(currency_code_value) !~ '^[A-Z]{3}$'
  then
    raise exception 'Invalid payment currency';
  end if;

  if coalesce(length(trim(checkout_reference_value)), 0) > 0 then
    select *
      into checkout_row
      from public.external_checkout_sessions
     where checkout_reference = checkout_reference_value
       and provider = provider_value
     for update;
  end if;

  select *
    into existing_row
    from public.subscriptions
   where provider = provider_value
     and external_subscription_id = external_subscription_id_value
   for update;

  if checkout_row.id is null and existing_row.id is null then
    raise exception 'Unknown checkout or subscription reference';
  end if;

  if checkout_row.id is not null
    and existing_row.id is not null
    and checkout_row.user_id <> existing_row.user_id
  then
    raise exception 'Checkout and subscription owners do not match';
  end if;

  resolved_user_id := coalesce(checkout_row.user_id, existing_row.user_id);
  resolved_tier := coalesce(checkout_row.tier, existing_row.tier);
  resolved_product_id := coalesce(checkout_row.product_id, existing_row.product_id);
  expected_provider_product_id := coalesce(
    checkout_row.provider_product_id,
    existing_row.receipt_metadata ->> 'provider_product_id'
  );

  if expected_provider_product_id is null
    or expected_provider_product_id <> provider_product_id_value
  then
    raise exception 'Provider product does not match the server checkout';
  end if;

  insert into public.store_billing_events (
    provider,
    provider_event_id,
    event_type,
    external_subscription_id,
    payload
  )
  values (
    provider_value,
    provider_event_id_value,
    event_type_value,
    external_subscription_id_value,
    coalesce(metadata_value, '{}'::jsonb)
  )
  on conflict (provider, provider_event_id) do nothing
  returning id into event_inserted;

  if event_inserted is null then
    select id
      into subscription_id_value
      from public.subscriptions
     where provider = provider_value
       and external_subscription_id = external_subscription_id_value;
    return subscription_id_value;
  end if;

  effective_period_start := coalesce(period_start_value, now());
  effective_period_end := greatest(
    coalesce(period_end_value, effective_period_start + interval '1 month'),
    effective_period_start
  );
  remains_entitled :=
    status_value in ('active', 'cancelled')
    and effective_period_end > now()
    and event_type_value not in ('expiration', 'refund');

  if remains_entitled then
    update public.subscriptions
       set is_current = false,
           updated_at = now()
     where user_id = resolved_user_id
       and is_current
       and not (
         provider = provider_value
         and external_subscription_id = external_subscription_id_value
       );
  end if;

  if existing_row.id is null then
    insert into public.subscriptions (
      user_id,
      tier,
      status,
      provider,
      product_id,
      current_period_start,
      current_period_end,
      cancel_at_period_end,
      is_current,
      auto_renew_enabled,
      cancelled_at,
      last_verified_at,
      external_subscription_id,
      receipt_metadata
    )
    values (
      resolved_user_id,
      resolved_tier,
      status_value,
      provider_value,
      resolved_product_id,
      effective_period_start,
      effective_period_end,
      not coalesce(auto_renew_enabled_value, false),
      remains_entitled,
      coalesce(auto_renew_enabled_value, false),
      case when event_type_value = 'cancellation' then now() else null end,
      now(),
      external_subscription_id_value,
      coalesce(metadata_value, '{}'::jsonb)
        || jsonb_strip_nulls(jsonb_build_object(
          'provider_product_id',
          provider_product_id_value,
          'checkout_reference',
          checkout_reference_value
        ))
    )
    returning id into subscription_id_value;
  else
    subscription_id_value := existing_row.id;

    update public.subscriptions
       set tier = resolved_tier,
           status = status_value,
           product_id = resolved_product_id,
           current_period_start = effective_period_start,
           current_period_end = effective_period_end,
           cancel_at_period_end = not coalesce(
             auto_renew_enabled_value,
             false
           ),
           is_current = remains_entitled,
           auto_renew_enabled = coalesce(auto_renew_enabled_value, false),
           cancelled_at = case
             when event_type_value = 'cancellation'
               then coalesce(cancelled_at, now())
             when event_type_value in (
               'purchase',
               'restore',
               'renewal',
               'recovery'
             ) then null
             else cancelled_at
           end,
           last_verified_at = now(),
           receipt_metadata =
             coalesce(receipt_metadata, '{}'::jsonb)
             || coalesce(metadata_value, '{}'::jsonb)
             || jsonb_strip_nulls(jsonb_build_object(
               'provider_product_id',
               provider_product_id_value,
               'checkout_reference',
               checkout_reference_value
             )),
           updated_at = now()
     where id = subscription_id_value;
  end if;

  if not remains_entitled then
    update public.subscriptions
       set is_current = false,
           updated_at = now()
     where id = subscription_id_value;
  end if;

  insert into public.payment_transactions (
    user_id,
    subscription_id,
    provider,
    provider_transaction_id,
    product_id,
    tier,
    event_type,
    status,
    amount_minor,
    currency_code,
    period_start,
    period_end,
    environment,
    metadata
  )
  values (
    resolved_user_id,
    subscription_id_value,
    provider_value,
    provider_transaction_id_value,
    resolved_product_id,
    resolved_tier,
    event_type_value,
    status_value,
    amount_minor_value,
    case
      when currency_code_value is null then null
      else upper(currency_code_value)
    end,
    effective_period_start,
    effective_period_end,
    environment_value,
    coalesce(metadata_value, '{}'::jsonb)
  )
  on conflict (provider, provider_transaction_id, event_type) do update
  set status = excluded.status,
      period_start = excluded.period_start,
      period_end = excluded.period_end,
      metadata = excluded.metadata;

  if checkout_row.id is not null then
    next_session_status := case
      when status_value = 'active' then 'completed'
      when status_value = 'cancelled' then 'cancelled'
      when status_value in ('expired', 'refunded') then 'expired'
      when status_value in ('pending', 'past_due') then 'pending'
      else 'failed'
    end;

    update public.external_checkout_sessions
       set provider_session_id = coalesce(
             provider_session_id,
             external_subscription_id_value
           ),
           status = next_session_status,
           amount_minor = coalesce(amount_minor_value, amount_minor),
           currency_code = coalesce(
             upper(currency_code_value),
             currency_code
           ),
           completed_at = case
             when next_session_status = 'completed'
               then coalesce(completed_at, now())
             else completed_at
           end,
           updated_at = now()
     where id = checkout_row.id;
  end if;

  insert into public.notifications (
    user_id,
    kind,
    title,
    body,
    entity_type,
    entity_id,
    data
  )
  values (
    resolved_user_id,
    'system',
    case
      when event_type_value in ('purchase', 'restore', 'renewal', 'recovery')
        then 'Abonnement confirmé'
      when event_type_value = 'cancellation'
        then 'Renouvellement désactivé'
      when event_type_value = 'billing_issue'
        then 'Paiement à vérifier'
      else 'Abonnement mis à jour'
    end,
    case
      when remains_entitled
        then 'Votre abonnement MapLov est actif.'
      when event_type_value = 'cancellation'
        then 'Votre accès reste disponible jusqu''à la fin de la période payée.'
      when event_type_value = 'billing_issue'
        then 'Le prestataire de paiement signale un problème de facturation.'
      else 'Le statut de votre abonnement MapLov a changé.'
    end,
    'subscription',
    subscription_id_value,
    jsonb_build_object(
      'provider',
      provider_value,
      'event_type',
      event_type_value,
      'subscription_id',
      subscription_id_value
    )
  );

  return subscription_id_value;
end;
$$;

revoke all on function public.apply_external_subscription_event(
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  timestamptz,
  timestamptz,
  boolean,
  bigint,
  text,
  text,
  jsonb
) from public, anon, authenticated;

grant execute on function public.apply_external_subscription_event(
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  timestamptz,
  timestamptz,
  boolean,
  bigint,
  text,
  text,
  jsonb
) to service_role;

commit;
