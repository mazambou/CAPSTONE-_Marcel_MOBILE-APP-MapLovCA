-- Deleted chat attachments are no longer readable through the normal
-- conversation storage policy. Moderators retain access during the 30-day
-- temporary period; filed report copies live in the separate evidence bucket.
drop policy if exists chat_media_storage_read on storage.objects;
create policy chat_media_storage_read on storage.objects
for select to authenticated
using (
  bucket_id='chat-media' and (
    private.is_admin(auth.uid()) or exists (
      select 1 from public.messages m
      where m.media_path=storage.objects.name
        and m.deleted_at is null
        and private.is_conversation_member(m.conversation_id)
    )
  )
);

create or replace function public.prune_expired_moderation_records()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  expired_messages integer;
  expired_reports integer;
begin
  if auth.role()<>'service_role' then raise exception 'Service role required'; end if;
  delete from public.deleted_message_retention
  where message_id in (
    select message_id from public.deleted_message_retention
    where retain_until<=now() order by retain_until limit 100
  );
  get diagnostics expired_messages=row_count;

  with expired as (
    delete from public.report_conversation_evidence
    where report_id in (
      select report_id from public.report_conversation_evidence
      where retain_until is not null and retain_until<=now()
      order by retain_until limit 100
    )
    returning report_id
  )
  delete from public.reports r where r.id in (select report_id from expired);
  get diagnostics expired_reports=row_count;
  return jsonb_build_object(
    'expired_messages',expired_messages,
    'expired_reports',expired_reports
  );
end;
$$;
revoke execute on function public.prune_expired_moderation_records()
  from public,anon,authenticated;
grant execute on function public.prune_expired_moderation_records()
  to service_role;
