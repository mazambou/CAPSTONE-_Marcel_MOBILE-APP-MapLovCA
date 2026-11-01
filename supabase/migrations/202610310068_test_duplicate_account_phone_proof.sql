-- Permit a verified test duplicate to share a contact phone without
-- assigning that phone to a second Supabase Auth identity.
begin;

create or replace function private.has_verified_account_phone(owner_user uuid)
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
        account.phone_confirmed_at is not null
        or (
          account.raw_app_meta_data ->> 'maplov_test_duplicate' = 'true'
          and account.raw_app_meta_data ->> 'maplov_test_phone_verified' = 'true'
          and account.raw_app_meta_data ->> 'maplov_contact_phone' =
              account.raw_user_meta_data ->> 'phone_number'
        )
      )
  );
$$;
revoke all on function private.has_verified_account_phone(uuid)
  from public, anon, authenticated;

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
          private.has_verified_account_phone(account.id)
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
      and private.has_verified_account_phone(account.id)
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
      and private.has_verified_account_phone(account.id)
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
                and private.has_verified_account_phone(account.id)
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

create table if not exists private.test_duplicate_sms_limits (
  phone text primary key,
  window_started_at timestamptz not null,
  last_sent_at timestamptz not null,
  sends integer not null check (sends > 0)
);
alter table private.test_duplicate_sms_limits enable row level security;
revoke all on private.test_duplicate_sms_limits from public, anon, authenticated;

