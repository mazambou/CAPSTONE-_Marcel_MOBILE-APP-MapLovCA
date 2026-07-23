begin;

create extension if not exists pgtap with schema extensions;
select plan(12);

select has_table('public', 'face_references',
  'private reference selfie metadata is stored');
select has_table('public', 'profile_photo_face_checks',
  'face comparison decisions are audited');
select has_column('public', 'face_references', 'consent_version',
  'biometric consent version is recorded');
select has_column('public', 'face_references', 'consented_at',
  'biometric consent time is recorded');
select has_column('public', 'profile_photo_face_checks', 'check_type',
  'reference enrollment and profile comparisons are distinguished');
select has_function('public', 'has_my_face_reference', array[]::text[],
  'users can query only their own enrollment status');
select has_function(
  'public',
  'register_verified_profile_photo',
  array['uuid', 'text', 'numeric', 'numeric', 'text'],
  'trusted verification registers accepted photos atomically'
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
  not has_table_privilege('authenticated', 'public.profile_photos', 'insert'),
  'authenticated users cannot bypass server-side face verification'
);

select * from finish();
rollback;
