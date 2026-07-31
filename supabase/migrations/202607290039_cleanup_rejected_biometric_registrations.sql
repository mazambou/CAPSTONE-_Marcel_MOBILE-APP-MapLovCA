-- Rejected duplicate registrations are provisional accounts, not members.
-- Remove them promptly and prevent a registered account from uploading a
-- second private reference selfie.

begin;

create or replace function private.can_upload_registration_selfie(
  owner_user uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and auth.uid() = owner_user
    and exists (
      select 1
      from public.profiles profile
      where profile.id = owner_user
        and profile.status = 'active'
        and profile.profile_completed_at is null
    )
    and not exists (
      select 1
      from public.face_references reference
      where reference.user_id = owner_user
    );
$$;

revoke execute on function private.can_upload_registration_selfie(uuid)
  from public, anon, authenticated;
grant execute on function private.can_upload_registration_selfie(uuid)
  to authenticated;

drop policy if exists identity_selfies_owner_insert on storage.objects;
create policy identity_selfies_owner_insert
on storage.objects for insert to authenticated
with check (
  bucket_id = 'identity-selfies'
  and private.safe_uuid((storage.foldername(name))[1]) = auth.uid()
  and private.can_upload_registration_selfie(auth.uid())
);

create or replace function public.cleanup_rejected_duplicate_registrations(
  batch_size integer default 100
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  item record;
  processed integer := 0;
begin
  if auth.uid() is not null and auth.role() <> 'service_role' then
    raise exception 'Service role required';
  end if;

  for item in
    select profile.id
    from public.profiles profile
    where profile.status = 'suspended'
      and profile.profile_completed_at is null
      and not exists (
        select 1
        from public.face_references reference
        where reference.user_id = profile.id
      )
      and exists (
        select 1
        from public.duplicate_account_checks duplicate_check
        where duplicate_check.candidate_user_id = profile.id
          and duplicate_check.status = 'blocked'
      )
    order by profile.created_at
    for update skip locked
    limit greatest(1, least(batch_size, 500))
  loop
    perform set_config('maplov.system_operation', 'account_deletion', true);

    delete from auth.users where id = item.id;
    processed := processed + 1;
  end loop;

  return processed;
end;
$$;

revoke execute on function
  public.cleanup_rejected_duplicate_registrations(integer)
  from public, anon, authenticated;
grant execute on function
  public.cleanup_rejected_duplicate_registrations(integer)
  to service_role;

comment on function public.cleanup_rejected_duplicate_registrations(integer) is
  'Permanently removes incomplete provisional auth accounts rejected by biometric duplicate-account detection.';

-- Remove provisional rows left by the previous implementation.
select public.cleanup_rejected_duplicate_registrations(500);

do $$
begin
  perform cron.unschedule(jobid)
  from cron.job
  where jobname = 'maplov-rejected-registration-cleanup';

  perform cron.schedule(
    'maplov-rejected-registration-cleanup',
    '*/15 * * * *',
    'select public.cleanup_rejected_duplicate_registrations(100)'
  );
end;
$$;

commit;
