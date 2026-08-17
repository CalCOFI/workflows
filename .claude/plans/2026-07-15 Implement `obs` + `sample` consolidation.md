# Implement `obs` + `sample` consolidation (design_env-bio-consolidation.md)

## Context

The integrated CalCOFI DB models observations as **per-dataset triples**
(`{ds}_sample` / `{ds}_measurement` / `{ds}_summary`) across ~13 datasets — ~40+
tables, each with a bespoke schema every cross-dataset consumer must relearn. The
design doc's target collapses these into a small **core** set every consumer
reads: one `obs` (long, `realm` env|bio), `obs_freq` (bin/count distributions),
`sample` (adjacency-list event dimension), `sample_measurement` (event-level
long), supplemental `obs_ctd_full`, plus shared refs (`grid`, `cruise`, `ship`,
`measurement_type`, `taxa`, `dataset`).

**Phase 1 is already done**: `release_database.qmd` chunk `obs_views` (L260–360)
builds `dataset` + `v_obs_env`/`v_obs_bio`/`v_obs` VIEWs — the exact projection
logic to promote to materialized tables. This task is design-doc **Phases 2–4**.

Alongside the schema work, three deliverables ride on it: (1) DB-derived temporal
extents on the workflows cards (today statically hard-coded in QMD frontmatter);
(2) a color-coded pipeline DAG at the bottom of the workflows index; (3) a
visually compelling stacked-bar of each dataset's row contribution per table in
`db-schema` — which only becomes meaningful *because* `obs`/`sample` are now
genuinely multi-dataset.

### Decisions locked with the user
- **Phased cutover**: materialize + parity-validate the core tables centrally in
  `release_database.qmd` FIRST (Phase 2), THEN cut each ingest over (Phase 3).
- **Code-ready**: implement all code + run cheap verification (unit tests, render
  `release_database.qmd` core chunks against existing local parquet). The user
  runs full `tar_make()`, the heavy CTD re-ingest, and the GCS release.
- **Repoint consumers too**: `calcofi4r` + `db-viz-hex`/`api-h3t*` + station portal
  + `db-viz-cruise`, keeping per-dataset names alive as compat VIEWs.
- **Chart in the db-schema Tables & Datasets cards**.

### Key path corrections (verified)
- Package is `/Users/bbest/Github/CalCOFI/calcofi4db` (not `~/Github/calcofi4db`).
- Neither `calcofi4db` nor `calcofi4r` has any test infrastructure — bootstrap
  `testthat(3)` from scratch.
- CTD in default `obs` must come from **`ctd_thin`** (~5.5M), not `ctd_measurement`;
  `obs_ctd_full` = `ctd_measurement` (~216M). CTD leaf `sample_key` = `ctd_cast_uuid`
  (not `cast_key` — not unique across `cast_dir`). `dataset_key` = `calcofi_ctd-cast`.
- `cast_condition` uses `condition_type`/`condition_value`; zooscan uses
  `station_date` not `datetime_start_utc`. `h3_latlng_to_cell`/`h3_cell_to_parent`
  need `INSTALL h3 FROM community; LOAD h3`.

---

## Workstream A — `calcofi4db` core-model engine + tests

New file **`calcofi4db/R/model.R`** (`@concept model` — one-file-per-concept
convention). Functions (full signatures/SQL in the design agent output; key shape):

- `build_grid_reference(con, grid_tbl="grid")` — deterministic grid from
  `calcofi4r::cc_grid` + `cc_grid_ctrs`, lifted verbatim from
  `ingest_swfsc_ichthyo.qmd` `mk_grid_v2` (L886–946) + `grid_to_db` (L949–983).
  Writes WKB → native GEOMETRY (safe: fresh untagged column, same pattern used
  today). Non-destructive — `grid_key` values byte-identical.
- `build_sample_reference(con, sample_tbl="sample")` — CTAS `sample` from the
  per-dataset event tables via UNION arms using the design's leaf→parent→root
  mapping (bottle cast+bottle, ctd cast, dic bottle-shared, ichthyo site→tow→net,
  and 8 single-level self-root datasets). Mints `geom = ST_Point(lon,lat)` in the
  CTAS (never `UPDATE` a tagged geom). Private `.sample_arm_self()` keeps the
  single-arm datasets one line each.
