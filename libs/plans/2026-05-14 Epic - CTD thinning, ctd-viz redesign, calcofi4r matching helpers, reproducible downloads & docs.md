# Epic: CTD thinning, ctd-viz redesign, calcofi4r matching helpers, reproducible downloads & docs

## Context

The `calcofi_ctd-cast` parquet dataset is **22.16 GB**, dominated by `ctd_measurement` (15.8 GB, 233 M rows). That size makes the `ctd-viz` Shiny app slow, makes direct GCS querying impractical, and bloats every frozen release. Investigation (DuckDB queries on `data/parquet/calcofi_ctd-cast/`) shows three stacked multipliers in `ctd_measurement`:

1. **Depth resolution** — median 1 m between samples within a cast; profiles to ~3,600 m.
2. **Up + down casts both stored** — `ctd_cast.cast_dir` is ~50/50 U/D (~2.97 M each). `cast_key` encodes direction in its trailing char (`...d`/`...u`); the physical cast key is `(cruise_key, site_key, regexp_replace(cast_key,'[duDU]$',''))` — ~7,067 of 7,074 physical casts have *both* directions, so direction roughly doubles rows.
3. **Measurement-type redundancy** — 53 `measurement_type` values, many redundant variants (16 oxygen, 5 temperature, 6 salinity, …).

This epic builds a durable pipeline-to-visualization process: a thinned `ctd_thin` table that preserves oceanographic structure, a redesigned `ctd-viz` app with linked map/table/plot, `calcofi4r` helper functions that query GCS parquet directly (superseding the retired Postgres Plumber API), reproducible-SQL downloads in `int-app`, and documentation tying it together. Outcome: the headline ctd-cast footprint drops ~40× (15.8 GB → ~0.35 GB), apps and direct queries become fast, and bio↔env matching is portable and reproducible.

**User decisions (locked):** Full epic planned in detail · `ctd_thin` pulls all three levers (10 m depth thin + drop redundant variants + single direction) · adaptive Ramer–Douglas–Peucker (RDP) simplification to preserve inflections · `ctd_thin` becomes the headline table, `ctd_measurement` demoted to supplemental.

## Sequencing & GitHub issues

Dependency order: **#1 → {#2, #3} → #4 → #5**. Create one tracking issue per part:

| Issue | Title | Plan part | Depends on |
|---|---|---|---|
| #1 | CTD-cast frequency report + `ctd_thin` table | Parts 1–2 | — |
| #2 | Redesign `ctd-viz`: resizable panes, linked map/table/plot, cruise stats | Part 3 | #1 |
| #3 | `calcofi4r` bio↔env matching helpers (query GCS parquet directly) | Part 4 | — |
| #4 | `int-app` reproducible downloads (original + summarized + SQL metadata) | Part 5 | #3 |
| #5 | Docs: direct querying, helper functions, reproducibility | Part 6 | #1–#4 |

---

## Part 1 — CTD-cast frequency report (preamble to #1)

Capture the investigation as a documented analysis section near the top of `ingest_calcofi_ctd-cast.qmd` (a `## Measurement Frequency` chunk, `results: asis`), so the rationale for `ctd_thin` lives with the code. Content: the size table, the three multipliers, per-cast depth-interval distribution (median 1 m), the U/D split, and the 53→~15 measurement-type breakdown. Read-only DuckDB queries; renders into the notebook for the record.

---

## Part 2 — `ctd_thin` table (#1)

### 2.1 Schema

`ctd_thin`, hive-partitioned by `cruise_key` like `ctd_measurement`:

| column | type | notes |
|---|---|---|
| `ctd_thin_uuid` | VARCHAR | PK, deterministic md5 via `assign_deterministic_uuids_md5`, key_cols `(ctd_cast_uuid, depth_m, measurement_type)` |
| `ctd_cast_uuid` | VARCHAR | FK → `ctd_cast.ctd_cast_uuid` |
| `depth_m` | DOUBLE | retained depths only |
| `measurement_type` | VARCHAR | canonical types only |
| `measurement_value` | DOUBLE | exact copy from `ctd_measurement` (RDP selects rows, never interpolates) |
| `measurement_qual` | VARCHAR | carried through |
| `cast_dir` | VARCHAR | the single kept direction (`D` preferred, `U` fallback) — lets `ctd-viz` label it |
| `retained_reason` | VARCHAR | `grid` (on 10 m node) or `inflection` (RDP-kept between nodes); `grid` wins ties |
| `cruise_key` | VARCHAR | partition key, carried from `ctd_measurement` |

