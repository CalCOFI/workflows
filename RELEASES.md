# CalCOFI integrated database — release notes

What changed between releases and why. One section per release, newest first; the
`# Unreleased` section collects changes since the last release and becomes the next release's
section when `release_database.qmd` runs. Each release's `RELEASE_NOTES.md` on GCS is the
section below plus a generated appendix (tables, rows, datasets, validation gates, package
versions). Conventions: see `CLAUDE.md` § "RELEASES.md is not optional".

# Unreleased

## Every dataset's citation, license and DOI now carries the evidence for it, or a filed question

Eight of sixteen datasets shipped `citation_main` empty and thirteen shipped `license` empty, with
nothing checked against the source. Filled from each dataset's own authority (EDI's cite service +
its EML `intellectualRights`, ERDDAP `.das` globals, NCEI/DataCite landing pages, the DataZoo/
zoodb/zooscan portal policy panels), never invented: **calcofi_phytoplankton** and
**calcofi_phyllosoma** gained their EDI citation + DOI + license (CC0-1.0 and `custom`
respectively — reading the actual EML `intellectualRights` matters: EDI packages are *not*
uniformly CC-BY-4.0, and assuming so would have mislabeled both); **cce-lter_euphausiids** gained
its EDI citation + DOI + `custom` license + an `acknowledgement` field (new key, additive) carrying
the EML's required credit text; **cce-lter_zoodb** and **cce-lter_zooscan** gained a `custom`
license from their portals' Data Use Policy panels and had the NSF credit prose that was sitting in
`citation_others` moved into the new `acknowledgement` field (`citation_others` is reserved for
*additional* citations, not credit prose); **farallon_bird-mammal** and **swfsc_cufes** gained a
`custom` license pointing at their ERDDAP `.das`/data-sharing-agreement source. `calcofi_dic`,
`sio_mesopelagic-fish` and `cdfw_dungeness-crab` had their free-text `"CC BY 4.0"` normalized to
the SPDX id `CC-BY-4.0`; `dic` and `mesopelagic-fish` also gained a bare `doi:` field pulled from
their existing citation strings.

Where the source states nothing, the field stays empty rather than guessing, and a `proposed`
`questions.csv` row carries the value we'd apply once confirmed: a formal citation for zoodb (Q10),
zooscan (Q06), farallon (Q09), cufes (Q06) and pic-zooplankton (Q08, plus its license); a license
for cce-lter_picoplankton-bacteria (Q06); a citation year/URL, `US-PD` license and `pi_names` for
swfsc_ichthyo (Q10–Q12, the citation proposal reflecting the CSV export we actually ingest, dated
2025-03-24); a `CC-BY-4.0` license and `pi_names` for calcofi_bottle (Q10–Q11), calcofi_ctd-cast
(Q28–Q29, naming both Rasmus Swalethorp and Benjamin Gire) and calcofi_mets (Q29–Q30) — calcofi.org
states no license for any of its three datasets. 14 `questions.csv` rows filed across 10 files, all
`status = proposed`, `related_table = dataset`.

New additive `dataset_meta` keys used here: `doi`, `license_url`, `acknowledgement` — the columns
themselves (`ingest_yaml_to_dataset_df()` / `.dataset_entry()`) and `calcofi4db::
check_dataset_citation()` are WS-A0's, not yet merged onto this branch, so that check was not run;
`Rscript scripts/build_workflows_index.R` passes with and without `CALCOFI_SKIP_LINK_CHECK=1`
(22 links, 22 OK). No `dataset_name` / `category` / `color` / `coverage_*` changed, and no ingest
was re-run — `release_database.qmd` reads this YAML directly.

## The boundary layers describe themselves (`spatial_layers.json`)