- `append_obs()` / `append_obs_freq()` / `append_sample_measurement()` /
  `append_sample()` — take a `select_sql` projection string (data already lives in
  DuckDB; no R round-trip), `CREATE TABLE IF NOT EXISTS` with a fixed typed DDL,
  compute `hex_id` via `.hex_expr(res_max)`, INSERT. Callable from BOTH the release
  (Phase 2) and each ingest (Phase 3). `obs_ctd_full` reuses `append_obs(obs_tbl=)`.
- Config: `CC_H3_RES_MAX <- 10L`; `.load_h3(con)`; `.hex_expr()`; `.ensure_*_schema()`.
- **`obs_id`/PK decision**: `hex_id` is deterministic (computed at write, partition-
  safe). The surrogate `obs_id` is the only non-deterministic key — assign it
  **centrally at release assembly** (ROW_NUMBER over the assembled union), so
  Phase-3 ingests emit obs rows *without* a global id. `append_obs(mint_id=FALSE)`
  supports the ingest path; Phase-2 central materialization uses `mint_id=TRUE`.

Bootstrap **tests** (`usethis::use_testthat(3)`; add `testthat` + `duckdb`/`sf`/
`units`/`calcofi4r` to `Suggests`, `Config/testthat/edition: 3`):
- `helper-fixtures.R`: tiny in-memory DuckDB — 1 site → 1 tow → 3 nets, 2 species,
  abundance + stage + size rows.
- `test-build_sample_reference.R`: per-level count parity + leaf→parent→root
  reconstruction (`N1`→`T1`→`S1`).
- `test-append_obs.R`: abundance headline + `obs_freq` sum-of-bins parity (stage
  bins == abundance; length bins ≤ abundance), `hex_id` present.
- `test-append_sample_measurement.R`: `net` UNPIVOT → 5 event-level rows/net with
  canonical type names.
- `devtools::document()` + `devtools::install()` so notebooks pick up the change.

---

## Workstream B — `release_database.qmd` Phase-2 materialization + parity

New chunk **`core_tables`** (after `obs_views`, ~L360). Reuses the exact `obs_views`
arm SQL (L274–354), extended with `sample_key` + `taxon_id` + `life_stage` +
`measurement_prec`, and **CTD switched to `ctd_thin`**:
1. `build_grid_reference(con_wdl)` (idempotent) + `build_sample_reference(con_wdl)`.
2. `append_obs(...)` — env arms (bottle, ctd_thin, dic) + bio arms (ichthyo base
   rows → `measurement_type='abundance'`, `value=tally`; cufes/euphausiids/
   phyllosoma/zoodb/zooscan/bird_mammal as in `v_obs_bio`).
3. `append_obs(obs_tbl="obs_ctd_full", ...)` — full `ctd_measurement ⨝ ctd_cast`.
4. `append_obs_freq(...)` — ichthyo `stage` + `size`→`body_length` (bin_value=value,
   count=tally, bin_label from `lookup`).
5. `append_sample_measurement(...)` — `net` UNPIVOT (volume_sampled/std_haul_factor/
   prop_sorted/small_plankton_biomass/total_plankton_biomass, aliased to canonical)
   + `cast_condition` (condition_type/value → measurement_type/value).

New chunk **`core_parity`** — hard `stopifnot()` per design Verification (L481–496):
sample-count parity per level; `obs` row-count == Σ per-dataset headline counts
(CTD via `ctd_thin`); `obs_ctd_full` == `ctd_measurement ⨝ ctd_cast`; `obs_freq`
stage-sum == abundance & length-sum ≤ abundance; FK validity of
`dataset_key`/`sample_key`/`grid_key`/`measurement_type` on `obs`, and `sample_key`
on `sample_measurement`/`obs_freq`. A parity break fails the render.

