-- Make every advertised paid entitlement effective and enforce it at the
-- database boundary without changing the established Free / Plus / VIP rules.

begin;

-- Super Likes are paid consumables. Toggling an existing reaction off does not
-- refund the credit; adding it again consumes a new credit.
create table if not exists public.super_like_consumptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  photo_id uuid not null references public.profile_photos(id) on delete cascade,
  balance_after bigint not null check (balance_after >= 0),
  consumed_at timestamptz not null default now()
);

create index if not exists super_like_consumptions_user_created_idx
  on public.super_like_consumptions(user_id, consumed_at desc);

alter table public.super_like_consumptions enable row level security;
drop policy if exists super_like_consumptions_owner_read
  on public.super_like_consumptions;
create policy super_like_consumptions_owner_read
on public.super_like_consumptions for select to authenticated
using (user_id = auth.uid() or private.is_admin(auth.uid()));

revoke all on public.super_like_consumptions from anon, authenticated;
grant select on public.super_like_consumptions to authenticated;

-- Mutations must pass through the atomic RPC below; direct table writes would
-- otherwise bypass the purchased-credit balance.
revoke insert, delete on public.photo_super_likes from authenticated;

create or replace function public.toggle_my_photo_super_like(target_photo uuid)
returns table(super_liked boolean, balance bigint)
language plpgsql
security definer
set search_path = ''
as $$
declare
  remaining bigint;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not exists (
    select 1 from public.profile_photos photo
    join public.profiles owner on owner.id = photo.user_id
    where photo.id = target_photo
      and photo.user_id <> auth.uid()
      and owner.status = 'active'
      and not private.is_blocked_between(auth.uid(), photo.user_id)
  ) then
    raise exception 'Photo unavailable';
  end if;

  if exists (
    select 1 from public.photo_super_likes value
    where value.photo_id = target_photo and value.user_id = auth.uid()
  ) then
    delete from public.photo_super_likes
    where photo_id = target_photo and user_id = auth.uid();
    select coalesce(super_likes_balance, 0) into remaining
    from public.user_consumable_balances where user_id = auth.uid();
    return query select false, coalesce(remaining, 0);
    return;
  end if;

  insert into public.user_consumable_balances(user_id, super_likes_balance)
  values (auth.uid(), 0)
  on conflict (user_id) do nothing;

  select super_likes_balance into remaining
  from public.user_consumable_balances
  where user_id = auth.uid()
  for update;

  if remaining <= 0 then raise exception 'No Super Like credits available'; end if;

  update public.user_consumable_balances
  set super_likes_balance = super_likes_balance - 1, updated_at = now()
  where user_id = auth.uid()
  returning super_likes_balance into remaining;

  insert into public.photo_super_likes(photo_id, user_id)
  values (target_photo, auth.uid());

  insert into public.super_like_consumptions(user_id, photo_id, balance_after)
  values (auth.uid(), target_photo, remaining);

  return query select true, remaining;
end;
$$;

revoke execute on function public.toggle_my_photo_super_like(uuid)
  from public, anon;
grant execute on function public.toggle_my_photo_super_like(uuid)
  to authenticated;

-- Plus and VIP profile likes are placed first in the recipient's incoming
-- Likes page. The value is assigned by a trigger and cannot be forged by a
-- client insert.
alter table public.profile_likes
  add column if not exists priority_rank smallint not null default 0
    check (priority_rank between 0 and 1);

create index if not exists profile_likes_recipient_priority_idx
  on public.profile_likes(liked_id, priority_rank desc, created_at desc);

create or replace function private.assign_profile_like_priority()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.priority_rank := case
    when private.current_subscription_tier(new.liker_id)
      in ('plus', 'elite', 'vip') then 1
    else 0
  end;
  return new;
end;
$$;

drop trigger if exists profile_likes_assign_priority on public.profile_likes;
create trigger profile_likes_assign_priority
before insert on public.profile_likes
for each row execute function private.assign_profile_like_priority();

