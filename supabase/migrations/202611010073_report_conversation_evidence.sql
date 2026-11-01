-- Keep moderation cases after an account is erased. Evidence has no foreign
-- keys to account-owned rows and cannot be read by either participant.
alter table public.reports
  add column if not exists reported_conversation_id uuid;
alter table public.reports
  alter column reporter_id drop not null;
alter table public.reports
  drop constraint if exists reports_reporter_id_fkey;
alter table public.reports
  add constraint reports_reporter_id_fkey
    foreign key (reporter_id) references public.profiles(id) on delete set null;

create table public.report_conversation_evidence (
  report_id uuid primary key,
  reporter_id uuid,
  reported_user_id uuid,
  conversation_id uuid,
  captured_at timestamptz not null default now(),
  messages jsonb not null default '[]'::jsonb,
  attachments jsonb not null default '[]'::jsonb,
  media_finalized_at timestamptz,
  retain_until timestamptz,
  constraint report_evidence_messages_array check (jsonb_typeof(messages)='array'),
  constraint report_evidence_attachments_array check (jsonb_typeof(attachments)='array')
);
create index report_evidence_retention_idx
  on public.report_conversation_evidence(retain_until)
  where retain_until is not null;
alter table public.report_conversation_evidence enable row level security;
create policy report_evidence_admin_read on public.report_conversation_evidence
  for select to authenticated using (private.is_admin(auth.uid()));
grant select on public.report_conversation_evidence to authenticated;

insert into storage.buckets(id,name,public,file_size_limit)
values('moderation-evidence','moderation-evidence',false,26214400)
on conflict(id) do nothing;
create policy moderation_evidence_admin_read on storage.objects
  for select to authenticated
  using (bucket_id='moderation-evidence' and private.is_admin(auth.uid()));

-- An erased message remains recoverable for moderation for 30 days. The
-- participant-facing message is still removed according to the chosen scope.
create table public.deleted_message_retention (
  message_id uuid primary key,
  conversation_id uuid not null,
  sender_id uuid,
  kind text not null,
  body text,
  media_path text,
  reply_to_id uuid,
  created_at timestamptz not null,
  deleted_at timestamptz not null default now(),
  retain_until timestamptz not null default now()+interval '30 days'
);
create index deleted_message_retention_due_idx
  on public.deleted_message_retention(retain_until);
alter table public.deleted_message_retention enable row level security;
create policy deleted_message_retention_admin_read on public.deleted_message_retention
  for select to authenticated using (private.is_admin(auth.uid()));
grant select on public.deleted_message_retention to authenticated;

create or replace function private.retain_deleted_message()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op='DELETE' or
     (new.deleted_at is not null and old.deleted_at is null) then
    insert into public.deleted_message_retention(
      message_id,conversation_id,sender_id,kind,body,media_path,reply_to_id,
      created_at,deleted_at
    ) values (
      old.id,old.conversation_id,old.sender_id,old.kind::text,old.body,
      old.media_path,old.reply_to_id,old.created_at,now()
    )
    on conflict(message_id) do nothing;
  end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end;
$$;
create trigger retain_deleted_message
before update of deleted_at or delete on public.messages
for each row execute function private.retain_deleted_message();

create or replace function private.capture_report_conversation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  selected_conversation uuid;
  reported_user uuid;
  snapshot jsonb;
begin
  if new.target_type::text not in ('user','message') then return new; end if;
  if new.target_type::text='user' then
    reported_user:=new.target_id;
  else
    select m.sender_id into reported_user
    from public.messages m where m.id=new.target_id;
  end if;
  selected_conversation:=new.reported_conversation_id;
  if selected_conversation is null and new.target_type::text='message' then
    select m.conversation_id into selected_conversation
    from public.messages m where m.id=new.target_id;
  end if;
  if selected_conversation is not null and not exists (
    select 1 from public.conversation_members cm
    where cm.conversation_id=selected_conversation and cm.user_id=new.reporter_id
  ) then raise exception 'Reported conversation is unavailable'; end if;
  if selected_conversation is not null and not exists (
    select 1 from public.conversation_members cm
    where cm.conversation_id=selected_conversation and cm.user_id=reported_user
  ) then raise exception 'Reported user is not in this conversation'; end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',m.id,'sender_id',m.sender_id,'kind',m.kind::text,
    'body',coalesce(m.body,d.body),'media_path',coalesce(m.media_path,d.media_path),
    'reply_to_id',m.reply_to_id,'created_at',m.created_at,
    'deleted_at',m.deleted_at
  ) order by m.created_at,m.id),'[]'::jsonb)
  into snapshot
  from public.messages m
  left join public.deleted_message_retention d on d.message_id=m.id
  where m.conversation_id=selected_conversation;

  insert into public.report_conversation_evidence(
    report_id,reporter_id,reported_user_id,conversation_id,messages
  ) values (
    new.id,new.reporter_id,reported_user,selected_conversation,
    coalesce(snapshot,'[]'::jsonb)
  );
  return new;
end;
$$;
create trigger capture_report_conversation
after insert on public.reports
for each row execute function private.capture_report_conversation();

-- Preserve cases with conversation evidence even when the account-erasure
-- worker removes an account. A separate retention job may delete them later.
create or replace function private.preserve_evidenced_report()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists(select 1 from public.report_conversation_evidence e
            where e.report_id=old.id) and
     current_setting('maplov.expire_report_evidence',true) is distinct from 'true'
  then return null; end if;
  return old;
end;
$$;
create trigger preserve_evidenced_report
before delete on public.reports
for each row execute function private.preserve_evidenced_report();

-- Set an expiry when the moderation decision closes the case.
create or replace function private.set_report_evidence_expiry()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status in ('resolved','dismissed') and
     old.status is distinct from new.status then
    update public.report_conversation_evidence
    set retain_until=coalesce(new.resolved_at,now())+interval '365 days'
    where report_id=new.id;
  elsif new.status in ('open','under_review') and
        old.status is distinct from new.status then
    update public.report_conversation_evidence
    set retain_until=null where report_id=new.id;
  end if;
  return new;
end;
$$;
create trigger set_report_evidence_expiry
after update of status on public.reports
for each row execute function private.set_report_evidence_expiry();

-- Capture the already-open case as far as the current database still permits.
insert into public.report_conversation_evidence(
  report_id,reporter_id,reported_user_id,conversation_id,messages
)
select r.id,r.reporter_id,r.target_id,c.id,
  coalesce((
    select jsonb_agg(jsonb_build_object(
      'id',m.id,'sender_id',m.sender_id,'kind',m.kind::text,
      'body',m.body,'media_path',m.media_path,'reply_to_id',m.reply_to_id,
      'created_at',m.created_at,'deleted_at',m.deleted_at
    ) order by m.created_at,m.id)
    from public.messages m where m.conversation_id=c.id
  ),'[]'::jsonb)
from public.reports r
join lateral (
  select cm.conversation_id as id
  from public.conversation_members cm
  join public.conversation_members other
    on other.conversation_id=cm.conversation_id and other.user_id=r.target_id
  where cm.user_id=r.reporter_id and r.target_type::text='user'
  order by cm.joined_at desc limit 1
) c on true
where r.status in ('open','under_review')
on conflict(report_id) do nothing;
