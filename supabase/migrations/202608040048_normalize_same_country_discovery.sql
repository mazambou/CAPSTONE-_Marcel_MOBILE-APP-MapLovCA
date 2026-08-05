-- A search for the member's own residence country is country discovery, not
-- international discovery. Normalize older saved preferences so profiles that
-- opted out of international discovery remain visible inside their country.

begin;

update public.dating_preferences preference
set location_mode = 'my_country', updated_at = now()
from public.profiles profile
where profile.id = preference.user_id
  and preference.location_mode in ('specific_country', 'worldwide')
  and cardinality(preference.country_codes) = 1
  and lower(trim(preference.country_codes[1])) =
      lower(trim(profile.country_name));

commit;
