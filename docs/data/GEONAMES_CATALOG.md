# MapLov GeoNames catalogue

MapLov's normalized `regions` and `cities` catalogue is generated from the
GeoNames Gazetteer exports:

- `admin1CodesASCII.txt` for first-level administrative divisions;
- `cities500.zip` for populated places above 500 inhabitants and
  administrative seats down to PPLA4.

GeoNames data is licensed under the Creative Commons Attribution 4.0 license.
Source and license: <https://download.geonames.org/export/dump/>.

## Rebuild

From the repository root:

```sh
python3 tool/generate_geonames_catalog.py \
  --cache-dir /private/tmp/maplov-geonames-cache
```

The command regenerates:

- `supabase/migrations/202608050052_complete_geonames_regions_cities.sql`;
- `docs/data/geonames_catalog_report.json`.

The generated SQL is deterministic for a given pair of source files. Their
SHA-256 hashes are embedded in the migration and report. The migration does
not insert countries. It resolves the 72 requested
countries using `countries.iso2`, aborts if one is missing, and then updates or
inserts regions and cities without duplicating existing hierarchy/name pairs.

## Scope and limitations

`cities500` is GeoNames' standard city dataset, not a legal registry of every
municipality. Small localities below 500 inhabitants are included only when
they are administrative seats. GeoNames also provides data as-is and does not
guarantee completeness or timeliness.

Entries without a recognized first-level administrative code cannot satisfy
MapLov's mandatory `city -> region -> country` hierarchy and are excluded.
Same-name populated places inside the same ADM1 are collapsed because MapLov's
current unique constraint permits one city name per region. Exact exclusions
and per-country counts are recorded in `geonames_catalog_report.json`.
