-- Origin is private by default and is shown only after explicit consent.

begin;

alter table public.profiles
  add column if not exists show_origin_on_profile boolean not null default false;

comment on column public.profiles.show_origin_on_profile is
  'When true, public profiles may show origin country and city. Origin region remains private.';

commit;