The release gains one sidecar beside `coverage.json`: the boundary-layer registry
(`metadata/spatial_layers.csv` — the 19 drawable layers, their PMTiles archives, default symbology
and provenance) joined with what only the release knows: each layer's feature count, bbox, its
distinct names (the Explorer's by-name palette) and how many root samples fall inside it
(`sample_spatial`). The CalCOFI Explorer's Layers card reads this instead of hard-coding the layer
list, so a row Erin adds to the registry reaches the app at the next release with no code change
(calcofi4db 3.28.0 `build_spatial_layers()`). Not a table: `catalog.json` and consumers of the
parquet are untouched.

## The seafloor stamp runs anywhere, and an unexplained NULL fails the release

`seafloor_depth_m` is sampled from GEBCO 2025, and until now that meant one laptop's local
933 MB tile (`CALCOFI_GEBCO_TIF`'s default) — a machine without it could not run the release at
all. The same grid is now published as a streamable Cloud-Optimized GeoTIFF
(`gs://calcofi-db/bathymetry/gebco_2025_sub_ice_n90_w180_e90_cog.tif`), and the `depth_coverage`
chunk falls back to it over `/vsicurl/` range reads when no local file is present
(calcofi4db 3.27.0 `sample_seafloor()` accepts URL sources).

With that, a NULL `seafloor_depth_m` stops being one undifferentiated count: every NULL is now
classified (`calcofi4db::check_seafloor_nulls()`) as *no coordinates*, *NaN coordinate*,
*outside the GEBCO source tile* (all three are the owning ingest's `questions.csv` material —
at v2026.08.25 they were 1,360 ichthyo positions east of −90° plus 71 METS rows with no
latitude), or *inside the tile and still NULL* — which can only be a regression in the sampling
itself and now **fails the release**. Consumers see no schema change.

Alongside (not release content, but the same D29 change): `gebco_2025_calcofi.tif`, the crop
`calcofi4r::cc_bathy()` serves, was re-cut from lon −127 → −116.8 × lat 29.3 → 38.4 to
**lon −165 → −100 × lat 15 → 56** (Int16 COG) so all 360,568 released positions that fell outside
it — 24.7 %, silently reading `NA` depth — now sample a real value; `cc_bathy_depth()` warns
about the remainder instead of keeping quiet (calcofi4r 1.16.0).

## One climatology for every anomaly

Two products drew the same section — line 90, July 2026, temperature — and disagreed by the whole
signal: [ctd-transects](https://calcofi.io/ctd-transects/) showed +1 to +3.9 °C through the upper
100 m, the [Explorer](https://calcofi.io/explore/?lens=section) looked like nothing. The ocean was
not the reason. Each product computed its own baseline: ctd-transects a 1993–2013 monthly mean at 5 m
over *one arbitrary cast per grid cell*; the Explorer a mean over **all calendar months** of whatever
year range the slider held — a map of the seasonal cycle (line 90 surface: January 15.2, July 18.3,
annual 16.8 °C), which hid 1–1.5 °C of the winter and spring warmth outright; and
`calcofi4r::cc_climatology()` a third copy. The Explorer also painted +2 °C **blue**: Plotly's built-in
`RdBu` runs blue → red, the reverse of the ColorBrewer scale its name suggests.

The release now ships **`climatology`** (`calcofi4db::build_climatology()` ≥ 3.26.0): a plain mean of
the env realm of `obs` per **dataset × station × calendar month × 10 m floor depth bin × measurement
type** over **1993–2013** (Rasmus Swalethorp's CCIEA window; both phases of the 1997–99 ENSO inside it,
ends before the 2014–16 heatwave; stamped on every row as `clim_yr_min`/`clim_yr_max`), kept only where
**≥ 3 distinct cruises** contribute (`n_cruises` — a floor in observations is met by one cruise's four
casts in a nearshore cell), with `clim_n` and `clim_sd`. Partitioned by `measurement_type` like
`obs_env`. Why 10 m and not 5: `obs` carries the *thinned* CTD series (10 m grid + inflection points),
so at 5 m the off-grid bins held a third of the casts, sampled exactly where the profile bends, and
their means sat visibly off their neighbours' (station 60, July: 14.27 °C between 15.39 and 15.04).
ctd-transects, the Explorer's Sections lens and `cc_climatology()` all subtract this table now; a cell
that is absent has no baseline and its anomaly is blank, never zero. Under it the three products agree:
July 2026 on line 90 is +1.3 to +1.4 °C in the upper 50 m and +0.6 °C at 200–500 m by every reading.

**Consumers:** additive — one new default table with FKs to `grid`, `dataset` and `measurement_type`;
`cc_climatology()` returns the table's cells (with `n_cruises`) when the release has one and bins depth
by 10 m floor bins (was 5 m rounded) — `cc_transect_section()` follows. Not yet fixed: both section
products key a station on `grid_key`, and nearshore cells hold 2–4 real stations (`st30-ln90` = 90.30,
90.28, 90.27.7, 88.5/30.1); `sample.site_key` is the station and the sections will move to it.

## `coverage.json` carries taxa and categories, and `measurement_type` says which category and variable a type belongs to

The explorer's organism list waited on a 22 MB download and its variables were grouped by a keyword rule
ported from the station app. `coverage.json` (`calcofi4db::build_coverage()` ≥ 3.25.0) now carries
`taxa[]` — one row per taxon of the bio realm with names, rank, class, `n_obs`, year span, life stages and
its datasets — and `variables[].category` / `.variable` from two new `metadata/measurement_type.csv`
columns: **`category`** (one of the twelve in the new **`metadata/category.csv`** registry, which
`build_workflows_index.R` now enforces on every ingest's `category:`) and **`variable`** (the
cross-dataset crosswalk: the bottle's `temperature` and the CTD's `temperature_ave` are one variable).
Both are set with `calcofi4db::declare_measurement_fields()`, never a bare `write_csv`.

**Consumers:** additive — `coverage.json` gains keys, `measurement_type` gains two nullable columns.

## The release now cuts browser-shaped objects, and effort travels with every bio observation

Four new tables and one sidecar, built at release time by calcofi4db 3.24.0 for the CalCOFI Explorer
(plan `2026-08-28 CalCOFI Explorer …`, D4/D8), and available to every consumer:

- **`obs_bio`** (supplemental, one ~22 MB object) — the bio realm of `obs`, slim, with `root_id`,
  `year`/`quarter`/`depth_bin`, `units`, `qual_ok` (`cc_qual_ok_sql()` evaluated at release), the gear
  and effort of the observation's own sample (`tow_type`, `std_haul_factor`, `prop_sorted`,
  `volume_sampled_m3`), and **two canonical densities derived once and named** —
  `density_per_10m2` (areal: `count × std_haul_factor / prop_sorted` for C1/CB/CV/PV tows, published
  per-m² × 10) and `density_per_1000m3` (volumetric: `count / prop_sorted / volume_sampled × 1000` for
  any tow with a volume, published per-1000 m³ as is) — plus `effort_class`
  (`count_with_effort` 482 k rows, 1 dataset · `raw_count_no_effort` 355 k, 5 datasets ·
  `density_as_published` 155 k · `other_unit` 263 k). Areal and volumetric are never converted into
  each other. The expression is `calcofi4r::cc_density_sql()` ≡ `calcofi4py.density_sql()` ≡ the
  explorer's `sql/density.sql`, fixture-pinned byte for byte. `hex7` is one `UBIGINT` H3 cell at res 7;
  coarser parents are bit arithmetic (`h3_parent_sql()`), so a browser needs no `h3` extension.
- **`obs_env`** (supplemental, hive-partitioned by `measurement_type`: 84 objects, ≤ 10 MB each, 287 MB
  in all) — the env realm with the same columns, so one variable is one fetch.
- **`sample_root`** (supplemental) — one row per root sampling event with a dense, deterministic
  integer `root_id`; the join key the three objects share, and the cruise tracks.
- **`sample_spatial`** (core) — exact per-root-sample polygon membership for every polygon layer of
  `spatial`, computed once, chunked per layer (≈1 M memberships over 15 polygon layers; the four
  maritime-limit/port layers are lines and points and hold nothing). Replaces the per-app spatial join
  that exhausted the 16 GB server.
- **`coverage.json`** — n obs and root samples by dataset, dataset × station × year, dataset × year and
  dataset × variable (181 KB): the explorer's first paint and Task 14's variable-based inventory.

`metadata/measurement_type.csv` gains **`denominator`** (`area` | `volume` | `none`) so the vocabulary
is registry-owned. The default view of a taxon is the denominator that covers the most datasets *with
effort* — never largest-n (`cc_default_stage()` / `cc_default_denominator()`): Pacific sardine opens as
larva · per 10 m² · swfsc_ichthyo (6,158 rows; 1,262 manta rows excluded, available per 1000 m³), not
one number averaged over 62,898 rows in three units.

**Missing effort is an ingest task, and is now filed** — `swfsc_cufes` Q05 (pump volume), `calcofi_phyllosoma`
Q05 (volume filtered, proposed), `sio_mesopelagic-fish` Q08 (VolFilt, proposed), `farallon_bird-mammal` Q08
(transect area → a per-km² denominator, proposed), `cdfw_dungeness-crab` Q13; until they land those rows are
`raw_count_no_effort` and the app says so. **Also found by the cut:** every `swfsc_ichthyo` tow/net sample
has `depth_max_m = NULL`, so a net tow cannot be drawn as the integrated span it is (`swfsc_ichthyo` Q08).

**Consumers:** `cc_get_db()` gets `sample_spatial` by default; `obs_bio`/`obs_env`/`sample_root` are
`supplemental = TRUE` (opt in). `test_release.qmd` gains seven contract rows over the new objects.


# v2026.08.25 (2026-08-25)

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

# v2026.08.14 (2026-08-14)

## CDFW Dungeness crab megalopae enter the release

Held out since 2026-07-30 behind `in_release: false` while permission was open; CDFW confirmed
publication (CC BY 4.0, Laura Rogers-Bennett primary provider, CDFW citable custodian), so
`cdfw_dungeness-crab` is the 16th dataset — 310 sorted samples and a 2,011-sample sorting log,
with the sorters credited in the citation ("a record of looking, not just of finding"). Its two
staged measurement types moved into the shared registry; its 14 orphan cruises are exempted as an
inventory grain rather than allowed.

## Phytoplankton regions have real geometry, derived not invented

The four Venrick pooling regions are now polygons derived from the station-membership list
(`+proj=calcofi` places all 34 stations; convex hulls were measured and rejected), which resolves
phytoplankton Q01. Four taxa the join had missed now resolve.

## Vernacular names, dataset display metadata, and a readable promotion

- `common_name` reached the release only from a dataset's own vocabulary — 1,208 of 2,125 taxa
  (57 %) had none. WoRMS returns an unordered bag of vernaculars with no preferred flag, so names
  are chosen only when unambiguous (43 picked); *Dungeness crab* is the worked example.
- Dataset display metadata (name, short name, description, links) is authored once in each
  ingest's front-matter; `metadata/dataset.csv` is deprecated.
- Promotion (`latest.txt`) is now gated on a *readable* release: `check_release_complete()`
  requires `catalog.json`/`metadata.json`/`relationships.json`, and the pointer is read through
  the authenticated API rather than the CDN, after 2026-08-14 promoted a release with no catalog.
- The workflows index build fails on a dead or non-URL `link_data_source`; `swfsc_ichthyo` had
  pointed at a 404 for months.

**Rows:** `obs` 26.45 M → 25.62 M and `obs_ctd_full` 274.9 M → 259.3 M as the CTD archive moved
off Google Drive to local scratch and the extraction completeness check began comparing member
counts (a Drive placeholder reads as an empty file with no error). **Packages:** calcofi4db
3.15.0–3.19.0, calcofi4r 1.7.0 (a time-series gap is drawn as a gap, not a measured zero).

# v2026.08.11 (2026-08-11)

## Ungridded observations are released

Observations whose position resolves no CalCOFI grid cell (transits, historical stations outside
the modern pattern) now reach `obs` with `grid_key` NULL, across all 14 ingests, and
`check_ungridded_obs()` reports them per dataset; each dataset carries a provider question asking
whether they are genuinely off-grid or coordinate errors.

## A position is a pair

CUFES samples were positioned at the segment *start* with the end coordinate resolved from a
different source; the sample position is now the segment midpoint and both coordinates come from
one source (calcofi4db 3.16.1 `append_obs()`). `obs_mets_full` gains the NaN-position guard that
`obs` already had (53 rows).

## The release refuses to re-cut the version consumers are reading

v2026.08.10 was republished under the same tag on 2026-08-11, failed `test_release`, and promotion
was correctly withheld — but `latest.txt` already pointed at the overwritten path, so consumers
read unverified data. `release_database.qmd` now stops if `release_version` equals the promoted
version unless `CALCOFI_ALLOW_REPUBLISH=true`.

**Packages:** calcofi4db 3.13.1 (NaN/Inf coordinates → NULL), 3.14.0 (line/station ↔ lon/lat).

# v2026.08.10 (2026-08-10)

## Ten CTD cruises are back

v2026.08.08 lost every observation of ten cruises while keeping their casts, and no FK check could
see it: the CTD ingest extracted archives into a Google Drive folder, Drive evicted files to
cloud-only placeholders mid-sync, and `read_csv()` returned a 0-row tibble with no error — while
the Drive-minted ` 2.csv` conflict copies broke the cast-direction parse. `check_cruise_coverage()`
(calcofi4db 3.12.0) now fails a release on a cruise that leaves `obs` but keeps its casts; 142
cruises restored (`obs_ctd_full` +13.7 M rows).

## METS longitudes have their sign

The unsigned `Longitude_W` was released as positive (125.8 °W read as 124.9 °E in the measured
coverage); it is negated, answering mets_20. The orphan-cruise ratchet tightened 5 → 1.

## The pipeline stops invalidating itself

`release_database` had declared the whole `data/releases` directory as its output, so
`test_release` writing `test_results.json` beside it made the release permanently outdated and
every later `tar_make()` re-froze and re-uploaded an already-promoted release. It now declares a
deterministic `_release_stamp.json`; `check_nested_outputs()` refuses any directory output.

**Packages:** calcofi4db 3.12.0, 3.13.0; calcofi4r 1.6.0 (seafloor sampled along the transect
track, not at stations).

# v2026.08.08 (2026-08-08)

## Declared bounds are enforced, and 31k impossible values leave

`valid_min`/`valid_max` in `metadata/measurement_type.csv` had been emitted as netCDF attributes
and shown on the schema site for months while nothing compared a value to them. v2026.08.07
shipped ~31k impossible CTD values (pH to −10, `oxygen_ml_l_1` to −79.5, `temperature_ave` to
−47.6) — the fallout of METS erasing curated bounds from the shared registry on its write-back.
`check_measurement_bounds()` now runs per dataset at ingest and across `obs` *and* the
supplemental tables at release; `out_of_range` fails the release, `undeclared` is ratcheted
(73 → 30 of 98 (dataset, type) pairs declared a bound at this release). Enforcement is a separate
`drop_out_of_bounds()` so a bound must be agreed before it deletes.

## Two-sensor averages are repaired, not averaged with −99

`TempAve` was averaged with the −99 missing marker when one sensor failed (Q21, cruise 2607SH);
each sensor is validated individually and the repair generalised to every two-sensor average.
Q22 records the surface-soak artifact.

**Rows:** `obs` 26.27 M → 25.39 M, `obs_ctd_full` 274.9 M → 261.1 M (the impossible values).
**Packages:** calcofi4db 3.10.0 (`declare_measurement_bounds()`), 3.11.0 (no directory outputs).

# v2026.08.07 (2026-08-07)

## The Wilkinson CTD archive and three data stages

JRW's Shared-Drive `_CTDFinalDB` archives are ingested alongside calcofi.org's, adding 45 gap
cruises; `data_stage` splits into `final`, `preliminary_with_bottle` and
`preliminary_without_bottle` (the sensor-only tier reaches the release with no salinity or oxygen
corrections). `obs_ctd_full` 212.4 M → 274.9 M rows; `obs` +6.2 M.

## Taxon authorities are cross-referenced and lineages completed

Birds key `itis:` because WoRMS bird taxonomy lags, but nothing populated `worms_id` for them, so
a consumer joining on `worms_id` matched zero rows for every seabird and marine mammal (92 % of the
Farallon census). `ensure_taxon_xref()` crosswalks TSN ↔ AphiaID by exact id; `taxonomic_status`
is fetched with `status_checked` instead of stamped "accepted"; ancestors are first-class taxa with
rank order from one vocabulary. Four new release gates cover it.

## Coverage is measured, never asserted

`coverage_temporal`/`coverage_spatial` were hand-written in each ingest and seven of fifteen were
wrong at v2026.08.06; `observed_coverage()` now measures both from the assembled core and the
measurement surfaces coordinate bugs the prose hid. Bulk parquet moved outside the repo to
`$CALCOFI_STAGE_DIR`; the JSON sidecars stay tracked in git.

**Packages:** calcofi4db 3.5.0–3.9.3; calcofi4r 1.5.0–1.5.4 (shared transect/climatology/anomaly
functions, summer-anomaly vignette).

# v2026.08.04 – v2026.08.06 (2026-08-04 … 2026-08-06)

Three closely spaced releases while consumer deployment became part of the pipeline: consumers
sync automatically on promotion, `deploy_consumers` is a real target that reports which release
each consumer is *actually* serving (the h3t API held its old database file open across a symlink
flip), ERDDAP deploys from `publish_to-erddap.qmd`, and the public release index is regenerated on
promotion. Spatial layers gained attributes (`spatial` 3,373 → 13,206 features; `spatial_attribute`
40k → 148k). v2026.08.05 dropped 17,187 duplicate/invalid `sample` rows. Four WoRMS/taxonomic-status
gates added (28 → 32).

# v2026.08.03 (2026-08-03)

## All released geometry is tagged EPSG:4326

`ST_Point()` tags `OGC:CRS84` while `ST_Read()` over GeoJSON tags `EPSG:4326`; DuckDB refuses
`ST_Intersects` across the two, so a `sample` → `spatial` join errored outright. Geometry is
normalised immediately before the freeze — and exported locally, because most tables are uploaded
by GCS server-side copy and never pass through the connection (the check passed while the published
`grid.parquet` stayed `OGC:CRS84`). `_spatial`/`_spatial_attr` become `spatial`/`spatial_attribute`
with a real `spatial_key`. Five spatial gates added (23 → 28). Partitioned uploads use `rsync`, so a
retry resumes; full-scan parquet is clustered by cast. Rows unchanged; 2.19 → 2.16 GB.

# v2026.08.02 (2026-08-02)

## A full rebuild on the core-only model

Every dataset's core projection SQL moved out of calcofi4db into the ingest notebook that owns it
(calcofi4db 3.2.0 deleted the `switch(dataset_key, …)` arms — the release had re-derived the core
from its own inline copy and the two copies drifted, each divergence a silent data error).
`obs_mets_full` and `taxon` are catalogued; spatial tables renamed. `obs` 18.7 M → 20.1 M.

# v2026.07.30 (2026-07-30)

## Four new datasets, the CTD QA/QC engine, and generic publishing

- **Datasets 12 → 15:** CCE-LTER euphausiids, CCE-LTER picoplankton/bacteria, SIO mesopelagic
  fish, and the METS underway series (`obs_mets_full`, 19.9 M rows). CDFW Dungeness crab is
  ingested but held out of the release behind a new `in_release: false` flag pending permission.
- **CTD QA/QC engine:** a declarative rule registry (`metadata/qc_rules/`), climatology-anomaly,
  seafloor-bathymetry and full-resolution profile rules, a Findings report with an input-fingerprint
  fast path, and a generated QA/QC protocol document.
- **Publishing:** one dataset-agnostic `publish_to-netcdf` + `publish_to-erddap` for every
  dataset; whole-dataset CF NetCDF to `calcofi-files-public`; `storage.calcofi.io` browsing.
- **Registries:** the hydro-master Access database reconciled against the release; a
  write-round-trip bug that let nine ingests corrupt `measurement_type.csv` with literal `"NA"`
  fixed; `-99` sentinels stripped from CTD; `data_stage` on `sample`; one question registry
  convention (`questions.csv`, `read_questions()`).

**Packages:** calcofi4db 2.11.0 → 3.4.0; calcofi4r 1.4.0–1.4.3 (non-blocking usage analytics).

# v2026.07.17 (2026-07-17)

Serving-layer release, no row change: thinned CTD served as CF Profile NetCDF on ERDDAP, profiles
keyed by station occupation (`ord_occ`) rather than per scan; `tow_type` (net gear) promoted onto
the core `sample` table (calcofi4db 2.10.0); the station portal refresh repointed to
`CalCOFI/db-viz-station`.

# v2026.07.16 (2026-07-16)

## One taxonomy

Eight per-dataset taxon tables (`species`, `taxa_rank`, `phyto_taxon`, `zoodb_taxon`,
`zooscan_taxon`, `bird_mammal_species`, `bird_mammal_behavior`, `obs_freq`) are replaced by
`taxon` (`worms:`/`itis:` keys), `dataset_taxon` (per-dataset crosswalk) and `taxon_group`, and
`obs_freq` becomes `obs_attribute` (size/stage frequencies + behaviour). 22 → 17 tables.
**Consumers:** the consumer contract rekeyed from `species_id` to `taxon_key`.

# v2026.07.15 (2026-07-15)

## The consolidated core model

The ~40 per-dataset triples (`{dataset}_sample` / `_measurement` / `_summary`) collapse into
`sample` (one row per sampling event, adjacency list via `parent_sample_key`), `obs` (one scalar
per row, `realm` env|bio), `sample_measurement` (event-level effort) and the supplemental
`obs_ctd_full` (full-resolution CTD scans, ~216 M rows, opt-in). Per-dataset tables survive as
compat views. Namespaced `sample_key` = `dataset_key:sample_type:id`; `hex_id` (H3 res 10) on
`obs`. `obs_ctd_full` complete for the first time.

# v2026.06.26 (2026-06-26)

CCE-LTER ZooDB holoplankton and ZooScan PRPOOS ingested with reproducible acquisition scripts;
`measurement_type` → dataset membership derived rather than asserted.

# v2026.06.07 – v2026.06.08 (2026-06-07 … 2026-06-08)

Phytoplankton (Venrick, region-pooled) added; 44 tables; full ingest + release re-run with
refreshed outputs, DB and PMTiles.

# v2026.05.14 – v2026.05.20 (2026-05-14 … 2026-05-20)

`ctd_thin` introduced as the headline CTD series (one direction, canonical types, 10 m grid +
inflections + bottle depths); schema browser site and the `test_release` → promote pipeline with
`test_results.json`; ERD and `metadata.json` sidecars from v2026.05.19.

# v2026.04.02 – v2026.04.08 (2026-04-02 … 2026-04-08)

Invertebrates folded into ichthyo; spatial tables consolidated and uploaded to GCS; pipeline
optimised with VIEWs and GCS server-side copy (60+ min → ~4 min); `inverts` → `invert`,
`dic_measurement_summary` → `dic_summary`.

# v2026.03 – v2026.03.26 (2026-03 … 2026-03-26)

First releases on the versioned GCS layout (`ducklake/releases/{version}/`), `relationships.json`
sidecar from v2026.03.14; bottle, CTD, DIC and ichthyo as per-dataset tables.

# v2026.02 (2026-02-05)

First frozen release: 17 tables, 13.4 M rows, 81 MB — ichthyo merged with bottle.
