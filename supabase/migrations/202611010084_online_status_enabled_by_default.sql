-- New accounts publish their online status unless the member turns it off.
-- Existing profile choices are preserved.
alter table public.profiles
  alter column show_online_status set default true;
