-- Versioned signup consent and separate residence/origin geography.

alter table public.profiles
  add column if not exists residence_country_name text,
  add column if not exists residence_city text,
  add column if not exists origin_country_name text,
  add column if not exists origin_city text;

update public.profiles
set residence_country_name = coalesce(residence_country_name, country_name),
    residence_city = coalesce(residence_city, city)
where residence_country_name is null or residence_city is null;

alter table public.dating_preferences
  add column if not exists origin_country_names text[] not null default '{}',
  add column if not exists origin_cities text[] not null default '{}';

create table if not exists public.legal_documents (
  document_key text not null,
  version text not null,
  title text not null,
  effective_at timestamptz not null,
  is_required boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (document_key, version)
);

create table if not exists public.user_legal_acceptances (
  user_id uuid not null references public.profiles(id) on delete cascade,
  document_key text not null,
  document_version text not null,
  accepted_at timestamptz not null,
  recorded_at timestamptz not null default now(),
  primary key (user_id, document_key, document_version),
  foreign key (document_key, document_version)
    references public.legal_documents(document_key, version)
);

insert into public.legal_documents
  (document_key, version, title, effective_at, is_required)
values
  ('terms_of_use', '2026-07-16', 'Terms of Use', '2026-07-16T00:00:00Z', true),
  ('privacy_policy', '2026-07-16', 'Privacy Policy', '2026-07-16T00:00:00Z', true),
  ('community_guidelines', '2026-07-16', 'Community Guidelines', '2026-07-16T00:00:00Z', true),
  ('adult_eligibility', '2026-07-16', 'Adult eligibility rules', '2026-07-16T00:00:00Z', true),
  ('content_and_safety_rules', '2026-07-16', 'Content, photo, reporting and safety rules', '2026-07-16T00:00:00Z', true)
on conflict (document_key, version) do update set
  title = excluded.title,
  effective_at = excluded.effective_at,
  is_required = excluded.is_required;

alter table public.legal_documents enable row level security;
alter table public.user_legal_acceptances enable row level security;

create policy legal_documents_authenticated_read
on public.legal_documents for select to authenticated
using (true);

create policy legal_acceptances_owner_or_admin_read
on public.user_legal_acceptances for select to authenticated
using (user_id = auth.uid() or private.is_admin());

grant select on public.legal_documents to authenticated;
grant select on public.user_legal_acceptances to authenticated;
revoke insert, update, delete on public.legal_documents from authenticated;
revoke insert, update, delete on public.user_legal_acceptances from authenticated;

create or replace function private.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  supplied_name text;
  accepted_documents jsonb := coalesce(
    new.raw_user_meta_data -> 'accepted_legal_documents',
    '{}'::jsonb
  );
  accepted_time timestamptz := coalesce(
    nullif(new.raw_user_meta_data ->> 'legal_accepted_at', '')::timestamptz,
    now()
  );
begin
  supplied_name := coalesce(
    nullif(btrim(new.raw_user_meta_data ->> 'first_name'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'name'), '')
  );

  insert into public.profiles (
    id,
    first_name,
    date_of_birth,
    country_code,
    country_name,
    city,
    residence_country_name,
    residence_city
  ) values (
    new.id,
    supplied_name,
    private.safe_date(new.raw_user_meta_data ->> 'date_of_birth'),
    nullif(upper(btrim(new.raw_user_meta_data ->> 'country_code')), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'country_name'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'city'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'country_name'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'city'), '')
  );

  insert into public.dating_preferences (user_id) values (new.id);
  insert into public.notification_preferences (user_id) values (new.id);

  insert into public.user_legal_acceptances (
    user_id,
    document_key,
    document_version,
    accepted_at
  )
  select new.id, d.document_key, d.version, accepted_time
  from public.legal_documents d
  where d.is_required
    and accepted_documents ->> d.document_key = d.version;

  return new;
end;
$$;

create index if not exists profiles_residence_lookup_idx
  on public.profiles(residence_country_name, residence_city)
  where status = 'active' and is_discoverable;

create index if not exists profiles_origin_lookup_idx
  on public.profiles(origin_country_name, origin_city)
  where status = 'active' and is_discoverable;

comment on column public.profiles.country_name is
  'Backward-compatible alias of residence_country_name.';
comment on column public.profiles.city is
  'Backward-compatible alias of residence_city.';
