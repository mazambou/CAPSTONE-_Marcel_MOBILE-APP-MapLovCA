-- Repair the production schema: migration 087 is recorded as applied, but
-- its restricted case log and closure trigger are absent. Preserve existing
-- data if either object was restored separately.
create table if not exists public.child_safety_case_actions (
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

create index if not exists child_safety_case_actions_report_idx
  on public.child_safety_case_actions(report_reference, recorded_at desc);
alter table public.child_safety_case_actions enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'child_safety_case_actions'
      and policyname = 'child_safety_case_actions_admin_read'
  ) then
    create policy child_safety_case_actions_admin_read
      on public.child_safety_case_actions for select to authenticated
      using (private.is_admin(auth.uid()));
  end if;
end;
$$;
grant select on public.child_safety_case_actions to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgrelid = 'public.reports'::regclass
      and tgname = 'require_child_safety_action_before_closure'
      and not tgisinternal
  ) then
    create trigger require_child_safety_action_before_closure
      before update of status on public.reports
      for each row execute function private.require_child_safety_action_before_closure();
  end if;
end;
$$;
