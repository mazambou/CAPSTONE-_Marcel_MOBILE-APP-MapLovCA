-- Older clients stored English reasons; they need the same safety gate.
create or replace function public.record_child_safety_action(
  report_id_value uuid,
  action_value text,
  authority_value text default null,
  reference_value text default null,
  rationale_value text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  report_reason text;
  action_id uuid;
begin
  if not private.is_admin(auth.uid()) then
    raise exception 'Admin required';
  end if;
  select reason into report_reason from public.reports
    where id = report_id_value for update;
  if report_reason is null or report_reason not in (
    'Mineur présumé', 'Exploitation sexuelle d’un enfant',
    'Suspected minor', 'Child sexual exploitation'
  ) then
    raise exception 'Child-safety report required';
  end if;
  if action_value not in ('no_referral_required', 'reported_to_authority') then
    raise exception 'Invalid child-safety action';
  end if;
  insert into public.child_safety_case_actions(
    report_id, report_reference, action, authority, authority_reference,
    rationale, recorded_by
  ) values (
    report_id_value, report_id_value, action_value,
    nullif(btrim(authority_value), ''), nullif(btrim(reference_value), ''),
    nullif(btrim(rationale_value), ''), auth.uid()
  ) returning id into action_id;
  return action_id;
end;
$$;

create or replace function private.require_child_safety_action_before_closure()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.reason in (
       'Mineur présumé', 'Exploitation sexuelle d’un enfant',
       'Suspected minor', 'Child sexual exploitation'
     )
     and new.status in ('resolved', 'dismissed')
     and old.status is distinct from new.status
     and not exists (
       select 1 from public.child_safety_case_actions a
       where a.report_reference = new.id
     ) then
    raise exception 'Record a child-safety decision before closing this report';
  end if;
  return new;
end;
$$;
