drop policy if exists chat_media_storage_insert on storage.objects;
create policy chat_media_storage_insert on storage.objects
for insert to authenticated
with check (
  bucket_id='chat-media'
  and private.safe_uuid((storage.foldername(name))[1])=auth.uid()
  and private.is_conversation_member(
    private.safe_uuid((storage.foldername(name))[2])
  )
  and not exists (
    select 1 from public.conversation_members member
    where member.conversation_id=
      private.safe_uuid((storage.foldername(name))[2])
      and member.user_id<>auth.uid()
      and private.is_blocked_between(auth.uid(),member.user_id)
  )
);

-- A member may hide a message through the scoped chat functions, but must
-- not delete its underlying attachment directly before moderation retention.
drop policy if exists chat_media_storage_delete on storage.objects;
