#!/usr/bin/env python3
"""Generate MapLov's city-only catalog cleanup migration.

GeoNames supplies the stable identifier, hierarchy and feature code.  Wikidata
is used as the positive classification source for generic populated places: an
entry is accepted only when its GeoNames id belongs to an entity whose type is
``city`` (Q515) or a subclass.  Feature codes that explicitly describe a
section, locality, historical/abandoned place, farm village or settlement are
always rejected.  Remaining ambiguous populated places are disabled and sent
to manual review instead of being guessed into the catalog.

The generated migration never deletes rows.  It records an audit row before
deactivation and remaps only a small set of certain parent-city relationships.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import time
import urllib.parse
import urllib.request
import zipfile
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

from generate_geonames_catalog import (
    ADMIN1_URL,
    CITIES_URL,
    COUNTRY_CODES,
    Download,
    clean_name,
    download,
    parse_regions,
    sql_text,
)


DEFAULT_OUTPUT = Path(
    "supabase/migrations/202608060053_city_only_catalog_cleanup.sql"
)
DEFAULT_SNAPSHOT = Path("docs/data/wikidata_city_geoname_ids.json")
DEFAULT_REPORT = Path("docs/data/city_catalog_cleanup_report.json")
WIKIDATA_ENDPOINT = "https://query.wikidata.org/sparql"
CHUNK_SIZE = 2000

# These codes are definitively not current cities according to GeoNames.
REJECTED_FEATURE_CODES = {
    "PPLCH",  # historical capital
    "PPLF",   # farm village
    "PPLH",   # historical populated place
    "PPLL",   # populated locality
    "PPLQ",   # abandoned populated place
    "PPLR",   # religious populated place
    "PPLS",   # undifferentiated populated places
    "PPLW",   # destroyed populated place
    "PPLX",   # section of populated place
    "STLMT",  # settlement
}

# National capitals are accepted even if Wikidata lacks a GeoNames statement.
INHERENT_CITY_CODES = {"PPLC", "PPLCD"}

# Certain Toronto subdivisions requested by the product owner.  Both sides are
# GeoNames ids, making this independent from translated/display names.
CERTAIN_PARENT_CITY_GEONAMES = {
    5950268: 6167865,   # Etobicoke -> Toronto
    5950269: 6167865,   # Etobicoke West Mall -> Toronto
    6141900: 6167865,   # Scarborough Village -> Toronto
    7871312: 6167865,   # Woodbine Corridor -> Toronto
    12156827: 6167865,  # Centennial Scarborough -> Toronto
}


@dataclass(frozen=True)
class CitySource:
    country_code: str
    admin1_code: str
    name: str
    geoname_id: int
    feature_class: str
    feature_code: str


def sha256_json(value: object) -> str:
    encoded = json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def sparql(query: str) -> dict[str, object]:
    url = WIKIDATA_ENDPOINT + "?" + urllib.parse.urlencode({"query": query})
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/sparql-results+json",
            "User-Agent": "MapLov-geography-audit/1.0 (https://maplov.ca)",
        },
    )
    last_error: Exception | None = None
    for attempt in range(5):
        try:
            with urllib.request.urlopen(request, timeout=180) as response:
                return json.loads(response.read().decode("utf-8"))
        except Exception as error:  # pragma: no cover - network retry
            last_error = error
            time.sleep(2 ** attempt)
    assert last_error is not None
    raise last_error


def result_values(payload: dict[str, object], variable: str) -> list[str]:
    results = payload["results"]
    assert isinstance(results, dict)
    bindings = results["bindings"]
    assert isinstance(bindings, list)
    values: list[str] = []
    for binding in bindings:
        assert isinstance(binding, dict)
        cell = binding.get(variable)
        if not isinstance(cell, dict):
            continue
        value = cell.get("value")
        if isinstance(value, str):
            values.append(value)
    return values


def refresh_wikidata_snapshot(path: Path) -> dict[str, object]:
    quoted_codes = " ".join(json.dumps(code) for code in COUNTRY_CODES)
    country_query = f"""
SELECT DISTINCT ?iso2 ?country WHERE {{
  VALUES ?iso2 {{ {quoted_codes} }}
  ?country wdt:P297 ?iso2.
}}
"""
    country_payload = sparql(country_query)
    results = country_payload["results"]
    assert isinstance(results, dict)
    bindings = results["bindings"]
    assert isinstance(bindings, list)
    qids: dict[str, str] = {}
    for binding in bindings:
        assert isinstance(binding, dict)
        iso = binding["iso2"]["value"]
        uri = binding["country"]["value"]
        qids[str(iso)] = str(uri).rsplit("/", 1)[-1]
    missing = sorted(set(COUNTRY_CODES) - set(qids))
    if missing:
        raise RuntimeError(f"Wikidata country identifiers missing: {missing}")

    ids_by_country: dict[str, list[int]] = {}
    for index, code in enumerate(COUNTRY_CODES):
        query = f"""
