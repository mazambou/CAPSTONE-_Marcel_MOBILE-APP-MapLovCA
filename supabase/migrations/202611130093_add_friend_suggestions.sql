-- Suggestions use the member's saved search radius. Exact coordinates stay
-- in the private schema; only eligible profile ids and interaction flags leave
-- the database. Visitor identities retain their Premium Plus entitlement.
create or replace function public.add_friend_suggestions(
  limit_value integer default 30,
  offset_value integer default 0
)
returns table (
  candidate_id uuid,
  compatibility_score integer,
  visited_profile boolean,
  liked_content boolean,
  commented_content boolean,
  sent_message boolean,
  friendship_id uuid,
  friendship_status text,
  request_sent_by_me boolean,
  visitor_only_locked boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  with viewer as materialized (
    select p.id, location.location,
      coalesce(preferences.distance_km, 100) as radius_km,
      private.current_subscription_tier(p.id) in ('plus', 'elite', 'vip')
        as can_see_visitors
    from public.profiles p
    join private.user_locations location on location.user_id = p.id
    left join public.dating_preferences preferences on preferences.user_id = p.id
    join auth.users account on account.id = p.id
      and account.email_confirmed_at is not null
    where p.id = auth.uid()
      and p.status = 'active'
      and p.profile_completed_at is not null
  ), nearby as materialized (
    select p.id, viewer.id as viewer_id, viewer.can_see_visitors
    from viewer
    join private.user_locations location on location.user_id <> viewer.id
      and extensions.st_dwithin(
        viewer.location, location.location, viewer.radius_km * 1000.0
      )
    join public.profiles p on p.id = location.user_id
    where p.status = 'active'
      and p.is_discoverable
      and p.profile_completed_at is not null
      and private.can_view_profile(p.id)
      and exists (
        select 1 from public.profile_photos photo
        where photo.user_id = p.id
          and photo.is_primary
          and photo.moderation_status = 'visible'
      )
  ), candidates as materialized (
    select nearby.id, nearby.viewer_id, nearby.can_see_visitors,
      calculated.score as score,
      exists (
        select 1 from public.profile_views pv
        where pv.viewer_id = nearby.id and pv.viewed_id = nearby.viewer_id
      ) as visited,
      (
        exists (
          select 1 from public.profile_likes pl
          where pl.liker_id = nearby.id and pl.liked_id = nearby.viewer_id
        )
        or exists (
          select 1 from public.photo_likes phl
          join public.profile_photos photo on photo.id = phl.photo_id
          where phl.user_id = nearby.id and photo.user_id = nearby.viewer_id
        )
        or exists (
          select 1 from public.photo_super_likes psl
          join public.profile_photos photo on photo.id = psl.photo_id
          where psl.user_id = nearby.id and photo.user_id = nearby.viewer_id
        )
        or exists (
          select 1 from public.post_likes pol
          join public.posts post on post.id = pol.post_id
          where pol.user_id = nearby.id and post.author_id = nearby.viewer_id
            and post.deleted_at is null
        )
      ) as liked,
      (
        exists (
          select 1 from public.photo_comments pc
          join public.profile_photos photo on photo.id = pc.photo_id
          where pc.author_id = nearby.id and photo.user_id = nearby.viewer_id
            and pc.deleted_at is null
        )
        or exists (
          select 1 from public.post_comments poc
          join public.posts post on post.id = poc.post_id
          where poc.author_id = nearby.id and post.author_id = nearby.viewer_id
            and poc.deleted_at is null and post.deleted_at is null
        )
      ) as commented,
      exists (
        select 1 from public.messages msg
        join public.conversation_members cm
          on cm.conversation_id = msg.conversation_id
          and cm.user_id = nearby.viewer_id
        join public.conversations conv
          on conv.id = msg.conversation_id
          and not conv.is_group
        where msg.sender_id = nearby.id and msg.deleted_at is null
      ) as messaged
    from nearby
    cross join lateral public.calculate_compatibility(nearby.id) calculated
  ), suggestions as materialized (
    select c.*, friendship.id as pending_friendship_id,
      friendship.status::text as pending_friendship_status,
      friendship.requester_id = c.viewer_id as sent_by_me,
      not c.can_see_visitors and c.visited
        and not (c.liked or c.commented or c.messaged or c.score >= 60)
        as locked_visitor
  from candidates c
  left join lateral (
    select item.id, item.status, item.requester_id
    from public.friendships item
    where item.status in ('pending', 'accepted')
      and (
        (item.requester_id = c.viewer_id and item.addressee_id = c.id)
        or (item.requester_id = c.id and item.addressee_id = c.viewer_id)
      )
    order by item.updated_at desc
    limit 1
  ) friendship on true
  where friendship.status is distinct from 'accepted'
    and (c.visited or c.liked or c.commented or c.messaged or c.score >= 60)
  )
  select
    case when s.locked_visitor then null else s.id end,
    case when s.locked_visitor then null else s.score end,
    s.visited and s.can_see_visitors,
    case when s.locked_visitor then false else s.liked end,
    case when s.locked_visitor then false else s.commented end,
    case when s.locked_visitor then false else s.messaged end,
    case when s.locked_visitor then null else s.pending_friendship_id end,
    case when s.locked_visitor then null else s.pending_friendship_status end,
    case when s.locked_visitor then false else s.sent_by_me end,
    s.locked_visitor
  from suggestions s
  order by
    (s.visited::integer + s.liked::integer + s.commented::integer
      + s.messaged::integer) desc,
    s.score desc, s.id
  limit greatest(1, least(coalesce(limit_value, 30), 50))
  offset greatest(0, coalesce(offset_value, 0));
$$;

revoke execute on function public.add_friend_suggestions(integer,integer)
  from public, anon;
grant execute on function public.add_friend_suggestions(integer,integer)
  to authenticated;
