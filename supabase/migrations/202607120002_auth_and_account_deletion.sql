-- MapLov authentication support and privacy-safe account deletion request.

begin;

create table public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (
    status in ('pending', 'cancelled', 'processing', 'completed')
  ),
  requested_at timestamptz not null default now(),
  scheduled_for timestamptz not null default now() + interval '30 days',
  cancelled_at timestamptz,
  processed_at timestamptz,
  constraint account_deletion_schedule_order check (scheduled_for >= requested_at)
);

alter table public.account_deletion_requests enable row level security;

create policy account_deletion_owner_read
on public.account_deletion_requests
for select to authenticated
using (user_id = auth.uid() or private.is_admin());

grant select on public.account_deletion_requests to authenticated;

create or replace function private.safe_date(value text)
returns date
language plpgsql
immutable
set search_path = ''
as $$
begin
  return value::date;
exception when invalid_datetime_format or datetime_field_overflow then
  return null;
end;
$$;

-- Supports email signup plus the standard metadata names returned by Google
-- and Apple. Privileged profile fields are never sourced from metadata.
create or replace function private.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  supplied_name text;
begin
  supplied_name := coalesce(
    nullif(btrim(new.raw_user_meta_data ->> 'first_name'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'name'), '')
  );

  insert into public.profiles (
    id,
    first_name,
    date_of_birth,
    country_code,
    country_name,
    city
  ) values (
    new.id,
    supplied_name,
    private.safe_date(new.raw_user_meta_data ->> 'date_of_birth'),
    nullif(upper(btrim(new.raw_user_meta_data ->> 'country_code')), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'country_name'), ''),
    nullif(btrim(new.raw_user_meta_data ->> 'city'), '')
  );

  insert into public.dating_preferences (user_id) values (new.id);
  insert into public.notification_preferences (user_id) values (new.id);
  return new;
end;
$$;

create or replace function public.request_account_deletion()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  insert into public.account_deletion_requests (user_id)
  values (auth.uid())
  on conflict (user_id) do update set
    status = 'pending',
    requested_at = now(),
    scheduled_for = now() + interval '30 days',
    cancelled_at = null,
    processed_at = null;

  perform set_config('maplov.system_operation', 'account_deletion', true);
  update public.profiles
  set status = 'deleted',
      is_discoverable = false,
      show_online_status = false,
      updated_at = now()
  where id = auth.uid();

  update public.garden_access_requests r
  set status = 'revoked', revoked_at = now()
  where r.status = 'approved'
    and (
      r.requester_id = auth.uid()
      or exists (
        select 1 from public.garden_albums a
        where a.id = r.album_id and a.owner_id = auth.uid()
      )
    );
end;
$$;

revoke execute on function public.request_account_deletion() from public, anon;
grant execute on function public.request_account_deletion() to authenticated;
grant execute on function private.safe_date(text) to authenticated;

commit;
