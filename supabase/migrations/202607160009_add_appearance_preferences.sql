-- Persist the appearance criteria exposed by the Advanced Filter screen.
alter table public.dating_preferences
  add column if not exists eye_colors text[] not null default '{}',
  add column if not exists hair_colors text[] not null default '{}';