**`cruise_summary` rewrite** (replace L533–558): one `GROUP BY` over `obs ⨝ sample`
using `count(DISTINCT root_sample_key)` per cruise×dataset with `FILTER (WHERE
dataset_key=…)` pivots — replaces the four correlated `COUNT(DISTINCT site_key)`
subqueries; reproduces the 691-row output and generalizes to new datasets.

**Freeze/upload wiring** (`freeze_release` L677–731, `upload_frozen` L806+): add
`obs`/`sample`/`obs_freq`/`sample_measurement`/`obs_ctd_full` to derived exports;
partition `obs` by `dataset_key`, `obs_ctd_full` by `cruise_key`; sort
`(grid_key, depth_min_m, measurement_type)`; mark `obs_ctd_full` **supplemental**;
add `sample` to `all_geom_tables` (L190) so its `geom` round-trips.

**Compat VIEWs**: in Phase 2 the per-dataset tables still physically exist (they're
the projection source), so nothing breaks. The per-dataset-name-as-VIEW-over-core
layer is a Phase-3 concern (Workstream D) — the release must define those VIEWs
only once ingests stop emitting the physical per-dataset tables.

---

## Workstream C — `measurement_type` registry + release contributions

`metadata/measurement_type.csv`: rename `size`→`body_length` (L47), **delete**
`tally` (L48), add `abundance` + 5 event-level types (`volume_sampled`,
`std_haul_factor`, `prop_sorted`, `small_plankton_biomass`,
`total_plankton_biomass`). These are load-bearing — the `obs.measurement_type` FK
parity check fails without `abundance`.

