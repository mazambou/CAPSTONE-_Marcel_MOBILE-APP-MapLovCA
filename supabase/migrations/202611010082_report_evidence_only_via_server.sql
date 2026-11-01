begin;

drop policy if exists reports_reporter_insert on public.reports;
create policy reports_reporter_insert on public.reports for insert to authenticated
with check (
  reporter_id = auth.uid()
  and target_type::text not in ('user', 'message')
  and status = 'open'
  and assigned_to is null
  and resolution_notes is null
  and resolved_at is null
);

create or replace function public.submit_conversation_report(
  target_type_value text,
  target_id_value uuid,
  reason_value text,
  comment_value text default null,
  conversation_id_value uuid default null
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  reporter uuid := auth.uid();
  reported_user uuid;
  selected_conversation uuid := conversation_id_value;
  existing_report uuid;
  new_report uuid;
begin
  if reporter is null then raise exception 'Authentication required'; end if;
  if target_type_value not in ('user', 'message') then
    raise exception 'Invalid report target';
  end if;
  if char_length(reason_value) not between 2 and 120
     or char_length(coalesce(comment_value, '')) > 4000 then
    raise exception 'Invalid report details';
  end if;

  if target_type_value = 'user' then
    select id into reported_user from public.profiles where id = target_id_value;
  else
    select sender_id, conversation_id into reported_user, selected_conversation
    from public.messages where id = target_id_value;
    if conversation_id_value is not null
       and selected_conversation is distinct from conversation_id_value then
      raise exception 'Reported conversation is unavailable';
    end if;
  end if;
  if reported_user is null or reported_user = reporter then
    raise exception 'Reported user is unavailable';
  end if;
  if selected_conversation is not null and (
    not exists (select 1 from public.conversation_members
      where conversation_id = selected_conversation and user_id = reporter)
    or not exists (select 1 from public.conversation_members
      where conversation_id = selected_conversation and user_id = reported_user)
  ) then raise exception 'Reported conversation is unavailable'; end if;

  select id into existing_report from public.reports
  where reporter_id = reporter
    and target_type::text = target_type_value
    and target_id = target_id_value
    and status in ('open', 'under_review')
  order by created_at desc limit 1;
  if existing_report is not null then return existing_report; end if;

  insert into public.reports(
    reporter_id, target_type, target_id, reason, comment,
    reported_conversation_id
  ) values (
    reporter, target_type_value::public.report_target_type,
    target_id_value, reason_value, comment_value, selected_conversation
  ) returning id into new_report;
  return new_report;
end;
$$;

revoke all on function public.submit_conversation_report(text,uuid,text,text,uuid)
  from public, anon;
grant execute on function public.submit_conversation_report(text,uuid,text,text,uuid)
  to authenticated;

commit;
