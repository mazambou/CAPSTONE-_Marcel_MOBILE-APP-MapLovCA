-- A restricted, append-only log of decisions about child-safety reports.
-- This records a human referral; it never transmits a report to an authority.
create table public.child_safety_case_actions (
  id uuid primary key default gen_random_uuid(),
  report_id uuid references public.reports(id) on delete set null,
  report_reference uuid not null,
  action text not null check (action in ('no_referral_required', 'reported_to_authority')),
  authority text,
  authority_reference text,
  rationale text,
  recorded_by uuid references public.profiles(id) on delete set null,
  recorded_at timestamptz not null default now(),
  constraint child_safety_referral_fields check (
    (action = 'reported_to_authority' and nullif(btrim(authority), '') is not null
      and nullif(btrim(authority_reference), '') is not null)
    or (action = 'no_referral_required' and nullif(btrim(rationale), '') is not null
      and authority is null and authority_reference is null)
  ),
  constraint child_safety_rationale_length check (char_length(rationale) <= 1000),
  constraint child_safety_authority_length check (char_length(authority) <= 120),
  constraint child_safety_reference_length check (char_length(authority_reference) <= 200)
);
create index child_safety_case_actions_report_idx
  on public.child_safety_case_actions(report_reference, recorded_at desc);
alter table public.child_safety_case_actions enable row level security;
create policy child_safety_case_actions_admin_read
  on public.child_safety_case_actions for select to authenticated
  using (private.is_admin(auth.uid()));
grant select on public.child_safety_case_actions to authenticated;

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
  if report_reason is null or report_reason not in
      ('Mineur présumé', 'Exploitation sexuelle d’un enfant') then
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
revoke execute on function public.record_child_safety_action(uuid,text,text,text,text)
  from public, anon;
grant execute on function public.record_child_safety_action(uuid,text,text,text,text)
  to authenticated;

-- Closing a child-safety case requires a recorded human decision. In
-- particular, a moderator cannot mark a potential CSAM report resolved
-- without documenting the referral or the reason it was unnecessary.
create or replace function private.require_child_safety_action_before_closure()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.reason in ('Mineur présumé', 'Exploitation sexuelle d’un enfant')
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
create trigger require_child_safety_action_before_closure
before update of status on public.reports
for each row execute function private.require_child_safety_action_before_closure();
