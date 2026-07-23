-- Private reference selfies and mandatory AWS Rekognition verification for
-- every new public profile photo.

begin;

create table if not exists public.face_references (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  storage_path text not null unique,
  provider text not null default 'aws_rekognition'
    check (provider = 'aws_rekognition'),
  provider_request_id text,
  face_confidence numeric(6,3),
  consent_version text not null,
  consented_at timestamptz not null,
  enrolled_at timestamptz not null default now(),
  last_verified_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint face_references_owner_path check (
    storage_path like user_id::text || '/%'
  )
);

create table if not exists public.profile_photo_face_checks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  photo_id uuid references public.profile_photos(id) on delete set null,
  check_type text not null default 'profile_photo'
    check (check_type in ('reference_selfie', 'profile_photo')),
  status text not null check (
    status in ('accepted', 'rejected', 'error')
  ),
  similarity numeric(6,3),
  threshold numeric(6,3) not null,
  provider text not null default 'aws_rekognition'
    check (provider = 'aws_rekognition'),
  provider_request_id text,
  failure_reason text,
  created_at timestamptz not null default now()
);

alter table public.face_references enable row level security;
alter table public.profile_photo_face_checks enable row level security;

-- Biometric references and comparison logs are server-only. Even their object
-- paths are not exposed through the authenticated Data API.
revoke all on public.face_references from public, anon, authenticated;
revoke all on public.profile_photo_face_checks from public, anon, authenticated;
grant select, insert, update, delete on public.face_references to service_role;
grant select, insert, update, delete on public.profile_photo_face_checks to service_role;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('identity-selfies', 'identity-selfies', false, 5242880,
    array['image/jpeg', 'image/png']),
  ('profile-media-pending', 'profile-media-pending', false, 5242880,
    array['image/jpeg', 'image/png'])
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists identity_selfies_owner_insert on storage.objects;
create policy identity_selfies_owner_insert
on storage.objects for insert to authenticated
with check (
  bucket_id = 'identity-selfies'
  and private.safe_uuid((storage.foldername(name))[1]) = auth.uid()
);

drop policy if exists profile_media_pending_owner_insert on storage.objects;
create policy profile_media_pending_owner_insert
on storage.objects for insert to authenticated
with check (
  bucket_id = 'profile-media-pending'
  and private.safe_uuid((storage.foldername(name))[1]) = auth.uid()
);

-- Public profile objects can now only be created by the trusted verification
-- function. Users keep delete access for their own already-verified photos.
drop policy if exists profile_media_insert on storage.objects;
drop policy if exists profile_media_update on storage.objects;
drop policy if exists profile_photos_owner_insert on public.profile_photos;
revoke insert on public.profile_photos from authenticated;
revoke execute on function public.register_profile_photo(text)
  from authenticated;

create or replace function private.protect_photo_verification()
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
  if tg_op = 'INSERT' then
    new.is_verified := false;
    new.moderation_status := 'visible';
    new.hidden_at := null;
    new.moderation_notes := null;
  elsif new.user_id is distinct from old.user_id
     or new.storage_path is distinct from old.storage_path
     or new.is_verified is distinct from old.is_verified
     or new.moderation_status is distinct from old.moderation_status
     or new.hidden_at is distinct from old.hidden_at
     or new.moderation_notes is distinct from old.moderation_notes then
    raise exception 'Photo identity and moderation fields are server-controlled';
  end if;
  return new;
end;
$$;

create or replace function public.has_my_face_reference()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null and exists (
    select 1 from public.face_references where user_id = auth.uid()
  );
$$;

