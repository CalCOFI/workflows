---
name: release-run
description: "Cutting a release with release_database.qmd and test_release.qmd — staging runs (CALCOFI_RELEASE_PREFIX + CALCOFI_TABLES_PREFIX, what a staging run must and must not touch), latest.txt promotion, the RELEASES.md contract and promote_unreleased(), the core_single + gcs_prefix = NA rule for anything rebuilt in con_wdl, EPSG:4326 normalization, NaN coordinates, the depth gates and seafloor ratchet, measured coverage. Load before staging, cutting, testing or promoting a release, or editing a release validation chunk."
---

# Cutting a release

> Moved verbatim out of `CLAUDE.md` on 2026-09-08 so the rules stay in every session's context and the mechanics and incidents behind them load only when needed. `CLAUDE.md` summarizes each rule and names this skill.

## Staging runs and promotion

There is no test suite or linter in this repo; correctness is enforced by the
`/validate-ingest` checks and the validation chunks inside `release_database.qmd`.
**A staging run must be tested as a staging run.** `test_release.qmd` picks the version
from `data/releases-staging/` when `CALCOFI_RELEASE_PREFIX` is a staging prefix (since
2026-09-04); before that it always read `data/releases/`, so the 2026-08-28 staging run "passed"
by testing the promoted v2026.08.25. A staging run that leaves no `test_results.json` under
`data/releases-staging/<version>/` did not test itself. **And it must not touch the real prefix
either:** the same file's `save_results` chunk hardcoded `ducklake/releases/` in its upload path
while every other path read the env var, so the 2026-09-04 staging test wrote a phantom
`releases/v2026.09.04/test_results.json` to the real bucket (deleted by hand). Before a staging
run, `grep -n '"ducklake/releases' *.qmd` must show only `Sys.getenv(..., "ducklake/releases")`
defaults, never a literal in a path; and after it,
`gcloud storage ls gs://calcofi-db/ducklake/releases/ | grep <version>` must be empty.
**And a staging run must not write the shared content store**: set
`CALCOFI_TABLES_PREFIX=ducklake-staging/tables` alongside the release prefix
(`release_database.qmd` now stops otherwise). Canonical objects are keyed by *row signature*,
and a row-identical re-export is not byte-identical for `obs_ctd_full`, `obs_mets_full` or
`obs`'s CTD/METS partitions, so the 2026-09-04 staging run's uploads into `ducklake/tables/`
replaced 173 of v2026.08.25's objects with different bytes; the real run then server-side
copied those bytes into `releases/v2026.09.04/parquet/` while its catalog described the local
files, and `scripts/verify_release_objects.R` flagged all 173. calcofi4db 4.0.3's
`freeze_plan()` records the copied object's bytes/sha256 (not the local export's) so the
catalog is true either way; the prefix rule is what keeps the store immutable.

`release_database.qmd` promotes `latest.txt` only after `test_release.qmd`'s
consumer-contract query suite passes (it exercises the app/`calcofi4r` query
shapes against the frozen release, so a schema drift that would break a consumer
fails the release rather than the app).


## RELEASES.md is not optional (the database's NEWS file)

