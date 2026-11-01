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
begin
  if not private.is_admin(auth.uid()) then raise exception 'Admin required'; end if;
  select target_id into target_user from public.reports
  where id=report_id_value and target_type::text='user'
    and status in ('open','under_review')
  for update;
  if target_user is null then raise exception 'Report unavailable'; end if;
  if not exists(select 1 from public.profiles where id=target_user) then
    raise exception 'Reported account no longer exists';
  end if;
  insert into public.notifications(
    user_id,actor_id,kind,title,body,entity_type,entity_id
  ) values (
    target_user,auth.uid(),'system',
    'MapLov safety warning',
    'A moderator reviewed a report about your account. Please follow MapLov community rules.',
    'report',report_id_value
  );
  update public.reports
  set status='resolved',resolution_notes=nullif(btrim(notes_value),''),
      resolved_at=now(),updated_at=now()
  where id=report_id_value;
  insert into public.admin_actions(
    admin_id,action,target_type,target_id,reason
  ) values (
    auth.uid(),'report_warning','user',target_user,
    nullif(btrim(notes_value),'')
  );
end;
$$;
revoke execute on function public.admin_warn_reported_user(uuid,text)
  from public,anon;
grant execute on function public.admin_warn_reported_user(uuid,text)
  to authenticated;
