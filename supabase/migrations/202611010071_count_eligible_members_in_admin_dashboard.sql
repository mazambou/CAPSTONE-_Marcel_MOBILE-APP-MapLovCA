-- Count members who have finished registration and can open other profiles.
-- Administrators, incomplete registrations, suspended accounts and users
-- awaiting confirmation of their contact email are not active members.
create or replace function public.admin_dashboard_statistics()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.is_admin(auth.uid()) then raise exception 'Admin required'; end if;
  return jsonb_build_object(
    'users', (
      select count(*)
      from public.profiles as profile
      join auth.users as account on account.id = profile.id
      where profile.role = 'user'
        and profile.status = 'active'
        and profile.profile_completed_at is not null
        and case
          when coalesce(account.raw_app_meta_data->>'maplov_contact_email', '') <> ''
            then account.raw_app_meta_data->>'maplov_contact_email_verified' = 'true'
          else account.email_confirmed_at is not null
        end
    ),
    'discoverable_profiles', (
      select count(*) from public.profiles
      where status = 'active'
        and profile_completed_at is not null
        and is_discoverable
    ),
    'photos', (select count(*) from public.profile_photos),
    'open_reports', (select count(*) from public.reports where status in ('open', 'under_review')),
    'suspensions', (select count(*) from public.profiles where status in ('suspended', 'banned')),
    'active_subscriptions', (select count(*) from public.subscriptions where is_current and status in ('active', 'cancelled') and tier <> 'free' and (current_period_end is null or current_period_end > now())),
    'payments', (select count(*) from public.payment_transactions),
    'pending_recoveries', (select count(*) from public.account_deletion_requests where status in ('pending', 'processing'))
  );
end;
$$;

comment on function public.admin_dashboard_statistics() is
  'Dashboard users count includes active, registration-complete members whose contact email is verified; administrators and incomplete accounts are excluded.';
