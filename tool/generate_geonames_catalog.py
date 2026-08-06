#!/usr/bin/env python3
"""Generate MapLov's idempotent GeoNames regions/cities SQL seed.

Source files:
  https://download.geonames.org/export/dump/admin1CodesASCII.txt
  https://download.geonames.org/export/dump/cities500.zip

The generated migration never inserts countries. It resolves existing countries
by ISO2, upserts first-level divisions, then upserts populated places under the
matching division. GeoNames data is CC BY 4.0.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import sys
import urllib.request
import zipfile
from dataclasses import dataclass
from pathlib import Path


BASE_URL = "https://download.geonames.org/export/dump"
ADMIN1_URL = f"{BASE_URL}/admin1CodesASCII.txt"
CITIES_URL = f"{BASE_URL}/cities500.zip"
DEFAULT_OUTPUT = Path(
    "supabase/migrations/202608050052_complete_geonames_regions_cities.sql"
)
DEFAULT_REPORT = Path("docs/data/geonames_catalog_report.json")
COUNTRY_CODES = (
    "AE AU BE BF BI BJ BW CA CD CF CG CH CI CM CV DE DJ DK DZ EG ER ES ET FR "
    "GA GB GH GM GN GQ GW IE IT KE KM LR LS LY MA MG ML MR MU MW MZ NA NE NG "
    "NL NO NZ PT RW SA SC SD SE SL SN SO SS ST SZ TD TG TN TZ UG US ZA ZM ZW"
).split()
CHUNK_SIZE = 4000


@dataclass(frozen=True)
class Download:
    body: bytes
    last_modified: str
    sha256: str


@dataclass(frozen=True)
class Region:
    country_code: str
    admin1_code: str
    name: str
    geoname_id: int


@dataclass(frozen=True)
class City:
    country_code: str
    admin1_code: str
    name: str
    geoname_id: int


def download(url: str, cache_path: Path | None) -> Download:
    if cache_path is not None and cache_path.exists():
        body = cache_path.read_bytes()
        modified = "cached-local-copy"
    else:
        request = urllib.request.Request(url, headers={"User-Agent": "MapLov/1.0"})
        with urllib.request.urlopen(request, timeout=120) as response:
            body = response.read()
            modified = response.headers.get("Last-Modified", "unknown")
        if cache_path is not None:
            cache_path.parent.mkdir(parents=True, exist_ok=True)
            cache_path.write_bytes(body)
    return Download(
        body=body,
        last_modified=modified,
        sha256=hashlib.sha256(body).hexdigest(),
    )


def clean_name(value: str) -> str:
    return " ".join(value.strip().split())


def sql_text(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def parse_regions(payload: bytes) -> dict[tuple[str, str], Region]:
    selected = set(COUNTRY_CODES)
    regions: dict[tuple[str, str], Region] = {}
    for raw_line in payload.decode("utf-8").splitlines():
        columns = raw_line.split("\t")
        if len(columns) < 4 or "." not in columns[0]:
            continue
        country_code, admin1_code = columns[0].split(".", 1)
        name = clean_name(columns[1])
        if (
            country_code not in selected
            or not admin1_code
            or admin1_code == "00"
            or not name
        ):
            continue
        regions[(country_code, admin1_code)] = Region(
            country_code=country_code,
            admin1_code=admin1_code,
            name=name,
            geoname_id=int(columns[3]),
        )
    return regions


def parse_cities(
    payload: bytes, regions: dict[tuple[str, str], Region]
) -> tuple[list[City], dict[str, object]]:
    selected = set(COUNTRY_CODES)
    cities: dict[tuple[str, str, str], City] = {}
    skipped: dict[str, object] = {
        "unknown_region": 0,
        "duplicate_name": 0,
        "unknown_region_by_country": {},
        "duplicate_name_by_country": {},
    }
    with zipfile.ZipFile(io.BytesIO(payload)) as archive:
        member = next(name for name in archive.namelist() if name.endswith(".txt"))
        with archive.open(member) as source:
            for raw_line in io.TextIOWrapper(source, encoding="utf-8"):
                columns = raw_line.rstrip("\n").split("\t")
                if len(columns) < 19 or columns[6] != "P":
                    continue
                country_code = columns[8]
                admin1_code = columns[10]
                if country_code not in selected:
                    continue
                if (country_code, admin1_code) not in regions:
                    skipped["unknown_region"] = int(skipped["unknown_region"]) + 1
                    unknown_by_country = skipped["unknown_region_by_country"]
                    assert isinstance(unknown_by_country, dict)
                    unknown_by_country[country_code] = (
                        unknown_by_country.get(country_code, 0) + 1
                    )
                    continue
                name = clean_name(columns[1])
                if not name:
                    continue
                key = (country_code, admin1_code, name.casefold())
                candidate = City(
                    country_code=country_code,
                    admin1_code=admin1_code,
                    name=name,
                    geoname_id=int(columns[0]),
                )
                previous = cities.get(key)
                if previous is not None:
                    skipped["duplicate_name"] = int(skipped["duplicate_name"]) + 1
                    duplicate_by_country = skipped["duplicate_name_by_country"]
                    assert isinstance(duplicate_by_country, dict)
                    duplicate_by_country[country_code] = (
                        duplicate_by_country.get(country_code, 0) + 1
                    )
                    if candidate.geoname_id >= previous.geoname_id:
                        continue
                cities[key] = candidate
    return sorted(
        cities.values(),
        key=lambda value: (
            value.country_code,
            value.admin1_code,
            value.name.casefold(),
            value.geoname_id,
        ),
    ), skipped


def chunks(values: list[Region] | list[City]):
    for start in range(0, len(values), CHUNK_SIZE):
        yield values[start : start + CHUNK_SIZE]


def region_sql(regions: list[Region]) -> str:
    statements: list[str] = []
    for batch in chunks(regions):
        rows = ",\n".join(
            "    ("
            + ", ".join(
                (
                    sql_text(value.country_code),
                    sql_text(value.admin1_code),
                    sql_text(value.name),
                    str(value.geoname_id),
                )
            )
            + ")"
            for value in batch
        )
        statements.append(
            f"""-- Update regions already known by GeoNames ID or hierarchy/name.
