-- A client may set profile_completed_at only after an accepted photo and the
-- selected verification route are present. This closes the direct Data API
-- bypass while leaving existing face-verified profiles unchanged.

begin;

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
            and exists (
              select 1 from auth.users as account
              where account.id = new.id
                and account.email_confirmed_at is not null
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

drop trigger if exists profiles_protect_completion_verification on public.profiles;
create trigger profiles_protect_completion_verification
before update of profile_completed_at, is_discoverable on public.profiles
for each row execute function private.protect_profile_completion_verification();

commit;
