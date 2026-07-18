-- The city of origin follows the same one-time choice rule as the country.

create or replace function private.protect_profile_geography()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() = 'service_role'
     or private.is_admin(auth.uid())
     or current_setting('maplov.phone_country_sync', true) = 'true'
     or current_setting('maplov.system_operation', true) = 'account_deletion' then
    return new;
  end if;

  if old.origin_country_name is not null
     and btrim(old.origin_country_name) <> ''
     and new.origin_country_name is distinct from old.origin_country_name then
    raise exception 'Country of origin can only be chosen once';
  end if;

  if old.origin_city is not null
     and btrim(old.origin_city) <> ''
     and new.origin_city is distinct from old.origin_city then
    raise exception 'City of origin can only be chosen once';
  end if;

  if new.country_name is distinct from old.country_name
     or new.residence_country_name is distinct from old.residence_country_name
     or new.country_code is distinct from old.country_code then
    raise exception 'Residence country is controlled by the verified phone number';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_protect_geography on public.profiles;
create trigger profiles_protect_geography
before update of country_name, residence_country_name, country_code,
  origin_country_name, origin_city on public.profiles
for each row execute function private.protect_profile_geography();

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
    residence_city,
    origin_country_name,
    origin_city
  ) values (
    new.id,
    supplied_name,
    private.safe_date(new.raw_user_meta_data ->> 'date_of_birth'),
    nullif(upper(btrim(new.raw_user_meta_data ->> 'country_code')), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'country_name'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'city'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'country_name'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'city'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'origin_country_name'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'origin_city'), '')
  );

  insert into public.dating_preferences (user_id) values (new.id);
  insert into public.notification_preferences (user_id) values (new.id);

  insert into public.user_legal_acceptances (
    user_id,
    document_key,
    document_version,
    accepted_at
  )
  select new.id, document.document_key, document.version, accepted_time
  from public.legal_documents document
  where document.is_required
    and accepted_documents ->> document.document_key = document.version;

  return new;
end;
$$;

comment on column public.profiles.origin_city is
  'Chosen once during account creation and immutable afterward.';