with source(iso2, admin1_code, name, geoname_id) as (
  values
{rows}
)
update public.regions region
set code = source.admin1_code,
    name = source.name,
    geoname_id = source.geoname_id,
    is_active = true
from source
join public.countries country on country.iso2 = source.iso2
where region.country_id = country.id
  and (
    region.geoname_id = source.geoname_id
    or lower(btrim(region.name)) = lower(btrim(source.name))
  );

with source(iso2, admin1_code, name, geoname_id) as (
  values
{rows}
), resolved as (
  select country.id as country_id, source.*
  from source
  join public.countries country on country.iso2 = source.iso2
)
insert into public.regions(country_id, code, name, geoname_id, is_active)
select country_id, admin1_code, name, geoname_id, true
from resolved
on conflict do nothing;"""
        )
    return "\n\n".join(statements)


def city_sql(cities: list[City]) -> str:
    statements: list[str] = []
    for batch in chunks(cities):
        rows = ",\n".join(
            "    ("
            + ", ".join(
                (
                    sql_text(value.country_code),
                    sql_text(value.admin1_code),
                    sql_text(value.name),
                    str(value.geoname_id),
                )
            )
            + ")"
            for value in batch
        )
        statements.append(
            f"""-- Update cities already known by GeoNames ID or hierarchy/name.
with source(iso2, admin1_code, name, geoname_id) as (
  values
{rows}
)
update public.cities city
set name = source.name,
    geoname_id = source.geoname_id,
    is_active = true
from source
join public.countries country on country.iso2 = source.iso2
join public.regions region
  on region.country_id = country.id
 and region.code = source.admin1_code
where city.country_id = country.id
  and city.region_id = region.id
  and (
    city.geoname_id = source.geoname_id
    or lower(btrim(city.name)) = lower(btrim(source.name))
  );

