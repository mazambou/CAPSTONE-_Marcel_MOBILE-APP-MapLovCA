-- Prevent self-reactions from entering the matching pipeline and remove any
-- historical rows that could make the client resolve the wrong participant.

begin;

delete from public.profile_likes
where liker_id = liked_id;

delete from public.photo_likes value
using public.profile_photos photo
where photo.id = value.photo_id
  and photo.user_id = value.user_id;

alter table public.profile_likes
  drop constraint if exists profile_likes_distinct_users;
alter table public.profile_likes
  add constraint profile_likes_distinct_users
  check (liker_id <> liked_id);

drop policy if exists profile_likes_owner_insert on public.profile_likes;
create policy profile_likes_owner_insert
on public.profile_likes for insert to authenticated
with check (
  liker_id = auth.uid()
  and liker_id <> liked_id
  and not private.is_blocked_between(liker_id, liked_id)
  and exists (
    select 1 from public.profiles profile
    where profile.id = liked_id and profile.status = 'active'
  )
);

create or replace function private.reject_own_photo_like()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1 from public.profile_photos photo
    where photo.id = new.photo_id and photo.user_id = new.user_id
  ) then
    raise exception 'A member cannot like their own photo';
  end if;
  return new;
end;
$$;

drop trigger if exists photo_likes_reject_own_photo on public.photo_likes;
create trigger photo_likes_reject_own_photo
before insert on public.photo_likes
for each row execute function private.reject_own_photo_like();

drop policy if exists photo_likes_insert on public.photo_likes;
create policy photo_likes_insert
on public.photo_likes for insert to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.profile_photos photo
    where photo.id = photo_id
      and photo.user_id <> auth.uid()
      and private.can_view_profile(photo.user_id)
  )
);

comment on constraint profile_likes_distinct_users on public.profile_likes is
  'A profile like must always target another MapLov member.';
comment on function private.reject_own_photo_like() is
  'Database safeguard preventing a photo owner from liking their own photo.';

commit;
