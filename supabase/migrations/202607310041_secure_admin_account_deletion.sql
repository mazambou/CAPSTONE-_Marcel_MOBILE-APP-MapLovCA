-- Permanent owner administration and physical account erasure.
--
-- Storage objects must be removed by the Storage API. The database only
-- prepares/claims deletions; the admin-delete-account Edge Function performs
-- the file removal and permanent Auth deletion.

begin;

create extension if not exists pg_net with schema extensions;
create extension if not exists supabase_vault with schema vault;

create table if not exists private.permanent_admin_emails (
  email text primary key,
  created_at timestamptz not null default now(),
  constraint permanent_admin_email_normalized
    check (email = lower(btrim(email)) and position('@' in email) > 1)
);

revoke all on private.permanent_admin_emails
  from public, anon, authenticated, service_role;

insert into private.permanent_admin_emails(email)
values ('mazambou@gmail.com')
on conflict (email) do nothing;

-- Promote the existing owner account now. The second trigger below also
-- promotes a future Auth identity created with this protected email.
select set_config('maplov.system_operation', 'account_deletion', true);
update public.profiles as profile
set role = 'admin',
    status = 'active',
    updated_at = now()
from auth.users as auth_user
where profile.id = auth_user.id
  and lower(auth_user.email) = 'mazambou@gmail.com';

create or replace function private.is_permanent_admin_user(check_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from auth.users as auth_user
    join private.permanent_admin_emails as protected
      on protected.email = lower(auth_user.email)
    where auth_user.id = check_user
  );
$$;

revoke execute on function private.is_permanent_admin_user(uuid)
  from public, anon, authenticated, service_role;

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
    update public.profiles
    set role = 'admin', status = 'active', updated_at = now()
    where id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists zz_promote_permanent_admin on auth.users;
create trigger zz_promote_permanent_admin
after insert or update of email on auth.users
for each row execute function private.promote_permanent_admin();

create or replace function private.protect_permanent_admin()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if private.is_permanent_admin_user(old.id)
     and (new.role <> 'admin' or new.status <> 'active') then
    raise exception 'The permanent owner administrator cannot be demoted or disabled';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_protect_permanent_admin on public.profiles;
create trigger profiles_protect_permanent_admin
before update of role, status on public.profiles
for each row execute function private.protect_permanent_admin();

alter table public.account_deletion_requests
  add column if not exists requested_by uuid
    references public.profiles(id) on delete set null,
  add column if not exists request_origin text not null default 'self',
  add column if not exists reason text,
  add column if not exists attempt_count integer not null default 0,
  add column if not exists last_attempt_at timestamptz;

alter table public.account_deletion_requests
  drop constraint if exists account_deletion_request_origin_check;
alter table public.account_deletion_requests
  add constraint account_deletion_request_origin_check
  check (request_origin in ('self', 'admin'));

alter table public.account_deletion_requests
  drop constraint if exists account_deletion_reason_length;
alter table public.account_deletion_requests
  add constraint account_deletion_reason_length
  check (reason is null or char_length(reason) <= 1000);

create or replace function public.request_account_deletion()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if private.is_permanent_admin_user(auth.uid()) then
    raise exception 'The permanent owner administrator account cannot be deleted';
  end if;

  insert into public.account_deletion_requests (
    user_id, requested_by, request_origin, status, requested_at,
    scheduled_for, cancelled_at, processed_at, reason, attempt_count,
    last_attempt_at
  ) values (
    auth.uid(), auth.uid(), 'self', 'pending', now(),
    now() + interval '30 days', null, null, null, 0, null
  )
  on conflict (user_id) do update set
    requested_by = excluded.requested_by,
    request_origin = excluded.request_origin,
    status = 'pending',
    requested_at = now(),
    scheduled_for = now() + interval '30 days',
    cancelled_at = null,
    processed_at = null,
    reason = null,
    attempt_count = 0,
    last_attempt_at = null;

  perform set_config('maplov.system_operation', 'account_deletion', true);
  update public.profiles
  set status = 'deleted',
      is_discoverable = false,
      show_online_status = false,
      updated_at = now()
  where id = auth.uid();

  update public.garden_access_requests as request
  set status = 'revoked', revoked_at = now()
  where request.status = 'approved'
    and (
      request.requester_id = auth.uid()
      or exists (
        select 1
        from public.garden_albums as album
        where album.id = request.album_id
          and album.owner_id = auth.uid()
      )
    );
