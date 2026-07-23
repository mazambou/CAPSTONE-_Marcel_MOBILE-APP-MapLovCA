-- Enforce Free < Premium Plus < VIP across discovery and Secret Garden.

begin;

alter table public.dating_preferences
  add column if not exists vip_only boolean not null default false;

create or replace function private.enforce_vip_discovery_filters()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare tier public.subscription_tier := private.current_subscription_tier(auth.uid());
begin
  if auth.role() = 'service_role' or private.is_admin(auth.uid()) then return new; end if;
  if new.vip_only and tier not in ('elite', 'vip') then
    raise exception 'VIP profile discovery requires VIP';
  end if;
  if new.premium_only and tier not in ('plus', 'elite', 'vip') then
    raise exception 'Premium profile discovery requires Premium Plus';
  end if;
  return new;
end;
$$;

drop trigger if exists dating_preferences_vip_filters on public.dating_preferences;
create trigger dating_preferences_vip_filters
before insert or update of vip_only, premium_only, most_liked_first
on public.dating_preferences
for each row execute function private.enforce_vip_discovery_filters();

create or replace function private.enforce_international_search_entitlement()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare tier public.subscription_tier := private.current_subscription_tier(auth.uid());
begin
  if auth.role() = 'service_role' or private.is_admin(auth.uid()) then return new; end if;
  if new.location_mode in ('my_country', 'specific_country', 'worldwide')
     and tier not in ('plus', 'elite', 'vip') then
    raise exception 'Country and international discovery require Premium Plus';
  end if;
  if (cardinality(new.origin_country_names) > 0
      or cardinality(new.origin_regions) > 0
      or cardinality(new.origin_cities) > 0)
     and tier not in ('plus', 'elite', 'vip') then
    raise exception 'Origin filters require Premium Plus';
  end if;
  return new;
end;
$$;

drop function if exists public.vip_discovery_ranking(boolean, boolean);
create function public.vip_discovery_ranking(
  vip_only_value boolean default false,
  premium_only_value boolean default false,
  most_liked_first_value boolean default false
)
returns table(profile_id uuid, popularity_score bigint)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare tier public.subscription_tier := private.current_subscription_tier(auth.uid());
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if vip_only_value and tier not in ('elite', 'vip') and not private.is_admin(auth.uid()) then
    raise exception 'VIP subscription required';
  end if;
  if premium_only_value and tier not in ('plus', 'elite', 'vip')
     and not private.is_admin(auth.uid()) then
    raise exception 'Premium Plus subscription required';
  end if;

  return query
  select p.id,
         coalesce(pl.likes, 0) + coalesce(phl.likes, 0) as score
  from public.profiles p
  left join lateral (
    select count(*)::bigint as likes
    from public.profile_likes l where l.liked_id = p.id
  ) pl on true
  left join lateral (
    select count(*)::bigint as likes
    from public.photo_likes l
    join public.profile_photos photo on photo.id = l.photo_id
    where photo.user_id = p.id
  ) phl on true
  where p.id <> auth.uid()
    and p.status = 'active'
    and p.is_discoverable
    and private.can_view_profile(p.id)
    and (not vip_only_value or private.current_subscription_tier(p.id) in ('elite', 'vip'))
    and (not premium_only_value or private.current_subscription_tier(p.id) in ('plus', 'elite', 'vip'))
  order by
    case when most_liked_first_value
      then coalesce(pl.likes, 0) + coalesce(phl.likes, 0)
      else 0
    end desc,
    p.created_at desc;
end;
$$;

revoke execute on function public.vip_discovery_ranking(boolean, boolean, boolean)
  from public, anon;
grant execute on function public.vip_discovery_ranking(boolean, boolean, boolean)
  to authenticated;

create or replace function private.enforce_secret_garden_request_entitlement()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() = 'service_role' or private.is_admin(auth.uid()) then return new; end if;
  if private.current_subscription_tier(new.requester_id) not in ('plus', 'elite', 'vip') then
    raise exception 'Secret album access requires Premium Plus';
  end if;
  return new;
end;
$$;

drop trigger if exists garden_requests_subscription_entitlement
  on public.garden_access_requests;
create trigger garden_requests_subscription_entitlement
before insert on public.garden_access_requests
for each row execute function private.enforce_secret_garden_request_entitlement();

commit;
