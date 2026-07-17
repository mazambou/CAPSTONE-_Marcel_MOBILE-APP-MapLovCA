-- Public offer: Free, Plus and VIP. Legacy Elite subscriptions receive VIP
-- entitlements so no existing subscriber loses access.

create or replace function private.enforce_invisible_mode_entitlement()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() = 'service_role' or private.is_admin(auth.uid())
     or current_setting('maplov.system_operation', true) = 'account_deletion' then
    return new;
  end if;
  if old.is_discoverable and not new.is_discoverable
     and new.profile_completed_at is not null
     and private.current_subscription_tier(auth.uid()) not in ('elite', 'vip') then
    raise exception 'Invisible navigation requires Premium VIP';
  end if;
  return new;
end;
$$;

-- Invisible VIP profiles are revealed only after the VIP initiates a direct
-- interaction with the viewer. Blocking always takes precedence.
create or replace function private.can_view_profile(target_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and (
      auth.uid() = target_user
      or private.is_admin(auth.uid())
      or (
        exists (
          select 1 from public.profiles p
          where p.id = target_user and p.status = 'active'
        )
        and not private.is_blocked_between(auth.uid(), target_user)
        and (
          exists (
            select 1 from public.profiles p
            where p.id = target_user and p.is_discoverable
          )
          or exists (
            select 1 from public.profile_likes pl
            where pl.liker_id = target_user and pl.liked_id = auth.uid()
          )
          or exists (
            select 1
            from public.photo_likes pl
            join public.profile_photos photo on photo.id = pl.photo_id
            where pl.user_id = target_user and photo.user_id = auth.uid()
          )
          or exists (
            select 1
            from public.messages m
            join public.conversation_members cm
              on cm.conversation_id = m.conversation_id
            where m.sender_id = target_user
              and cm.user_id = auth.uid()
              and cm.left_at is null
              and m.deleted_at is null
          )
        )
      )
    );
$$;

create or replace function public.is_vip_profile(target_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and private.can_view_profile(target_user)
    and private.current_subscription_tier(target_user) in ('elite', 'vip');
$$;

revoke execute on function public.is_vip_profile(uuid) from public, anon;
grant execute on function public.is_vip_profile(uuid) to authenticated;

-- Elite and legacy VIP are now the same public VIP package.
create or replace function private.enforce_garden_limits()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  tier public.subscription_tier := private.current_subscription_tier(auth.uid());
  current_count integer;
  allowed_count integer;
begin
  if auth.role() = 'service_role' or private.is_admin(auth.uid()) then return new; end if;
  if tg_table_name = 'garden_albums' then
    select count(*) into current_count
    from public.garden_albums where owner_id = auth.uid();
    allowed_count := case tier when 'free' then 1 when 'plus' then 3 else 10 end;
  elsif tg_table_name = 'garden_photos' then
    select count(*) into current_count
    from public.garden_photos where owner_id = auth.uid();
    allowed_count := case tier when 'free' then 10 when 'plus' then 30 else 100 end;
  else
    select count(*) into current_count
    from public.garden_access_requests
    where requester_id = auth.uid()
      and requested_at > now() - interval '1 day';
    allowed_count := case tier when 'free' then 5 when 'plus' then 20 else 100 end;
  end if;
  if current_count >= allowed_count then
    raise exception 'Secret Garden limit reached for the current plan';
  end if;
  return new;
end;
$$;

comment on function public.is_vip_profile(uuid) is
  'Returns the public VIP badge state. Legacy Elite subscriptions are treated as VIP.';
