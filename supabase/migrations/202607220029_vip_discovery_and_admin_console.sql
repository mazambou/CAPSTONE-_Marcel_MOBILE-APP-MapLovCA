-- VIP discovery filters and consolidated administration operations.

begin;

alter table public.dating_preferences
  add column if not exists premium_only boolean not null default false,
  add column if not exists most_liked_first boolean not null default false;

create or replace function private.enforce_vip_discovery_filters()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (new.premium_only or new.most_liked_first)
     and auth.role() <> 'service_role'
     and not private.is_admin(auth.uid())
     and private.current_subscription_tier(auth.uid()) not in ('elite', 'vip') then
    raise exception 'Premium-only and most-liked filters require VIP';
  end if;
  return new;
end;
$$;

drop trigger if exists dating_preferences_vip_filters on public.dating_preferences;
create trigger dating_preferences_vip_filters
before insert or update of premium_only, most_liked_first
on public.dating_preferences
for each row execute function private.enforce_vip_discovery_filters();

create or replace function public.vip_discovery_ranking(
  premium_only_value boolean default false,
  most_liked_first_value boolean default false
)
returns table(profile_id uuid, popularity_score bigint)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if (premium_only_value or most_liked_first_value)
     and private.current_subscription_tier(auth.uid()) not in ('elite', 'vip')
     and not private.is_admin(auth.uid()) then
    raise exception 'VIP subscription required';
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
    and (
      not premium_only_value
      or private.current_subscription_tier(p.id) in ('plus', 'elite', 'vip')
    )
  order by
    case when most_liked_first_value
      then coalesce(pl.likes, 0) + coalesce(phl.likes, 0)
      else 0
    end desc,
    p.created_at desc;
end;
$$;

revoke execute on function public.vip_discovery_ranking(boolean, boolean)
  from public, anon;
grant execute on function public.vip_discovery_ranking(boolean, boolean)
  to authenticated;

create or replace function public.admin_dashboard_statistics()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.is_admin(auth.uid()) then raise exception 'Admin required'; end if;
  return jsonb_build_object(
    'users', (select count(*) from public.profiles),
    'discoverable_profiles', (select count(*) from public.profiles where status = 'active' and is_discoverable),
    'photos', (select count(*) from public.profile_photos),
    'open_reports', (select count(*) from public.reports where status in ('open', 'under_review')),
    'suspensions', (select count(*) from public.profiles where status in ('suspended', 'banned')),
    'active_subscriptions', (select count(*) from public.subscriptions where is_current and status in ('active', 'cancelled') and tier <> 'free' and (current_period_end is null or current_period_end > now())),
    'payments', (select count(*) from public.payment_transactions),
    'pending_recoveries', (select count(*) from public.account_deletion_requests where status in ('pending', 'processing'))
  );
end;
$$;

create or replace function public.admin_send_global_notification(
  title_value text,
  body_value text
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare sent_count integer;
begin
  if not private.is_admin(auth.uid()) then raise exception 'Admin required'; end if;
  if char_length(btrim(title_value)) not between 2 and 100 then
    raise exception 'Title must contain 2 to 100 characters';
  end if;
  if char_length(btrim(body_value)) not between 2 and 1000 then
    raise exception 'Message must contain 2 to 1000 characters';
  end if;

  insert into public.notifications(user_id, actor_id, kind, title, body, entity_type)
  select id, auth.uid(), 'system', btrim(title_value), btrim(body_value), 'global_notification'
  from public.profiles where status = 'active';
  get diagnostics sent_count = row_count;

  insert into public.admin_actions(admin_id, action, target_type, reason, metadata)
  values (auth.uid(), 'global_notification_sent', 'notification', btrim(title_value),
          jsonb_build_object('recipient_count', sent_count));
  return sent_count;
end;
$$;

create or replace function public.admin_restore_account(
  user_id_value uuid,
  reason_value text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_admin(auth.uid()) then raise exception 'Admin required'; end if;
  if user_id_value = auth.uid() then raise exception 'Cannot restore your own admin account'; end if;

  perform set_config('maplov.system_operation', 'account_recovery', true);
  update public.profiles p
  set status = 'active',
      is_discoverable = p.profile_completed_at is not null and exists (
        select 1 from public.profile_photos photo
        where photo.user_id = p.id and photo.moderation_status = 'visible'
      ),
      updated_at = now()
  where p.id = user_id_value;
  if not found then raise exception 'Account not found'; end if;

  update public.account_deletion_requests
  set status = 'cancelled', cancelled_at = now(), processed_at = null
  where user_id = user_id_value and status in ('pending', 'processing');

  insert into public.notifications(user_id, actor_id, kind, title, body, entity_type)
  values (user_id_value, auth.uid(), 'security', 'Account restored',
          'An administrator restored access to your MapLov account.', 'account');
  insert into public.admin_actions(admin_id, action, target_type, target_id, reason)
  values (auth.uid(), 'account_restored', 'user', user_id_value, nullif(btrim(reason_value), ''));
end;
$$;

create or replace function public.admin_set_manual_subscription(
  user_id_value uuid,
  tier_value text,
  active_value boolean,
  reason_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare subscription_id_value uuid;
begin
  if not private.is_admin(auth.uid()) then raise exception 'Admin required'; end if;
  if tier_value not in ('free', 'plus', 'elite', 'vip') then raise exception 'Invalid tier'; end if;

  update public.subscriptions set is_current = false, updated_at = now()
  where user_id = user_id_value and is_current;
  if active_value and tier_value <> 'free' then
    insert into public.subscriptions(
      user_id, tier, provider, status, current_period_start,
      current_period_end, is_current, auto_renew_enabled, receipt_metadata
    ) values (
      user_id_value, tier_value::public.subscription_tier, 'manual', 'active', now(),
      now() + interval '30 days', true, false,
      jsonb_build_object('granted_by', auth.uid(), 'reason', reason_value)
    ) returning id into subscription_id_value;
  end if;

  insert into public.notifications(user_id, actor_id, kind, title, body, entity_type, entity_id)
  values (user_id_value, auth.uid(), 'system', 'Subscription updated',
          case when active_value and tier_value <> 'free'
            then 'Your MapLov subscription is now ' || upper(tier_value) || '.'
            else 'Your manual MapLov subscription has ended.' end,
          'subscription', subscription_id_value);
  insert into public.admin_actions(admin_id, action, target_type, target_id, reason, metadata)
  values (auth.uid(), 'manual_subscription_updated', 'user', user_id_value,
          nullif(btrim(reason_value), ''), jsonb_build_object('tier', tier_value, 'active', active_value));
  return subscription_id_value;
end;
$$;

revoke execute on function public.admin_dashboard_statistics() from public, anon;
revoke execute on function public.admin_send_global_notification(text, text) from public, anon;
revoke execute on function public.admin_restore_account(uuid, text) from public, anon;
revoke execute on function public.admin_set_manual_subscription(uuid, text, boolean, text) from public, anon;
grant execute on function public.admin_dashboard_statistics() to authenticated;
grant execute on function public.admin_send_global_notification(text, text) to authenticated;
grant execute on function public.admin_restore_account(uuid, text) to authenticated;
grant execute on function public.admin_set_manual_subscription(uuid, text, boolean, text) to authenticated;

commit;
