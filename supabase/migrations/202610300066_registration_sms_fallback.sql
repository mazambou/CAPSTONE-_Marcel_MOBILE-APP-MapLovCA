-- A verified phone may complete registration while the email remains pending.
-- Only the server can set the SMS fallback marker in auth app metadata.
begin;

create table if not exists private.registration_sms_fallback_limits (
  phone text primary key,
  window_started_at timestamptz not null,
  last_sent_at timestamptz not null,
  sends integer not null check (sends > 0)
);
alter table private.registration_sms_fallback_limits enable row level security;
revoke all on private.registration_sms_fallback_limits from public, anon, authenticated;

create or replace function public.find_pending_registration_for_sms(
  email_value text, phone_value text
)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select account.id
  from auth.users as account
  where auth.role() = 'service_role'
    and account.email = lower(trim(email_value))
    and account.raw_user_meta_data ->> 'phone_number' = phone_value
    and account.email_confirmed_at is null
    and account.phone_confirmed_at is null
    and account.deleted_at is null
    and not exists (
      select 1 from auth.users as other_account
      where other_account.phone = phone_value
        and other_account.id <> account.id
    )
  limit 1;
$$;
revoke all on function public.find_pending_registration_for_sms(text, text)
  from public, anon, authenticated;
grant execute on function public.find_pending_registration_for_sms(text, text)
  to service_role;

create or replace function public.claim_registration_sms_fallback_send(
  owner_user uuid, phone_value text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  previous private.registration_sms_fallback_limits%rowtype;
  checked_at timestamptz := now();
begin
  if auth.role() <> 'service_role'
     or owner_user is null
     or phone_value !~ '^\+[1-9][0-9]{7,14}$'
     or not exists (
       select 1 from auth.users as account
       where account.id = owner_user
         and account.raw_user_meta_data ->> 'phone_number' = phone_value
         and account.email_confirmed_at is null
         and account.phone_confirmed_at is null
     ) then
    return false;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(phone_value));
  select * into previous
  from private.registration_sms_fallback_limits
  where phone = phone_value;

  if not found then
    insert into private.registration_sms_fallback_limits (
      phone, window_started_at, last_sent_at, sends
    ) values (phone_value, checked_at, checked_at, 1);
    return true;
  end if;
  if previous.last_sent_at > checked_at - interval '1 minute' then
    return false;
  end if;
  if previous.window_started_at > checked_at - interval '24 hours'
     and previous.sends >= 5 then
    return false;
  end if;

  update private.registration_sms_fallback_limits
  set window_started_at = case
        when previous.window_started_at <= checked_at - interval '24 hours'
          then checked_at
        else previous.window_started_at
      end,
      last_sent_at = checked_at,
      sends = case
        when previous.window_started_at <= checked_at - interval '24 hours'
          then 1
        else previous.sends + 1
      end
  where phone = phone_value;
  return true;
end;
$$;
revoke all on function public.claim_registration_sms_fallback_send(uuid, text)
  from public, anon, authenticated;
grant execute on function public.claim_registration_sms_fallback_send(uuid, text)
  to service_role;

create or replace function private.has_verified_registration_contact(owner_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from auth.users as account
    where account.id = owner_user
      and (
        account.email_confirmed_at is not null
        or (
          account.phone_confirmed_at is not null
          and account.raw_app_meta_data ->> 'maplov_sms_fallback_verified' = 'true'
        )
      )
  );
$$;
revoke all on function private.has_verified_registration_contact(uuid)
  from public, anon, authenticated;

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
    join private.user_locations as location on location.user_id = account.id
    join private.quebec_residence_checks as check_result
      on check_result.user_id = account.id
     and check_result.location_updated_at = location.updated_at
     and location.updated_at >= now() - interval '10 minutes'
    where account.id = auth.uid()
      and private.has_verified_registration_contact(account.id)
      and account.phone_confirmed_at is not null
      and profile.country_code = 'CA'
      and profile.residence_location_verified_at is not null
      and check_result.eligible
      and check_result.detected_country_code = 'CA'
  );
$$;

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
      and private.has_verified_registration_contact(account.id)
      and account.phone_confirmed_at is not null
      and profile.country_code = 'CA'
      and profile.residence_location_verified_at is not null
  ) then
    raise exception 'Verified contact, phone and residence are required';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtext('profile_photos:' || owner_user::text)
  );
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

create or replace function private.protect_profile_completion_verification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() = 'service_role'
     or current_setting('maplov.system_operation', true) in (
       'account_deletion', 'photo_moderation'
     )
     or private.is_admin(auth.uid()) then
    return new;
  end if;

  if (old.profile_completed_at is null and new.profile_completed_at is not null)
     or (not old.is_discoverable and new.is_discoverable) then
    if new.first_name is null
       or new.date_of_birth is null
       or new.gender is null
       or new.city is null
       or new.country_name is null
       or new.residence_region is null
       or new.origin_country_name is null
       or new.origin_region is null
       or new.origin_city is null
       or coalesce(array_length(new.spoken_languages, 1), 0) = 0 then
      raise exception 'Complete the required profile fields first';
    end if;

    if not exists (
      select 1 from public.profile_photos as photo
      where photo.user_id = new.id
        and photo.is_primary
        and photo.moderation_status = 'visible'
        and (
          (
            photo.verification_method = 'face_match'
            and photo.is_verified
            and exists (
              select 1 from public.face_references as reference
              where reference.user_id = new.id
            )
          )
          or (
            photo.verification_method = 'account_checks'
            and new.country_code = 'CA'
            and new.residence_location_verified_at is not null
            and private.has_verified_registration_contact(new.id)
            and exists (
              select 1 from auth.users as account
              where account.id = new.id
                and account.phone_confirmed_at is not null
            )
          )
        )
    ) then
      raise exception 'A verified account and accepted primary photo are required';
    end if;
  end if;
  return new;
end;
$$;

commit;
