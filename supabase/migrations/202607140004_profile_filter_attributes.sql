-- Profile attributes displayed by Standard and Advanced Filters.
-- Age, distance, verification and activity remain derived or trusted values.

begin;

alter table public.profiles
  add column if not exists religion text,
  add column if not exists children_preference text,
  add column if not exists relationship_status text,
  add column if not exists body_type text,
  add column if not exists eye_color text,
  add column if not exists hair_color text,
  add column if not exists beard_style text,
  add column if not exists smoking_status text,
  add column if not exists income_level text,
  add column if not exists interest_slugs text[] not null default '{}';

alter table public.profiles
  add constraint profiles_religion_length
    check (religion is null or char_length(religion) <= 80),
  add constraint profiles_children_preference_length
    check (children_preference is null or char_length(children_preference) <= 80),
  add constraint profiles_relationship_status_length
    check (relationship_status is null or char_length(relationship_status) <= 80),
  add constraint profiles_body_type_length
    check (body_type is null or char_length(body_type) <= 80),
  add constraint profiles_eye_color_length
    check (eye_color is null or char_length(eye_color) <= 80),
  add constraint profiles_hair_color_length
    check (hair_color is null or char_length(hair_color) <= 80),
  add constraint profiles_beard_style_length
    check (beard_style is null or char_length(beard_style) <= 80),
  add constraint profiles_smoking_status_length
    check (smoking_status is null or char_length(smoking_status) <= 80),
  add constraint profiles_income_level_length
    check (income_level is null or char_length(income_level) <= 80),
  add constraint profiles_interest_slugs_limit
    check (cardinality(interest_slugs) <= 50);

create index if not exists profiles_filter_attributes_idx
  on public.profiles (
    relationship_goal,
    religion,
    relationship_status,
    body_type,
    education_level
  )
  where status = 'active' and is_discoverable;

create index if not exists profiles_interest_slugs_gin_idx
  on public.profiles using gin (interest_slugs);

commit;