Register columns in `metadata/calcofi/ctd-cast/metadata_derived.csv` (mirror the `ctd_measurement` block). Add `ctd_thin = "ctd_thin_uuid"` to `ctd_rels$primary_keys` and a FK entry in the `schema` chunk (`ingest_calcofi_ctd-cast.qmd:1372-1379`).

### 2.2 The three levers

**Lever (c) — single direction** (done first; grid + RDP operate on one profile). Resolve the physical cast as `(cruise_key, site_key, cast_base)` where `cast_base = regexp_replace(cast_key,'[duDU]$','')`. Per physical cast pick one `cast_key`: prefer `cast_dir='D'` (resolved via `COALESCE(cast_dir, suffix→D/U)`), fall back to `U`, deterministic `cast_key` tiebreak. Build temp view `_chosen_dir(ctd_cast_uuid, cruise_key, site_key, cast_key, cast_dir)` covering *all* sample-row UUIDs of the chosen `cast_key` (note `ctd_cast` is stored per-sample-row, not per-cast). When `cast_dir` and the `cast_key` suffix disagree (~1,756 rows, 0.06%), trust the explicit `cast_dir`; document it.

**Lever (b) — canonical measurement types.** Add an `is_canonical` boolean column to `metadata/measurement_type.csv` (the notebook already reads this file as `d_meas_type` and exports it as the `measurement_type` reference table — single source of truth, version-controlled, readable downstream). Canonical keep-list (~15): `temperature_ave`, `salinity_ave_corr`, `oxygen_ml_l_ave_sta_corr`, `oxygen_umol_kg_1_sta_corr`, `sigma_theta_1`, `fluorescence_v`, `isus_v`, `pressure`, `dynamic_height`, `specific_volume_anomaly`, `par`, `spar`, `beam_attenuation`, `transmissometer`, `ph`. Dropped: redundant sensor-1/2/ave/corr variants of T/S/O2, derived potential-temperature & est-chlorophyll/nitrate, the 11 sparse `btl_*` bottle-trip types (they belong to the `bottle` dataset). *Default drops `oxygen_saturation_1/2`; one-line revert if the stats panel wants saturation.*

**Lever (a) — 10 m depth thinning** via RDP (next section).

### 2.3 RDP adaptive simplification

**Approach: hybrid — coarse 10 m grid in SQL + RDP refinement in R, chunked by `cruise_key`.** DuckDB has no native RDP and recursive CTEs can't express it cleanly; pure-R over 233 M rows moves too much data. The hybrid bounds data movement: RDP runs only on the **two key variables** (`temperature_ave`, `salinity_ave_corr`) of the chosen-direction profiles; the retained-depth set is the **union across both**, then *all* canonical measurement types at those depths are kept.

