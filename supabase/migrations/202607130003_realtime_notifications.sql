-- Realtime feeds and server-created notifications for MapLov.
-- Notification rows are never accepted directly from a mobile client; trusted
-- PostgreSQL triggers create them after the protected business row succeeds.

begin;

alter table public.messages replica identity full;
alter table public.notifications replica identity full;
alter table public.friendships replica identity full;
alter table public.posts replica identity full;
alter table public.post_comments replica identity full;
alter table public.garden_access_requests replica identity full;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'messages', 'notifications', 'friendships', 'posts',
    'post_comments', 'garden_access_requests'
  ] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = table_name
    ) then
      execute format('alter publication supabase_realtime add table public.%I', table_name);
    end if;
  end loop;
end;
$$;

create or replace function private.notification_enabled(
  target_user uuid,
  preference_column text
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  enabled boolean;
begin
  execute format(
    'select %I from public.notification_preferences where user_id = $1',
    preference_column
  ) into enabled using target_user;
  return coalesce(enabled, true);
end;
$$;

create or replace function private.notify_friendship_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' and new.status = 'pending'
     and private.notification_enabled(new.addressee_id, 'friend_requests') then
    insert into public.notifications(user_id, actor_id, kind, title, body, entity_type, entity_id)
    values (new.addressee_id, new.requester_id, 'friend_request', 'New friend request',
            'Someone wants to connect with you.', 'friendship', new.id);
  elsif tg_op = 'UPDATE' and old.status = 'pending' and new.status = 'accepted'
     and private.notification_enabled(new.requester_id, 'friend_requests') then
    insert into public.notifications(user_id, actor_id, kind, title, body, entity_type, entity_id)
    values (new.requester_id, new.addressee_id, 'friend_accepted', 'Friend request accepted',
            'You are now friends.', 'friendship', new.id);
  end if;
  return new;
end;
$$;

create trigger friendships_create_notification
after insert or update of status on public.friendships
for each row execute function private.notify_friendship_change();

create or replace function private.notify_new_message()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.notifications(user_id, actor_id, kind, title, body, entity_type, entity_id)
  select cm.user_id, new.sender_id, 'message', 'New message',
         case when new.kind = 'text' then left(coalesce(new.body, ''), 160) else 'New media message' end,
         'conversation', new.conversation_id
  from public.conversation_members cm
  where cm.conversation_id = new.conversation_id
    and cm.user_id <> new.sender_id
    and cm.left_at is null
    and private.notification_enabled(cm.user_id, 'messages');
  return new;
end;
$$;

create trigger messages_create_notification
after insert on public.messages
for each row execute function private.notify_new_message();

create or replace function private.notify_post_activity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  post_owner uuid;
  actor uuid;
  notification_type public.notification_kind;
  notification_title text;
begin
  select author_id into post_owner from public.posts where id = new.post_id;
  if tg_table_name = 'post_likes' then
    actor := new.user_id;
    notification_type := 'post_like';
    notification_title := 'New like';
  else
    actor := new.author_id;
    notification_type := 'post_comment';
    notification_title := 'New comment';
  end if;
  if post_owner <> actor and private.notification_enabled(post_owner, 'post_activity') then
    insert into public.notifications(user_id, actor_id, kind, title, body, entity_type, entity_id)
    values (post_owner, actor, notification_type, notification_title,
            'A friend interacted with your post.', 'post', new.post_id);
  end if;
  return new;
end;
$$;

create trigger post_likes_create_notification
after insert on public.post_likes
for each row execute function private.notify_post_activity();
create trigger post_comments_create_notification
after insert on public.post_comments
for each row execute function private.notify_post_activity();

create or replace function private.notify_garden_request_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  album_owner uuid;
begin
  select owner_id into album_owner from public.garden_albums where id = new.album_id;
  if tg_op = 'INSERT' and private.notification_enabled(album_owner, 'garden_requests') then
    insert into public.notifications(user_id, actor_id, kind, title, body, entity_type, entity_id)
    values (album_owner, new.requester_id, 'garden_request', 'Secret Garden request',
            'Someone requested access to a private album.', 'garden_access_request', new.id);
  elsif tg_op = 'UPDATE' and old.status = 'pending' and new.status in ('approved', 'declined')
     and private.notification_enabled(new.requester_id, 'garden_requests') then
    insert into public.notifications(user_id, actor_id, kind, title, body, entity_type, entity_id)
    values (new.requester_id, album_owner, 'garden_response', 'Secret Garden response',
            case when new.status = 'approved' then 'Your access request was approved.' else 'Your access request was declined.' end,
            'garden_access_request', new.id);
  end if;
  return new;
end;
$$;

create trigger garden_requests_create_notification
after insert or update of status on public.garden_access_requests
for each row execute function private.notify_garden_request_change();

revoke execute on function private.notification_enabled(uuid, text) from public, anon, authenticated;
revoke execute on function private.notify_friendship_change() from public, anon, authenticated;
revoke execute on function private.notify_new_message() from public, anon, authenticated;
revoke execute on function private.notify_post_activity() from public, anon, authenticated;
revoke execute on function private.notify_garden_request_change() from public, anon, authenticated;

commit;
