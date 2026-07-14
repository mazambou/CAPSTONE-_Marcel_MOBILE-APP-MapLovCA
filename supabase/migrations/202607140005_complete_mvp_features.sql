-- Complete the MapLov V1 feature set without changing existing data.

begin;

alter table public.profiles alter column is_discoverable set default false;

create policy conversation_reads_members_read
on public.conversation_reads for select to authenticated
using (private.is_conversation_member(conversation_id));

alter table public.dating_preferences
  add column if not exists interest_slugs text[] not null default '{}',
  add column if not exists interest_importance smallint not null default 1
    check (interest_importance between 1 and 5),
  add column if not exists required_genders boolean not null default false,
  add column if not exists required_location boolean not null default false,
  add column if not exists required_languages boolean not null default false,
  add column if not exists required_relationship_goal boolean not null default false;

alter table public.notifications
  add column if not exists archived_at timestamptz;

alter table public.notification_preferences
  add column if not exists security boolean not null default true,
  add column if not exists push_enabled boolean not null default true,
  add column if not exists in_app_enabled boolean not null default true,
  add column if not exists email_important boolean not null default true,
  add column if not exists quiet_hours_enabled boolean not null default false,
  add column if not exists quiet_start time not null default '22:00',
  add column if not exists quiet_end time not null default '07:00';

drop index if exists public.garden_access_one_active_request;
create unique index garden_access_one_pending_or_permanent
  on public.garden_access_requests(album_id, requester_id)
  where status = 'pending' or (status = 'approved' and expires_at is null);

create or replace function private.prevent_duplicate_active_garden_request()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1 from public.garden_access_requests r
    where r.album_id = new.album_id and r.requester_id = new.requester_id
      and (
        r.status = 'pending'
        or (r.status = 'approved' and (r.expires_at is null or r.expires_at > now()))
      )
  ) then
    raise exception 'An active Secret Garden request already exists';
  end if;
  return new;
end;
$$;

drop trigger if exists garden_requests_prevent_active_duplicate
  on public.garden_access_requests;
create trigger garden_requests_prevent_active_duplicate
before insert on public.garden_access_requests
for each row execute function private.prevent_duplicate_active_garden_request();

create table if not exists public.profile_likes (
  liker_id uuid not null references public.profiles(id) on delete cascade,
  liked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (liker_id, liked_id),
  constraint profile_likes_distinct_users check (liker_id <> liked_id)
);

create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references public.profiles(id) on delete cascade,
  user_b uuid not null references public.profiles(id) on delete cascade,
  matched_at timestamptz not null default now(),
  unique (user_a, user_b),
  constraint matches_ordered_users check (user_a < user_b)
);

create index if not exists profile_likes_liked_idx
  on public.profile_likes(liked_id, created_at desc);
create index if not exists matches_user_a_idx on public.matches(user_a, matched_at desc);
create index if not exists matches_user_b_idx on public.matches(user_b, matched_at desc);

create or replace function private.current_subscription_tier(check_user uuid default auth.uid())
returns public.subscription_tier
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select s.tier from public.subscriptions s
      where s.user_id = check_user and s.is_current
        and s.status in ('active', 'cancelled')
        and (s.current_period_end is null or s.current_period_end > now())
      order by s.created_at desc limit 1
    ),
    'free'::public.subscription_tier
  );
$$;

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
     and private.current_subscription_tier(auth.uid()) = 'free' then
    raise exception 'Invisible mode requires Premium Plus';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_enforce_invisible_entitlement on public.profiles;
create trigger profiles_enforce_invisible_entitlement
before update of is_discoverable on public.profiles
for each row execute function private.enforce_invisible_mode_entitlement();

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
    select count(*) into current_count from public.garden_albums where owner_id = auth.uid();
    allowed_count := case tier when 'free' then 1 when 'plus' then 3 when 'elite' then 10 else 25 end;
  elsif tg_table_name = 'garden_photos' then
    select count(*) into current_count from public.garden_photos where owner_id = auth.uid();
    allowed_count := case tier when 'free' then 10 when 'plus' then 30 when 'elite' then 100 else 250 end;
  else
    select count(*) into current_count from public.garden_access_requests
    where requester_id = auth.uid() and requested_at > now() - interval '1 day';
    allowed_count := case tier when 'free' then 5 when 'plus' then 20 when 'elite' then 100 else 250 end;
  end if;
  if current_count >= allowed_count then
    raise exception 'Secret Garden limit reached for the current plan';
  end if;
  return new;
end;
$$;

