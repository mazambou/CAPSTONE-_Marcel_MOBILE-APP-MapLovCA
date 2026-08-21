-- Give every account effective VIP access until the 1,001st profile is
-- created. Paid subscriptions remain the source of truth and are never
-- overwritten by this promotion.

create table if not exists private.founding_vip_promotion (
  singleton boolean primary key default true check (singleton),
  member_threshold integer not null default 1000
    check (member_threshold = 1000),
  registered_count bigint not null default 0
    check (registered_count >= 0),
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

revoke all on table private.founding_vip_promotion from public, anon, authenticated;

insert into private.founding_vip_promotion (
  singleton,
  member_threshold,
  registered_count,
  ended_at
)
select
  true,
  1000,
  count(*),
  case when count(*) > 1000 then now() else null end
from public.profiles
on conflict (singleton) do update
set member_threshold = 1000,
    registered_count = excluded.registered_count,
    ended_at = case
      when private.founding_vip_promotion.ended_at is not null
        then private.founding_vip_promotion.ended_at
      when excluded.registered_count > 1000 then now()
      else null
    end,
    updated_at = now();

create or replace function private.track_founding_vip_profile_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    -- This update locks the singleton row. Concurrent registrations therefore
    -- cross the threshold in a deterministic order.
    update private.founding_vip_promotion
    set registered_count = registered_count + 1,
        ended_at = case
          when ended_at is null
               and registered_count + 1 > member_threshold then now()
          else ended_at
        end,
        updated_at = now()
    where singleton;
    return new;
  end if;

  update private.founding_vip_promotion
  set registered_count = greatest(registered_count - 1, 0),
      updated_at = now()
  where singleton;
  -- ended_at is deliberately preserved: once the 1,001st account has existed,
  -- deleting accounts cannot reactivate the founding promotion.
  return old;
end;
$$;

revoke all on function private.track_founding_vip_profile_count()
  from public, anon, authenticated;

drop trigger if exists profiles_track_founding_vip_count on public.profiles;
create trigger profiles_track_founding_vip_count
after insert or delete on public.profiles
for each row execute function private.track_founding_vip_profile_count();

-- Keep the paid/base tier separate so ending the promotion restores Free or
-- Plus and never changes a genuine paid VIP subscription.
create or replace function private.actual_subscription_tier(
  check_user uuid default auth.uid()
)
returns public.subscription_tier
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select subscription.tier
      from public.subscriptions subscription
      where subscription.user_id = check_user
        and subscription.is_current
        and subscription.status in ('active', 'cancelled')
        and (
          subscription.current_period_end is null
          or subscription.current_period_end > now()
        )
      order by subscription.created_at desc
      limit 1
    ),
    'free'::public.subscription_tier
  );
$$;

revoke all on function private.actual_subscription_tier(uuid)
  from public, anon, authenticated;

create or replace function private.current_subscription_tier(
  check_user uuid default auth.uid()
)
returns public.subscription_tier
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  base_tier public.subscription_tier;
  promotion_active boolean;
begin
  base_tier := private.actual_subscription_tier(check_user);

  select promotion.ended_at is null
  into promotion_active
  from private.founding_vip_promotion promotion
  where promotion.singleton;

  if coalesce(promotion_active, false)
     and base_tier not in ('elite', 'vip') then
    return 'vip'::public.subscription_tier;
  end if;

  return base_tier;
end;
$$;

revoke execute on function private.current_subscription_tier(uuid)
  from public, anon;
grant execute on function private.current_subscription_tier(uuid)
  to authenticated;

create or replace function public.my_subscription_entitlement()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  viewer_id uuid := auth.uid();
  base_tier public.subscription_tier;
  promotion private.founding_vip_promotion%rowtype;
  promotional_vip boolean;
begin
  if viewer_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  base_tier := private.actual_subscription_tier(viewer_id);

  select *
  into strict promotion
  from private.founding_vip_promotion
  where singleton;

  promotional_vip := promotion.ended_at is null
    and base_tier not in ('elite', 'vip');

  return jsonb_build_object(
    'effective_tier', case when promotional_vip then 'vip' else base_tier::text end,
    'base_tier', base_tier::text,
    'is_promotional_vip', promotional_vip,
    'promotion_active', promotion.ended_at is null,
    'registered_count', promotion.registered_count,
    'member_threshold', promotion.member_threshold
  );
end;
$$;

revoke all on function public.my_subscription_entitlement()
  from public, anon;
grant execute on function public.my_subscription_entitlement()
  to authenticated;

comment on table private.founding_vip_promotion is
  'Race-safe, irreversible state for the first-1,000-members VIP promotion.';
comment on function public.my_subscription_entitlement() is
  'Returns the authenticated user paid tier and effective promotional tier.';