SELECT DISTINCT ?geonameId WHERE {{
  ?city wdt:P17 wd:{qids[code]};
        wdt:P1566 ?geonameId;
        wdt:P31/wdt:P279* wd:Q515.
  FILTER regex(str(?geonameId), "^[0-9]+$")
}}
"""
        payload = sparql(query)
        ids_by_country[code] = sorted(
            {
                int(value)
                for value in result_values(payload, "geonameId")
                if value.isdigit()
            }
        )
        if index + 1 < len(COUNTRY_CODES):
            time.sleep(0.15)

    snapshot: dict[str, object] = {
        "source": "Wikidata Query Service",
        "license": "CC0 1.0",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "classification": "P31/subclass of city (Q515), with P1566 GeoNames id",
        "country_qids": qids,
        "geoname_ids_by_country": ids_by_country,
    }
    snapshot["sha256"] = sha256_json(snapshot)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(snapshot, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return snapshot


def load_snapshot(path: Path) -> dict[str, object]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    ids = payload.get("geoname_ids_by_country")
    if not isinstance(ids, dict):
        raise ValueError("Invalid Wikidata city snapshot")
    return payload


def parse_cities(
    payload: bytes, valid_regions: set[tuple[str, str]]
) -> list[CitySource]:
    selected = set(COUNTRY_CODES)
    cities: dict[tuple[str, str, str], CitySource] = {}
    with zipfile.ZipFile(io.BytesIO(payload)) as archive:
        member = next(name for name in archive.namelist() if name.endswith(".txt"))
        with archive.open(member) as source:
            for raw_line in io.TextIOWrapper(source, encoding="utf-8"):
                columns = raw_line.rstrip("\n").split("\t")
                if len(columns) < 19 or columns[6] != "P":
                    continue
                country_code = columns[8]
                admin1_code = columns[10]
                if (
                    country_code not in selected
                    or (country_code, admin1_code) not in valid_regions
                ):
                    continue
                name = clean_name(columns[1])
                if not name:
                    continue
                key = (country_code, admin1_code, name.casefold())
                candidate = CitySource(
                    country_code=country_code,
                    admin1_code=admin1_code,
                    name=name,
                    geoname_id=int(columns[0]),
                    feature_class=columns[6],
                    feature_code=columns[7],
                )
                previous = cities.get(key)
                if previous is None or candidate.geoname_id < previous.geoname_id:
                    cities[key] = candidate
    return sorted(
        cities.values(),
        key=lambda city: (
            city.country_code,
            city.admin1_code,
            city.name.casefold(),
            city.geoname_id,
        ),
    )


def classification(
    city: CitySource, wikidata_ids: dict[str, set[int]]
) -> tuple[str, str, str]:
    if city.feature_code in REJECTED_FEATURE_CODES:
        return (
            "excluded",
            "non_city_feature",
            f"GeoNames feature code {city.feature_code} is not a current city",
        )
    if (
        city.geoname_id in wikidata_ids.get(city.country_code, set())
        or city.feature_code in INHERENT_CITY_CODES
    ):
        return (
            "verified_city",
            "city",
            "Wikidata class city (Q515) or GeoNames national capital",
        )
    return (
        "manual_review",
        "unverified_populated_place",
        f"GeoNames {city.feature_code} does not establish official city status",
    )


def chunks(values: list[CitySource]):
    for start in range(0, len(values), CHUNK_SIZE):
        yield values[start : start + CHUNK_SIZE]


def metadata_sql(
    cities: list[CitySource], wikidata_ids: dict[str, set[int]]
) -> str:
    statements: list[str] = []
    for batch in chunks(cities):
        rows: list[str] = []
        for city in batch:
            status, source_type, reason = classification(city, wikidata_ids)
            rows.append(
                "    ("
                + ", ".join(
                    (
                        str(city.geoname_id),
                        sql_text(city.feature_class),
                        sql_text(city.feature_code),
                        sql_text(status),
                        sql_text(source_type),
                        sql_text(reason),
                    )
                )
                + ")"
            )
        statements.append(
            """with source(
  geoname_id, feature_class, feature_code, classification_status,
  source_type, classification_reason
) as (
  values
%s
)
update public.cities city
set source_name = 'GeoNames',
    source_identifier = source.geoname_id::text,
    feature_class = source.feature_class,
    feature_code = source.feature_code,
    classification_status = source.classification_status,
    source_type = source.source_type,
    classification_reason = source.classification_reason,
    classified_at = now()
