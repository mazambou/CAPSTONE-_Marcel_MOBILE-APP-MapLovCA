-- Discovery engagement, real presence, verified residence and immutable origin.

alter table public.profiles
  add column if not exists is_online boolean not null default false;

-- Existing rows must not appear online merely because they were recently created.
update public.profiles set is_online = false;

create table if not exists public.photo_super_likes (
  photo_id uuid not null references public.profile_photos(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (photo_id, user_id)
);

create index if not exists photo_super_likes_photo_created_idx
  on public.photo_super_likes(photo_id, created_at desc);

alter table public.photo_super_likes enable row level security;

drop policy if exists photo_super_likes_read on public.photo_super_likes;
create policy photo_super_likes_read
on public.photo_super_likes for select to authenticated
using (exists (
  select 1 from public.profile_photos photo
  where photo.id = photo_id and private.can_view_profile(photo.user_id)
));

drop policy if exists photo_super_likes_insert on public.photo_super_likes;
create policy photo_super_likes_insert
on public.photo_super_likes for insert to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.profile_photos photo
    where photo.id = photo_id
      and photo.user_id <> auth.uid()
      and private.can_view_profile(photo.user_id)
  )
);

drop policy if exists photo_super_likes_delete on public.photo_super_likes;
create policy photo_super_likes_delete
on public.photo_super_likes for delete to authenticated
using (user_id = auth.uid());

grant select, insert, delete on public.photo_super_likes to authenticated;

create or replace function public.set_my_presence(online boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  update public.profiles
  set is_online = online,
      last_active_at = now()
  where id = auth.uid();
end;
$$;

revoke execute on function public.set_my_presence(boolean) from public, anon;
grant execute on function public.set_my_presence(boolean) to authenticated;

create or replace function private.new_account_visible_to_viewer(
  target_user uuid,
  viewer_user uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select case
      when viewer_user = target_user then true
      when p.created_at <= now() - interval '28 days' then true
      when p.created_at <= now() - interval '14 days' then true
      when p.created_at <= now() - interval '7 days' then
        private.current_subscription_tier(viewer_user) in ('plus', 'elite', 'vip')
      else private.current_subscription_tier(viewer_user) in ('elite', 'vip')
    end
    from public.profiles p where p.id = target_user
  ), false);
$$;

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
        and private.new_account_visible_to_viewer(target_user, auth.uid())
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
            from public.messages message
            join public.conversation_members member
              on member.conversation_id = message.conversation_id
            where message.sender_id = target_user
              and member.user_id = auth.uid()
              and member.left_at is null
              and message.deleted_at is null
          )
        )
      )
    );
$$;

create or replace function public.find_nearby_profiles(
  radius_km integer default 50,
  result_limit integer default 50,
  result_offset integer default 0
)
returns table (
  id uuid,
  first_name text,
  age integer,
  city text,
  country_name text,
  is_verified boolean,
  is_online boolean,
  distance_km numeric
)
language sql
stable
security definer
set search_path = ''
as $$
  with me as (
    select latitude, longitude
    from private.user_locations
    where user_id = auth.uid()
  ), candidates as (
    select
      profile.id,
      profile.first_name,
      extract(year from age(current_date, profile.date_of_birth))::integer as age,
      profile.city,
      profile.country_name,
      profile.is_verified,
      profile.show_online_status
        and profile.is_online
        and profile.last_active_at > now() - interval '3 minutes' as is_online,
      6371.0 * 2 * asin(
        sqrt(
          power(sin(radians(location.latitude - me.latitude) / 2), 2)
          + cos(radians(me.latitude)) * cos(radians(location.latitude))
          * power(sin(radians(location.longitude - me.longitude) / 2), 2)
        )
      ) as raw_distance_km
    from me
    join private.user_locations location on location.user_id <> auth.uid()
    join public.profiles profile on profile.id = location.user_id
    where profile.status = 'active'
      and profile.is_discoverable
      and private.new_account_visible_to_viewer(profile.id, auth.uid())
      and not private.is_blocked_between(auth.uid(), profile.id)
  )
  select
    candidate.id,
    candidate.first_name,
    candidate.age,
    candidate.city,
    candidate.country_name,
    candidate.is_verified,
    candidate.is_online,
    round(candidate.raw_distance_km::numeric, 1)
  from candidates candidate
  where candidate.raw_distance_km <= greatest(1, least(radius_km, 20000))
  order by candidate.raw_distance_km
  limit greatest(1, least(result_limit, 100))
  offset greatest(0, result_offset);
$$;

