-- Expose a single, audited administrative view of account identity and profile
-- data. Auth contact fields remain inaccessible through ordinary table APIs.
create or replace function public.admin_user_details(user_id_value uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  details jsonb;
begin
  if not private.is_admin(auth.uid()) then
    raise exception 'Admin required';
  end if;

  select jsonb_build_object(
    'id', profile.id,
    'first_name', profile.first_name,
    'email', auth_user.email,
    'phone', auth_user.phone,
    'email_confirmed_at', auth_user.email_confirmed_at,
    'phone_confirmed_at', auth_user.phone_confirmed_at,
    'last_sign_in_at', auth_user.last_sign_in_at,
    'auth_created_at', auth_user.created_at,
    'profile_created_at', profile.created_at,
    'last_active_at', profile.last_active_at,
    'profile_completed_at', profile.profile_completed_at,
    'date_of_birth', profile.date_of_birth,
    'gender', profile.gender,
    'city', profile.city,
    'country_code', profile.country_code,
    'country_name', profile.country_name,
    'profession', profile.profession,
    'education_level', profile.education_level,
    'relationship_goal', profile.relationship_goal,
    'role', profile.role,
    'status', profile.status,
    'is_discoverable', profile.is_discoverable,
    'is_verified', profile.is_verified,
    'is_photo_verified', profile.is_photo_verified,
    'photo_count', (
      select count(*)
      from public.profile_photos as photo
      where photo.user_id = profile.id
    ),
    'open_reports', (
      select count(*)
      from public.reports as report
      where report.status in ('open', 'under_review')
        and (
          (report.target_type = 'user' and report.target_id = profile.id)
          or (
            report.target_type = 'photo'
            and exists (
              select 1
              from public.profile_photos as photo
              where photo.id = report.target_id
                and photo.user_id = profile.id
            )
          )
          or (
            report.target_type = 'post'
            and exists (
              select 1
              from public.posts as post
              where post.id = report.target_id
                and post.author_id = profile.id
            )
          )
          or (
            report.target_type = 'comment'
            and exists (
              select 1
              from public.photo_comments as comment
              where comment.id = report.target_id
                and comment.author_id = profile.id
            )
          )
        )
    ),
    'subscription_tier', coalesce(
      (
        select subscription.tier::text
        from public.subscriptions as subscription
        where subscription.user_id = profile.id
          and subscription.is_current
        order by subscription.created_at desc
        limit 1
      ),
      'free'
    ),
    'deletion_status', (
      select request.status
      from public.account_deletion_requests as request
      where request.user_id = profile.id
      order by request.requested_at desc
      limit 1
    )
  )
  into details
  from public.profiles as profile
  join auth.users as auth_user on auth_user.id = profile.id
  where profile.id = user_id_value;

  if details is null then
    raise exception 'Account not found';
  end if;

  return details;
end;
$$;

revoke execute on function public.admin_user_details(uuid)
  from public, anon;
grant execute on function public.admin_user_details(uuid)
  to authenticated;