with source(iso2, admin1_code, name, geoname_id) as (
  values
{rows}
), resolved as (
  select country.id as country_id, region.id as region_id, source.*
  from source
  join public.countries country on country.iso2 = source.iso2
  join public.regions region
    on region.country_id = country.id
   and region.code = source.admin1_code
)
insert into public.cities(country_id, region_id, name, geoname_id, is_active)
select country_id, region_id, name, geoname_id, true
from resolved
on conflict do nothing;"""
        )
    return "\n\n".join(statements)


def migration_sql(
    regions: list[Region],
    cities: list[City],
    admin_download: Download,
    city_download: Download,
    skipped: dict[str, object],
) -> str:
    country_array = ", ".join(sql_text(value) for value in COUNTRY_CODES)
    return f"""-- Generated by tool/generate_geonames_catalog.py.
-- GeoNames CC BY 4.0: https://www.geonames.org/
-- admin1CodesASCII SHA-256: {admin_download.sha256}
-- cities500 SHA-256: {city_download.sha256}
-- Countries: {len(COUNTRY_CODES)}; regions: {len(regions)}; cities: {len(cities)}.
-- Skipped cities without a recognized ADM1: {skipped['unknown_region']}.
-- Collapsed same-name city duplicates within one ADM1: {skipped['duplicate_name']}.
-- This migration intentionally contains no INSERT into public.countries.

begin;

alter table public.regions add column if not exists geoname_id bigint;
alter table public.cities add column if not exists geoname_id bigint;
create unique index if not exists regions_geoname_id_unique
  on public.regions(geoname_id) where geoname_id is not null;
create unique index if not exists cities_geoname_id_unique
  on public.cities(geoname_id) where geoname_id is not null;

do $$
declare
  missing_iso2 text;
begin
  select requested.iso2 into missing_iso2
  from unnest(array[{country_array}]::text[]) requested(iso2)
  left join public.countries country on country.iso2 = requested.iso2
  where country.id is null
  limit 1;
  if missing_iso2 is not null then
    raise exception 'GeoNames seed requires existing country ISO2 %', missing_iso2;
  end if;
end
$$;

{region_sql(regions)}

{city_sql(cities)}

comment on column public.regions.geoname_id is
  'Stable GeoNames identifier; source licensed CC BY 4.0.';
comment on column public.cities.geoname_id is
  'Stable GeoNames identifier; source licensed CC BY 4.0.';

commit;
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--cache-dir", type=Path)
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    args = parser.parse_args()
    cache = args.cache_dir
    admin_download = download(
        ADMIN1_URL, None if cache is None else cache / "admin1CodesASCII.txt"
    )
    city_download = download(
        CITIES_URL, None if cache is None else cache / "cities500.zip"
    )
    region_by_code = parse_regions(admin_download.body)
    regions = sorted(
        region_by_code.values(),
        key=lambda value: (
            value.country_code,
            value.name.casefold(),
            value.admin1_code,
        ),
    )
    cities, skipped = parse_cities(city_download.body, region_by_code)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        migration_sql(
            regions, cities, admin_download, city_download, skipped
        ),
        encoding="utf-8",
    )
    region_counts = {
        code: sum(value.country_code == code for value in regions)
        for code in COUNTRY_CODES
    }
    city_counts = {
        code: sum(value.country_code == code for value in cities)
        for code in COUNTRY_CODES
    }
    report = {
        "source": {
            "provider": "GeoNames",
            "license": "CC BY 4.0",
            "admin1_url": ADMIN1_URL,
            "admin1_sha256": admin_download.sha256,
            "cities_url": CITIES_URL,
            "cities_sha256": city_download.sha256,
            "city_scope": (
                "cities500: populated places with population above 500, plus "
                "administrative seats down to PPLA4"
            ),
        },
        "totals": {
            "countries": len(COUNTRY_CODES),
            "regions": len(regions),
            "cities": len(cities),
        },
        "countries": [
            {
                "iso2": code,
                "regions": region_counts[code],
                "cities": city_counts[code],
            }
            for code in COUNTRY_CODES
        ],
        "incomplete_countries": [
            code
            for code in COUNTRY_CODES
            if region_counts[code] == 0 or city_counts[code] == 0
        ],
        "skipped": skipped,
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(
        f"countries={len(COUNTRY_CODES)} regions={len(regions)} "
        f"cities={len(cities)} skipped={skipped} output={args.output}",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