drop trigger if exists garden_albums_enforce_plan_limit on public.garden_albums;
create trigger garden_albums_enforce_plan_limit before insert on public.garden_albums
for each row execute function private.enforce_garden_limits();
drop trigger if exists garden_photos_enforce_plan_limit on public.garden_photos;
create trigger garden_photos_enforce_plan_limit before insert on public.garden_photos
for each row execute function private.enforce_garden_limits();
drop trigger if exists garden_requests_enforce_plan_limit on public.garden_access_requests;
create trigger garden_requests_enforce_plan_limit before insert on public.garden_access_requests
for each row execute function private.enforce_garden_limits();

create or replace function private.create_match_from_like()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  first_user uuid := least(new.liker_id, new.liked_id);
  second_user uuid := greatest(new.liker_id, new.liked_id);
begin
  if exists (
    select 1 from public.profile_likes reciprocal
    where reciprocal.liker_id = new.liked_id
      and reciprocal.liked_id = new.liker_id
  ) then
    insert into public.matches(user_a, user_b)
    values (first_user, second_user)
    on conflict (user_a, user_b) do nothing;

    insert into public.notifications(user_id, actor_id, kind, title, body, entity_type, entity_id)
    values
      (new.liker_id, new.liked_id, 'compatibility', 'It''s a match!',
       'You liked each other. Start a conversation!', 'profile', new.liked_id),
      (new.liked_id, new.liker_id, 'compatibility', 'It''s a match!',
       'You liked each other. Start a conversation!', 'profile', new.liker_id);
  end if;
  return new;
end;
$$;

drop trigger if exists profile_likes_create_match on public.profile_likes;
create trigger profile_likes_create_match
after insert on public.profile_likes
for each row execute function private.create_match_from_like();

create or replace function private.remove_match_after_unlike()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.matches
  where user_a = least(old.liker_id, old.liked_id)
    and user_b = greatest(old.liker_id, old.liked_id);
  return old;
end;
$$;

drop trigger if exists profile_likes_remove_match on public.profile_likes;
create trigger profile_likes_remove_match
after delete on public.profile_likes
for each row execute function private.remove_match_after_unlike();

create or replace function public.calculate_compatibility(candidate uuid)
returns table(score integer, breakdown jsonb)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  me public.profiles%rowtype;
  other_profile public.profiles%rowtype;
  pref public.dating_preferences%rowtype;
  age_value integer;
  preference_score numeric := 0;
  interest_score numeric := 0;
  relationship_score numeric := 0;
  language_score numeric := 0;
  geography_score numeric := 0;
  personality_score numeric := 0;
  shared_interests integer := 0;
  shared_languages integer := 0;
  final_score integer;
begin
  if auth.uid() is null or candidate is null or candidate = auth.uid() then
    raise exception 'Invalid compatibility candidate';
  end if;

  select * into me from public.profiles where id = auth.uid();
  select * into other_profile from public.profiles
    where id = candidate and status = 'active' and is_discoverable;
  select * into pref from public.dating_preferences where user_id = auth.uid();
  if other_profile.id is null then raise exception 'Candidate unavailable'; end if;

  age_value := extract(year from age(current_date, other_profile.date_of_birth));
  preference_score := case
    when age_value between pref.minimum_age and pref.maximum_age then 70 else 0 end;
  if cardinality(pref.genders) = 0 or other_profile.gender = any(pref.genders) then
    preference_score := preference_score + 30;
  end if;

  select count(*) into shared_interests
  from unnest(coalesce(me.interest_slugs, '{}')) value
  where value = any(coalesce(other_profile.interest_slugs, '{}'));
  interest_score := least(100, shared_interests * 25);

  relationship_score := case
    when cardinality(pref.relationship_goals) > 0
      and other_profile.relationship_goal = any(pref.relationship_goals) then 100
    when me.relationship_goal is not null
      and me.relationship_goal = other_profile.relationship_goal then 85
    else 45 end;

  select count(*) into shared_languages
  from unnest(coalesce(me.spoken_languages, '{}')) value
  where value = any(coalesce(other_profile.spoken_languages, '{}'));
  language_score := case when shared_languages > 0 then 100 else 35 end;

  geography_score := case
    when me.city is not null and lower(me.city) = lower(other_profile.city) then 100
    when me.country_code is not null and me.country_code = other_profile.country_code then 75
    else 45 end;

  personality_score := case
    when cardinality(pref.personalities) = 0 then 70 else 55 end;

  final_score := round(
    preference_score * 0.30 + interest_score * 0.20 +
    relationship_score * 0.15 + language_score * 0.10 +
    geography_score * 0.15 + personality_score * 0.10
  );

  score := greatest(0, least(100, final_score));
  breakdown := jsonb_build_object(
    'preferences', round(preference_score),
    'interests', round(interest_score),
    'relationship', round(relationship_score),
    'languages', round(language_score),
    'geography', round(geography_score),
    'personality', round(personality_score),
    'shared_interests', shared_interests,
    'shared_languages', shared_languages
  );
  return next;