from source
where city.geoname_id = source.geoname_id;"""
            % ",\n".join(rows)
        )
    return "\n\n".join(statements)


def migration_sql(
    cities: list[CitySource],
    wikidata_ids: dict[str, set[int]],
    city_download: Download,
    snapshot: dict[str, object],
) -> str:
    replacements = ",\n".join(
        f"  ({source}, {target})"
        for source, target in sorted(CERTAIN_PARENT_CITY_GEONAMES.items())
    )
    snapshot_hash = snapshot.get("sha256", sha256_json(snapshot))
    return f"""-- Generated by tool/generate_city_catalog_cleanup.py.
-- GeoNames CC BY 4.0 cities500 SHA-256: {city_download.sha256}
-- Wikidata CC0 city-classification snapshot SHA-256: {snapshot_hash}
-- No country or region is inserted, deleted or replaced by this migration.
-- Ambiguous entries are audited and disabled, never silently deleted.

begin;

alter table public.cities
  add column if not exists source_name text,
  add column if not exists source_identifier text,
  add column if not exists source_type text,
  add column if not exists feature_class varchar(1),
  add column if not exists feature_code text,
  add column if not exists classification_status text not null
    default 'manual_review',
  add column if not exists classification_reason text,
  add column if not exists classified_at timestamptz;

create table if not exists public.geography_city_classification_audit (
  migration_key text not null,
  city_id uuid not null references public.cities(id) on delete cascade,
  city_name text not null,
  country_id uuid not null references public.countries(id) on delete cascade,
  region_id uuid not null references public.regions(id) on delete cascade,
  previous_is_active boolean not null,
  classification_status text not null,
  classification_reason text,
  replacement_city_id uuid references public.cities(id) on delete set null,
  affected_profile_ids uuid[] not null default '{{}}',
  affected_preference_user_ids uuid[] not null default '{{}}',
  captured_at timestamptz not null default now(),
  primary key (migration_key, city_id)
);

alter table public.geography_city_classification_audit enable row level security;
revoke all on public.geography_city_classification_audit from anon, authenticated;
grant all on public.geography_city_classification_audit to service_role;

{metadata_sql(cities, wikidata_ids)}

-- Rows from the legacy fallback seed have no source classification.  They are
-- retained for referential integrity but require review and are not selectable.
update public.cities
set source_name = coalesce(source_name, 'MapLov legacy seed'),
    source_type = coalesce(source_type, 'unverified_legacy_entry'),
    classification_status = 'manual_review',
    classification_reason = coalesce(
      classification_reason,
      'Legacy entry has no external city classification'
    ),
    classified_at = coalesce(classified_at, now())
where geoname_id is null;

create temporary table maplov_city_replacements (
  source_city_id uuid primary key,
  replacement_city_id uuid not null
) on commit drop;

with source(source_geoname_id, replacement_geoname_id) as (
  values
{replacements}
)
insert into maplov_city_replacements(source_city_id, replacement_city_id)
select old_city.id, replacement.id
from source
join public.cities old_city on old_city.geoname_id = source.source_geoname_id
join public.cities replacement
  on replacement.geoname_id = source.replacement_geoname_id
where old_city.id <> replacement.id
on conflict do nothing;

-- Legacy "Other region" duplicates are remapped only when an exact-name,
-- verified city exists in the same country.
insert into maplov_city_replacements(source_city_id, replacement_city_id)
select legacy.id, min(verified.id::text)::uuid
from public.cities legacy
join public.regions legacy_region on legacy_region.id = legacy.region_id
join public.cities verified
  on verified.country_id = legacy.country_id
 and lower(btrim(verified.name)) = lower(btrim(legacy.name))
 and verified.classification_status = 'verified_city'
 and verified.id <> legacy.id
where legacy.geoname_id is null
  and lower(btrim(legacy_region.name)) = 'other region'
group by legacy.id
on conflict do nothing;

insert into public.geography_city_classification_audit(
  migration_key, city_id, city_name, country_id, region_id,
  previous_is_active, classification_status, classification_reason,
  replacement_city_id, affected_profile_ids, affected_preference_user_ids
)
select
  '202608060053_city_only_catalog', city.id, city.name, city.country_id,
  city.region_id, city.is_active, city.classification_status,
  city.classification_reason, replacement.replacement_city_id,
  array(
    select profile.id
    from public.profiles profile
    where profile.residence_city_id = city.id
       or profile.origin_city_id = city.id
    order by profile.id
  ),
  array(
    select preference.user_id
    from public.dating_preferences preference
    where city.id = any(preference.city_ids)
       or city.id = any(preference.origin_city_ids)
    order by preference.user_id
  )
from public.cities city
left join maplov_city_replacements replacement on replacement.source_city_id = city.id
where city.classification_status <> 'verified_city'
on conflict (migration_key, city_id) do nothing;

update public.profiles profile
set residence_city_id = target.id,
    residence_region_id = target.region_id,
    residence_country_id = target.country_id,
    residence_city = target.name,
    city = target.name
