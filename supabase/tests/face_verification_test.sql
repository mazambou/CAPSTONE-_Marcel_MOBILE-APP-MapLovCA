begin;

create extension if not exists pgtap with schema extensions;
select plan(35);

select has_table('public', 'face_references',
  'private reference selfie metadata is stored');
select col_is_pk('public', 'face_references', array['user_id'],
  'each account can store only one private reference selfie');
select has_table('public', 'profile_photo_face_checks',
  'face comparison decisions are audited');
select has_table('public', 'duplicate_account_checks',
  'duplicate identity matches are audited');
select has_column('public', 'face_references', 'consent_version',
  'biometric consent version is recorded');
select has_column('public', 'face_references', 'consented_at',
  'biometric consent time is recorded');
select has_column('public', 'face_references', 'country_id',
  'face references retain their normalized residence country');
select has_column('public', 'face_references', 'face_id',
  'the authoritative Rekognition FaceId is retained');
select has_column('public', 'face_references', 'collection_id',
  'the country collection identifier is retained');
select has_column('public', 'face_references', 'external_image_id',
  'the server-derived Rekognition external identifier is retained');
select has_column('public', 'face_references', 'indexed_at',
  'the Rekognition indexing time is retained');
select has_table('private', 'face_enrollment_locks',
  'country collection enrollment leases are stored privately');
select has_table('public', 'face_index_cleanup_queue',
  'failed AWS compensation is retained for retry');
select has_column('public', 'profile_photo_face_checks', 'check_type',
  'reference enrollment and profile comparisons are distinguished');
select has_column('public', 'profiles', 'residence_location_verified_at',
  'identity enrollment can require a recent GPS-backed residence');
select has_function('public', 'has_my_face_reference', array[]::text[],
  'users can query only their own enrollment status');
select has_function(
  'public',
  'register_verified_profile_photo',
  array['uuid', 'text', 'numeric', 'numeric', 'text'],
  'trusted verification registers accepted photos atomically'
);
select has_function(
  'public',
  'try_acquire_face_enrollment_lock',
  array['text', 'uuid', 'integer'],
  'the backend can atomically acquire a country enrollment lease'
);
select has_function(
  'public',
  'release_face_enrollment_lock',
  array['text', 'uuid'],
  'the backend can release its country enrollment lease'
);
select has_function(
  'public',
  'register_indexed_face_reference',
  array[
    'uuid', 'uuid', 'text', 'text', 'text', 'text', 'numeric', 'text',
    'text', 'text', 'text', 'uuid'
  ],
  'indexed reference metadata is committed atomically while holding the lease'
);
select has_index(
  'public', 'face_references', 'face_references_face_id_idx',
  'FaceId lookups are indexed'
);
select has_index(
  'public', 'face_references', 'face_references_collection_id_idx',
  'collection lookups are indexed'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.try_acquire_face_enrollment_lock(text,uuid,integer)',
    'EXECUTE'
  ),
  'members cannot acquire face enrollment locks'
);
select ok(
  exists(select 1 from storage.buckets where id = 'identity-selfies' and not public),
  'reference selfie bucket is private'
);
select ok(
  exists(select 1 from storage.buckets where id = 'profile-media-pending' and not public),
  'pending profile photo bucket is private'
);
select ok(
  not has_table_privilege('authenticated', 'public.face_references', 'select'),
  'authenticated users cannot read biometric reference metadata directly'
);
select ok(
  not has_table_privilege('authenticated', 'public.profile_photo_face_checks', 'select'),
  'authenticated users cannot read face comparison logs directly'
);
select ok(
  not has_table_privilege('authenticated', 'public.duplicate_account_checks', 'select'),
  'authenticated users cannot read duplicate identity matches'
);
select ok(
  not has_table_privilege('authenticated', 'public.face_index_cleanup_queue', 'select'),
  'authenticated users cannot read orphan face cleanup metadata'
);
select has_function(
  'public',
  'sync_my_residence_from_location',
  array['text', 'text', 'text', 'text'],
  'residence can only be synchronized by the controlled location RPC'
);
select ok(
  not has_table_privilege('authenticated', 'public.profile_photos', 'insert'),
  'authenticated users cannot bypass server-side face verification'
);
select has_function(
  'private',
  'can_upload_registration_selfie',
  array['uuid'],
  'storage checks whether registration may upload its unique selfie'
);
select has_function(
  'public',
  'cleanup_rejected_duplicate_registrations',
  array['integer'],
  'rejected provisional duplicate accounts have a cleanup worker'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.cleanup_rejected_duplicate_registrations(integer)',
    'EXECUTE'
  ),
  'members cannot invoke rejected-registration cleanup'
);
select ok(
  exists(
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'identity_selfies_owner_insert'
      and with_check like '%can_upload_registration_selfie%'
  ),
  'identity storage rejects a second reference-selfie upload'
);

select * from finish();
rollback;
