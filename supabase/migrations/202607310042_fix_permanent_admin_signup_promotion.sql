-- Allow only the trusted Auth trigger to pass the existing role guard while
-- promoting a protected owner email after signup.

begin;

create or replace function private.promote_permanent_admin()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1
    from private.permanent_admin_emails as protected
    where protected.email = lower(new.email)
  ) then
    perform set_config('maplov.system_operation', 'account_deletion', true);
    update public.profiles
    set role = 'admin', status = 'active', updated_at = now()
    where id = new.id;
  end if;
  return new;
end;
$$;

commit;