**Release-derived contributions** (feeds Workstream E's chart): the core tables are
release-derived, so their per-dataset row breakdown isn't in any per-ingest
`metadata.json`. In `release_database.qmd`, compute
`SELECT dataset_key, count(*) FROM {obs,sample,obs_freq,sample_measurement} GROUP BY 1`
and inject into the release `metadata.json` `contributions` block (extend
`merge_metadata_json()` in `calcofi4db/R/wrangle.R` L2373+ to accept a
`derived_contributions` arg, or write these entries directly before upload at
L892–952). This makes `obs`/`sample` show genuine multi-dataset stacks.

---

## Workstream D — Phase-3 per-ingest cutover (all notebooks)

Canonical `emit_core` block added to each `ingest_*.qmd` after its per-dataset
tables are built, before `write_parquet_outputs`:
```r
build_grid_reference(con)                    # idempotent shared ref
append_sample(con, "<this dataset's sample arms>")
append_sample_measurement(con, "<effort select or skip>")
append_obs(con, "<headline occurrence select>", mint_id = FALSE)
append_obs_freq(con, "<bin/count select or skip>")
# per-dataset tables become VIEWs over core:
dbExecute(con, "CREATE OR REPLACE VIEW net AS SELECT sample_key AS net_uuid, ... FROM sample WHERE ...")
```
`write_parquet_outputs` then exports the core tables (VIEWs are excluded); release
assembly reads all datasets' `obs` partitions and assigns global `obs_id`.

Sequencing by complexity: **ichthyo** (3-level hierarchy + all three grains +
grid promotion) → **bottle** (obs + `cast_condition`→`sample_measurement`, carries
`measurement_prec`) → **dic** (bottle-shared `sample_key` dedup rule) → the 8
single-arm datasets (cufes, euphausiids, phyllosoma, zoodb, zooscan, bird_mammal,
pic_zooplankton, phytoplankton — phyto has NULL `grid_key`).

**Grid promotion**: make `ingest_spatial.qmd` the canonical `grid` owner (call
`build_grid_reference(con)` there, add `{table: grid, shared: true}` to its
`tables_owned`); replace ichthyo's `mk_grid_v2`+`grid_to_db` chunks with
`build_grid_reference(con)` and drop `grid` from ichthyo `tables_owned`. Registry
"first ingest wins" makes spatial the source. Non-destructive.

Update each notebook's `calcofi:` `tables_owned` to reflect the core tables it now
contributes to; per-dataset names documented as detail VIEWs.

---

## Workstream E — db-schema stacked-bar contribution chart

Pure additive JS/CSS/HTML in `/Users/bbest/Github/CalCOFI/db-schema` (Jekyll, no
framework, no charting lib). Data already published in `metadata.json`:
`contributions[table].by_dataset[].{rows,pct,provider_dataset}` + `total_rows`,
colored via `erd_legend` → `State.datasetColor` (`app.js` L19–28, 255–259).

- Add a `renderContribBar(table)` helper emitting a horizontal stacked bar of
  inline `<div>`/SVG segments (segment width ∝ rows, color = dataset), with
  `title`/hover → `"{provider_dataset}: {fmtInt(rows)} rows ({pct}%)"`.
- Inject into the **Tables cards** (next to the rows/cols chips, `app.js` L517–544)
  and the **Datasets cards** (augment `datasetTablesHtml`, L671–707).
- Reuse `.ds-swatch`/`.erd-legend` styling; theme via CSS vars only (survives the
  light/dark toggle). Handle the `over_attributed` case (measurement_type sums
  >100%) with a capped bar + a small warn badge.

---

## Workstream F — workflows index: DB temporal + pipeline DAG

`scripts/build_workflows_index.R` + `_output/`:
- **DB-derived temporal**: in `release_database.qmd`, compute
  `SELECT dataset_key, min(datetime), max(datetime) FROM obs GROUP BY 1` and persist
  as `datasets.<key>.coverage_temporal_observed` in the release `metadata.json`.
  Change `build_workflows_index.R` L93 to read that from the latest release
  `metadata.json` (fallback to static `dm$coverage_temporal`). `index.html` L38
  template unchanged.
- **DAG** (port from `MarineSensitivity/workflows`, but grouped **into subgraphs by
  workflow_type** per the user's ask): add a `dag_mermaid` key to `workflows.yml`
  built from `targets::tar_mermaid(targets_only=TRUE)`, post-processed by a
  `color_dag()` that (a) wraps nodes in `subgraph ingest/publish/release/reference/
  spatial` blocks by `classify()` category and (b) appends a `classDef` per type
  (colors from the category map / `cc$erd$color`). Preserve MS's "committed DAG
  fallback" when `targets` is absent in CI. Add a `#dag` `<section>` + a
  `<script type="module">` mermaid init + `<a href="#dag">` nav link +
  `.wf-dag`/`.dag-frame` CSS to `_output/index.html`/`style.css` (portable from MS).

---

## Workstream G — repoint consumers (compat VIEWs keep old names alive)

- **calcofi4r** (`/Users/bbest/Github/CalCOFI/calcofi4r`): add `cc_read_obs()`,
  `cc_read_sample()`, `cc_read_obs_freq()`, `cc_read_sample_measurement()`,
  `cc_read_ctd_full()` (`R/read.R`). Existing per-dataset readers keep working via
  compat VIEWs (zero change). **`R/match.R`**: collapse the env 3-table join and
  bio 5-table join to single-scan reads of `obs` (realm filters) — and **mirror
  every edit 1:1 into `db-query/lib/match.js`** + bump its `VERSION` (hard
  coupling). Delete/repoint the stale `get_sp`/`get_env` in `R/functions.R`.
  Bootstrap `tests/testthat` here too.
- **db-viz-hex** (`/Users/bbest/Github/CalCOFI/db-viz-hex`): `prep_db.R` — drop the
  `hex_h3res1..10` wide-column precompute; read core `obs` (carries `hex_id`) and
  derive coarser cells at query time. `app/functions.R` + `functions_h3t.R`: replace
  `starts_with("hex_h3res")` / `hex_h3res{{res}}` with
  `h3_cell_to_parent(hex_id, {{res}})` and `FROM bio_obs`/`env_obs` →
  `FROM obs WHERE realm=…`. **api-h3t / api-h3t-py**: SQL-agnostic — only update the
  `/h3t/meta` advertisement (`hex_id` + `h3_cell_to_parent` convention).
- **station portal** (`2026-ucsb-station-data-portal/scripts/build_stations.sql`):
  delete the hand-rolled per-dataset UNION (L30–116); `CREATE TEMP VIEW obs AS
  SELECT … FROM read_parquet('…/obs.parquet')`. Downstream `cov`/`ybin`/`mbin`/`ds`/
  `srv`/`COPY` already key on `grid_key,dataset_key` — unchanged (only
  `depth_min_m`/`depth_max_m` aliasing).
- **db-viz-cruise** (`/Users/bbest/Github/CalCOFI/apps/db-viz-cruise`): shrink
  `prep_db.R` to read core `obs`; rename columns in `global.R`/`server.R`
  (`dataset`→`dataset_key`, `id`/`site_key`→`sample_key`); drop the per-scan CTD
  special case (subsumed by `sample`/`obs_ctd_full`).

---

## Workstream H — docs & skills

- `workflows/CLAUDE.md` + root `../../CLAUDE.md` refs: replace the per-dataset-triple
  description with the core model (`obs`/`obs_freq`/`sample`/`sample_measurement` +
  refs), the `append_*`/`build_*_reference` helpers, grid promotion, `hex_id`.
- `README_PLAN.qmd` / `README.md`: fold the design into the architecture section;
  update the Primary Key Strategy for `sample_key`/`obs_id`/`hex_id`.
- `.claude/skills/` (`/ingest-new`, `/validate-ingest`, `/generate-metadata`,
  `templates/`, `RUNBOOK.md`): the ingest loop now emits core tables via
  `emit_core`; validation asserts core parity.

---

## Workstream I — re-render notebooks + rebuild index

After B–H land: render all `*.qmd` → HTML and regenerate the index. Per the
code-ready decision, I render what's cheap (`release_database.qmd` core chunks
against existing local `data/parquet/*`, the light ingests) and run
`scripts/build_workflows_index.R`; the user runs the heavy CTD re-ingest, full
`tar_make()`, and the freeze+GCS release.

---

## Recommended execution order

1. **A** (calcofi4db engine + tests) — the foundation everything calls.
2. **B + C** (release Phase-2 materialization, parity, measurement_type, release
   contributions) — produces `obs`/`sample`/etc. in a release with **zero re-ingest**;
   unblocks E and F. This is the de-risking backbone.
3. **E + F** (chart, temporal, DAG) — now have real multi-dataset core tables.
4. **D** (per-ingest cutover) — the largest/riskiest; parity in B keeps validating
   until every ingest is migrated.
5. **G** (consumers) — after core tables are frozen in a release.
6. **H + I** (docs, re-render).

Steps 1–3 are a coherent, independently valuable milestone (consolidated release +
reporting) and a natural first check-in before the notebook rewrites.

---

## Verification

- **Unit**: `devtools::test()` in `calcofi4db` (and `calcofi4r`) — new fixtures
  assert sample-count parity, leaf→parent→root reconstruction, obs_freq
  sum-of-bins, sample_measurement effort projection.
- **End-to-end Phase 2 (feasible locally, no re-ingest)**: render
  `release_database.qmd`'s `core_tables` + `core_parity` chunks against the existing
  `data/parquet/*` VIEWs; the `stopifnot` parity assertions passing IS the
  end-to-end proof that the materialized `obs`/`sample`/`obs_freq`/
  `sample_measurement` reproduce the per-dataset tables.
- **Chart**: build the `db-schema` site (`jekyll build`) against the new release
  `metadata.json`; confirm the `obs`/`sample` bars render multi-segment, colors
  match `erd_legend`, and hover shows `provider_dataset` + rows + pct.
- **Index/DAG**: run `scripts/build_workflows_index.R`; confirm `dag_mermaid` is
  produced with type subgraphs + colors and that card `coverage` values now come
  from `coverage_temporal_observed`. Open the rendered `_output/index.html`.
- **Consumers**: `cc_read_obs()` returns rows against a local release; `match.R`
  and `db-query/lib/match.js` produce identical SQL for a sample query; the station
  portal `build_stations.sql` yields the same `stations.json` shape.
- **Full pipeline + release + heavy CTD render**: run by the user
  (`targets::tar_make()`, freeze, GCS upload).
