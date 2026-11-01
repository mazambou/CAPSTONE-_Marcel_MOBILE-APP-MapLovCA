-- Supabase stores auth.users.phone without the leading '+' used by E.164 input.
-- Detect a number already linked to another account before sending an SMS.
begin;

create or replace function public.find_pending_registration_for_sms(
  email_value text, phone_value text
)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select account.id
  from auth.users as account
  where auth.role() = 'service_role'
    and account.email = lower(trim(email_value))
    and account.raw_user_meta_data ->> 'phone_number' = phone_value
    and account.email_confirmed_at is null
    and account.phone_confirmed_at is null
    and account.deleted_at is null
  limit 1;
$$;

revoke all on function public.find_pending_registration_for_sms(text, text)
  from public, anon, authenticated;
grant execute on function public.find_pending_registration_for_sms(text, text)
  to service_role;

create or replace function public.registration_sms_phone_linked_elsewhere(
  owner_user uuid, phone_value text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.role() = 'service_role'
    and owner_user is not null
    and phone_value ~ '^[+][1-9][0-9]{7,14}$'
    and exists (
      select 1 from auth.users as other_account
      where other_account.id <> owner_user
        and other_account.phone is not null
        and regexp_replace(other_account.phone, '[^0-9]', '', 'g') =
          substring(phone_value from 2)
    );
$$;

revoke all on function public.registration_sms_phone_linked_elsewhere(uuid, text)
  from public, anon, authenticated;
grant execute on function public.registration_sms_phone_linked_elsewhere(uuid, text)
  to service_role;

commit;