create or replace function public.test_duplicate_source_exists(
  contact_email text, contact_phone text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.role() = 'service_role'
    and exists (
      select 1 from auth.users as account
      join public.profiles as profile on profile.id = account.id
      where lower(account.email) = lower(trim(contact_email))
        and regexp_replace(coalesce(account.phone, ''), '[^0-9]', '', 'g') =
            substring(contact_phone from 2)
        and account.email_confirmed_at is not null
        and account.phone_confirmed_at is not null
        and account.deleted_at is null
        and profile.status = 'active'
    );
$$;
revoke all on function public.test_duplicate_source_exists(text, text)
  from public, anon, authenticated;
grant execute on function public.test_duplicate_source_exists(text, text)
  to service_role;

create or replace function public.test_duplicate_accounts_by_phone(
  contact_phone text
)
returns table (
  account_id uuid,
  auth_email text,
  contact_email text,
  account_name text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select account.id, account.email::text,
    coalesce(
      nullif(account.raw_app_meta_data ->> 'maplov_contact_email', ''),
      account.email
    )::text,
    coalesce(nullif(profile.first_name, ''), 'MapLov account')::text,
    account.created_at
  from auth.users as account
  join public.profiles as profile on profile.id = account.id
  where auth.role() = 'service_role'
    and account.deleted_at is null
    and profile.status = 'active'
    and (
      (
        regexp_replace(coalesce(account.phone, ''), '[^0-9]', '', 'g') =
          substring(contact_phone from 2)
        and account.phone_confirmed_at is not null
      )
      or (
        account.raw_app_meta_data ->> 'maplov_test_duplicate' = 'true'
        and account.raw_app_meta_data ->> 'maplov_test_phone_verified' = 'true'
        and account.raw_app_meta_data ->> 'maplov_contact_phone' = contact_phone
      )
    )
  order by account.created_at, account.id;
$$;
revoke all on function public.test_duplicate_accounts_by_phone(text)
  from public, anon, authenticated;
grant execute on function public.test_duplicate_accounts_by_phone(text)
  to service_role;

create or replace function public.claim_test_duplicate_sms_send(contact_phone text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  previous private.test_duplicate_sms_limits%rowtype;
  checked_at timestamptz := now();
begin
  if auth.role() <> 'service_role'
     or contact_phone !~ '^[+][1-9][0-9]{7,14}$' then
    return false;
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtext('test_duplicate_sms:' || contact_phone)
  );
  select * into previous from private.test_duplicate_sms_limits
  where phone = contact_phone;
  if not found then
    insert into private.test_duplicate_sms_limits (
      phone, window_started_at, last_sent_at, sends
    ) values (contact_phone, checked_at, checked_at, 1);
    return true;
  end if;
  if previous.last_sent_at > checked_at - interval '1 minute' then
    return false;
  end if;
  if previous.window_started_at > checked_at - interval '24 hours'
     and previous.sends >= 20 then
    return false;
  end if;
  update private.test_duplicate_sms_limits
  set window_started_at = case
        when previous.window_started_at <= checked_at - interval '24 hours'
          then checked_at else previous.window_started_at end,
      last_sent_at = checked_at,
      sends = case
        when previous.window_started_at <= checked_at - interval '24 hours'
          then 1 else previous.sends + 1 end
  where phone = contact_phone;
  return true;
end;
$$;
revoke all on function public.claim_test_duplicate_sms_send(text)
  from public, anon, authenticated;
grant execute on function public.claim_test_duplicate_sms_send(text)
  to service_role;

create or replace function public.admin_user_details(user_id_value uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  details jsonb;
begin
  if not private.is_admin(auth.uid()) then
    raise exception 'Admin required';
  end if;

  select jsonb_build_object(
    'id', profile.id,
    'first_name', profile.first_name,
    'email', coalesce(nullif(auth_user.raw_app_meta_data ->> 'maplov_contact_email', ''), auth_user.email),
    'phone', coalesce(nullif(auth_user.raw_app_meta_data ->> 'maplov_contact_phone', ''), auth_user.phone),
    'email_confirmed_at', auth_user.email_confirmed_at,
    'phone_confirmed_at', coalesce(auth_user.phone_confirmed_at, case when auth_user.raw_app_meta_data ->> 'maplov_test_phone_verified' = 'true' then (auth_user.raw_app_meta_data ->> 'maplov_test_created_at')::timestamptz end),
    'last_sign_in_at', auth_user.last_sign_in_at,
    'auth_created_at', auth_user.created_at,
    'profile_created_at', profile.created_at,
    'last_active_at', profile.last_active_at,
    'profile_completed_at', profile.profile_completed_at,
    'date_of_birth', profile.date_of_birth,
    'gender', profile.gender,
    'city', profile.city,
    'country_code', profile.country_code,
    'country_name', profile.country_name,
    'profession', profile.profession,
    'education_level', profile.education_level,
    'relationship_goal', profile.relationship_goal,
    'role', profile.role,
    'status', profile.status,
    'is_discoverable', profile.is_discoverable,
    'is_verified', profile.is_verified,
    'is_photo_verified', profile.is_photo_verified,
    'photo_count', (
      select count(*)
      from public.profile_photos as photo
      where photo.user_id = profile.id
    ),
    'open_reports', (
      select count(*)
      from public.reports as report
      where report.status in ('open', 'under_review')
        and (
          (report.target_type = 'user' and report.target_id = profile.id)
          or (
            report.target_type = 'photo'
            and exists (
              select 1
              from public.profile_photos as photo
              where photo.id = report.target_id
                and photo.user_id = profile.id
            )
          )
          or (
            report.target_type = 'post'
            and exists (
              select 1
              from public.posts as post
              where post.id = report.target_id
                and post.author_id = profile.id
            )
          )
          or (
            report.target_type = 'comment'
            and exists (
              select 1
              from public.photo_comments as comment
              where comment.id = report.target_id
                and comment.author_id = profile.id
            )
          )
        )
    ),
    'subscription_tier', coalesce(
      (
        select subscription.tier::text
        from public.subscriptions as subscription
        where subscription.user_id = profile.id
          and subscription.is_current
        order by subscription.created_at desc
        limit 1
      ),
      'free'
    ),
    'deletion_status', (
      select request.status
      from public.account_deletion_requests as request
      where request.user_id = profile.id
      order by request.requested_at desc
      limit 1
    )
  )
  into details
  from public.profiles as profile
  join auth.users as auth_user on auth_user.id = profile.id
  where profile.id = user_id_value;

  if details is null then
    raise exception 'Account not found';
  end if;

  return details;
end;
$$;

revoke execute on function public.admin_user_details(uuid)
  from public, anon;
grant execute on function public.admin_user_details(uuid)
  to authenticated;

commit;