create or replace function public.register_verified_profile_photo(
  owner_user uuid,
  storage_path_value text,
  similarity_value numeric,
  threshold_value numeric,
  provider_request_id_value text default null
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
     or similarity_value < threshold_value then
    raise exception 'Invalid verified profile photo';
  end if;
  if not exists (
    select 1 from public.face_references where user_id = owner_user
  ) then
    raise exception 'A private reference selfie is required';
  end if;

  perform pg_advisory_xact_lock(hashtext('profile_photos:' || owner_user::text));
  select coalesce(max(display_order), -1)::smallint + 1, count(*) = 0
  into next_order, first_photo
  from public.profile_photos
  where user_id = owner_user;

  insert into public.profile_photos(
    user_id, storage_path, display_order, is_primary, is_verified,
    moderation_status
  ) values (
    owner_user, storage_path_value, next_order, first_photo, true,
    'visible'
  ) returning id into new_photo_id;

  insert into public.profile_photo_face_checks(
    user_id, photo_id, status, similarity, threshold, provider_request_id
  ) values (
    owner_user, new_photo_id, 'accepted', similarity_value,
    threshold_value, provider_request_id_value
  );

  update public.face_references
  set last_verified_at = now(), updated_at = now()
  where user_id = owner_user;

  return new_photo_id;
end;
$$;

revoke execute on function public.has_my_face_reference()
  from public, anon;
grant execute on function public.has_my_face_reference()
  to authenticated;
revoke execute on function public.register_verified_profile_photo(
  uuid, text, numeric, numeric, text
) from public, anon, authenticated;
grant execute on function public.register_verified_profile_photo(
  uuid, text, numeric, numeric, text
) to service_role;

create or replace function public.export_my_data()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  request_id uuid;
  result jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  insert into public.data_export_requests(user_id)
  values (auth.uid()) returning id into request_id;

  select jsonb_build_object(
    'generated_at', now(),
    'profile', (select to_jsonb(p) from public.profiles p where p.id = auth.uid()),
    'dating_preferences', (select to_jsonb(d) from public.dating_preferences d where d.user_id = auth.uid()),
    'notification_preferences', (select to_jsonb(n) from public.notification_preferences n where n.user_id = auth.uid()),
    'photos', coalesce((select jsonb_agg(to_jsonb(x)) from public.profile_photos x where x.user_id = auth.uid()), '[]'::jsonb),
    'face_reference', (select to_jsonb(r) from public.face_references r where r.user_id = auth.uid()),
    'face_comparison_records', coalesce((select jsonb_agg(to_jsonb(x)) from public.profile_photo_face_checks x where x.user_id = auth.uid()), '[]'::jsonb),
    'sent_messages', coalesce((select jsonb_agg(to_jsonb(x)) from public.messages x where x.sender_id = auth.uid()), '[]'::jsonb),
    'posts', coalesce((select jsonb_agg(to_jsonb(x)) from public.posts x where x.author_id = auth.uid()), '[]'::jsonb),
    'post_comments', coalesce((select jsonb_agg(to_jsonb(x)) from public.post_comments x where x.author_id = auth.uid()), '[]'::jsonb),
    'reports_submitted', coalesce((select jsonb_agg(to_jsonb(x)) from public.reports x where x.reporter_id = auth.uid()), '[]'::jsonb),
    'blocks', coalesce((select jsonb_agg(to_jsonb(x)) from public.blocks x where x.blocker_id = auth.uid()), '[]'::jsonb),
    'subscriptions', coalesce((select jsonb_agg(to_jsonb(x) - 'receipt_metadata') from public.subscriptions x where x.user_id = auth.uid()), '[]'::jsonb),
    'deletion_requests', coalesce((select jsonb_agg(to_jsonb(x)) from public.account_deletion_requests x where x.user_id = auth.uid()), '[]'::jsonb)
  ) into result;

  update public.data_export_requests
  set status = 'completed', completed_at = now()
  where id = request_id;
  return result;
exception when others then
  update public.data_export_requests set status = 'failed' where id = request_id;
  raise;
end;
$$;

revoke execute on function public.export_my_data() from public, anon;
grant execute on function public.export_my_data() to authenticated;

-- Clean interrupted uploads without ever touching an enrolled reference.
create or replace function public.cleanup_stale_face_verification_uploads()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  removed integer;
  removed_references integer;
begin
  if auth.role() <> 'service_role' and auth.uid() is not null then
    raise exception 'Service role required';
  end if;
  delete from storage.objects
  where bucket_id = 'profile-media-pending'
    and created_at < now() - interval '1 day';
  get diagnostics removed = row_count;

  delete from storage.objects as pending_reference
  where pending_reference.bucket_id = 'identity-selfies'
    and pending_reference.created_at < now() - interval '1 day'
    and not exists (
      select 1 from public.face_references as enrolled_reference
      where enrolled_reference.storage_path = pending_reference.name
    );
  get diagnostics removed_references = row_count;
  return removed + removed_references;
end;
$$;

revoke execute on function public.cleanup_stale_face_verification_uploads()
  from public, anon, authenticated;
grant execute on function public.cleanup_stale_face_verification_uploads()
  to service_role;

do $$
begin
  perform cron.unschedule(jobid)
  from cron.job where jobname = 'maplov-face-upload-cleanup';
  perform cron.schedule(
    'maplov-face-upload-cleanup',
    '43 3 * * *',
    'select public.cleanup_stale_face_verification_uploads()'
  );
end;
$$;

commit;
