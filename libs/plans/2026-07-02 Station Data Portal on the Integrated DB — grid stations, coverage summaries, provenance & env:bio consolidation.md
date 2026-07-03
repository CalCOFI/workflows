# Station Data Portal on the Integrated DB — grid stations, coverage summaries, provenance & env/bio consolidation

## Context

`../2026-ucsb-station-data-portal` is a **static** discovery site: `build_stations.py` maps a hardcoded 115-row `metadata/stations.csv` to datasets via ERDDAP `distinct(sta_id)` or an "applies-to-all-stations" fallback, and emits `public/data/*.json`. It holds no real observations and shows no coverage — just outbound query-URLs to external portals.

We want it to instead present **real per-station coverage summaries from the CalCOFI integrated database**, keyed to the regularized station grid (the `grid` table, derived from `calcofi4r::cc_grid` Voronoi cells). It is the **station/grid** member of a trio of spatial summarizations of the same integrated DB:

- **`db-viz-hex`** (formerly int-app) — H3 hexagon summarization
- **`db-viz-cruise`** (formerly datacheck) — observations by cruise track
- **this portal** — station-grid summarization

All three read the integrated DB and precompute a compact summary artifact; the apps stay fast (no on-the-fly queries). Per the user: **regenerate the portal's summary file on every DB update.**

Two supporting goals: (1) formalize provenance with a single `dataset_id = provider_dataset` on observations; (2) deliver a design for consolidating per-dataset observation tables into an **env/bio split**.

**Decisions (confirmed):** portal build = DuckDB-over-GCS-parquet static build; DB work = non-destructive enablers now + written design for the deeper merge; consolidation target = two obs tables (`obs_env` + `obs_bio`).

Grid lineage question is **resolved**: `grid` is not missing — it's minted in `ingest_swfsc_ichthyo.qmd` (`grid_to_db` chunk) from `cc_grid` + `cc_grid_ctrs`; 9+ datasets FK into `grid.grid_key` (`metadata/relationships_cross.csv`). Its smell is that a *shared reference* is coupled to one dataset's ingest — addressed in Part B.

---

## Part A — Portal refactor: grid-station coverage summaries (implement)

**Data source:** DuckDB + `httpfs` over `gs://calcofi-db/ingest/{provider_dataset}/{table}.parquet` plus the `grid` table, producing static JSON at build time. Mirrors the proven `apps/db-viz-cruise/prep_db.R` union pattern (whose `dataset` column already *is* `provider_dataset`).

**A0 — Crosswalk (do first).** Build a reviewable mapping between the *existing portal* and the *integrated DB*, since names differ — the portal uses external-portal ids (`siocalcofiHydroBottle`, `erdCalCOFIlrvcnt`, `zoodb/save.php`, `/euphausiid/save.php`) and a harvested variable catalog, while the DB uses `provider_dataset` (`calcofi_bottle`, `swfsc_ichthyo`) and the `measurement_type`/`taxa` vocab. Two crosswalks, each classifying every row **matching / new (in DB, not portal) / missing (in portal, not in DB)**:
- **datasets** — `data_sources.csv.dataset_id` ↔ `provider_dataset` (keep the external access URL per dataset)
- **variables** — portal `variables.json` entries ↔ `measurement_type` (env) / taxon (bio)

Emit `metadata/crosswalk_datasets.csv` + `metadata/crosswalk_variables.csv` in the portal repo. This drives the rewrite, seeds the new `provider_dataset` column in `data_sources.csv`, and surfaces gaps: portal datasets not yet in the DB = ingest backlog; DB datasets/variables not yet surfaced = to add to the portal. No silent drops — every existing entry must resolve to a class.

**Stations = the `grid` table** (replaces `metadata/stations.csv`): `grid_key`, `line`, `station`, lat/lon from `geom_ctr`, `pattern`, `shore`, `zone`, `area_km2`. Keep the legacy `"LLL.L SSS.S" station_id` as a derived field (from `line`+`station`) for back-compat; expose `pattern` as a filter (standard/extended/historical).

**Per station × dataset coverage** — one templated aggregation per dataset over its `{ds}_sample`(+`{ds}_measurement`) parquet, `GROUP BY grid_key`, then `UNION ALL BY NAME` across datasets:
- `time_min`/`time_max` (datetime extent)
- `depth_min`/`depth_max` (per-dataset depth column: bottle/CTD/DIC = profile depth from measurement; net-tow datasets = tow depth range)
- `n_obs` (measurement rows), `n_samples` (distinct sample key)
- `n_surveys` = `COUNT(DISTINCT cruise_key)`
- year histogram (`COUNT` per `year(datetime)`) → overall coverage
- month histogram (per `month(datetime)`, 1–12) → seasonal coverage
- `dataset_id` = `provider_dataset` (provenance)

Then roll up to **per-station totals across datasets** + keep per-dataset breakdown. Enumerating "all the queries" = { per-dataset summary template ×N datasets; the cross-dataset UNION; per-station rollup; year-bin query; month-bin query; the variables/measurement_type coverage query }.

**Variables catalog** from the `measurement_type` registry (`measurement_type`, `units`, `is_canonical`, `_source_datasets`) + per-dataset taxa, each tagged with `dataset_id` and the stations where present. Replaces the harvested `variables.json`. Keep external **access** links (ERDDAP/EDI/zoodb/euphausiid) per dataset by mapping `data_sources.csv` external ids ↔ `provider_dataset`, so the portal still offers source access, now backed by real coverage.

**Refresh mechanism (every DB update):** a single build script (Python + `duckdb`) regenerates `public/data/{stations,variables,search_index}.json`. Trigger on release via a GitHub Action in the portal repo (schedule + `repository_dispatch` from `release_database.qmd`/`test_release.qmd`, exactly like the existing `bump-default-version.yml` dispatch to `db-query`). Commit/deploy the JSON (GitHub Pages/Vercel).