from maplov_city_replacements mapping
join public.cities target on target.id = mapping.replacement_city_id
where profile.residence_city_id = mapping.source_city_id;

update public.profiles profile
set origin_city_id = target.id,
    origin_region_id = target.region_id,
    origin_country_id = target.country_id,
    origin_city = target.name
from maplov_city_replacements mapping
join public.cities target on target.id = mapping.replacement_city_id
where profile.origin_city_id = mapping.source_city_id;

update public.dating_preferences preference
set city_ids = coalesce((
  select array_agg(value.city_id order by value.first_position)
  from (
    select coalesce(mapping.replacement_city_id, choice.city_id) city_id,
           min(choice.ordinality) first_position
    from unnest(preference.city_ids) with ordinality choice(city_id, ordinality)
    left join maplov_city_replacements mapping
      on mapping.source_city_id = choice.city_id
    group by coalesce(mapping.replacement_city_id, choice.city_id)
  ) value
), '{{}}'::uuid[]),
origin_city_ids = coalesce((
  select array_agg(value.city_id order by value.first_position)
  from (
    select coalesce(mapping.replacement_city_id, choice.city_id) city_id,
           min(choice.ordinality) first_position
    from unnest(preference.origin_city_ids) with ordinality choice(city_id, ordinality)
    left join maplov_city_replacements mapping
      on mapping.source_city_id = choice.city_id
    group by coalesce(mapping.replacement_city_id, choice.city_id)
  ) value
), '{{}}'::uuid[]);

update public.cities
set is_active = (classification_status = 'verified_city');

alter table public.cities drop constraint if exists cities_active_verified_city;
alter table public.cities
  add constraint cities_active_verified_city
  check (not is_active or classification_status = 'verified_city') not valid;
alter table public.cities validate constraint cities_active_verified_city;

create index if not exists cities_region_active_name_idx
  on public.cities(region_id, name) where is_active;
create index if not exists cities_classification_review_idx
  on public.cities(classification_status, country_id, region_id, name);

comment on column public.cities.classification_status is
  'verified_city, manual_review, or excluded; only verified_city may be active.';
comment on table public.geography_city_classification_audit is
  'Immutable pre-deactivation report, including affected profile and preference ids.';

commit;
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--cache-dir", type=Path)
    parser.add_argument("--snapshot", type=Path, default=DEFAULT_SNAPSHOT)
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    parser.add_argument("--refresh-wikidata", action="store_true")
    args = parser.parse_args()

    snapshot = (
        refresh_wikidata_snapshot(args.snapshot)
        if args.refresh_wikidata or not args.snapshot.exists()
        else load_snapshot(args.snapshot)
    )
    raw_ids = snapshot["geoname_ids_by_country"]
    assert isinstance(raw_ids, dict)
    wikidata_ids = {
        code: {int(value) for value in raw_ids.get(code, [])}
        for code in COUNTRY_CODES
    }
    cache = args.cache_dir
    admin_download = download(
        ADMIN1_URL, None if cache is None else cache / "admin1CodesASCII.txt"
    )
    city_download = download(
        CITIES_URL, None if cache is None else cache / "cities500.zip"
    )
    valid_regions = set(parse_regions(admin_download.body))
    cities = parse_cities(city_download.body, valid_regions)
    decisions = {
        city.geoname_id: classification(city, wikidata_ids) for city in cities
    }
    totals = {
        status: sum(decision[0] == status for decision in decisions.values())
        for status in ("verified_city", "manual_review", "excluded")
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        migration_sql(cities, wikidata_ids, city_download, snapshot),
        encoding="utf-8",
    )
    manual_examples = [
        {
            "iso2": city.country_code,
            "region_code": city.admin1_code,
            "name": city.name,
            "geoname_id": city.geoname_id,
            "feature_code": city.feature_code,
        }
        for city in cities
        if decisions[city.geoname_id][0] == "manual_review"
    ][:250]
    report = {
        "sources": {
            "geonames": {
                "url": CITIES_URL,
                "license": "CC BY 4.0",
                "sha256": city_download.sha256,
                "admin1_url": ADMIN1_URL,
                "admin1_sha256": admin_download.sha256,
            },
            "wikidata": {
                "endpoint": WIKIDATA_ENDPOINT,
                "license": "CC0 1.0",
                "snapshot": str(args.snapshot),
                "sha256": snapshot.get("sha256"),
            },
        },
        "totals": {"source_entries": len(cities), **totals},
        "rejected_feature_codes": sorted(REJECTED_FEATURE_CODES),
        "certain_parent_city_remaps": CERTAIN_PARENT_CITY_GEONAMES,
        "manual_review_examples": manual_examples,
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(report["totals"], sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