create or replace function public.create_my_garden_album(album_title text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_title text := btrim(album_title);
  album_id uuid;
  tier public.subscription_tier := private.current_subscription_tier(auth.uid());
  current_count integer;
  allowed_count integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if normalized_title is null or char_length(normalized_title) not between 1 and 120 then
    raise exception 'Album name must contain between 1 and 120 characters';
  end if;
  select count(*) into current_count
  from public.garden_albums where owner_id = auth.uid();
  allowed_count := case tier when 'free' then 1 when 'plus' then 3 else 10 end;
  if current_count >= allowed_count then
    raise exception 'Secret Garden album limit reached for the current plan';
  end if;
  insert into public.garden_albums(owner_id, title)
  values (auth.uid(), normalized_title)
  returning id into album_id;
  return album_id;
end;
$$;

revoke execute on function public.create_my_garden_album(text) from public, anon;
grant execute on function public.create_my_garden_album(text) to authenticated;

create or replace function private.protect_profile_geography()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() = 'service_role'
     or private.is_admin(auth.uid())
     or current_setting('maplov.phone_country_sync', true) = 'true'
     or current_setting('maplov.system_operation', true) = 'account_deletion' then
    return new;
  end if;

  if old.origin_country_name is not null
     and btrim(old.origin_country_name) <> ''
     and new.origin_country_name is distinct from old.origin_country_name then
    raise exception 'Country of origin can only be chosen once';
  end if;

  if new.country_name is distinct from old.country_name
     or new.residence_country_name is distinct from old.residence_country_name
     or new.country_code is distinct from old.country_code then
    raise exception 'Residence country is controlled by the verified phone number';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_protect_geography on public.profiles;
create trigger profiles_protect_geography
before update of country_name, residence_country_name, country_code,
  origin_country_name on public.profiles
for each row execute function private.protect_profile_geography();

create or replace function public.sync_my_residence_from_verified_phone(
  residence_country text,
  calling_code text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  verified_phone text;
  normalized_code text := regexp_replace(calling_code, '[^0-9]', '', 'g');
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select phone into verified_phone
  from auth.users
  where id = auth.uid() and phone_confirmed_at is not null;
  if verified_phone is null then raise exception 'Phone verification required'; end if;
  if residence_country is null or btrim(residence_country) = ''
     or normalized_code = ''
     or verified_phone not like '+' || normalized_code || '%' then
    raise exception 'Residence country does not match the verified phone number';
  end if;
  perform set_config('maplov.phone_country_sync', 'true', true);
  update public.profiles
  set country_name = btrim(residence_country),
      residence_country_name = btrim(residence_country)
  where id = auth.uid();
end;
$$;

revoke execute on function public.sync_my_residence_from_verified_phone(text, text)
  from public, anon;
grant execute on function public.sync_my_residence_from_verified_phone(text, text)
  to authenticated;

create or replace function private.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  supplied_name text;
  accepted_documents jsonb := coalesce(
    new.raw_user_meta_data -> 'accepted_legal_documents',
    '{}'::jsonb
  );
  accepted_time timestamptz := coalesce(
    nullif(new.raw_user_meta_data ->> 'legal_accepted_at', '')::timestamptz,
    now()
  );
begin
  supplied_name := coalesce(
    nullif(btrim(new.raw_user_meta_data ->> 'first_name'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'name'), '')
  );

  insert into public.profiles (
    id,
    first_name,
    date_of_birth,
    country_code,
    country_name,
    city,
    residence_country_name,
    residence_city,
    origin_country_name
  ) values (
    new.id,
    supplied_name,
    private.safe_date(new.raw_user_meta_data ->> 'date_of_birth'),
    nullif(upper(btrim(new.raw_user_meta_data ->> 'country_code')), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'country_name'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'city'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'country_name'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'city'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'origin_country_name'), '')
  );

  insert into public.dating_preferences (user_id) values (new.id);
  insert into public.notification_preferences (user_id) values (new.id);

  insert into public.user_legal_acceptances (
    user_id,
    document_key,
    document_version,
    accepted_at
  )
  select new.id, document.document_key, document.version, accepted_time
  from public.legal_documents document
  where document.is_required
    and accepted_documents ->> document.document_key = document.version;

  return new;
end;
$$;

comment on table public.photo_super_likes is
  'Persisted Super Likes included in the Discover engagement score.';
comment on function private.new_account_visible_to_viewer(uuid, uuid) is
  'Days 0-6 VIP, days 7-13 Plus/VIP, days 14-27 everyone; owners always see themselves.';
