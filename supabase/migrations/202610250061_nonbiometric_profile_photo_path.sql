-- An account can publish photos without facial recognition after its email,
-- phone and residence have been verified. These photos never receive the
-- face-match badge. The existing biometric enrollment path remains intact.

begin;

alter table public.profile_photos
  add column if not exists verification_method text not null default 'face_match';

alter table public.profile_photos
  drop constraint if exists profile_photos_verification_method_check;
alter table public.profile_photos
  add constraint profile_photos_verification_method_check
  check (verification_method in ('face_match', 'account_checks'));

create or replace function public.has_my_account_verification()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null and exists (
    select 1 from auth.users as account
    join public.profiles as profile on profile.id = account.id
    where account.id = auth.uid()
      and account.email_confirmed_at is not null
      and account.phone_confirmed_at is not null
      and profile.country_code = 'CA'
      and profile.residence_location_verified_at is not null
  );
$$;

revoke all on function public.has_my_account_verification() from public, anon;
grant execute on function public.has_my_account_verification() to authenticated;

create or replace function public.register_account_checked_profile_photo(
  owner_user uuid,
  storage_path_value text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_photo_id uuid;
  next_order smallint;
  first_photo boolean;
begin
  if auth.role() <> 'service_role' then
    raise exception 'Service role required';
  end if;
  if owner_user is null
     or storage_path_value not like owner_user::text || '/%'
     or storage_path_value like '%..%'
     or storage_path_value !~* '[.](jpe?g|png)$' then
    raise exception 'Invalid profile photo path';
  end if;
  if not exists (
    select 1 from auth.users as account
    join public.profiles as profile on profile.id = account.id
    where account.id = owner_user
      and account.email_confirmed_at is not null
      and account.phone_confirmed_at is not null
      and profile.country_code = 'CA'
      and profile.residence_location_verified_at is not null
  ) then
    raise exception 'Verified email, phone and residence are required';
  end if;

  perform pg_advisory_xact_lock(hashtext('profile_photos:' || owner_user::text));
  select coalesce(max(display_order), -1)::smallint + 1, count(*) = 0
    into next_order, first_photo
  from public.profile_photos
  where user_id = owner_user;

  insert into public.profile_photos (
    user_id, storage_path, display_order, is_primary, is_verified,
    verification_method, moderation_status
  ) values (
    owner_user, storage_path_value, next_order, first_photo, false,
    'account_checks', 'visible'
  ) returning id into new_photo_id;

  return new_photo_id;
end;
$$;

revoke all on function public.register_account_checked_profile_photo(uuid, text)
  from public, anon, authenticated;
grant execute on function public.register_account_checked_profile_photo(uuid, text)
  to service_role;

commit;
