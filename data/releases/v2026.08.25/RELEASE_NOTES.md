# CalCOFI integrated database release v2026.08.25

**Release date:** 2026-08-25 · **promoted** (`latest.txt`)

## `sample` is unique on its key — the 4,855-duplicate bug is fixed, and a gate now guards it

An earlier same-day cut of v2026.08.25 shipped `sample` with 1,472,100 rows for 1,467,245 distinct `sample_key`s — 3,345 bottles,
150 casts, 133 ichthyo sites and 13 underway samples appeared twice, identical except for a
`seafloor_depth_m` differing in the 11th decimal. The seafloor stamp (new in that release) collapsed
positions with `unique()` but joined them back with `merge()`, which compares coordinates as
15-significant-digit strings — two positions differing past that digit both matched every sample at
either. Nothing checked `sample` for uniqueness; the release only warned on `ship` and `cruise`.
76,320 `obs` rows (35,047 bottle, 31,057 CTD, 6,032 zooscan, 1,482 ichthyo, …) joined twice through
those samples, so any count or join keyed on `sample` over-counted them by exactly 2×.

- `sample` is unique on `sample_key` again (calcofi4db 3.23.3 maps positions back by exact index and
  errors on a duplicate), and `check_core_pk_unique()` **fails the release** on any core table that is
  not unique on its primary key.
