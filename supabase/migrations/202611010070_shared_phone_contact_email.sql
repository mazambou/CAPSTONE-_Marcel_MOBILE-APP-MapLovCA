-- Keep the real email unverified while an allowlisted, SMS-verified account
-- uses an internal Auth email. Only server functions may look up the alias
-- or manage the one-time codes sent to the real email.
begin;

create or replace function public.find_pending_shared_phone_auth_email(
  contact_email text
)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case when count(*) = 1 then min(account.email) else null end
  from auth.users as account
  where auth.role() = 'service_role'
    and lower(account.raw_app_meta_data ->> 'maplov_contact_email') =
        lower(trim(contact_email))
    and account.raw_app_meta_data ->> 'maplov_shared_test_phone_verified' = 'true'
    and account.raw_app_meta_data ->> 'maplov_contact_email_verified' <> 'true'
    and account.email like 'shared-%@accounts.maplov.ca'
    and account.deleted_at is null;
$$;
revoke all on function public.find_pending_shared_phone_auth_email(text)
  from public, anon, authenticated;
grant execute on function public.find_pending_shared_phone_auth_email(text)
  to service_role;

create table if not exists private.shared_phone_contact_email_codes (
  user_id uuid primary key references auth.users(id) on delete cascade,
  salt text not null,
  code_hash text not null,
  expires_at timestamptz not null,
  sent_at timestamptz not null,
  window_started_at timestamptz not null,
  sends integer not null check (sends > 0),
  attempts integer not null default 0 check (attempts >= 0)
);
alter table private.shared_phone_contact_email_codes enable row level security;
revoke all on private.shared_phone_contact_email_codes
  from public, anon, authenticated;

create or replace function public.claim_shared_phone_contact_email_code(
  owner_user uuid, supplied_code text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  previous private.shared_phone_contact_email_codes%rowtype;
  checked_at timestamptz := now();
  new_salt text := pg_catalog.gen_random_uuid()::text;
begin
  if auth.role() <> 'service_role'
     or owner_user is null
     or supplied_code !~ '^[0-9]{8}$'
     or not exists (
       select 1 from auth.users as account
       where account.id = owner_user
         and account.email like 'shared-%@accounts.maplov.ca'
         and account.raw_app_meta_data ->> 'maplov_shared_test_phone_verified' = 'true'
         and account.raw_app_meta_data ->> 'maplov_contact_email_verified' <> 'true'
         and account.raw_app_meta_data ->> 'maplov_contact_email' ~
             '^[^@[:space:]]+@[^@[:space:]]+[.][^@[:space:]]+$'
     ) then
    return false;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtext(owner_user::text || ':contact_email')
  );
  select * into previous
  from private.shared_phone_contact_email_codes
  where user_id = owner_user
  for update;
  if found then
    if previous.sent_at > checked_at - interval '1 minute'
       or (
         previous.window_started_at > checked_at - interval '24 hours'
         and previous.sends >= 5
       ) then
      return false;
    end if;
  end if;

  insert into private.shared_phone_contact_email_codes (
    user_id, salt, code_hash, expires_at, sent_at,
    window_started_at, sends, attempts
  ) values (
    owner_user,
    new_salt,
    pg_catalog.encode(
      pg_catalog.sha256(pg_catalog.convert_to(new_salt || supplied_code, 'UTF8')),
      'hex'
    ),
    checked_at + interval '1 hour',
    checked_at,
    case when found and previous.window_started_at >
        checked_at - interval '24 hours'
      then previous.window_started_at else checked_at end,
    case when found and previous.window_started_at >
        checked_at - interval '24 hours'
      then previous.sends + 1 else 1 end,
    0
  )
  on conflict (user_id) do update set
    salt = excluded.salt,
    code_hash = excluded.code_hash,
    expires_at = excluded.expires_at,
    sent_at = excluded.sent_at,
    window_started_at = excluded.window_started_at,
    sends = excluded.sends,
    attempts = 0;
  return true;
end;
$$;
revoke all on function public.claim_shared_phone_contact_email_code(uuid, text)
  from public, anon, authenticated;
grant execute on function public.claim_shared_phone_contact_email_code(uuid, text)
  to service_role;

create or replace function public.check_shared_phone_contact_email_code(
  owner_user uuid, supplied_code text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  pending private.shared_phone_contact_email_codes%rowtype;
begin
  if auth.role() <> 'service_role'
     or owner_user is null
     or supplied_code !~ '^[0-9]{8}$' then
    return false;
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtext(owner_user::text || ':contact_email')
  );
  select * into pending
  from private.shared_phone_contact_email_codes
  where user_id = owner_user
  for update;
  if not found or pending.expires_at < now() or pending.attempts >= 5 then
    return false;
  end if;
  if pending.code_hash <> pg_catalog.encode(
    pg_catalog.sha256(
      pg_catalog.convert_to(pending.salt || supplied_code, 'UTF8')
    ),
    'hex'
  ) then
    update private.shared_phone_contact_email_codes
    set attempts = attempts + 1
    where user_id = owner_user;
    return false;
  end if;
  delete from private.shared_phone_contact_email_codes
  where user_id = owner_user;
  return true;
end;
$$;
revoke all on function public.check_shared_phone_contact_email_code(uuid, text)
  from public, anon, authenticated;
grant execute on function public.check_shared_phone_contact_email_code(uuid, text)
  to service_role;

commit;
