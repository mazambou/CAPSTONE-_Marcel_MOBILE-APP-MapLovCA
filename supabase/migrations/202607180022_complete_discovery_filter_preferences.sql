-- Persist every criterion exposed by Standard and Advanced discovery filters.

begin;

alter table public.dating_preferences
  add column if not exists children_preferences text[] not null default '{}',
  add column if not exists relationship_statuses text[] not null default '{}',
  add column if not exists education_levels text[] not null default '{}',
  add column if not exists beard_styles text[] not null default '{}',
  add column if not exists smoking_statuses text[] not null default '{}',
  add column if not exists profession_categories text[] not null default '{}',
  add column if not exists income_levels text[] not null default '{}',
  add column if not exists photo_verified_only boolean not null default false;

commit;