`RELEASES.md` at the repo root documents **what changed between database releases and
why** — one `# vYYYY.MM.DD (date)` section per release, newest first, with `# Unreleased`
collecting changes until the next cut. It is uploaded to
`gs://calcofi-db/ducklake/releases/RELEASES.md`, and each version's `RELEASE_NOTES.md`
(what db-schema's "release notes" modal and `calcofi4r::cc_release_notes()` show) is its
section plus a **generated appendix** (tables/rows from `catalog.json`, datasets, the
consumer-contract result, package versions). Before 2026-08-25 `RELEASE_NOTES.md` was a
`paste0()` template whose only live content was row counts; it listed four datasets while
sixteen shipped and named tables retired months earlier.

- **Every change that alters release content adds to `# Unreleased` in the same commit**
  — a schema column, a key derivation, a validation gate, a dataset entering or leaving, a
  data fix. Headings are declarative sentences ("Depth is a coordinate, and it is now
  bounded"), bodies say what was wrong, what is true now, by how much, and which
  provider question it raised; consumer-facing breakage gets a `**Consumers:**` line.
- `release_database.qmd`'s `release_notes_narrative` chunk (before the freeze) renames a
  non-empty `# Unreleased` to the release and **stops the release** if no section for
  `release_version` exists — `calcofi4db::promote_unreleased()`. Do not bypass it by
  writing a one-line section; the packages' `NEWS.md` rule has the same intent.
- Notes are not data. `Rscript scripts/publish_release_notes.R [version | --all]`
  (`calcofi4db::publish_release_notes()`) re-renders and re-uploads `RELEASE_NOTES.md` for
  any version at any time — an edit between the freeze and `test_release`, a correction to
  a promoted version, or the full backfill — without touching parquet, `catalog.json` or
  `latest.txt`. `test_release.qmd` re-publishes the promoted version's notes so the
  appendix carries the validation result.
- A range heading (`# v2026.08.04 – v2026.08.06`) documents several closely spaced
  releases at once; each of those versions' `RELEASE_NOTES.md` says so.


## What the release rebuilds must also be what it uploads

- **All released geometry is tagged `EPSG:4326`**, normalized in
  `release_database.qmd` immediately before the freeze — not left to whatever each
  ingest happened to mint. `ST_Point(lon, lat)` tags `OGC:CRS84` while `ST_Read()`
  over GeoJSON tags `EPSG:4326`; they label the same WGS 84 lon/lat, but **DuckDB
  refuses `ST_Intersects` across differing tags**, so a `sample`→`spatial` join
  errored outright until v2026.08.03. `ST_SetCRS` relabels without transforming.
  Two traps this walked into, both worth remembering:
  - **Normalizing in the connection is not enough.** Most tables are uploaded by a
    GCS server-side copy straight from the ingest bucket and never pass through
    `con_wdl`, so the check passed while the published `grid.parquet` stayed
    `OGC:CRS84`. Any CRS-normalized table must also be exported locally and marked
    `gcs_prefix = NA` so the uploader takes the local copy.

    **This generalizes past CRS: anything `release_database.qmd` rebuilds in
    `con_wdl` must appear in BOTH `core_single` (so a local parquet exists) and the
    `gcs_prefix = NA` list (so the uploader takes it). One without the other either
    ships the ingest's copy or fails the upload.** `dataset` had neither through
    `v2026.08.11`: every ingest writes its own full `dataset` shard, so the registry
    handed the table a `gcs_prefix` and the release copied one arbitrary ingest's
    version — publishing that ingest's row count rather than the release's (one
    dataset was `in_release: false` at the time), **no `dataset_key` column at all**,
    and the *asserted*
    `coverage_temporal`/`coverage_spatial` rather than the values
    `observed_coverage()` measures. Nothing caught it, because every check between
    the build and the freeze reads `con_wdl`, where the table was correct. The
    published bytes are the only thing worth asserting on.
  - **A consumer that coerces one side to match the other will break on the next
    release.** Normalize *both* sides of a spatial join (`db-viz-hex/prep_db.R`).
- **`NaN` is not `NULL`, and it corrupts spatial queries — not just its own row.**
  A `NaN` coordinate survives `IS NOT NULL`, and `ST_Point(NaN, NaN)` returns a
  real non-NULL `GEOMETRY` that survives `geom IS NOT NULL` too. Worse, its
  presence makes `ST_Intersects` return **different counts at different thread
  counts**, dropping valid unrelated pairs: v2026.08.02 shipped 1,590 such rows and
  every spatial join over it silently under-counted by a different amount on every
  machine. `append_sample()` (calcofi4db ≥ 3.4.2) normalizes `NaN`/`Inf` to `NULL`
  before minting geometry, and `release_database.qmd` does the same at release time
  so a fix does not require re-running all 16 ingests. Test `isnan()`/`isinf()`
  explicitly; never trust `IS NOT NULL` for a coordinate.

## Depth is a coordinate; bound it as one

`check_measurement_bounds()` bounds a **value**. v2026.08.14 shipped a CTD cast
with scans at 14,671 m over a 101 m seafloor: the 17,964 dbar `pressure` was
deleted by its bound and the depth derived from it was not, because
`drop_out_of_bounds()` cannot see a coordinate column. (The cast was JRW's
fluorometer test dip from `20-0010NH_CTDFinalQC/db-csvs/orig/`, a superseded
export the tier classifier matched by substring; it now excludes `orig*` and
`uncorrected/` folders — but **not** every subfolder: `20-1104SH`'s
`separate_runs/` holds six casts that exist nowhere else.)

`release_database.qmd`'s `depth_coverage` chunk (calcofi4db ≥ 3.20.0):
- `check_depth_bounds()` — NaN, negative, or beyond **`CC_DEPTH_MAX_M` (6,500 m,
  the `pressure` ceiling)** on `sample`, `obs` and the supplementals **fails the
  release**.
- `add_sample_seafloor()` stamps `seafloor_depth_m` (bilinear GEBCO 2025,
  positive down, land 0, NA outside the raster) on `sample` — the raster is the
  local master at `$CALCOFI_GEBCO_TIF`; consumers get the column, not the raster.
- `check_depth_vs_seafloor()` — each root sample's deepest attributed depth
  against the deepest GEBCO cell within one cell of its position **+ 10 m** is a
  **report and a ratchet** (`DEPTH_SEAFLOOR_OVER_MAX`, only ever down), never a
  delete: 695 of 412,640 root samples fail it and all but the CTD cast are within
  1.2 km, on slopes and canyons with minute-rounded 1949–1975 positions. The
  measurement is fine; the place is imprecise. That is a `questions.csv` row for
  the owning ingest, filed from `/validate-ingest`'s D3 section.


## Coverage is measured, never asserted

**Do not add `coverage_temporal` / `coverage_spatial` to a `dataset_meta`
block.** `calcofi4db::observed_coverage()` measures both from the assembled core
in `release_database.qmd`'s `dataset_coverage` chunk, writes them into the
release `dataset` table and into `metadata.json` as
`coverage_temporal_observed` / `coverage_spatial_observed` / `coverage_bbox`,
and `scripts/build_workflows_index.R` puts them on the calcofi.io/workflows
cards.

A hand-written extent is authored once while the data grows underneath it. At
`v2026.08.06` seven of fifteen were wrong: `cce-lter_zoodb` claimed data through
2021-05 that ends 2015-04, `calcofi_phyllosoma` stopped a year short of its own
rows, `calcofi_bottle` was a month late at the start, and three said `"present"`
while stalling in 2019, 2022 and 2023. `ingest_calcofi_ctd-cast.qmd` had already
been hand-corrected twice and was stale again.

**One exception remains, and it carries a comment saying why.**
`calcofi_phytoplankton` is region-pooled — real coordinates, zero datetimes — so
it asserts `coverage_temporal` only and measures the spatial half like everyone
else. (`cdfw_dungeness-crab` was the second; both its keys were deleted when it
entered the release on 2026-08-14, exactly as this rule said to.) If you add
another, the bar is "the data provably cannot answer", not "I know the answer".

The measurement is honest about what it finds, which means it surfaces
coordinate bugs the prose hid — `calcofi_mets` measures `125.8°W–124.9°E` (a
dropped minus sign) and `swfsc_ichthyo` reaches latitude `0.0` (null island).
Fix those at the source; do not paper over them by re-asserting a tidy bbox.


