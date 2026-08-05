-- Add Stripe annual subscriptions and server-verified one-time purchases.

begin;

alter table public.external_checkout_sessions
  alter column tier drop not null,
  add column if not exists billing_mode text not null default 'subscription',
  add column if not exists duration_seconds integer,
  add column if not exists quantity integer;

alter table public.external_checkout_sessions
  drop constraint if exists external_checkout_sessions_tier_check,
  add constraint external_checkout_sessions_product_shape_check check (
    (
      billing_mode = 'subscription'
      and tier in ('plus', 'elite', 'vip')
      and duration_seconds is null
      and quantity is null
    )
    or (
      billing_mode = 'payment'
      and tier is null
      and (
        (duration_seconds > 0 and quantity is null)
        or (quantity > 0 and duration_seconds is null)
      )
    )
  );

create table public.one_time_purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  checkout_session_id uuid not null unique
    references public.external_checkout_sessions(id) on delete restrict,
  product_id text not null,
  product_kind text not null check (
    product_kind in ('country_pass', 'international_pass', 'boost', 'super_likes')
  ),
  provider text not null check (provider in ('stripe', 'paypal', 'flutterwave')),
  provider_transaction_id text not null,
  provider_product_id text not null,
  duration_seconds integer check (duration_seconds is null or duration_seconds > 0),
  quantity integer check (quantity is null or quantity > 0),
  amount_minor bigint check (amount_minor is null or amount_minor >= 0),
  currency_code text check (currency_code is null or currency_code ~ '^[A-Z]{3}$'),
  starts_at timestamptz,
  expires_at timestamptz,
  environment text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (provider, provider_transaction_id),
  check ((duration_seconds is not null) <> (quantity is not null))
);

create table public.payment_entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  purchase_id uuid not null unique
    references public.one_time_purchases(id) on delete restrict,
  entitlement_kind text not null check (
    entitlement_kind in ('country_pass', 'international_pass', 'boost')
  ),
  product_id text not null,
  starts_at timestamptz not null,
  expires_at timestamptz not null check (expires_at > starts_at),
  created_at timestamptz not null default now()
);

create index payment_entitlements_active_idx
  on public.payment_entitlements(user_id, entitlement_kind, expires_at desc);

create table public.user_consumable_balances (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  super_likes_balance bigint not null default 0 check (super_likes_balance >= 0),
  updated_at timestamptz not null default now()
);

create table public.consumable_balance_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  purchase_id uuid not null unique
    references public.one_time_purchases(id) on delete restrict,
  consumable_kind text not null check (consumable_kind = 'super_likes'),
  delta bigint not null check (delta > 0),
  balance_after bigint not null check (balance_after >= 0),
  created_at timestamptz not null default now()
);

alter table public.one_time_purchases enable row level security;
alter table public.payment_entitlements enable row level security;
alter table public.user_consumable_balances enable row level security;
alter table public.consumable_balance_events enable row level security;

create policy one_time_purchases_owner_read on public.one_time_purchases
for select to authenticated
using (user_id = auth.uid() or private.is_admin(auth.uid()));
create policy payment_entitlements_owner_read on public.payment_entitlements
for select to authenticated
using (user_id = auth.uid() or private.is_admin(auth.uid()));
create policy user_consumable_balances_owner_read on public.user_consumable_balances
for select to authenticated
using (user_id = auth.uid() or private.is_admin(auth.uid()));
create policy consumable_balance_events_owner_read on public.consumable_balance_events
for select to authenticated
using (user_id = auth.uid() or private.is_admin(auth.uid()));

revoke all on public.one_time_purchases from anon, authenticated;
revoke all on public.payment_entitlements from anon, authenticated;
revoke all on public.user_consumable_balances from anon, authenticated;
revoke all on public.consumable_balance_events from anon, authenticated;
grant select on public.one_time_purchases to authenticated;
grant select on public.payment_entitlements to authenticated;
grant select on public.user_consumable_balances to authenticated;
grant select on public.consumable_balance_events to authenticated;