**Key files (Part A):**
- `2026-ucsb-station-data-portal/scripts/build_stations.py` → rewrite to DuckDB grid+coverage build (drop ERDDAP `distinct` / spatial-approx)
- `.../scripts/build_vars.py` → rewrite as `measurement_type`-driven; `build_search.py`/`build_data.py` → adjust to new schema; `requirements.txt` → add `duckdb`
- `.../metadata/stations.csv` → derived from `grid` (or removed); `data_sources.csv` → add `provider_dataset` mapping column
- `.../public/app.js`, `index.html`, `styles.css` → render coverage (time/depth ranges, obs/survey counts, year & month coverage bars) on station click
- `.../metadata/crosswalk_datasets.csv` + `crosswalk_variables.csv` → new crosswalk artifacts (A0)
- Reference pattern: `apps/db-viz-cruise/prep_db.R`; new `.github/workflows/` build+deploy action

**Branch & delivery:** do all portal work on a new branch of `2026-ucsb-station-data-portal` (e.g. `feat/integrated-db-coverage`) → PR, not commits to `main`; branch the DB-side repos (`calcofi4db`, `workflows`) similarly for Part B. Preview-deploy from the branch before merge.

---

## Part B — Non-destructive DB enablers (implement now)

1. **`dataset_id = provider_dataset`** — add one `dataset_id` column (e.g. `swfsc_ichthyo`) derived from the existing `_ingest_provider`/`_ingest_dataset` provenance, on observation tables (sample + measurement). Add a `dataset` reference table keyed by `dataset_id` (from `metadata/dataset.csv`) so `dataset_id` FKs to it. Register in `metadata/field_dictionary.csv` + `metadata/relationships_cross.csv`.
2. **Promote `grid` to a first-class shared reference** — move its build out of `ingest_swfsc_ichthyo.qmd` into a shared step (a `calcofi4db` reference-builder or a tiny reference ingest), so it no longer depends on ichthyo running first (mirrors `cruise`/`ship`/`measurement_type`). Keep `grid_key` stable.
3. **Unified observation VIEWs** — add `v_obs_env` and `v_obs_bio` (+ optional `v_obs`) over existing per-dataset tables, projecting the common columns (`dataset_id`, `grid_key`, `cruise_key`, `latitude`, `longitude`, `datetime`, `depth`, `measurement_type`, `measurement_value`, `measurement_qual`; `taxon`/`life_stage` for bio). These power the Part A build and prove the target model non-destructively.

**Key files (Part B):** `calcofi4db/R/workflow.R` (finalize/integrate: `dataset_id`, grid promotion), `workflows/release_database.qmd` (assemble grid + dataset refs, obs views, validation), `workflows/ingest_swfsc_ichthyo.qmd` (remove grid ownership), `metadata/{field_dictionary,relationships_cross,dataset}.csv`.

---

## Part C — Env/bio consolidation (written design deliverable)

Deliver a phased design (new section in `workflows/README_PLAN.qmd` or a design note) targeting **two consolidated long tables**:

- **`obs_env`** — physical/chem: `dataset_id, grid_key, cruise_key, cast/site key, lat, lon, datetime, depth (profile), measurement_type, measurement_value, measurement_qual`. Sources: bottle, ctd-cast, dic.
- **`obs_bio`** — species/biology: `dataset_id, grid_key, cruise_key, tow/net key, lat, lon, datetime, depth_min/depth_max (tow-integrated), taxon (species_id/aphia_id), life_stage, measurement_type (abundance/biomass/tally), measurement_value, measurement_qual`. Sources: ichthyo, cufes, euphausiids, zooplankton, zooscan, zoodb, phytoplankton, phyllosoma, bird_mammal.
- Shared refs: `grid`, `cruise`, `ship`, `measurement_type`, `taxa`, `dataset`.

**Shift to ingestion:** each ingest maps into `obs_env`/`obs_bio` with `dataset_id` + `grid_key`; the per-dataset `{ds}_sample`/`_measurement`/`_summary` triple generalizes to shared long tables + per-dataset summary views. **Shift to querying:** one coverage/join surface per realm; cross-dataset queries on `grid_key`/`cruise_key`/`measurement_type`/`taxon`; all three summarization apps (hex/cruise/grid) read the same `obs_env`/`obs_bio`. **Migration:** views-first (Part B) → backfill consolidated tables → cut ingests over → deprecate redundant per-dataset tables. **Edge cases to document:** depth semantics (profile vs tow-integrated), datasets carrying both env sensors + catch, region-pooled phytoplankton (no `grid_key`), `_qual`/`_prec` columns, CRS-tagged geometry.

---

## Verification

- Review `crosswalk_datasets.csv` / `crosswalk_variables.csv`: every existing portal dataset & variable resolves to matching / new / missing — no silent drops; gaps (ingest backlog, unsurfaced DB datasets) are listed.
- Run the portal build against GCS parquet; confirm `stations.json` = grid-keyed stations with `time_min/max`, `depth_min/max`, `n_obs`/`n_samples`/`n_surveys`, and year + month bins; spot-check a core Line-80 station against known coverage; cross-check row counts vs `db-viz-cruise`'s `obs` table for sanity.
- Serve `public/` locally (`python -m http.server`), click stations, verify coverage + year/month bars render and external access links resolve.
- After `release_database.qmd`: verify `dataset_id` populated and FKs to the `dataset` ref; `grid` builds independent of ichthyo; `v_obs_env`/`v_obs_bio` return expected counts; validation chunk passes.
- Confirm the release → portal-rebuild dispatch fires and redeploys updated JSON.