end;
$$;

revoke execute on function public.request_account_deletion()
  from public, anon;
grant execute on function public.request_account_deletion()
  to authenticated;

create or replace function public.admin_schedule_account_deletion(
  user_id_value uuid,
  reason_value text default null
)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_role text;
  deletion_time timestamptz := now() + interval '30 days';
begin
  if not private.is_full_admin(auth.uid()) then
    raise exception 'Full administrator access required';
  end if;
  if user_id_value = auth.uid() then
    raise exception 'You cannot delete your own administrator account';
  end if;

  select profile.role::text into target_role
  from public.profiles as profile
  where profile.id = user_id_value
  for update;
  if target_role is null then
    raise exception 'Account not found';
  end if;
  if target_role in ('admin', 'moderator')
     or private.is_permanent_admin_user(user_id_value) then
    raise exception 'A privileged account cannot be deleted here';
  end if;

  insert into public.account_deletion_requests (
    user_id, requested_by, request_origin, status, requested_at,
    scheduled_for, cancelled_at, processed_at, reason, attempt_count,
    last_attempt_at
  ) values (
    user_id_value, auth.uid(), 'admin', 'pending', now(),
    deletion_time, null, null, nullif(btrim(reason_value), ''), 0, null
  )
  on conflict (user_id) do update set
    requested_by = excluded.requested_by,
    request_origin = excluded.request_origin,
    status = 'pending',
    requested_at = now(),
    scheduled_for = deletion_time,
    cancelled_at = null,
    processed_at = null,
    reason = excluded.reason,
    attempt_count = 0,
    last_attempt_at = null;

  perform set_config('maplov.system_operation', 'account_deletion', true);
  update public.profiles
  set status = 'deleted',
      is_discoverable = false,
      show_online_status = false,
      updated_at = now()
  where id = user_id_value;

  update public.garden_access_requests as request
  set status = 'revoked', revoked_at = now()
  where request.status = 'approved'
    and (
      request.requester_id = user_id_value
      or exists (
        select 1
        from public.garden_albums as album
        where album.id = request.album_id
          and album.owner_id = user_id_value
      )
    );

  insert into public.admin_actions(
    admin_id, action, target_type, target_id, reason, metadata
  ) values (
    auth.uid(), 'account_deletion_scheduled', 'user', user_id_value,
    nullif(btrim(reason_value), ''),
    jsonb_build_object('scheduled_for', deletion_time)
  );
  return deletion_time;
end;
$$;

