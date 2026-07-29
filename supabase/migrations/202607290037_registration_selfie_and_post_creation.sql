-- Keep identity enrollment inside registration and create posts through a
-- trusted author-scoped RPC instead of relying on a client-provided author id.

begin;

create or replace function public.create_my_post(
  post_body text default null,
  allow_comments boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_post_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if not exists (
    select 1
    from public.profiles profile
    where profile.id = auth.uid()
      and profile.status = 'active'
  ) then
    raise exception 'This account is not active';
  end if;

  insert into public.posts(author_id, body, comments_enabled)
  values (
    auth.uid(),
    nullif(btrim(coalesce(post_body, '')), ''),
    coalesce(allow_comments, true)
  )
  returning id into new_post_id;

  return new_post_id;
end;
$$;

revoke execute on function public.create_my_post(text, boolean)
  from public, anon;
grant execute on function public.create_my_post(text, boolean)
  to authenticated;

comment on function public.create_my_post(text, boolean) is
  'Creates a friends-only post for the authenticated active account without trusting a client-supplied author id.';

comment on table public.face_references is
  'One immutable private reference selfie per account, enrolled during registration and used for profile-photo verification and global duplicate-account prevention.';

comment on table public.duplicate_account_checks is
  'Server-only AWS face matches used to block multiple accounts for the same person across existing private reference selfies.';

commit;
