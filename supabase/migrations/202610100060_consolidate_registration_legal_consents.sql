-- Consolidate registration into the three legal documents supplied for launch.
-- Age eligibility remains enforced independently from consent by the existing
-- profiles_enforce_adult trigger.

begin;

update public.legal_documents
set is_required = false
where is_required
  and document_key in (
    'terms_of_use',
    'privacy_policy',
    'community_guidelines',
    'adult_eligibility',
    'content_and_safety_rules'
  );

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
    '1.1-2026-09-24',
    'MapLov Terms of Use',
    '2026-09-24T00:00:00Z',
    true
  ),
  (
    'privacy_policy',
    '1.0-2026-09-30',
    'MapLov Privacy Policy',
    '2026-09-30T00:00:00Z',
    true
  ),
  (
    'community_guidelines',
    '1.0-2026-09-30',
    'MapLov Community and Safety Guidelines',
    '2026-09-30T00:00:00Z',
    true
  )
on conflict (document_key, version) do update set
  title = excluded.title,
  effective_at = excluded.effective_at,
  is_required = excluded.is_required;

commit;