create or replace function public.admin_prepare_immediate_account_deletion(
  user_id_value uuid,
  reason_value text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_role text;
begin
  if not private.is_full_admin(auth.uid()) then
    raise exception 'Full administrator access required';
  end if;
  if user_id_value = auth.uid() then
    raise exception 'You cannot delete your own administrator account';
  end if;

  select profile.role::text into target_role
  from public.profiles as profile
  where profile.id = user_id_value
  for update;
  if target_role is null then
    raise exception 'Account not found';
  end if;
  if target_role in ('admin', 'moderator')
     or private.is_permanent_admin_user(user_id_value) then
    raise exception 'A privileged account cannot be deleted here';
  end if;

  insert into public.account_deletion_requests (
    user_id, requested_by, request_origin, status, requested_at,
    scheduled_for, cancelled_at, processed_at, reason, attempt_count,
    last_attempt_at
  ) values (
    user_id_value, auth.uid(), 'admin', 'processing', now(), now(),
    null, null, nullif(btrim(reason_value), ''), 1, now()
  )
  on conflict (user_id) do update set
    requested_by = excluded.requested_by,
    request_origin = excluded.request_origin,
    status = 'processing',
    requested_at = now(),
    scheduled_for = now(),
    cancelled_at = null,
    processed_at = null,
    reason = excluded.reason,
    attempt_count = public.account_deletion_requests.attempt_count + 1,
    last_attempt_at = now();

  perform set_config('maplov.system_operation', 'account_deletion', true);
  update public.profiles
  set status = 'deleted',
      is_discoverable = false,
      show_online_status = false,
      updated_at = now()
  where id = user_id_value;

  update public.garden_access_requests as request
  set status = 'revoked', revoked_at = now()
  where request.status = 'approved'
    and (
      request.requester_id = user_id_value
      or exists (
        select 1
        from public.garden_albums as album
        where album.id = request.album_id
          and album.owner_id = user_id_value
      )
    );

  insert into public.admin_actions(
    admin_id, action, target_type, target_id, reason, metadata
  ) values (
    auth.uid(), 'account_deletion_started', 'user', user_id_value,
    nullif(btrim(reason_value), ''),
    jsonb_build_object('mode', 'immediate')
  );
end;
$$;

revoke execute on function public.admin_schedule_account_deletion(uuid, text)
  from public, anon;
revoke execute on function public.admin_prepare_immediate_account_deletion(uuid, text)
  from public, anon;
grant execute on function public.admin_schedule_account_deletion(uuid, text)
  to authenticated;
grant execute on function public.admin_prepare_immediate_account_deletion(uuid, text)
  to authenticated;

create or replace function public.claim_due_account_deletions(
  batch_size_value integer default 25
)
returns table(
  user_id uuid,
  requested_by uuid,
  request_origin text,
  reason text
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() <> 'service_role' then
    raise exception 'Service role required';
  end if;

  return query
  with due as (
    select request.id
    from public.account_deletion_requests as request
    where request.scheduled_for <= now()
      and (
        request.status = 'pending'
        or (
          request.status = 'processing'
          and (
            request.last_attempt_at is null
            or request.last_attempt_at <= now() - interval '15 minutes'
          )
        )
      )
    order by request.scheduled_for
    for update skip locked
    limit greatest(1, least(batch_size_value, 100))
  )
  update public.account_deletion_requests as request
  set status = 'processing',
      last_attempt_at = now(),
      attempt_count = request.attempt_count + 1
  from due
  where request.id = due.id
  returning request.user_id, request.requested_by,
            request.request_origin, request.reason;
end;
$$;

revoke execute on function public.claim_due_account_deletions(integer)
  from public, anon, authenticated;
grant execute on function public.claim_due_account_deletions(integer)
  to service_role;

-- Remove references whose generic UUID/JSON columns cannot have foreign-key
-- cascades. All ordinary account-owned rows then disappear with auth.users.
create or replace function public.purge_account_relations_before_auth_delete(
  user_id_value uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() <> 'service_role' then
    raise exception 'Service role required';
  end if;
  if private.is_permanent_admin_user(user_id_value) then
    raise exception 'The permanent owner administrator cannot be deleted';
  end if;
  if not exists (
    select 1 from public.profiles where id = user_id_value
  ) then
    raise exception 'Account not found';
  end if;

  delete from public.admin_actions as action
  where action.admin_id = user_id_value
     or action.target_id = user_id_value
     or exists (
       select 1 from public.profile_photos as photo
       where photo.user_id = user_id_value
         and action.target_id = photo.id
     )
     or exists (
       select 1 from public.posts as post
       where post.author_id = user_id_value
         and action.target_id = post.id
     )
     or exists (
       select 1 from public.post_comments as comment
       where comment.author_id = user_id_value
         and action.target_id = comment.id
     )
     or exists (
       select 1 from public.messages as message
       where message.sender_id = user_id_value
         and action.target_id = message.id
     )
     or exists (
       select 1 from public.reports as report
       where action.target_id = report.id
         and (
           report.reporter_id = user_id_value
           or (report.target_type::text = 'user'
               and report.target_id = user_id_value)
           or (report.target_type::text = 'photo' and exists (
             select 1 from public.profile_photos as photo
             where photo.id = report.target_id
               and photo.user_id = user_id_value
           ))
           or (report.target_type::text = 'post' and exists (
             select 1 from public.posts as post
             where post.id = report.target_id
               and post.author_id = user_id_value
           ))
           or (report.target_type::text = 'comment' and exists (
             select 1 from public.post_comments as comment
             where comment.id = report.target_id
               and comment.author_id = user_id_value
           ))
         )
     );

  delete from public.notifications as notification
  where notification.actor_id = user_id_value
     or notification.entity_id = user_id_value
     or notification.data::text like '%' || user_id_value::text || '%'
     or exists (
       select 1 from public.profile_photos as photo
       where photo.user_id = user_id_value
         and notification.entity_id = photo.id
     )
     or exists (
       select 1 from public.posts as post
       where post.author_id = user_id_value
         and notification.entity_id = post.id
     )
     or exists (
       select 1 from public.post_comments as comment
       where comment.author_id = user_id_value
         and notification.entity_id = comment.id
     )
     or exists (
       select 1 from public.messages as message
       where message.sender_id = user_id_value
         and notification.entity_id = message.id
     );

  delete from public.store_billing_events as event
  where event.payload::text like '%' || user_id_value::text || '%'
     or exists (
       select 1 from public.subscriptions as subscription
       where subscription.user_id = user_id_value
         and subscription.external_subscription_id is not null
         and subscription.external_subscription_id =
             event.external_subscription_id
     );

  delete from public.reports as report
  where report.reporter_id = user_id_value
     or (report.target_type::text = 'user'
         and report.target_id = user_id_value)
     or (report.target_type::text = 'photo' and exists (
       select 1 from public.profile_photos as photo
       where photo.id = report.target_id
         and photo.user_id = user_id_value
     ))
     or (report.target_type::text = 'post' and exists (
       select 1 from public.posts as post
       where post.id = report.target_id
         and post.author_id = user_id_value
     ))
     or (report.target_type::text = 'comment' and exists (
       select 1 from public.post_comments as comment
       where comment.id = report.target_id
         and comment.author_id = user_id_value
     ));
end;
$$;

revoke execute on function public.purge_account_relations_before_auth_delete(uuid)
  from public, anon, authenticated;
grant execute on function public.purge_account_relations_before_auth_delete(uuid)
  to service_role;

-- Disable the former SQL implementation so it can never orphan physical
-- objects by deleting storage.objects metadata directly.
create or replace function public.process_due_account_deletions(
  batch_size integer default 100
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() <> 'service_role' then
    raise exception 'Service role required';
  end if;
  return 0;
end;
$$;

revoke execute on function public.process_due_account_deletions(integer)
  from public, anon, authenticated;
grant execute on function public.process_due_account_deletions(integer)
  to service_role;

do $$
begin
  perform cron.unschedule(jobid)
  from cron.job
  where jobname = 'maplov-account-erasure';

  perform cron.schedule(
    'maplov-account-erasure',
    '17 * * * *',
    $job$
      select net.http_post(
        url := 'https://heqkgexzlhdnmrkuikle.supabase.co/functions/v1/admin-delete-account',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'X-MapLov-Cron-Secret',
          coalesce((
            select decrypted_secret
            from vault.decrypted_secrets
            where name = 'maplov_account_deletion_cron_secret'
            limit 1
          ), '')
        ),
        body := '{"action":"process_due"}'::jsonb
      )
    $job$
  );
end;
$$;

commit;
