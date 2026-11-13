-- Keep a moderator's actual warning message separate from the ordinary,
-- dismissible notification feed. Only the recipient can read it, and only a
-- server function can acknowledge it.
create table public.admin_user_notices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  report_id uuid references public.reports(id) on delete set null,
  created_by uuid references public.profiles(id) on delete set null,
  body text not null check (char_length(btrim(body)) between 1 and 2000),
  created_at timestamptz not null default now(),
  acknowledged_at timestamptz
);
create index admin_user_notices_pending_idx
  on public.admin_user_notices(user_id, created_at)
  where acknowledged_at is null;
alter table public.admin_user_notices enable row level security;
create policy admin_user_notices_recipient_read
  on public.admin_user_notices for select to authenticated
  using (user_id = auth.uid());
grant select on public.admin_user_notices to authenticated;

create or replace function public.acknowledge_admin_user_notice(notice_id_value uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.admin_user_notices
  set acknowledged_at = now()
  where id = notice_id_value
    and user_id = auth.uid()
    and acknowledged_at is null;
  if not found then
    raise exception 'Notice unavailable';
  end if;
end;
$$;
revoke execute on function public.acknowledge_admin_user_notice(uuid)
  from public, anon;
grant execute on function public.acknowledge_admin_user_notice(uuid)
  to authenticated;

create or replace function public.admin_warn_reported_user(
  report_id_value uuid, notes_value text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_user uuid;
  warning_text text := nullif(btrim(notes_value), '');
begin
  if not private.is_admin(auth.uid()) then raise exception 'Admin required'; end if;
  if warning_text is null or char_length(warning_text) > 2000 then
    raise exception 'Warning message must contain 1 to 2000 characters';
  end if;
  select target_id into target_user from public.reports
  where id = report_id_value and target_type::text = 'user'
    and status in ('open', 'under_review')
  for update;
  if target_user is null then raise exception 'Report unavailable'; end if;
  if not exists(select 1 from public.profiles where id = target_user) then
    raise exception 'Reported account no longer exists';
  end if;

  insert into public.admin_user_notices(user_id, report_id, created_by, body)
  values (target_user, report_id_value, auth.uid(), warning_text);
  insert into public.notifications(
    user_id, actor_id, kind, title, body, entity_type, entity_id
  ) values (
    target_user, auth.uid(), 'system',
    'MapLov safety warning',
    'A moderator reviewed a report about your account. Please follow MapLov community rules.',
    'report', report_id_value
  );
  update public.reports
  set status = 'resolved', resolution_notes = warning_text,
      resolved_at = now(), updated_at = now()
  where id = report_id_value;
  insert into public.admin_actions(
    admin_id, action, target_type, target_id, reason
  ) values (
    auth.uid(), 'report_warning', 'user', target_user, warning_text
  );
end;
$$;
revoke execute on function public.admin_warn_reported_user(uuid,text)
  from public, anon;
grant execute on function public.admin_warn_reported_user(uuid,text)
  to authenticated;
