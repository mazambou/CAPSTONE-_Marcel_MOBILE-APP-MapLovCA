-- Release hardening: privacy exports, final account erasure and report abuse controls.
create table if not exists public.data_export_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  requested_at timestamptz not null default now(),
  completed_at timestamptz,
  status text not null default 'processing'
    check (status in ('processing', 'completed', 'failed'))
);

alter table public.data_export_requests enable row level security;
create policy data_export_owner_read on public.data_export_requests
for select to authenticated using (user_id = auth.uid());
grant select on public.data_export_requests to authenticated;

create or replace function public.export_my_data()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  request_id uuid;
  result jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  insert into public.data_export_requests(user_id)
  values (auth.uid()) returning id into request_id;

  select jsonb_build_object(
    'generated_at', now(),
    'profile', (select to_jsonb(p) from public.profiles p where p.id = auth.uid()),
    'dating_preferences', (select to_jsonb(d) from public.dating_preferences d where d.user_id = auth.uid()),
    'notification_preferences', (select to_jsonb(n) from public.notification_preferences n where n.user_id = auth.uid()),
    'photos', coalesce((select jsonb_agg(to_jsonb(x)) from public.profile_photos x where x.user_id = auth.uid()), '[]'::jsonb),
    'sent_messages', coalesce((select jsonb_agg(to_jsonb(x)) from public.messages x where x.sender_id = auth.uid()), '[]'::jsonb),
    'posts', coalesce((select jsonb_agg(to_jsonb(x)) from public.posts x where x.author_id = auth.uid()), '[]'::jsonb),
    'post_comments', coalesce((select jsonb_agg(to_jsonb(x)) from public.post_comments x where x.author_id = auth.uid()), '[]'::jsonb),
    'reports_submitted', coalesce((select jsonb_agg(to_jsonb(x)) from public.reports x where x.reporter_id = auth.uid()), '[]'::jsonb),
    'blocks', coalesce((select jsonb_agg(to_jsonb(x)) from public.blocks x where x.blocker_id = auth.uid()), '[]'::jsonb),
    'subscriptions', coalesce((select jsonb_agg(to_jsonb(x) - 'receipt_metadata') from public.subscriptions x where x.user_id = auth.uid()), '[]'::jsonb),
    'deletion_requests', coalesce((select jsonb_agg(to_jsonb(x)) from public.account_deletion_requests x where x.user_id = auth.uid()), '[]'::jsonb)
  ) into result;

  update public.data_export_requests
  set status = 'completed', completed_at = now()
  where id = request_id;
  return result;
exception when others then
  update public.data_export_requests set status = 'failed' where id = request_id;
  raise;
end;
$$;

revoke execute on function public.export_my_data() from public, anon;
grant execute on function public.export_my_data() to authenticated;

create or replace function private.validate_report_submission()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  recent_count integer;
  target_exists boolean := false;
begin
  if new.reporter_id <> auth.uid() then raise exception 'Invalid reporter'; end if;
  if new.target_type = 'user' then
    select exists(select 1 from public.profiles where id = new.target_id) into target_exists;
  elsif new.target_type = 'post' then
    select exists(select 1 from public.posts where id = new.target_id) into target_exists;
  elsif new.target_type = 'comment' then
    select exists(select 1 from public.post_comments where id = new.target_id) into target_exists;
  elsif new.target_type = 'photo' then
    select exists(select 1 from public.profile_photos where id = new.target_id) into target_exists;
  end if;
  if not target_exists then raise exception 'Reported content is unavailable'; end if;
  if new.target_type = 'user' and new.target_id = auth.uid() then
    raise exception 'You cannot report your own account';
  end if;

  select count(*) into recent_count from public.reports
  where reporter_id = auth.uid() and created_at > now() - interval '24 hours';
  if recent_count >= 20 then raise exception 'Daily report limit reached'; end if;

  if exists (
    select 1 from public.reports
    where reporter_id = auth.uid() and target_type = new.target_type
      and target_id = new.target_id and status in ('open', 'under_review')
  ) then raise exception 'This content is already under review'; end if;
  return new;
end;
$$;

drop trigger if exists validate_report_submission on public.reports;
create trigger validate_report_submission
before insert on public.reports for each row
execute function private.validate_report_submission();

-- Called hourly by pg_cron. Requests remain reversible for 30 days, then the
-- authentication row and all FK-linked application data are permanently erased.
create or replace function public.process_due_account_deletions(batch_size integer default 100)
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
    select r.user_id from public.account_deletion_requests r
    where r.status = 'pending' and r.scheduled_for <= now()
    order by r.scheduled_for for update skip locked limit greatest(1, least(batch_size, 500))
  loop
    perform set_config('maplov.system_operation', 'account_deletion', true);
    delete from storage.objects
    where owner_id = item.user_id::text or name like item.user_id::text || '/%';
    delete from auth.users where id = item.user_id;
    processed := processed + 1;
  end loop;
  return processed;
end;
$$;

revoke execute on function public.process_due_account_deletions(integer) from public, anon, authenticated;
grant execute on function public.process_due_account_deletions(integer) to service_role;

create extension if not exists pg_cron with schema pg_catalog;
do $$
begin
  perform cron.unschedule(jobid) from cron.job where jobname = 'maplov-account-erasure';
  perform cron.schedule(
    'maplov-account-erasure',
    '17 * * * *',
    'select public.process_due_account_deletions(100)'
  );
end;
$$;
