-- Store body shapes with stable, language-independent identifiers.

begin;

update public.profiles
set body_type = case lower(replace(trim(body_type), '-', '_'))
  when 'slim' then 'slim'
  when 'toned' then 'toned'
  when 'lean / toned' then 'toned'
  when 'fit' then 'fit'
  when 'average' then 'fit'
  when 'athletic' then 'athletic'
  when 'muscular' then 'muscular'
  when 'muscular / built' then 'muscular'
  when 'robust' then 'robust'
  when 'stocky' then 'robust'
  when 'round' then 'round'
  when 'curvy' then 'round'
  when 'very_round' then 'very_round'
  when 'full_figured' then 'very_round'
  when 'plus_size' then 'very_round'
  else null
end
where body_type is not null;

with expanded as (
  select
    preferences.user_id,
    case lower(replace(trim(value), '-', '_'))
      when 'slim' then 'slim'
      when 'toned' then 'toned'
      when 'lean / toned' then 'toned'
      when 'fit' then 'fit'
      when 'average' then 'fit'
      when 'athletic' then 'athletic'
      when 'muscular' then 'muscular'
      when 'muscular / built' then 'muscular'
      when 'robust' then 'robust'
      when 'stocky' then 'robust'
      when 'round' then 'round'
      when 'curvy' then 'round'
      when 'very_round' then 'very_round'
      when 'full_figured' then 'very_round'
      when 'plus_size' then 'very_round'
      else null
    end as normalized
  from public.dating_preferences preferences
  cross join lateral unnest(preferences.body_types) value
),
normalized as (
  select
    user_id,
    coalesce(
      array_agg(distinct normalized) filter (where normalized is not null),
      '{}'::text[]
    ) as body_types
  from expanded
  group by user_id
)
update public.dating_preferences preferences
set body_types = normalized.body_types
from normalized
where normalized.user_id = preferences.user_id;

update public.dating_preferences
set body_types = '{}'
where cardinality(body_types) > 0
  and not exists (
    select 1
    from unnest(body_types) value
    where value in (
      'slim', 'toned', 'fit', 'athletic',
      'muscular', 'robust', 'round', 'very_round'
    )
  );

alter table public.profiles
  drop constraint if exists profiles_body_type_values;

alter table public.profiles
  add constraint profiles_body_type_values check (
    body_type is null or body_type in (
      'slim', 'toned', 'fit', 'athletic',
      'muscular', 'robust', 'round', 'very_round'
    )
  );

alter table public.dating_preferences
  drop constraint if exists dating_preferences_body_type_values;

alter table public.dating_preferences
  add constraint dating_preferences_body_type_values check (
    body_types <@ array[
      'slim', 'toned', 'fit', 'athletic',
      'muscular', 'robust', 'round', 'very_round'
    ]::text[]
  );

commit;