end;
$$;

create or replace function public.refresh_my_compatibility_scores()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  candidate_row record;
  calculated record;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  for candidate_row in
    select id from public.profiles
    where id <> auth.uid() and status = 'active' and is_discoverable
      and not private.is_blocked_between(auth.uid(), id)
  loop
    select * into calculated from public.calculate_compatibility(candidate_row.id);
    insert into public.compatibility_scores(user_id, candidate_id, score, breakdown, calculated_at)
    values (auth.uid(), candidate_row.id, calculated.score, calculated.breakdown, now())
    on conflict (user_id, candidate_id) do update set
      score = excluded.score,
      breakdown = excluded.breakdown,
      calculated_at = excluded.calculated_at;
  end loop;
end;
$$;

-- Exposes album metadata, never photos, so a user can request access safely.
create or replace function public.garden_album_summaries(album_owner uuid)
returns table(id uuid, owner_id uuid, title text, description text, photo_count bigint)
language sql
stable
security definer
set search_path = ''
as $$
  select a.id, a.owner_id, a.title, coalesce(a.description, ''), count(gp.id)
  from public.garden_albums a
  left join public.garden_photos gp on gp.album_id = a.id
  where auth.uid() is not null
    and a.owner_id = album_owner
    and a.owner_id <> auth.uid()
    and not private.is_blocked_between(auth.uid(), a.owner_id)
  group by a.id;
$$;

alter table public.profile_likes enable row level security;
alter table public.matches enable row level security;

create policy profile_likes_participants_read on public.profile_likes
for select to authenticated using (
  liker_id = auth.uid()
  or (
    liked_id = auth.uid()
    and private.current_subscription_tier(auth.uid()) <> 'free'
  )
);
create policy profile_likes_owner_insert on public.profile_likes
for insert to authenticated with check (
  liker_id = auth.uid()
  and not private.is_blocked_between(liker_id, liked_id)
  and exists (select 1 from public.profiles p where p.id = liked_id and p.status = 'active')
);
create policy profile_likes_owner_delete on public.profile_likes
for delete to authenticated using (liker_id = auth.uid());
create policy matches_participants_read on public.matches
for select to authenticated using (user_a = auth.uid() or user_b = auth.uid());

grant select, insert, delete on public.profile_likes to authenticated;
grant select on public.matches to authenticated;
revoke execute on function public.calculate_compatibility(uuid) from public, anon;
revoke execute on function public.refresh_my_compatibility_scores() from public, anon;
revoke execute on function public.garden_album_summaries(uuid) from public, anon;
grant execute on function public.calculate_compatibility(uuid) to authenticated;
grant execute on function public.refresh_my_compatibility_scores() to authenticated;
grant execute on function public.garden_album_summaries(uuid) to authenticated;
revoke execute on function private.current_subscription_tier(uuid) from public, anon;

-- A session that became suspended after login cannot keep mutating user data.
create or replace function private.require_active_actor()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is not null
     and auth.role() <> 'service_role'
     and coalesce(current_setting('maplov.system_operation', true), '')
       <> 'account_deletion'
     and not exists (
       select 1 from public.profiles p
       where p.id = auth.uid() and p.status = 'active'
     ) then
    raise exception 'This account is not active';
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

do $$
declare
  guarded_table text;
begin
  foreach guarded_table in array array[
    'profiles', 'dating_preferences', 'notification_preferences',
    'profile_photos', 'photo_likes', 'photo_comments', 'friendships',
    'messages', 'posts', 'post_media', 'post_likes', 'post_comments',
    'garden_albums', 'garden_photos', 'garden_access_requests',
    'profile_views', 'profile_likes', 'blocks', 'reports'
  ]
  loop
    execute format(
      'drop trigger if exists require_active_actor on public.%I',
      guarded_table
    );
    execute format(
      'create trigger require_active_actor before insert or update or delete on public.%I for each row execute function private.require_active_actor()',
      guarded_table
    );
  end loop;
end;
$$;

commit;
