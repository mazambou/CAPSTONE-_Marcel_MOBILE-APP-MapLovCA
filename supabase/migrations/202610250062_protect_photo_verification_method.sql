-- Keep the verification method as trusted metadata. Owners may still edit
-- ordinary photo fields, and existing moderator operations keep working.

begin;

create or replace function private.protect_photo_verification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() = 'service_role'
     or current_setting('maplov.system_operation', true) in (
       'account_deletion', 'photo_moderation'
     )
     or private.is_admin(auth.uid()) then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.is_verified := false;
    new.verification_method := 'face_match';
    new.moderation_status := 'visible';
    new.hidden_at := null;
    new.moderation_notes := null;
  elsif new.user_id is distinct from old.user_id
     or new.storage_path is distinct from old.storage_path
     or new.is_verified is distinct from old.is_verified
     or new.verification_method is distinct from old.verification_method
     or new.moderation_status is distinct from old.moderation_status
     or new.hidden_at is distinct from old.hidden_at
     or new.moderation_notes is distinct from old.moderation_notes then
    raise exception 'Photo identity and moderation fields are server-controlled';
  end if;
  return new;
end;
$$;

commit;
