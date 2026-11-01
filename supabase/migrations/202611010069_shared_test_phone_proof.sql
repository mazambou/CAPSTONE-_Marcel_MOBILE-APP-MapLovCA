-- A second account may prove control of a single allowlisted test phone
-- without assigning the same Supabase Auth phone identity twice.
begin;

create or replace function private.has_verified_account_phone(owner_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from auth.users as account
    where account.id = owner_user
      and (
        account.phone_confirmed_at is not null
        or (
          account.raw_app_meta_data ->> 'maplov_test_duplicate' = 'true'
          and account.raw_app_meta_data ->> 'maplov_test_phone_verified' = 'true'
          and account.raw_app_meta_data ->> 'maplov_contact_phone' =
              account.raw_user_meta_data ->> 'phone_number'
        )
        or (
          account.raw_app_meta_data ->> 'maplov_shared_test_phone_verified' = 'true'
          and account.raw_app_meta_data ->> 'maplov_shared_test_phone' =
              account.raw_user_meta_data ->> 'phone_number'
        )
      )
  );
$$;
revoke all on function private.has_verified_account_phone(uuid)
  from public, anon, authenticated;

commit;