Pipeline:
1. **SQL 10 m grid** — `_grid_depths`: per cast, the sample nearest each `ROUND(depth_m/10)*10` node, plus force-keep shallowest & deepest sample.
2. **R RDP kernel** — base-R, no package dependency; iterative-stack form. `rdp_keep(depth, value, eps, max_gap=10)` keeps a point if its perpendicular distance to the local chord exceeds `eps` **OR** the kept-neighbour depth span would exceed `max_gap` (guarantees the 10 m max gap). Per-variable tolerances: `temperature_ave` `eps=0.05` °C, `salinity_ave_corr` `eps=0.01` PSS-78 — a named `rdp_eps` list, printed in the notebook, the primary tunable knob.
3. **Driver** — loop cruise partitions; each worker opens its own DuckDB connection (connections aren't fork-safe), pulls that cruise's two key variables for chosen-direction casts, runs `rdp_keep` per `(ctd_cast_uuid, measurement_type)`, `distinct(ctd_cast_uuid, depth_m)`. Parallelize with `furrr`/`future` if available, else serial `purrr::map_dfr`.
4. **Union** — `_retained_depths` = `_grid_depths` (reason `grid`) ∪ RDP depths not already in grid (reason `inflection`).

### 2.4 Notebook integration — `ingest_calcofi_ctd-cast.qmd`

Insert after the `ctd_summary` chunk (after line 1329), before `measurement_type` (line 1333). New chunks:
- `ctd_thin_verify_pairing` — read-only diagnostic confirming ~7,067 two-direction physical casts (stop if not reproduced).
- `ctd_thin_chosen_dir` — builds `_chosen_dir`.
- `ctd_thin_grid` — builds `_grid_depths`.
- `ctd_thin_rdp` — R: `rdp_keep` kernel, `rdp_eps`, driver → `_rdp_retained`.
- `ctd_thin_assemble` — `_retained_depths` union, then `CREATE TABLE ctd_thin` joining `ctd_measurement` ⋈ `_chosen_dir` ⋈ `_retained_depths` ⋈ canonical-type filter; then `assign_deterministic_uuids_md5(con,"ctd_thin","ctd_thin_uuid", c("ctd_cast_uuid","depth_m","measurement_type"))`.

Also edit: `schema` chunk (PK/FK), `preview` chunk (line 1438 — add `"ctd_thin"`), `measurement_type` validation (lines 1339-1355 — assert `ctd_thin` types are registered and `is_canonical`).

Reuse `calcofi4db` functions as-is: `assign_deterministic_uuids_md5` (`R/wrangle.R:551`), `write_parquet_outputs` (`R/wrangle.R:1310`).

### 2.5 Release pipeline changes

Two edits to the `write_parquet` chunk (`ingest_calcofi_ctd-cast.qmd:1457-1472`):
1. Add `ctd_thin` to `tables`, to `partition_by` (`ctd_thin = "cruise_key"`), and to `sort_by` (`ctd_thin = c("measurement_type","depth_m")`).
2. Change `supplemental = "ctd_wide"` → `supplemental = c("ctd_wide", "ctd_measurement")`.

That single `supplemental` change is the whole demotion. Downstream is automatic: `write_parquet_outputs` writes the manifest flag → `build_release_table_registry` (`calcofi4db/R/workflow.R:587`) marks `ctd_measurement` supplemental → `release_database.qmd:110-111` (`reg_canon |> filter(canonical, !supplemental)`) and `:534-535` drop it from assembled VIEWs and the frozen release → the GCS copy loop skips it. `ctd_measurement` parquet is still *written and synced* (still in `tables=`), just not promoted. **No edits to `release_database.qmd`** (optional cosmetic ERD/notes touch-ups at `:425`, `:489`, `:594`).

### 2.6 Estimated outcome

`233 M rows ÷ ~2 (direction) ÷ ~7 (depth) ÷ ~3.5 (variant drop) ≈ 4–6 M rows ≈ 300–400 MB` partitioned parquet — roughly the size of `ctd_cast`, ~40–50× smaller than `ctd_measurement`. Real number reported by the verification chunk.

---

## Part 3 — `ctd-viz` app redesign (#2)

Files: `/Users/bbest/Github/CalCOFI/apps/ctd-viz/{ui,server,global,prep_db}.R`. Default data source becomes `ctd_thin`; graceful fallback to `ctd_measurement` if a release predates it.

### 3.1 Layout — two vertically-stacked resizable panes

Switch `ui.R` from `page_sidebar()` to `page_fillable(padding=0, gap=0)`. Top pane wrapped in `shinyjqui::jqui_resizable(div(id="pane_top", style="height:45vh; min-height:240px; ..."), options=list(handles="s"))`; bottom pane `div(style="flex:1; min-height:0; ...")`. `shinyjqui` gives a proper south-edge drag handle (bslib has no native splitter; raw CSS `resize` doesn't push a sibling). **Drop the persistent left sidebar** — map controls go in a control bar inside the top pane; plot controls into the Plot subtab header; stats into a third subtab.

### 3.2 Top pane — map

Control bar: `radioButtons("sel_cruise_mode", c("All cruises","By day"))`, `selectInput("sel_cruise")`, `selectInput("sel_day")` (populated from the loaded cruise's distinct dates via `updateSelectInput`), `radioButtons("tog_cast_dir", c("Downcast"="D","Upcast"="U"), inline=TRUE)`, `actionButton("btn_load_cruise")`, `actionButton("btn_reset_selection")`, `textOutput("txt_sel_count")`. Reuse the existing `mapgl` maplibre setup (`server.R:74-123`) and `compute_segments()` (`global.R:81-102`). The up/down toggle: `D`/canonical reads `ctd_thin` (fast); `U` falls back to `ctd_measurement` filtered on `ctd_cast.cast_dir` with a `showNotification`. Everything renders from a day-filtered `rv$map_casts_view`. Remove the old `sl_time_range` slider (superseded by linked selection).

### 3.3 Bottom pane — Table & Plot subtabs

`navset_card_underline(id="subtabs")` with three `nav_panel`s:
- **Table** — `DT` (matches the `oceano` pattern we reuse). Design: `tbl_casts` (one row per cast — the selection driver, `selection="multiple"`) + `tbl_values` (per-measurement detail of selected casts, sortable by time/depth/value).
- **Plot** — the transect plot, moved from static `renderPlot`+`ggExtra` to `plotly`. Refactor `build_transect_plot()` → `build_transect_plotly()`: keep MBA surface → viridis raster → contours → sampling dots → optional bathy polygon → `scale_y_reverse` → date sec-axis, wrap in `ggplotly(source="transect")` with `dragmode="select"` and `customdata = ctd_cast_uuid` on the point trace. **Drop the `ggExtra` marginal histograms** (can't survive `ggplotly`; that info now lives in the stats panel). **Memoize the MBA grid** keyed on `(meas_data, max_depth, interp_n)` so selection-only changes skip `mba.surf`; **debounce** the selection feeding the plot (~400 ms). On `ctd_thin` (≤~50 depths/cast) MBA is sub-second — this is why the redesign depends on #1.
- **Cruise Stats** — `value_box` row + `DT` detail.

### 3.4 Tri-directional linked selection (core)

Single source of truth in `rv`: `sel_uuids` (character vector of selected `ctd_cast_uuid`) + `sel_source` (`"map"|"table"|"plot"|"reset"`). Replaces the old `sel_begin_idx`/`sel_end_idx`/`transect_casts`/`transect_plot`.

**Three writers** (input → store): `observeEvent(input$map_cruise_feature_click)` (toggle uuid), `observeEvent(input$tbl_casts_rows_selected, ignoreNULL=FALSE)`, `observeEvent(event_data("plotly_selected", source="transect"))`. Each sets `sel_source` then `sel_uuids`, guarded by `if (setequal(new, rv$sel_uuids)) return()`.

**Three updaters** (store → view proxy): `observeEvent(rv$sel_uuids, ...)` for map (`maplibre_proxy` + `set_filter` `in` on `ctd_cast_uuid`), table (`DT::dataTableProxy() |> selectRows()`), plot (`renderPlotly` re-render with highlighted dots). Each early-returns when `sel_source` equals its own view.

**Loop prevention** — four guards: (1) `sel_source` tag skips the originating updater; (2) `setequal` no-op guard in every writer terminates the cycle when a proxy push re-fires the widget's input; (3) `ignoreInit=TRUE` everywhere; (4) `freezeReactiveValue(input,"tbl_casts_rows_selected")` + `selectRows(NULL)` on cruise load. Same shape as `oceano/server.R:203-234` (shared `reactiveValues` + observers + proxies), hardened with the explicit source tag because there are three widgets plus plotly.

### 3.5 Cruise stats panel

Reacts to `rv$cruise_key`. Metrics → sources: **n casts / by direction** ← `ctd_cast`; **avg depth interval between retained measurements** ← `ctd_thin` window `LAG(depth_m)`; **avg # repeat values & avg stddev** ← `ctd_summary` (`mean(n_obs)`, `mean(stddev)`); **avg inflection points per cast** ← `ctd_thin` `COUNT(*) FILTER (retained_reason='inflection') / n_casts`; **avg time between casts** ← `ctd_cast` window `LAG(datetime_utc)`; **thinning ratio** ← `ctd_measurement` vs `ctd_thin`. All tiny aggregates — compute in one `observeEvent(rv$cruise_key)`, stash in `rv$cruise_stats`.

### 3.6 Data layer & file changes

`prep_db.R` — add `"ctd_thin"` to `keep_tables` (line 47); guard `cc_get_db(tables=)` with `intersect(keep_tables, info$tables$name)`; `ctd_thin` materializes via the existing `part_tbls` loop if the release marks it partitioned; add ART indexes on `ctd_thin(ctd_cast_uuid)` and `(cruise_key)`; extend the UUID-overlap check (lines 136-143) to `ctd_cast ∩ ctd_thin`. Keep direct `tbl(con,...)`/`dbGetQuery` (status quo — `cc_read_*` helpers each open their own connection; partition pruning on `cruise_key` matters here). `global.R` — add `shinyjqui, DT, plotly` to `librarian::shelf`, drop `ggExtra`; add a `ctd_thin` capability probe (`has_thin`, `thin_has_dir`, `primary_meas_tbl`); filter `meas_vec` to types present in `ctd_thin`; refactor `build_transect_plot` → `build_transect_plotly` with memoized grid; add `cruise_stats()` helper. `ui.R`/`server.R` rewritten per 3.1–3.5.

---

## Part 4 — `calcofi4r` bio↔env matching helpers (#3)

New file `calcofi4r/R/match.R`. Replaces the retired Postgres Plumber endpoints (`zooplankton_biomass`, `itis_ichthyodata`, `ichthyodata`) with functions that query GCS-release parquet directly via the existing `cc_get_db()` remote-views / `.cc_setup_gcs_httpfs()` mechanism (`calcofi4r/R/database.R`).

### 4.1 New functions

- **`cc_match_bio_env(bio, env, max_dist_km=2, max_time_hr=6, join_method=c("nearest_time","nearest_dist","average"), con=NULL, version="latest", collect=TRUE, return_sql=FALSE)`** — core engine. Builds one DuckDB SQL string (CTE: temporal interval join `± max_time_hr` + spatial `ST_Distance` ≤ `max_dist_km`), runs it, attaches the fully-interpolated SQL as `attr(x,"sql")` and `attr(x,"query_meta")` (version, params, GCS source URLs).
- Three wrappers: **`cc_match_zooplankton_biomass()`**, **`cc_match_ichthyo_by_taxon()`** (was `/itis_ichthyodata` — adopt WoRMS `worms_id` + recursive `taxon.parentNameUsageID` subtree, replacing dead ITIS `path` regex), **`cc_match_ichthyo_by_name()`** (was `/ichthyodata` — scientific-name filter).

**Param mapping:** the old `relax_matching` boolean → `max_dist_km` (2 default / 5 relaxed) + `max_time_hr` (6 / 72). `include_bottles` → join `bottle`/`bottle_measurement`. `cruiseymd_min/max`, `stage`, `ITISid`/`species`, `exact_match`, `fields` → direct args.

### 4.2 Matching SQL

Model on the proven on-the-fly matcher in `int-app/app/server.R:1093-1126` / `functions.R::prep_splot()` (interval join + `ST_Distance_Sphere ≤ M`, with `nearest_time`/`nearest_dist`/`average` methods). Read released base tables (`ichthyo`, `net`, `tow`, `site`, `casts`, `bottle`, `bottle_measurement`, `taxon`, …) — the app-materialized `bio_obs`/`env_obs` and the old `uunet2ctd*` tables are **not** in releases, so join base tables. `FROM` clauses use `read_parquet('https://storage.googleapis.com/calcofi-db/.../{table}.parquet')` so the emitted SQL is portable.

### 4.3 Reproducibility hook

`return_sql=TRUE` makes the helpers return/attach the exact SQL — single source of truth consumed by Part 5. `@concept match` roxygen grouping; bump `DESCRIPTION` version. Update the deprecated `get_*()` shims to delegate where sensible.

---

## Part 5 — `int-app` reproducible downloads (#4)

Files: `int-app/app/{server,functions,global,ui}.R`. Current download handler (`server.R:1046-1228`, `write_data()` closure) zips raw + processed CSVs but captures **no SQL**.

New zip layout: `data/original/` (raw bio + env), `data/summarized/` (aggregated: map/hex, time-series, scatterplot, depth-profile), and `query/` with `manifest.json` (release version, parameters, GCS source URLs, row counts), per-file `*.sql` (fully-interpolated, GCS-URL-based, copy-paste runnable), and `REPRODUCE.md` (duckdb-CLI / Python / R snippets). Single source of truth: new `int-app/app/functions.R::build_download_bundle()` calls `cc_match_bio_env(..., return_sql=TRUE)` once per join method — same SQL is executed *and* serialized. So a user can re-run the integration query in any language against the same GCS parquet and get identical rows.

---

## Part 6 — `docs` (#5)

`docs/` is a Quarto book. Two new pages + one expansion:
- **`data-access.qmd`** — direct DuckDB + GCS parquet querying: `httpfs` setup (`.cc_setup_gcs_httpfs` settings), single-file vs hive-partitioned `read_parquet` examples, plus a `## Reproducibility` section explaining the download `query/` folder.
- **`helpers.qmd`** — the `calcofi4r` matching helpers with worked examples.
- **`api.qmd`** — expand the stub; add a "superseded by `calcofi4r` helpers + direct querying" callout.

`_quarto.yml` order: insert `data-access.qmd` and `helpers.qmd` after `db.qmd`, before `api.qmd`. Recurring worked example across all three pages: *"Pacific sardine larvae + temperature, Q1 2023, relaxed matching"* shown three ways — direct SQL, `cc_match_ichthyo_by_name()`, int-app download — all producing identical rows.

---

## Critical files

| Path | Change |
|---|---|
| `workflows/ingest_calcofi_ctd-cast.qmd` | Part 1 report chunk; Part 2 `ctd_thin` chunks after line 1329; edit `schema` 1372-1379, `preview` 1438, `write_parquet` 1457-1472 |
| `workflows/metadata/measurement_type.csv` | add `is_canonical` column |
| `workflows/metadata/calcofi/ctd-cast/metadata_derived.csv` | add `ctd_thin` table + column rows |
| `workflows/release_database.qmd` | no required edits (manifest-driven); optional cosmetic |
| `calcofi4db/R/wrangle.R` | reused as-is (`assign_deterministic_uuids_md5`, `write_parquet_outputs`) |
| `apps/ctd-viz/{ui,server,global,prep_db}.R` | Part 3 redesign |
| `apps/oceano/server.R` | reference pattern (shared `reactiveValues` ↔ DT ↔ map) |
| `calcofi4r/R/match.R` (new), `R/database.R`, `DESCRIPTION`, `NAMESPACE` | Part 4 helpers |
| `int-app/app/{server,functions,global,ui}.R` | Part 5 reproducible downloads |
| `docs/_quarto.yml`, `docs/data-access.qmd` (new), `docs/helpers.qmd` (new), `docs/api.qmd` | Part 6 |

## Verification

**#1 `ctd_thin`** — add a `ctd_thin_verify` chunk asserting: row count lands 4–6 M; every chosen-direction cast with ≥1 canonical measurement has ≥1 `ctd_thin` row; per-cast `MIN`/`MAX(depth_m)` match `ctd_measurement` (endpoints kept); per-cast-per-type max depth gap ≤ 10 m + ε; `measurement_type` ⊆ canonical list; one resolved direction per physical cast; `measurement_value` identical to `ctd_measurement` on matched keys; `ctd_thin_uuid` unique; both `retained_reason` values present (grid dominant). Visual spot-check: overlay full `ctd_measurement` profile vs `ctd_thin` points for `temperature_ave`/`salinity_ave_corr` on ~6 casts (sharp summer thermocline + near-isothermal deep) — thermocline/halocline curvature tracked, flat segments sparse. After `write_parquet_outputs`, confirm `manifest.json` has `"supplemental":["ctd_wide","ctd_measurement"]` and `ctd_thin` partitioned; run `build_release_table_registry(here())` and confirm `ctd_thin` `supplemental==FALSE`, `ctd_measurement` `supplemental==TRUE`.

**#2 `ctd-viz`** — `Rscript prep_db.R latest TRUE` (expect a much smaller DB; `ctd_cast ∩ ctd_thin` overlap > 0; fallback works if `ctd_thin` absent). `R -e 'shiny::runApp("ctd-viz")'`. Test matrix: resizable panes drag + window resize; cruise/daily/up-down selectors change data without error; **tri-directional highlighting** map↔table↔plot in all directions, toggle off, no infinite loop (temporarily `message(rv$sel_source)` — each updater fires ≤ once/action, originating view skipped), reset clears all three, cruise switch leaves no stale selection; dynamic transect re-renders within debounce, 1-cast/empty shows placeholder, oversized selection shows guard; stats `value_box`es cross-check against direct DuckDB queries (`COUNT(DISTINCT ctd_cast_uuid)`, `AVG(n_obs)`, `AVG(stddev)`); measurement dropdown lists only `ctd_thin` types.

**#3 helpers** — run all three wrappers against live GCS parquet; assert `dist_m`/`time_diff_hr` within bounds for default vs relaxed params; round-trip `attr(x,"sql")` through `dbGetQuery` and confirm identical rows.

**#4 downloads** — run `int-app`, download a bundle, re-run `query/integrated.sql` in the `duckdb` CLI, confirm row count + checksum match `data/.../integrated.csv`.

**#5 docs** — `quarto render docs/`; confirm the worked-example SQL in `data-access.qmd` matches `attr(cc_match_ichthyo_by_name(...), "sql")` and all three methods return identical rows.