update public.profile_likes value
set priority_rank = 1
where priority_rank = 0
  and private.current_subscription_tier(value.liker_id)
    in ('plus', 'elite', 'vip');

-- Rewind restores the most recent profile like. It is atomic and restricted
-- to Plus/VIP even when called outside the Flutter client.
create or replace function public.rewind_my_last_profile_like()
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_user uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if private.current_subscription_tier(auth.uid())
      not in ('plus', 'elite', 'vip') then
    raise exception 'Profile rewind requires Premium Plus';
  end if;

  select liked_id into target_user
  from public.profile_likes
  where liker_id = auth.uid()
  order by created_at desc, liked_id desc
  limit 1
  for update;

  if target_user is null then return null; end if;
  delete from public.profile_likes
  where liker_id = auth.uid() and liked_id = target_user;
  return target_user;
end;
$$;

revoke execute on function public.rewind_my_last_profile_like()
  from public, anon;
grant execute on function public.rewind_my_last_profile_like()
  to authenticated;

-- Free members may update their own read marker, but another participant's
-- marker (the read receipt) is visible only to Plus/VIP.
drop policy if exists conversation_reads_members_read
  on public.conversation_reads;
drop policy if exists conversation_reads_owner_read
  on public.conversation_reads;
create policy conversation_reads_plan_read
on public.conversation_reads for select to authenticated
using (
  private.is_conversation_member(conversation_id)
  and (
    user_id = auth.uid()
    or private.current_subscription_tier(auth.uid()) in ('plus', 'elite', 'vip')
  )
);

-- Make the Garden rule match the published plans: owning a Free album remains
-- allowed, while requesting access requires Plus and has the existing 20/100
-- daily limits.
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
    if tier = 'free' then
      raise exception 'Secret Garden requests require Premium Plus';
    end if;
    select count(*) into current_count
    from public.garden_access_requests
    where requester_id = auth.uid()
      and requested_at > now() - interval '1 day';
    allowed_count := case tier when 'plus' then 20 else 100 end;
  end if;
  if current_count >= allowed_count then
    raise exception 'Secret Garden limit reached for the current plan';
  end if;
  return new;
end;
$$;

-- Keep Country search at Plus (or Country Pass), and international search at
-- VIP (or International Pass), both while saving and while querying Discover.
create or replace function private.enforce_international_search_entitlement()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  tier public.subscription_tier := private.current_subscription_tier(auth.uid());
  country_pass boolean;
  international_pass boolean;
begin
  if auth.role() = 'service_role' or private.is_admin(auth.uid()) then return new; end if;

  select exists (
    select 1 from public.payment_entitlements entitlement
    where entitlement.user_id = auth.uid()
      and entitlement.entitlement_kind = 'country_pass'
      and entitlement.starts_at <= now() and entitlement.expires_at > now()
  ) into country_pass;
  select exists (
    select 1 from public.payment_entitlements entitlement
    where entitlement.user_id = auth.uid()
      and entitlement.entitlement_kind = 'international_pass'
      and entitlement.starts_at <= now() and entitlement.expires_at > now()
  ) into international_pass;

  if new.location_mode = 'my_country'
     and tier not in ('plus', 'elite', 'vip') and not country_pass then
    raise exception 'Country discovery requires Premium Plus or a Country Pass';
  end if;
  if new.location_mode in ('specific_country', 'worldwide')
     and tier not in ('elite', 'vip') and not international_pass then
    raise exception 'International discovery requires Premium VIP or an International Pass';
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