- **Consumers:** anything built from v2026.08.25 (the cruise, hex and CTD apps' local databases, the
  station portal's derived JSON) over-counted those 4,855 samples until rebuilt on this release.

## Release tables are content-addressed, and written deterministically

Between v2026.08.14 and v2026.08.25 only 52 MB of the 2.09 GB release was byte-identical, and
tables whose row counts had not changed (`obs_mets_full`, `taxon`, `cruise`, `measurement_type`)
still differed byte-for-byte: the release writes carried no total order and ran multi-threaded.
Every released table is now written by one function with a unique `ORDER BY`, a single writer
thread and pinned parquet options, so the same rows always give the same bytes.

- **Schema:** the provenance columns (`_source_file`, `_source_row`, `_source_uuid`,
  `_ingested_at`) that `cruise`, `ship`, `lookup` and a few reference tables still carried are
  no longer in the release — `_ingested_at` changed on every ingest and would have made every
  table look changed. `lookup` and `spatial_attribute` are exported from the assembled
  database like every other table instead of being copied from the ingest bucket.
- **`catalog.json`** keeps `name`/`rows`/`partitioned`/`supplemental` and adds, per table,
  `content_hash`, `bytes` and `objects[]` — one entry per parquet object with its `path`,
  `bytes`, `sha256`, `content_hash` and `since` (the first release that shipped that content;
  for partitioned tables, per partition). Consumers that only read table names are unaffected.
- **Uploads:** an object whose content is unchanged since the previous release is reused (GCS
  server-side copy) rather than uploaded; a release's upload is now its delta.
- **Where the bytes live.** Each object is stored once, under
  `gs://calcofi-db/ducklake/tables/{table}/{content_hash}/{table}.parquet` (partitioned tables:
  `…/{table}/{col}={value}/{content_hash}/data_0.parquet`), and every release whose catalog
  points at it shares it. The familiar `releases/{version}/parquet/{table}.parquet` path is a
  real copy **only for the promoted version and the consolidated ones** (below); on
  `https://storage.calcofi.io/calcofi-db/…` a legacy path that has no copy redirects (302) to the
  canonical object while it exists. Resolve tables through `catalog.json` `objects[].path` —
  `calcofi4r::cc_release_sources()` (1.11.0), `calcofi4py.release_sources()` (0.4.0), and the
  same rule in db-query, db-viz-station, ctd-transects, db-viz-hex, the apps, ERDDAP's parquet
  sync and the PostgreSQL `release.*` views — rather than building the path by hand.

## Archive thinning: consolidated and retired versions

28 releases held 157 GB, most of it byte-identical tables re-uploaded under a new version
directory. `versions.json` now says which versions keep their parquet: `consolidated: true` for
v2026.04.08 (last per-dataset schema), v2026.05.14 (docs examples pin it), v2026.06.26,
v2026.07.17, v2026.08.14 and v2026.08.25, plus always the promoted version and the one before
it (`metadata/release_policy.yml`). Every other version keeps its `catalog.json`,
`metadata.json`, `relationships.json` and `RELEASE_NOTES.md` — the record stays complete — and
loses its `parquet/`; its entry carries `retired: {retired_utc, to, reason}` naming the nearest
kept version, `cc_get_db()` and `cc_get_db` (py) refuse it with that name, and its release page
says so. Pin a consolidated version for reproducibility; pin any other and plan to move.


## A quality flag now reaches every consumer, not just the database

Ralf Goericke reported a 2.18 ml/L oxygen spike at 1,144 m on station 080.0 160.0 in the
station data finder. The value is real and *was already flagged*: bottle 198640 of cast 7644
(cruise 5508BD, R/V Black Douglas, 3 Sep 1955) carries `O_qual = 8` (suspect) in the CalCOFI
Bottle Database. Two gaps let it through. The registry mapped `o_qual` onto `oxygen_ml_l` and
`oxygen_saturation` but not `oxygen_umol_kg` — the form the app plots — so the flag was dropped at
ingest; and no consumer filtered on `measurement_qual` at all.

- `oxygen_umol_kg` now carries `o_qual`; the CTD unit-conversion siblings (`oxygen_umol_kg_1/2`,
  `oxygen_saturation_1/2`, `potential_temperature_1/2`) carry their sensor's `ox1q`/`ox2q`/
  `temp1q`/`temp2q`. The bottle ingest writes `8`, not `8.0`, like the CTD ingest.
- The pre-QC `r_*` bottle types deliberately stay unflagged (Q09 to the provider): code 6 "OK but
  taken from CTD" describes a substitution made *during* QC and would mislabel ~36k rows.
- **Consumers:** one NULL-safe predicate per language — `calcofi4r::cc_qual_ok_sql()` (1.9.0),
  `calcofi4py.qual_ok_sql()` (0.3.7), db-query `qualOkSQL()` — applied in db-viz-station,
  db-viz-hex, ctd-transects, ctd-viz, db-query and the calcofi4r matchers/transects. On this
  release it excludes 35,587 bottle, 6,138 CTD and 51 DIC rows. Flagged values remain in the
  database with their codes; nothing is deleted.

## `cruise_key` is the cruise's designated month, resolved by date span

`YYYY-MM` in `cruise_key` was each cast's or tow's *own* calendar month. A CalCOFI cruise
routinely straddles a month boundary (5508BD ran 7 Aug – 25 Sep 1955; 184 of the 664 bottle
cruises span two months) and the neighbouring month is usually a real cruise of the same ship,
so the shorn-off casts landed on the wrong cruise with no FK ever failing: v2026.08.14 released 664
source bottle cruises as **799** keys, with 5,941 of 35,644 casts on a key their own source
disagrees with. Seven other ingests keyed tows the same way.

- The ichthyo ingest stamps every reference cruise's observed `date_min`/`date_max` (new columns on
  `cruise`); every other ingest resolves span containment first (same ship, ± 3 d — no two cruises
  of one ship overlap), then the source's own designation (bottle `Cruise` = YYYYMM), then the
  event month. Bottle: 799 → **657** keys; 5508BD is 34 casts and 5509BD 22, as in the source.
- The reference wins when sources disagree on a designation (ichthyo calls the 9 Feb – 29 Mar 1984
  Jordan cruise 8403, the bottle database 8402); the bottle notebook reports those cases.
- Second-order bug fixed on the way: the bottle CSV reader typed the all-digit `Cruise` column as
  DOUBLE (`'195508.0'`), which silently defeated the designation step on the first attempt.

## Depth is a coordinate, and it is now bounded

The previous release contained a CTD "cast" with scans at **14,671 m** over a 101 m seafloor — a
fluorometer test dip (`0010_001d`) from the `db-csvs/orig/` folder of the 2000-10 New Horizon
archive, which the tier classifier matched by substring. Its 17,964 dbar `pressure` value had been
deleted by the declared bound; the depth derived from it had not, because bounds apply to values,
not coordinates.

