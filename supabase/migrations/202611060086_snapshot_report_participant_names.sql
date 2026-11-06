-- Keep readable author labels with moderation evidence after a profile is
-- renamed or deleted. Existing cases can be labelled while profiles exist.
alter table public.report_conversation_evidence
  add column if not exists participant_names jsonb not null default '{}'::jsonb;

create or replace function private.snapshot_report_participant_names()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  select coalesce(
    jsonb_object_agg(p.id::text, btrim(p.first_name)),
    '{}'::jsonb
  )
  into new.participant_names
  from public.profiles p
  where nullif(btrim(p.first_name), '') is not null
    and (
      p.id = new.reporter_id
      or p.id = new.reported_user_id
      or exists (
        select 1 from public.conversation_members cm
        where cm.conversation_id = new.conversation_id
          and cm.user_id = p.id
      )
    );
  return new;
end;
$$;

drop trigger if exists snapshot_report_participant_names
  on public.report_conversation_evidence;
create trigger snapshot_report_participant_names
before insert on public.report_conversation_evidence
for each row execute function private.snapshot_report_participant_names();

update public.report_conversation_evidence e
set participant_names = (
  select coalesce(
    jsonb_object_agg(p.id::text, btrim(p.first_name)),
    '{}'::jsonb
  )
  from public.profiles p
  where nullif(btrim(p.first_name), '') is not null
    and (
      p.id = e.reporter_id
      or p.id = e.reported_user_id
      or exists (
        select 1 from public.conversation_members cm
        where cm.conversation_id = e.conversation_id
          and cm.user_id = p.id
      )
    )
)
where e.participant_names = '{}'::jsonb;
