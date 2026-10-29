-- A member who joined through Québec account checks may later opt in to
-- facial verification of the existing primary photo. The selfie enrollment,
-- comparison decision and photo badge change are one database transaction.

begin;

create or replace function public.register_indexed_face_reference_upgrade(
  owner_user uuid,
  photo_id_value uuid,
  photo_path_value text,
  country_id_value uuid,
  storage_path_value text,
  face_id_value text,
  collection_id_value text,
  external_image_id_value text,
  face_confidence_value numeric,
  similarity_value numeric,
  threshold_value numeric,
  consent_version_value text,
  detect_request_id_value text,
  compare_request_id_value text,
  index_request_id_value text,
  face_model_version_value text,
  lock_owner_token_value uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() <> 'service_role' then
    raise exception 'Service role required';
  end if;
  if not exists (
    select 1 from private.face_enrollment_locks as enrollment_lock
    where enrollment_lock.collection_id = collection_id_value
      and enrollment_lock.owner_token = lock_owner_token_value
      and enrollment_lock.lease_until > now()
  ) then
    raise exception 'The face enrollment lock is not held';
  end if;
  if owner_user is null or photo_id_value is null
     or storage_path_value not like owner_user::text || '/%'
     or external_image_id_value <> owner_user::text
     or nullif(btrim(face_id_value), '') is null
     or nullif(btrim(collection_id_value), '') is null
     or similarity_value < threshold_value then
    raise exception 'Invalid photo verification upgrade';
  end if;
  if not exists (
    select 1 from public.profiles as profile
    join public.countries as country on country.id = country_id_value
    where profile.id = owner_user
      and profile.profile_completed_at is not null
      and (
        profile.residence_country_id = country_id_value
        or profile.country_code = country.iso2
      )
  ) or exists (
    select 1 from public.face_references where user_id = owner_user
  ) then
    raise exception 'Photo verification upgrade is not available';
  end if;

  perform pg_advisory_xact_lock(hashtext('profile_photos:' || owner_user::text));
  if not exists (
    select 1 from public.profile_photos as photo
    where photo.id = photo_id_value
      and photo.user_id = owner_user
      and photo.storage_path = photo_path_value
      and photo.is_primary
      and photo.moderation_status = 'visible'
      and photo.verification_method = 'account_checks'
      and not photo.is_verified
  ) then
    raise exception 'The primary photo changed during verification';
  end if;

  insert into public.face_references (
    user_id, country_id, face_id, collection_id, external_image_id,
    storage_path, provider_request_id, index_request_id,
    face_model_version, face_confidence, consent_version, consented_at,
    indexed_at
  ) values (
    owner_user, country_id_value, face_id_value, collection_id_value,
    external_image_id_value, storage_path_value, detect_request_id_value,
    index_request_id_value, face_model_version_value, face_confidence_value,
    consent_version_value, now(), now()
  );

  insert into public.profile_photo_face_checks (
    user_id, check_type, status, similarity, threshold,
    provider_request_id
  ) values (
    owner_user, 'reference_selfie', 'accepted', face_confidence_value,
    99, coalesce(index_request_id_value, detect_request_id_value)
  );

  update public.profile_photos
  set is_verified = true, verification_method = 'face_match'
  where id = photo_id_value;

  insert into public.profile_photo_face_checks (
    user_id, photo_id, check_type, status, similarity, threshold,
    provider_request_id
  ) values (
    owner_user, photo_id_value, 'profile_photo', 'accepted',
    similarity_value, threshold_value, compare_request_id_value
  );
end;
$$;

revoke all on function public.register_indexed_face_reference_upgrade(
  uuid, uuid, text, uuid, text, text, text, text, numeric, numeric,
  numeric, text, text, text, text, text, uuid
) from public, anon, authenticated;
grant execute on function public.register_indexed_face_reference_upgrade(
  uuid, uuid, text, uuid, text, text, text, text, numeric, numeric,
  numeric, text, text, text, text, text, uuid
) to service_role;

create or replace function private.protect_profile_security_fields()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() = 'service_role'
     or current_setting('maplov.system_operation', true) = 'account_deletion' then
    return new;
  end if;
  if new.role is distinct from old.role
     and not private.is_full_admin(auth.uid()) then
    raise exception 'Only administrators can change application roles';
  end if;
  if (new.status is distinct from old.status
      or new.is_verified is distinct from old.is_verified)
     and not private.is_admin(auth.uid()) then
    raise exception 'Protected profile fields cannot be changed by the user';
  end if;
  if new.is_photo_verified is distinct from old.is_photo_verified
     and not private.is_admin(auth.uid())
     and coalesce(current_setting('maplov.photo_verification_sync', true), '') <> 'true' then
    raise exception 'Protected profile fields cannot be changed by the user';
  end if;
  return new;
end;
$$;

create or replace function private.sync_primary_photo_verification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  affected_user uuid;
begin
  affected_user := case when tg_op = 'DELETE' then old.user_id else new.user_id end;
  perform set_config('maplov.photo_verification_sync', 'true', true);
  update public.profiles as profile
  set is_photo_verified = exists (
    select 1 from public.profile_photos as photo
    where photo.user_id = affected_user
      and photo.is_primary
      and photo.moderation_status = 'visible'
      and photo.is_verified
  )
  where profile.id = affected_user;
  perform set_config('maplov.photo_verification_sync', '', true);
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

drop trigger if exists zz_profile_photos_sync_face_badge on public.profile_photos;
create trigger zz_profile_photos_sync_face_badge
after insert or update of is_primary, is_verified, moderation_status or delete
on public.profile_photos
for each row execute function private.sync_primary_photo_verification();

select set_config('maplov.photo_verification_sync', 'true', true);
update public.profiles as profile
set is_photo_verified = true
where not profile.is_photo_verified
  and exists (
    select 1 from public.profile_photos as photo
    where photo.user_id = profile.id
      and photo.is_primary
      and photo.moderation_status = 'visible'
      and photo.is_verified
  );
select set_config('maplov.photo_verification_sync', '', true);

commit;
