-- Version the original MapLov legal drafts without overwriting prior consent
-- evidence. Only the Terms and Privacy Policy changed at the signup gate.
insert into public.legal_documents (
  document_key,
  version,
  title,
  effective_at,
  is_required
)
values
  (
    'terms_of_use',
    '2026-07-30',
    'MapLov Terms of Use',
    '2026-07-30T00:00:00Z',
    true
  ),
  (
    'privacy_policy',
    '2026-07-30',
    'MapLov Privacy Policy',
    '2026-07-30T00:00:00Z',
    true
  ),
  (
    'cookie_policy',
    '2026-07-30',
    'MapLov Cookie and Similar Technologies Policy',
    '2026-07-30T00:00:00Z',
    false
  ),
  (
    'face_verification_notice',
    'face-verification-v3-global-dedup',
    'MapLov Face Verification Notice',
    '2026-07-30T00:00:00Z',
    false
  )
on conflict (document_key, version) do update set
  title = excluded.title,
  effective_at = excluded.effective_at,
  is_required = excluded.is_required;
