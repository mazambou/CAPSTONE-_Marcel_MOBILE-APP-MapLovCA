-- Final MapLov matching rules:
-- 1. A profile like with a compatibility score strictly above 80 creates a match.
-- 2. At 80 or below, profile likes must be reciprocal.
-- 3. Likes on photos create a match when the two photo owners like one another's photos.

create or replace function private.pair_should_match(first_user uuid, second_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    exists (
      select 1
      from public.profile_likes outgoing
      join public.compatibility_scores score
        on score.user_id = outgoing.liker_id
       and score.candidate_id = outgoing.liked_id
       and score.score > 80
      where outgoing.liker_id in (first_user, second_user)
        and outgoing.liked_id in (first_user, second_user)
        and outgoing.liker_id <> outgoing.liked_id
    )
    or (
      exists (
        select 1 from public.profile_likes
        where liker_id = first_user and liked_id = second_user
      )
      and exists (
        select 1 from public.profile_likes
        where liker_id = second_user and liked_id = first_user
      )
    )
    or (
      exists (
        select 1
        from public.photo_likes likes
        join public.profile_photos photos on photos.id = likes.photo_id
        where likes.user_id = first_user and photos.user_id = second_user
      )
      and exists (
        select 1
        from public.photo_likes likes
        join public.profile_photos photos on photos.id = likes.photo_id
        where likes.user_id = second_user and photos.user_id = first_user
      )
    );
$$;

create or replace function private.create_match_if_qualified(
  first_user uuid,
  second_user uuid,
  notification_body text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  created_match uuid;
begin
  if first_user is null or second_user is null or first_user = second_user
     or not private.pair_should_match(first_user, second_user) then
    return false;
  end if;

  insert into public.matches(user_a, user_b)
  values (least(first_user, second_user), greatest(first_user, second_user))
  on conflict (user_a, user_b) do nothing
  returning id into created_match;

  if created_match is null then return false; end if;

  insert into public.notifications(
    user_id, actor_id, kind, title, body, entity_type, entity_id
  )
  values
    (first_user, second_user, 'compatibility', 'It''s a match!',
     notification_body, 'profile', second_user),
    (second_user, first_user, 'compatibility', 'It''s a match!',
     notification_body, 'profile', first_user);
  return true;
end;
$$;

create or replace function private.create_match_from_like()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.create_match_if_qualified(
    new.liker_id,
    new.liked_id,
    case
      when exists (
        select 1 from public.compatibility_scores
        where user_id = new.liker_id and candidate_id = new.liked_id
          and score > 80
      ) then 'Your compatibility is above 80%. Start a conversation!'
      else 'You liked each other. Start a conversation!'
    end
  );
  return new;
end;
$$;

create or replace function private.create_match_from_photo_like()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  photo_owner uuid;
begin
  select user_id into photo_owner
  from public.profile_photos
  where id = new.photo_id;

  perform private.create_match_if_qualified(
    new.user_id,
    photo_owner,
    'You liked each other''s photos. Start a conversation!'
  );
  return new;
end;
$$;

drop trigger if exists photo_likes_create_match on public.photo_likes;
create trigger photo_likes_create_match
after insert on public.photo_likes
for each row execute function private.create_match_from_photo_like();

create or replace function private.remove_match_if_no_longer_qualified()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  first_user uuid;
  second_user uuid;
begin
  if tg_table_name = 'profile_likes' then
    first_user := old.liker_id;
    second_user := old.liked_id;
  else
    first_user := old.user_id;
    select user_id into second_user
    from public.profile_photos
    where id = old.photo_id;
  end if;

  if first_user is not null and second_user is not null
     and not private.pair_should_match(first_user, second_user) then
    delete from public.matches
    where user_a = least(first_user, second_user)
      and user_b = greatest(first_user, second_user);
  end if;
  return old;
end;
$$;

drop trigger if exists profile_likes_remove_match on public.profile_likes;
create trigger profile_likes_remove_match
after delete on public.profile_likes
for each row execute function private.remove_match_if_no_longer_qualified();

drop trigger if exists photo_likes_remove_match on public.photo_likes;
create trigger photo_likes_remove_match
after delete on public.photo_likes
for each row execute function private.remove_match_if_no_longer_qualified();

revoke execute on function private.pair_should_match(uuid, uuid) from public, anon, authenticated;
revoke execute on function private.create_match_if_qualified(uuid, uuid, text) from public, anon, authenticated;
