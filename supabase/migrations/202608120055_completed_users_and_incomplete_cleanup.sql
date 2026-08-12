-- Count only completed MapLov members and erase abandoned registrations after
-- 72 hours through the existing physical account-deletion worker.

begin;

create or replace function public.has_completed_my_registration_gate()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and exists (
      select 1 from public.profiles
      where id = auth.uid() and date_of_birth is not null
    )
    and not exists (
      select 1
      from public.legal_documents as document
      where document.is_required
        and not exists (
          select 1
          from public.user_legal_acceptances as acceptance
          where acceptance.user_id = auth.uid()
            and acceptance.document_key = document.document_key
            and acceptance.document_version = document.version
        )
    );
$$;

create or replace function public.complete_my_social_registration_gate(
  date_of_birth_value date,
  accepted_documents_value jsonb,
  accepted_at_value timestamptz
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not exists (
    select 1
    from auth.identities as identity
    where identity.user_id = auth.uid()
      and identity.provider in ('google', 'apple')
  ) then
    raise exception 'A Google or Apple account is required';
  end if;
  if date_of_birth_value is null
     or date_of_birth_value > (current_date - interval '18 years')::date then
    raise exception 'MapLov is restricted to adults aged 18 or older';
  end if;
  if accepted_at_value is null or accepted_at_value > now() + interval '5 minutes' then
    raise exception 'A valid acceptance time is required';
  end if;
  if exists (
    select 1
    from public.legal_documents as document
    where document.is_required
      and (accepted_documents_value ->> document.document_key)
          is distinct from document.version
  ) then
    raise exception 'Every current required agreement must be accepted';
  end if;

  update public.profiles
  set date_of_birth = date_of_birth_value,
      updated_at = now()
  where id = auth.uid()
    and date_of_birth is null;

  if not exists (
    select 1
    from public.profiles as profile
    where profile.id = auth.uid()
      and profile.date_of_birth = date_of_birth_value
  ) then
    raise exception 'The date of birth does not match this account';
  end if;

  insert into public.user_legal_acceptances(
    user_id, document_key, document_version, accepted_at
  )
  select auth.uid(), document.document_key, document.version,
         accepted_at_value
  from public.legal_documents as document
  where document.is_required
    and accepted_documents_value ->> document.document_key = document.version
  on conflict (user_id, document_key, document_version) do nothing;
end;
$$;

revoke execute on function public.has_completed_my_registration_gate()
  from public, anon;
revoke execute on function public.complete_my_social_registration_gate(
  date, jsonb, timestamptz
) from public, anon;
grant execute on function public.has_completed_my_registration_gate()
  to authenticated;
grant execute on function public.complete_my_social_registration_gate(
  date, jsonb, timestamptz
) to authenticated;

alter table public.account_deletion_requests
  drop constraint if exists account_deletion_request_origin_check;
alter table public.account_deletion_requests
  add constraint account_deletion_request_origin_check check (
    request_origin in ('self', 'admin', 'incomplete_registration')
  );

create or replace function public.enqueue_stale_incomplete_registrations()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  queued_count integer;
begin
  if auth.role() <> 'service_role' then
    raise exception 'Service role required';
  end if;

  with stale as (
    select profile.id
    from public.profiles as profile
    where profile.role = 'user'
      and profile.profile_completed_at is null
      and profile.created_at <= now() - interval '72 hours'
      and profile.status <> 'deleted'
      and not exists (
        select 1
        from public.account_deletion_requests as existing_request
        where existing_request.user_id = profile.id
          and existing_request.status in ('pending', 'processing')
      )
    for update skip locked
    limit 100
  ), queued as (
    insert into public.account_deletion_requests (
      user_id, requested_by, request_origin, status, requested_at,
      scheduled_for, cancelled_at, processed_at, reason, attempt_count,
      last_attempt_at
    )
    select
      stale.id, null, 'incomplete_registration', 'pending', now(), now(),
      null, null, 'Registration incomplete after 72 hours', 0, null
    from stale
    on conflict (user_id) do update set
      requested_by = null,
      request_origin = 'incomplete_registration',
      status = 'pending',
      requested_at = now(),
      scheduled_for = now(),
      cancelled_at = null,
      processed_at = null,
      reason = 'Registration incomplete after 72 hours',
      attempt_count = 0,
      last_attempt_at = null
    returning user_id
  )
  update public.profiles as profile
  set status = 'deleted',
      is_discoverable = false,
      show_online_status = false,
      updated_at = now()
  from queued
  where profile.id = queued.user_id;
  get diagnostics queued_count = row_count;
  return queued_count;
end;
$$;

revoke execute on function public.enqueue_stale_incomplete_registrations()
  from public, anon, authenticated;
grant execute on function public.enqueue_stale_incomplete_registrations()
  to service_role;

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
      from public.profiles
      where profile_completed_at is not null
        and status <> 'deleted'
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

-- The UI already reserves invisible mode for VIP. Enforce the same rule at
-- the database boundary so Plus clients cannot bypass it with a direct update.
create or replace function private.enforce_invisible_mode_entitlement()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() = 'service_role' or private.is_admin(auth.uid())
     or current_setting('maplov.system_operation', true) in (
       'account_deletion', 'account_recovery'
     ) then
    return new;
  end if;
  if old.is_discoverable and not new.is_discoverable
     and new.profile_completed_at is not null
     and private.current_subscription_tier(auth.uid()) not in ('elite', 'vip') then
    raise exception 'Invisible navigation requires Premium VIP';
  end if;
  return new;
end;
$$;

comment on function public.enqueue_stale_incomplete_registrations() is
  'Queues non-member registrations that remain incomplete after 72 hours for the existing idempotent physical erasure worker.';

commit;
