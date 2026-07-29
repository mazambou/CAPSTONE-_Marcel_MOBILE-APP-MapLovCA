-- Derive the default dating preference from a profile gender at registration
-- and whenever that profile gender is explicitly changed.

begin;

-- Entitlement validation only needs to run when an affected location field is
-- inserted or changed. This lets internal preference synchronization preserve
-- an existing location choice without revalidating unrelated columns.
drop trigger if exists preferences_international_entitlement
  on public.dating_preferences;
create trigger preferences_international_entitlement
before insert or update of location_mode, origin_country_names,
  origin_regions, origin_cities
on public.dating_preferences
for each row execute function private.enforce_international_search_entitlement();

create or replace function private.sync_default_gender_preference()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  preferred_gender text;
begin
  preferred_gender := case new.gender
    when 'Man' then 'Woman'
    when 'Woman' then 'Man'
    when 'Non-binary' then 'Non-binary'
    else null
  end;

  if preferred_gender is null then
    return new;
  end if;

  insert into public.dating_preferences as preferences (
    user_id,
    genders,
    required_genders
  ) values (
    new.id,
    array[preferred_gender],
    true
  )
  on conflict (user_id) do update
  set genders = excluded.genders,
      required_genders = true,
      body_types = case preferred_gender
        when 'Woman' then array(
          select body_type
          from unnest(preferences.body_types) body_type
          where left(body_type, 6) = 'women_'
        )
        when 'Man' then array(
          select body_type
          from unnest(preferences.body_types) body_type
          where left(body_type, 4) = 'men_'
        )
        else preferences.body_types
      end;

  return new;
end;
$$;

drop trigger if exists profiles_sync_default_gender_preference
  on public.profiles;
create trigger profiles_sync_default_gender_preference
after update of gender on public.profiles
for each row
when (old.gender is distinct from new.gender)
execute function private.sync_default_gender_preference();

-- Initialize only accounts that never chose a dating gender. Existing manual
-- choices remain untouched until the member changes their profile gender.
update public.dating_preferences preferences
set genders = array[
      case profile.gender
        when 'Man' then 'Woman'
        when 'Woman' then 'Man'
        else 'Non-binary'
      end
    ],
    required_genders = true
from public.profiles profile
where profile.id = preferences.user_id
  and cardinality(preferences.genders) = 0
  and profile.gender in ('Man', 'Woman', 'Non-binary');

comment on function private.sync_default_gender_preference() is
  'Resets the single dating-gender preference only when the member changes their profile gender.';

commit;