- `sample.seafloor_depth_m` (new column): bilinear GEBCO 2025 depth at every sample position
  (positive down, 0 on land, NULL outside the raster — 99.5 % of samples have one).
- Release gates: a depth beyond 6,500 m (the `pressure` ceiling) or NaN/negative fails the
  release (0 violations); samples deeper than the deepest GEBCO cell within one cell of their
  position + 10 m are reported and ratcheted (`DEPTH_SEAFLOOR_OVER_MAX = 694`, only ever down) —
  all but the test cast are 1949–1975 casts and tows on slopes and canyons with minute-rounded
  positions, so the measurement is fine and the place is imprecise. Never deleted.
- The CTD ingest excludes superseded `orig*`/`uncorrected/` exports (every cast in them is also in
  the top-level file, except that test dip) but keeps `separate_runs/` (20-1104SH's casts 031–036
  exist nowhere else).

## Two calcofi.org archives arrived with casts nobody can place

The 19-9604JD and 19-9608NH FinalQC archives, fetched from calcofi.org for the first time, carry
9,225 "RATHBURN CORE STN" scans with `-99` positions and the station *name* in the line/station
columns. They cannot enter `sample`/`obs`; the ingest now lists and drops them under a 0.2 %
ratchet instead of failing (Q27 asks whether coordinates exist). R's default 60 s download timeout,
which truncated every ~30 MB calcofi.org fetch at 15–25 MB, is now one hour.

**Packages:** calcofi4db 3.20.1, calcofi4r 1.9.0, calcofi4py 0.3.7. **Consumers rebuilt:**
db-viz-station, ctd-transects (both had a broken DuckDB installer step, `| sh` → `| bash`),
db-viz-hex, h3t API, db-viz-cruise, ERDDAP, db-query, ctd-qaqc, and ctd-viz — whose `prep_db.R`
had needed the retired `ctd_cast`/`ctd_thin`/`ctd_summary` parquet since the core consolidation
and had served a 2026-05-15 database for three releases; it now builds from `sample`/`obs`.
**Open:** ERDDAP `flag_values`/`flag_meanings` on `measurement_qual`; netCDF `*_qc` companions.

## Contents (generated)

| table | rows | |
|---|---:|---|
| `cruise` | 691 |  |
| `dataset` | 16 |  |
| `dataset_taxon` | 1,910 |  |
| `grid` | 218 |  |
| `lookup` | 26 |  |
| `measurement_type` | 200 |  |
| `obs` | 26,261,931 | partitioned |
| `obs_attribute` | 452,789 |  |
| `region` | 4 |  |
| `sample` | 1,467,245 |  |
| `sample_measurement` | 589,603 |  |
| `ship` | 49 |  |
| `spatial` | 13,206 |  |
| `spatial_attribute` | 148,461 |  |
| `taxon` | 2,125 |  |
| `taxon_group` | 151 |  |
| `obs_ctd_full` | 271,394,164 | supplemental |
| `obs_mets_full` | 19,927,416 | supplemental |

**18 tables, 320,260,205 rows, 2.10 GB.**

**Datasets (16):** `calcofi_bottle`, `calcofi_ctd-cast`, `calcofi_dic`, `calcofi_mets`, `calcofi_phyllosoma`, `calcofi_phytoplankton`, `cce-lter_euphausiids`, `cce-lter_picoplankton-bacteria`, `cce-lter_zoodb`, `cce-lter_zooscan`, `cdfw_dungeness-crab`, `farallon_bird-mammal`, `sio_mesopelagic-fish`, `sio_pic-zooplankton`, `swfsc_cufes`, `swfsc_ichthyo`

**Validation:** 28 pass / 0 fail / 4 skip (consumer-contract suite, 2026-08-25T14:06:36Z).

**Software:** calcofi4db 3.23.3, calcofi4r 1.12.0.

## Access

```r
con <- calcofi4r::cc_get_db(version = "v2026.08.25")
```
```python
con = calcofi4py.cc_get_db("v2026.08.25")
```
Parquet: `https://storage.googleapis.com/calcofi-db/ducklake/releases/v2026.08.25/parquet/{table}.parquet`; 
full history: [RELEASES.md](https://storage.googleapis.com/calcofi-db/ducklake/releases/RELEASES.md).
