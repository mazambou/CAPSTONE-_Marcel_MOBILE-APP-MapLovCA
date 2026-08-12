-- Country-scoped AWS Rekognition indexes for constant-cost duplicate checks.

begin;

alter table public.face_references
  add column if not exists country_id uuid
    references public.countries(id) on delete restrict,
  add column if not exists face_id text,
  add column if not exists collection_id text,
  add column if not exists external_image_id text,
  add column if not exists indexed_at timestamptz,
  add column if not exists index_request_id text,
  add column if not exists face_model_version text;

create index if not exists face_references_user_id_idx
  on public.face_references(user_id);
create index if not exists face_references_face_id_idx
  on public.face_references(face_id) where face_id is not null;
create index if not exists face_references_collection_id_idx
  on public.face_references(collection_id) where collection_id is not null;
create unique index if not exists face_references_collection_face_unique
  on public.face_references(collection_id, face_id)
  where collection_id is not null and face_id is not null;
create unique index if not exists face_references_collection_external_unique
  on public.face_references(collection_id, external_image_id)
  where collection_id is not null and external_image_id is not null;

alter table public.face_references
  drop constraint if exists face_references_index_fields_complete;
alter table public.face_references
  add constraint face_references_index_fields_complete check (
    (face_id is null and collection_id is null and external_image_id is null
      and indexed_at is null)
    or
    (face_id is not null and collection_id is not null
      and external_image_id is not null and indexed_at is not null
      and country_id is not null)
  ) not valid;

create table if not exists public.face_index_cleanup_queue (
  collection_id text not null,
  face_id text not null,
  user_id uuid references public.profiles(id) on delete set null,
  reason text not null,
  attempt_count integer not null default 0,
  last_attempt_at timestamptz,
  created_at timestamptz not null default now(),
  primary key (collection_id, face_id)
);

alter table public.face_index_cleanup_queue enable row level security;
revoke all on public.face_index_cleanup_queue
  from public, anon, authenticated;
grant select, insert, update, delete on public.face_index_cleanup_queue
  to service_role;

-- A lease survives separate Data API transactions, unlike a transaction-level
-- advisory lock. Only service-role RPCs can acquire or release it.
create table if not exists private.face_enrollment_locks (
  collection_id text primary key,
  owner_token uuid not null,
  lease_until timestamptz not null,
  updated_at timestamptz not null default now()
);

revoke all on private.face_enrollment_locks
  from public, anon, authenticated, service_role;

create or replace function public.try_acquire_face_enrollment_lock(
  collection_id_value text,
  owner_token_value uuid,
  lease_seconds_value integer default 120
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  affected integer;
begin
  if auth.role() <> 'service_role' then
    raise exception 'Service role required';
  end if;
  if collection_id_value is null or btrim(collection_id_value) = ''
     or owner_token_value is null then
    raise exception 'A collection and lock owner are required';
  end if;

  insert into private.face_enrollment_locks(
    collection_id, owner_token, lease_until, updated_at
  ) values (
    collection_id_value,
    owner_token_value,
    now() + make_interval(secs => greatest(30, least(lease_seconds_value, 300))),
    now()
  )
  on conflict (collection_id) do update
  set owner_token = excluded.owner_token,
      lease_until = excluded.lease_until,
      updated_at = now()
  where private.face_enrollment_locks.lease_until <= now()
     or private.face_enrollment_locks.owner_token = owner_token_value;
  get diagnostics affected = row_count;
  return affected = 1;
end;
$$;

create or replace function public.release_face_enrollment_lock(
  collection_id_value text,
  owner_token_value uuid
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
  delete from private.face_enrollment_locks
  where collection_id = collection_id_value
    and owner_token = owner_token_value;
end;
$$;

create or replace function public.register_indexed_face_reference(
  owner_user uuid,
  country_id_value uuid,
  storage_path_value text,
  face_id_value text,
  collection_id_value text,
  external_image_id_value text,
  face_confidence_value numeric,
  consent_version_value text,
  detect_request_id_value text,
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
    select 1
    from private.face_enrollment_locks as enrollment_lock
    where enrollment_lock.collection_id = collection_id_value
      and enrollment_lock.owner_token = lock_owner_token_value
      and enrollment_lock.lease_until > now()
  ) then
    raise exception 'The face enrollment lock is not held';
  end if;
  if storage_path_value not like owner_user::text || '/%'
     or nullif(btrim(face_id_value), '') is null
     or nullif(btrim(collection_id_value), '') is null
     or external_image_id_value <> owner_user::text then
    raise exception 'Invalid indexed face reference';
  end if;
  if not exists (
    select 1
    from public.profiles as profile
    join public.countries as country on country.id = country_id_value
    where profile.id = owner_user
      and (
        profile.residence_country_id = country_id_value
        or profile.country_code = country.iso2
      )
      and profile.profile_completed_at is null
  ) then
    raise exception 'Identity enrollment is not available for this profile';
  end if;

  insert into public.face_references(
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

  insert into public.profile_photo_face_checks(
    user_id, check_type, status, similarity, threshold,
    provider_request_id
  ) values (
    owner_user, 'reference_selfie', 'accepted', face_confidence_value, 99,
    coalesce(index_request_id_value, detect_request_id_value)
  );
end;
$$;

revoke execute on function public.try_acquire_face_enrollment_lock(
  text, uuid, integer
) from public, anon, authenticated;
revoke execute on function public.release_face_enrollment_lock(text, uuid)
  from public, anon, authenticated;
revoke execute on function public.register_indexed_face_reference(
  uuid, uuid, text, text, text, text, numeric, text, text, text, text, uuid
) from public, anon, authenticated;
grant execute on function public.try_acquire_face_enrollment_lock(
  text, uuid, integer
) to service_role;
grant execute on function public.release_face_enrollment_lock(text, uuid)
  to service_role;
grant execute on function public.register_indexed_face_reference(
  uuid, uuid, text, text, text, text, numeric, text, text, text, text, uuid
) to service_role;

comment on column public.face_references.face_id is
  'Authoritative AWS Rekognition FaceId used for lookup and deletion.';
comment on column public.face_references.collection_id is
  'Deterministic country-scoped AWS Rekognition collection identifier.';
comment on table private.face_enrollment_locks is
  'Short service-only leases serializing SearchFacesByImage and IndexFaces per country collection.';
comment on table public.face_index_cleanup_queue is
  'Service-only retry queue for compensating AWS faces whose database registration failed.';

commit;