-- VIP support requests enter a real priority queue rather than relying on a
-- marketing label in the plan comparison.
create table if not exists public.support_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  subject text not null check (char_length(trim(subject)) between 3 and 160),
  description text not null check (char_length(trim(description)) between 10 and 5000),
  priority smallint not null default 0 check (priority between 0 and 1),
  status text not null default 'open'
    check (status in ('open', 'in_progress', 'resolved', 'closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists support_requests_queue_idx
  on public.support_requests(status, priority desc, created_at);

alter table public.support_requests enable row level security;
drop policy if exists support_requests_owner_read on public.support_requests;
create policy support_requests_owner_read
on public.support_requests for select to authenticated
using (user_id = auth.uid() or private.is_admin(auth.uid()));

revoke all on public.support_requests from anon, authenticated;
grant select on public.support_requests to authenticated;

create or replace function public.submit_my_support_request(
  subject_value text,
  description_value text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  request_id uuid;
  request_priority smallint := 0;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if char_length(trim(coalesce(subject_value, ''))) not between 3 and 160
     or char_length(trim(coalesce(description_value, ''))) not between 10 and 5000 then
    raise exception 'Support request is incomplete';
  end if;
  if private.current_subscription_tier(auth.uid()) in ('elite', 'vip') then
    request_priority := 1;
  end if;
  insert into public.support_requests(user_id, subject, description, priority)
  values (auth.uid(), trim(subject_value), trim(description_value), request_priority)
  returning id into request_id;
  return request_id;
end;
$$;

revoke execute on function public.submit_my_support_request(text, text)
  from public, anon;
grant execute on function public.submit_my_support_request(text, text)
  to authenticated;

-- Patch the deployed keyset RPC in place so active Boosts are the first stable
-- sorting key. Using pg_get_functiondef avoids maintaining a second divergent
-- copy of the large, already-validated filtering function.
do $$
declare
  definition text;
  updated_definition text;
begin
  select pg_get_functiondef(
    'public.discover_profiles_page(text,jsonb,jsonb,integer)'::regprocedure
  ) into definition;

  updated_definition := replace(
    definition,
    '      profile.created_at > now() - interval ''28 days'' as is_new,',
    '      exists (select 1 from public.payment_entitlements boost where boost.user_id = profile.id and boost.entitlement_kind = ''boost'' and boost.starts_at <= now() and boost.expires_at > now()) as has_active_boost,' || chr(10) ||
    '      profile.created_at > now() - interval ''28 days'' as is_new,'
  );
  updated_definition := replace(
    updated_definition,
    '      case when most_liked then popularity_score else 0 end::bigint as sort_popularity,',
    '      case when has_active_boost then 1 else 0 end::integer as sort_boost,' || chr(10) ||
    '      case when most_liked then popularity_score else 0 end::bigint as sort_popularity,'
  );
  updated_definition := replace(
    updated_definition,
    '      sort_popularity, sort_new, engagement_score,',
    '      sort_boost, sort_popularity, sort_new, engagement_score,'
  );
  updated_definition := replace(
    updated_definition,
    '      (cursor_value->>''popularity'')::bigint,',
    '      coalesce((cursor_value->>''boost'')::integer, 0),' || chr(10) ||
    '      (cursor_value->>''popularity'')::bigint,'
  );
  updated_definition := replace(
    updated_definition,
    'order by sort_popularity desc, sort_new desc, engagement_score desc,',
    'order by sort_boost desc, sort_popularity desc, sort_new desc, engagement_score desc,'
  );
  updated_definition := replace(
    updated_definition,
    '      ''popularity'', value.sort_popularity,',
    '      ''boost'', value.sort_boost,' || chr(10) ||
    '      ''popularity'', value.sort_popularity,'
  );
  updated_definition := replace(
    updated_definition,
    '  order by value.sort_popularity desc, value.sort_new desc,',
    '  order by value.sort_boost desc, value.sort_popularity desc, value.sort_new desc,'
  );

  if updated_definition = definition
     or position('sort_boost' in updated_definition) = 0
     or position('has_active_boost' in updated_definition) = 0 then
    raise exception 'Unable to add Boost ordering to discover_profiles_page';
  end if;
  execute updated_definition;
end;
$$;

comment on function public.toggle_my_photo_super_like(uuid) is
  'Atomically toggles a Super Like and consumes one purchased credit when adding it.';
comment on function public.rewind_my_last_profile_like() is
  'Plus/VIP rewind: removes and returns the latest profile like.';
comment on function public.submit_my_support_request(text, text) is
  'Creates a support request; VIP requests receive server-assigned queue priority.';

commit;