create or replace function public.apply_external_one_time_payment(
  provider_value text,
  provider_event_id_value text,
  checkout_reference_value text,
  provider_transaction_id_value text,
  provider_product_id_value text,
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
  purchase_id_value uuid;
  event_inserted uuid;
  resolved_kind text;
  expected_duration integer;
  expected_quantity integer;
  entitlement_start timestamptz;
  entitlement_end timestamptz;
  new_balance bigint;
begin
  if auth.role() <> 'service_role' then
    raise exception 'Only the service role may apply external payments';
  end if;
  if provider_value not in ('stripe', 'paypal', 'flutterwave') then
    raise exception 'Unsupported external billing provider';
  end if;
  if coalesce(length(trim(provider_event_id_value)), 0) = 0
    or coalesce(length(trim(checkout_reference_value)), 0) = 0
    or coalesce(length(trim(provider_transaction_id_value)), 0) = 0
    or coalesce(length(trim(provider_product_id_value)), 0) = 0 then
    raise exception 'External payment identifiers must not be empty';
  end if;

  select * into checkout_row
  from public.external_checkout_sessions
  where checkout_reference = checkout_reference_value
    and provider = provider_value
  for update;

  if checkout_row.id is null or checkout_row.billing_mode <> 'payment' then
    raise exception 'Unknown one-time checkout reference';
  end if;
  if checkout_row.provider_product_id <> provider_product_id_value then
    raise exception 'Provider product does not match the server checkout';
  end if;

  select product_kind, duration_seconds, quantity
  into resolved_kind, expected_duration, expected_quantity
  from (values
    ('maplov_country_pass_24h', 'country_pass', 86400, null::integer),
    ('maplov_country_pass_7d', 'country_pass', 604800, null::integer),
    ('maplov_international_pass_24h', 'international_pass', 86400, null::integer),
    ('maplov_international_pass_7d', 'international_pass', 604800, null::integer),
    ('maplov_boost_30m', 'boost', 1800, null::integer),
    ('maplov_boost_3h', 'boost', 10800, null::integer),
    ('maplov_boost_24h', 'boost', 86400, null::integer),
    ('maplov_super_likes_5', 'super_likes', null::integer, 5),
    ('maplov_super_likes_15', 'super_likes', null::integer, 15),
    ('maplov_super_likes_30', 'super_likes', null::integer, 30)
  ) as catalog(product_id, product_kind, duration_seconds, quantity)
  where product_id = checkout_row.product_id;

  if resolved_kind is null
    or checkout_row.duration_seconds is distinct from expected_duration
    or checkout_row.quantity is distinct from expected_quantity then
    raise exception 'Invalid server product configuration';
  end if;

  insert into public.store_billing_events(
    provider, provider_event_id, event_type, external_subscription_id, payload
  ) values (
    provider_value, provider_event_id_value, 'purchase', null,
    coalesce(metadata_value, '{}'::jsonb)
  ) on conflict (provider, provider_event_id) do nothing
  returning id into event_inserted;

  if event_inserted is null then
    select id into purchase_id_value from public.one_time_purchases
    where checkout_session_id = checkout_row.id;
    return purchase_id_value;
  end if;

  if expected_duration is not null then
    select greatest(now(), coalesce(max(expires_at), now()))
    into entitlement_start
    from public.payment_entitlements
    where user_id = checkout_row.user_id
      and entitlement_kind = resolved_kind
      and expires_at > now();
    entitlement_end := entitlement_start
      + make_interval(secs => expected_duration);
  end if;

  insert into public.one_time_purchases(
    user_id, checkout_session_id, product_id, product_kind, provider,
    provider_transaction_id, provider_product_id, duration_seconds, quantity,
    amount_minor, currency_code, starts_at, expires_at, environment, metadata
  ) values (
    checkout_row.user_id, checkout_row.id, checkout_row.product_id,
    resolved_kind, provider_value, provider_transaction_id_value,
    provider_product_id_value, expected_duration, expected_quantity,
    amount_minor_value, upper(currency_code_value), entitlement_start,
    entitlement_end, environment_value, coalesce(metadata_value, '{}'::jsonb)
  ) returning id into purchase_id_value;

  if expected_duration is not null then
    insert into public.payment_entitlements(
      user_id, purchase_id, entitlement_kind, product_id, starts_at, expires_at
    ) values (
      checkout_row.user_id, purchase_id_value, resolved_kind,
      checkout_row.product_id, entitlement_start, entitlement_end
    );
  else
    insert into public.user_consumable_balances(user_id, super_likes_balance)
    values (checkout_row.user_id, expected_quantity)
    on conflict (user_id) do update
    set super_likes_balance = public.user_consumable_balances.super_likes_balance
        + excluded.super_likes_balance,
        updated_at = now()
    returning super_likes_balance into new_balance;
    insert into public.consumable_balance_events(
      user_id, purchase_id, consumable_kind, delta, balance_after
    ) values (
      checkout_row.user_id, purchase_id_value, 'super_likes',
      expected_quantity, new_balance
    );
  end if;

  insert into public.payment_transactions(
    user_id, subscription_id, provider, provider_transaction_id, product_id,
    tier, event_type, status, amount_minor, currency_code, period_start,
    period_end, environment, metadata
  ) values (
    checkout_row.user_id, null, provider_value, provider_transaction_id_value,
    checkout_row.product_id, 'free', 'purchase', 'active', amount_minor_value,
    upper(currency_code_value), entitlement_start, entitlement_end,
    environment_value, coalesce(metadata_value, '{}'::jsonb)
      || jsonb_build_object('billing_mode', 'payment', 'product_kind', resolved_kind)
  );

  update public.external_checkout_sessions
  set status = 'completed', amount_minor = coalesce(amount_minor_value, amount_minor),
      currency_code = coalesce(upper(currency_code_value), currency_code),
      completed_at = coalesce(completed_at, now()), updated_at = now()
  where id = checkout_row.id;

  insert into public.notifications(
    user_id, kind, title, body, entity_type, entity_id, data
  ) values (
    checkout_row.user_id, 'system', 'Achat confirmé',
    'Votre achat MapLov est maintenant disponible.', 'purchase',
    purchase_id_value, jsonb_build_object('product_id', checkout_row.product_id)
  );

  return purchase_id_value;
end;
$$;

revoke all on function public.apply_external_one_time_payment(
  text, text, text, text, text, bigint, text, text, jsonb
) from public, anon, authenticated;
grant execute on function public.apply_external_one_time_payment(
  text, text, text, text, text, bigint, text, text, jsonb
) to service_role;

commit;
