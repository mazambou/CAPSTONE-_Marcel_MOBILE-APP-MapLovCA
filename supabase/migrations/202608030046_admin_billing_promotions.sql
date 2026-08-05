-- Time-bound Stripe promotions managed by MapLov administrators.

begin;

create table public.billing_promotions (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 2 and 80),
  product_id text not null check (length(trim(product_id)) > 0),
  original_amount_minor bigint not null check (original_amount_minor > 0),
  promotional_amount_minor bigint not null check (
    promotional_amount_minor > 0
    and promotional_amount_minor < original_amount_minor
  ),
  currency_code text not null default 'CAD' check (currency_code ~ '^[A-Z]{3}$'),
  stripe_price_id text not null check (stripe_price_id ~ '^price_'),
  starts_at timestamptz not null,
  ends_at timestamptz not null check (ends_at > starts_at),
  is_enabled boolean not null default true,
  created_by uuid not null references public.profiles(id) on delete restrict,
  updated_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index billing_promotions_active_product_idx
  on public.billing_promotions(product_id, starts_at, ends_at)
  where is_enabled;

alter table public.external_checkout_sessions
  add column if not exists promotion_id uuid
  references public.billing_promotions(id) on delete set null;

alter table public.billing_promotions enable row level security;

create policy billing_promotions_active_or_admin_read
on public.billing_promotions for select to authenticated
using (
  private.is_admin(auth.uid())
  or (is_enabled and starts_at <= now() and ends_at > now())
);

revoke all on public.billing_promotions from anon, authenticated;
grant select on public.billing_promotions to authenticated;

create or replace function public.admin_save_billing_promotion(
  promotion_id_value uuid,
  name_value text,
  product_id_value text,
  original_amount_minor_value bigint,
  promotional_amount_minor_value bigint,
  currency_code_value text,
  stripe_price_id_value text,
  starts_at_value timestamptz,
  ends_at_value timestamptz,
  is_enabled_value boolean
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare resolved_id uuid;
begin
  if not private.is_admin(auth.uid()) then
    raise exception 'Admin required';
  end if;
  if trim(name_value) = '' or trim(product_id_value) = '' then
    raise exception 'Promotion name and product are required';
  end if;
  if original_amount_minor_value <= 0
    or promotional_amount_minor_value <= 0
    or promotional_amount_minor_value >= original_amount_minor_value then
    raise exception 'Promotional price must be lower than the original price';
  end if;
  if upper(currency_code_value) !~ '^[A-Z]{3}$'
    or stripe_price_id_value !~ '^price_'
    or ends_at_value <= starts_at_value then
    raise exception 'Invalid promotion configuration';
  end if;

  if promotion_id_value is null then
    insert into public.billing_promotions(
      name, product_id, original_amount_minor, promotional_amount_minor,
      currency_code, stripe_price_id, starts_at, ends_at, is_enabled,
      created_by, updated_by
    ) values (
      trim(name_value), trim(product_id_value), original_amount_minor_value,
      promotional_amount_minor_value, upper(currency_code_value),
      trim(stripe_price_id_value), starts_at_value, ends_at_value,
      is_enabled_value, auth.uid(), auth.uid()
    ) returning id into resolved_id;
  else
    update public.billing_promotions set
      name = trim(name_value), product_id = trim(product_id_value),
      original_amount_minor = original_amount_minor_value,
      promotional_amount_minor = promotional_amount_minor_value,
      currency_code = upper(currency_code_value),
      stripe_price_id = trim(stripe_price_id_value),
      starts_at = starts_at_value, ends_at = ends_at_value,
      is_enabled = is_enabled_value, updated_by = auth.uid(), updated_at = now()
    where id = promotion_id_value
    returning id into resolved_id;
    if resolved_id is null then raise exception 'Promotion not found'; end if;
  end if;

  insert into public.admin_actions(
    admin_id, action, target_type, target_id, reason, metadata
  ) values (
    auth.uid(), 'save_billing_promotion', 'billing_promotion', resolved_id,
    trim(name_value), jsonb_build_object(
      'product_id', product_id_value,
      'promotional_amount_minor', promotional_amount_minor_value,
      'starts_at', starts_at_value,
      'ends_at', ends_at_value,
      'enabled', is_enabled_value
    )
  );
  return resolved_id;
end;
$$;

revoke all on function public.admin_save_billing_promotion(
  uuid, text, text, bigint, bigint, text, text, timestamptz, timestamptz, boolean
) from public, anon;
grant execute on function public.admin_save_billing_promotion(
  uuid, text, text, bigint, bigint, text, text, timestamptz, timestamptz, boolean
) to authenticated;

commit;
