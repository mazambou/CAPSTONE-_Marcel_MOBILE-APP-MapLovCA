-- Keep each feminine and masculine silhouette as an independent filter value.

begin;

-- Existing entitlement checks apply to user actions, not to this data
-- normalization. The trigger is restored before the transaction commits.
alter table public.dating_preferences
  disable trigger preferences_international_entitlement;

alter table public.profiles
  drop constraint if exists profiles_body_type_values;

alter table public.dating_preferences
  drop constraint if exists dating_preferences_body_type_values;

update public.profiles
set body_type = case
  when body_type ~ '^(women|men)_(slim|toned|fit|athletic|muscular|robust|round|very_round)$'
    then body_type
  when gender = 'Woman'
    then 'women_' || body_type
  when gender = 'Man'
    then 'men_' || body_type
  else null
end
where body_type is not null;

update public.profiles
set body_type = null
where body_type is not null
  and not (
    (gender = 'Woman' and left(body_type, 6) = 'women_')
    or (gender = 'Man' and left(body_type, 4) = 'men_')
    or (
      gender = 'Non-binary'
      and body_type ~ '^(women|men)_'
    )
  );

with normalized as (
  select
    preferences.user_id,
    coalesce(
      array_agg(
        distinct case
          when value ~ '^(women|men)_(slim|toned|fit|athletic|muscular|robust|round|very_round)$'
            then value
          when cardinality(preferences.genders) = 1
            and preferences.genders[1] in ('Woman', 'Women')
            then 'women_' || value
          when cardinality(preferences.genders) = 1
            and preferences.genders[1] in ('Man', 'Men')
            then 'men_' || value
          else null
        end
      ) filter (
        where value ~ '^(women|men)_(slim|toned|fit|athletic|muscular|robust|round|very_round)$'
          or (
            value in (
              'slim', 'toned', 'fit', 'athletic',
              'muscular', 'robust', 'round', 'very_round'
            )
            and cardinality(preferences.genders) = 1
            and preferences.genders[1] in ('Woman', 'Women', 'Man', 'Men')
          )
      ),
      '{}'::text[]
    ) as body_types
  from public.dating_preferences preferences
  left join lateral unnest(preferences.body_types) value on true
  group by preferences.user_id
)
update public.dating_preferences preferences
set body_types = normalized.body_types
from normalized
where normalized.user_id = preferences.user_id;

update public.dating_preferences
set genders = '{}',
    body_types = '{}',
    required_genders = false
where cardinality(genders) > 1;

update public.dating_preferences
set genders = case genders[1]
  when 'Women' then array['Woman']
  when 'Men' then array['Man']
  else genders
end
where cardinality(genders) = 1;

update public.dating_preferences
set genders = '{}',
    body_types = '{}',
    required_genders = false
where cardinality(genders) = 1
  and genders[1] not in ('Woman', 'Man', 'Non-binary');

update public.dating_preferences preferences
set body_types = array(
  select value
  from unnest(preferences.body_types) value
  where (preferences.genders = array['Woman'] and left(value, 6) = 'women_')
     or (preferences.genders = array['Man'] and left(value, 4) = 'men_')
     or (
       preferences.genders = array['Non-binary']
       and value ~ '^(women|men)_'
     )
);

update public.dating_preferences
set maximum_age = 80
where maximum_age > 80;

alter table public.dating_preferences
  alter column maximum_age set default 80;

alter table public.profiles
  add constraint profiles_body_type_values check (
    body_type is null or body_type in (
      'women_slim', 'women_toned', 'women_fit', 'women_athletic',
      'women_muscular', 'women_robust', 'women_round', 'women_very_round',
      'men_slim', 'men_toned', 'men_fit', 'men_athletic',
      'men_muscular', 'men_robust', 'men_round', 'men_very_round'
    )
  ),
  add constraint profiles_body_type_matches_gender check (
    body_type is null
    or (gender = 'Woman' and left(body_type, 6) = 'women_')
    or (gender = 'Man' and left(body_type, 4) = 'men_')
    or (
      gender = 'Non-binary'
      and body_type ~ '^(women|men)_'
    )
  );

alter table public.dating_preferences
  add constraint dating_preferences_body_type_values check (
    body_types <@ array[
      'women_slim', 'women_toned', 'women_fit', 'women_athletic',
      'women_muscular', 'women_robust', 'women_round', 'women_very_round',
      'men_slim', 'men_toned', 'men_fit', 'men_athletic',
      'men_muscular', 'men_robust', 'men_round', 'men_very_round'
    ]::text[]
  ),
  add constraint dating_preferences_gender_values check (
    genders <@ array['Woman', 'Man', 'Non-binary']::text[]
  ),
  add constraint dating_preferences_single_gender check (
    cardinality(genders) <= 1
  ),
  add constraint dating_preferences_body_types_match_gender check (
    cardinality(body_types) = 0
    or (
      genders = array['Woman']
      and body_types <@ array[
        'women_slim', 'women_toned', 'women_fit', 'women_athletic',
        'women_muscular', 'women_robust', 'women_round', 'women_very_round'
      ]::text[]
    )
    or (
      genders = array['Man']
      and body_types <@ array[
        'men_slim', 'men_toned', 'men_fit', 'men_athletic',
        'men_muscular', 'men_robust', 'men_round', 'men_very_round'
      ]::text[]
    )
    or (
      genders = array['Non-binary']
      and body_types <@ array[
        'women_slim', 'women_toned', 'women_fit', 'women_athletic',
        'women_muscular', 'women_robust', 'women_round', 'women_very_round',
        'men_slim', 'men_toned', 'men_fit', 'men_athletic',
        'men_muscular', 'men_robust', 'men_round', 'men_very_round'
      ]::text[]
    )
  );

alter table public.dating_preferences
  enable trigger preferences_international_entitlement;

commit;
