# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> General R/Quarto/plumber conventions live in the parent `../../CLAUDE.md`
> (2-space indent, snake_case, `|>`, roxygen2, `librarian::shelf()` outside
> packages, etc.). This file covers what is specific to the `workflows` repo.

## What this repo does

`CalCOFI/workflows` ingests source datasets (zooplankton, ichthyoplankton,
bottle, CTD, DIC, …) into a single integrated CalCOFI database and publishes the
result as Parquet on GCS and as versioned "frozen" DuckLake releases. The heavy
lifting lives in the sibling R package **`calcofi4db`** (`../calcofi4db`); the
notebooks here orchestrate it. `calcofi4r` (`../calcofi4r`) is the user-facing
read package.

Each dataset is one `ingest_{provider}_{dataset}.qmd` Quarto notebook.
`release_database.qmd` is the "caboose" that assembles, validates, freezes, and
uploads the combined release.

## Commands

The pipeline is the source of truth — prefer running notebooks through `targets`
(which renders the `.qmd` and tracks dependencies) over rendering by hand.

```r
# from the workflows/ directory
Rscript -e 'targets::tar_make()'                       # run full pipeline
Rscript -e 'targets::tar_make("ingest_calcofi_dic")'   # run one target
Rscript -e 'targets::tar_visnetwork()'                 # dependency graph
Rscript -e 'targets::tar_outdated()'                   # what would re-run
Rscript -e 'targets::tar_meta(fields = error)'         # inspect target errors
Rscript -e 'targets::tar_invalidate("ingest_swfsc_ichthyo")'  # force re-run a node
Rscript -e 'targets::tar_unblock_process()'            # clear a locked db process

# render a single notebook directly (bypasses dependency tracking)
quarto render ingest_calcofi_dic.qmd

# install/update the engine packages (sibling repos, not on CRAN)
Rscript -e 'remotes::install_github("calcofi/calcofi4db"); remotes::install_github("calcofi/calcofi4r")'

# regenerate the calcofi.io/workflows landing index after adding/removing a notebook
Rscript scripts/build_workflows_index.R
```

There is no test suite or linter in this repo; correctness is enforced by the
`/validate-ingest` checks and the validation chunks inside `release_database.qmd`.
`release_database.qmd` promotes `latest.txt` only after `test_release.qmd`'s
consumer-contract query suite passes (it exercises the app/`calcofi4r` query
shapes against the frozen release, so a schema drift that would break a consumer
fails the release rather than the app).

## Deploy (release → consumers)

After a new release is frozen, uploaded, and promoted to `latest`, the read-only
consumers must be refreshed. They fall in two buckets:

**Shiny apps** live on the CalCOFI server (`ssh calcofi`). Source repos are cloned
to `/share/github/CalCOFI/{repo}`; `shiny-server` runs inside the **`rstudio`**
Docker container and serves them from `/srv/shiny-server/{app}`, which are symlinks
into those repos (e.g. `db-viz-hex → …/db-viz-hex/app`, `datacheck` +
`db-viz-cruise → …/apps/db-viz-cruise`). Deploy per app:

```bash
ssh calcofi                                            # documented in ../server/README.md
# 1. pull source (and calcofi4r, since prep_db.R does devtools::load_all("../calcofi4r"))
git -C /share/github/CalCOFI/calcofi4r  pull --ff-only
git -C /share/github/CalCOFI/db-viz-hex pull --ff-only
git -C /share/github/CalCOFI/apps       pull --ff-only
# 2. rebuild each app's local DuckDB from the new release — MUST run in the
#    rstudio container (it has R + the pkg deps + network to the public GCS bucket)
docker exec -d rstudio bash -lc 'cd /share/github/CalCOFI/db-viz-hex        && Rscript prep_db.R'
docker exec -d rstudio bash -lc 'cd /share/github/CalCOFI/apps/db-viz-cruise && Rscript prep_db.R TRUE'  # TRUE = force rebuild (else skips if db exists)
# 3. restart the app(s) — touch restart.txt in the served app dir
touch /share/github/CalCOFI/db-viz-hex/app/restart.txt
touch /share/github/CalCOFI/apps/db-viz-cruise/restart.txt
```

Notes: `prep_db.R` is heavy (downloads the release parquet + materializes H3 /
join tables), so background it with `docker exec -d` and tail the log. Apps that
read the release **at runtime** (e.g. `apps/cruises`) have no `prep_db.R` and need
only `git pull` + `restart.txt`. Ports 5432-forward warnings from `ssh calcofi`
are harmless.

**Static / hosted consumers** redeploy themselves on push or on release dispatch:
the **station portal** (`db-viz-station`; the archived 2026 UCSB student capstone
`2026-ucsb-station-data-portal` was forked here) rebuilds its coverage
JSON from the DB via GitHub Actions — `gh workflow run refresh.yml --ref main -R CalCOFI/db-viz-station`
(also runs weekly + on release dispatch); **`calcofi.io/query`** and
**`calcofi.io/schema`** are GitHub Pages and rebuild on push. `calcofi4r` reads
`latest` directly, so it needs no deploy — but keep `calcofi4r/R/match.R`
byte-identical with `db-query/lib/match.js` (verified in CI).

## Architecture

### Data flow

```
Google Drive ──rclone──> GCS (gs://calcofi-files/) ──targets──> ingest_*.qmd
   └─ source CSVs                                                    │
                                                                     ▼
            Working DuckLake (gs://calcofi-db/ducklake/working/) <── finalize_ingest()
                                                                     │
                                          release_database.qmd ──────┘
                                          (validate → freeze → upload)
                                                                     ▼
                                   Parquet + frozen release (gs://calcofi-db/)
```

### YAML-driven pipeline (no per-dataset `_targets.R` edits)

`_targets.R` calls `calcofi4db::build_targets_list()`, which parses the
`calcofi:` YAML front-matter block of **every** `*.qmd` in the directory to
discover targets and wire up dependencies. To add a dataset to the pipeline you
add the notebook with a `calcofi:` block (`target_name`, `dependency`, `output`,
`provider`, `dataset`, `dataset_meta`, `tables_owned`, …) — you do **not**
hand-edit the targets list. Use the `exclude =` argument in `_targets.R` to drop
a target temporarily.

### Working DuckLake → frozen release

- Each ingest notebook ends by calling `calcofi4db::finalize_ingest()`, which
  pushes its tables (with provenance columns) into the **Working DuckLake** at
  `gs://calcofi-db/ducklake/working/` and writes `data/parquet/{provider}_{dataset}/`
  outputs + `manifest.json` + `relationships.json`.
- `release_database.qmd` **auto-discovers** `data/parquet/*/relationships.json`
  and outputs (no manual `rels_paths` edits), merges `relationships_cross.csv`,
  validates PK/FK/null/range across the assembled DB, then freezes and uploads a
  versioned release. Read-only consumers use `calcofi4r::cc_get_db()` against the
  frozen release, not the Working DuckLake.

### Consolidated core model (`obs` / `sample` / …)

Per `design_env-bio-consolidation.md`, the ~40 per-dataset triples collapse into a
small **core** family that every consumer reads (built by the `calcofi4db` model
engine, `R/model.R`):

| core table | grain | built by |
|---|---|---|
| `sample` | one row per physical sampling event (site/tow/net/cast/bottle/underway/transect/region_pool); adjacency list via `parent_sample_key` + `root_sample_key` | `build_sample_reference()` |
| `obs` | occurrence-headline long table (`realm` env\|bio, one scalar/row); bio taxon via `taxon_key` (global, `worms:`/`itis:`); env CTD via `ctd_thin` | `append_obs()` |
| `obs_attribute` | sub-occurrence attribution — length/stage frequency (`bin_value`/`bin_label`/`count`) **+ categorical behavior** (was `obs_freq`) | `append_obs_attribute()` |
| `sample_measurement` | event-level effort (net `volume_sampled`/`std_haul_factor`/… ; bottle cast conditions) | `append_sample_measurement()` |
| `obs_ctd_full` | **supplemental** full-resolution CTD scans (~216M rows; hosted + catalog-flagged, excluded from ERD/default list; `cc_get_db(supplemental=TRUE)`) | `append_obs(obs_tbl="obs_ctd_full")` |

Shared taxonomy refs (built by `calcofi4db/R/taxa.R`, replacing the ~7 per-dataset
taxon tables): **`taxon`** (one row per taxon, `taxon_key` = lowercase authority
prefix `worms:<id>` — or `itis:<id>` for birds/Aves — + `worms_id`/`itis_id`/
`gbif_id`/`ncbi_id`/`inat_id`, `parent_taxon_key`, lineage), **`dataset_taxon`**
(per-dataset vocabulary → `taxon_key` crosswalk; `obs` resolves `taxon_key` by
joining it on `(dataset_key, ds_taxa_code)`), **`taxon_group`** (groupings). Built
by `build_taxon_reference()` / `build_dataset_taxon()` / `build_taxon_group()`.
Coarse/composite taxa (cufes eggs, phyllosoma stages, euphausiid family, phyto
functional groups, seabirds/mammals) resolve to real WoRMS/ITIS ids via the
reviewable `metadata/measurement_taxon.csv` + `metadata/taxon_override.csv`.

- **Namespaced keys**: every `sample_key` is `dataset_key:sample_type:id` (globally
  unique across datasets *and* event levels; makes the DIC→bottle dedup fall out).
  `obs.sample_key` FKs into `sample`; `grid_key`/`cruise_key` stay **denormalized**
  on `obs` so rollups `GROUP BY` them without a join.
- **`hex_id`** (H3, `UBIGINT`) is computed on `obs`/`obs_ctd_full` at
  `CC_H3_RES_MAX` (res 10); aggregate coarser via `h3_cell_to_parent(hex_id, res)`
  — no per-resolution columns. `geom` lives on `sample` (and refs), never on `obs`.
- **Phased migration**: Phase 2 (done) materializes the core centrally in
  `release_database.qmd` (chunks `core_tables` + `core_parity`) over the existing
  per-dataset tables, with hard parity assertions. Phase 3 cuts each ingest over to
  emit its slice via the `append_*` helpers, with the per-dataset tables surviving
  as compat VIEWs (see the `emit_core` pattern in `RUNBOOK.md`).
- **`build_grid_reference(con)`** materializes the shared `grid` deterministically
  from `calcofi4r::cc_grid` (promoted out of the ichthyo ingest; non-destructive).

### Metadata registries — single sources of truth (`metadata/`)

| File | Role |
|---|---|
| `field_dictionary.csv` | **Prescriptive** canonical field names/types/units/aliases. New datasets conform; consistency is linted against it. |
| `measurement_type.csv` | Canonical measurement vocabulary (raw measured quantities). `is_canonical` flags the headline types. |
| `dataset.csv` | Registry of datasets (citations, links, PIs, coverage). |
| `dataset_status.csv` | Pipeline-stage tracker, one row per dataset; each skill writes its stage column. |
| `relationships_cross.csv` | Cross-dataset FKs (intra-dataset FKs live in each ingest's `relationships.json`). |
| `metadata/{provider}/{dataset}/` | Per-dataset `tbls_redefine.csv`, `flds_redefine.csv`, `questions.csv`, corrections, etc. |

### The ingest skills loop (`.claude/skills/`, see `RUNBOOK.md`)

```
/explore-dataset {path|url}  →  /generate-metadata {provider} {dataset}
   →  /ingest-new {provider} {dataset}  →  run the notebook
   →  /validate-ingest {provider} {dataset}  →  re-render release_database.qmd
```

Each skill updates the shared tracking artifacts above so the loop is
self-documenting; human review happens at every hand-off. Scaffolds come from
`.claude/skills/templates/`.

## Repo-specific conventions

- **`provider` = the organization curating the data, not the portal that hosts
  it.** CalCOFI program data is `calcofi` even when served from NCEI/EDI/ERDDAP;
  the portal goes in `link_data_source`. Other providers: `swfsc`, `pic`,
  `sccoos`, `cce-lter`.
- **Key-suffix convention (per `../docs/db.qmd`)**: `*_id` = **integer** key
  (surrogate/counter); `*_key` = **string** natural key; `*_seq` =
  auto-incrementing integer sequence. A character-valued identifier must use
  `_key`, never `_id` — e.g. `cruise_key`, `site_key`, `grid_key`, and
  `dataset_key` (= `provider_dataset`, the observation provenance stamp).
- **Identifiers**: `*_uuid` for source tables that mint UUIDs at sea (site, tow,
  net), `cruise_key` natural key `YYYY-MM-NODC`, `site_key`; source integer
  counters where stable (bottle `cast_id`/`bottle_id`); sequential `*_id` only
  for derived/pivoted tables without a source key. UUID-first where available.
- **Tidy long-format measurements**: `measurement_type` / `measurement_value` /
  `measurement_qual`. Historically each dataset built a triple (`{dataset}_sample`
  position/time/FK + `{dataset}_measurement` long values + `{dataset}_summary`
  replicate aggregate). These now **project into the core family** (`sample` /
  `obs` / `obs_attribute` / `sample_measurement`, see above): headline occurrences →
  `obs`, event-level effort → `sample_measurement`, sub-occurrence (bin/count +
  behavior) detail → `obs_attribute`. Per-dataset triple tables survive as compat VIEWs over the core.
- **Records lacking a cast/cruise FK**: use the `calcofi4db` helpers
  `match_by_site_datetime()` then `match_nearest_by_depth()` — do not hand-write
  the matching SQL.
- **DuckDB**: always open via `calcofi4db::get_duckdb_con()` (sets
  `storage_compatibility_version=latest` so CRS-tagged geometry round-trips);
  never strip the geometry column. Known bug: `UPDATE`/`CREATE INDEX` on a table
  with a CRS-tagged `GEOMETRY` column fails through ≥ v1.5.1 — drop/avoid mutating
  `geom`.
- **Notebook chunks**: use `cat()` not `message()`; one `datatable()` call per
  preview (not a loop helper); section headings suffixed with `----` in long
  chunks.

## Layout

- `ingest_*.qmd` — one notebook per dataset (12 of them); `release_database.qmd`
  is the assembler/release step.
- `explore_*.qmd|.Rmd` — exploratory analyses, not part of the pipeline.
- `metadata/` — the registries above.
- `data/` — local working artifacts: `data/parquet/{dataset}/` ingest outputs,
  `calcofi_wrangling.duckdb`, caches. Source CSVs live on GCS/Drive, not in git.
- `scripts/` — `sync_gdrive_to_gcs.sh` (rclone), `build_workflows_index.R`,
  pipeline runners, benchmark generators.
- `_output/` — rendered Quarto HTML + Jekyll landing index, published at
  <https://calcofi.github.io/workflows/>.
- `README_PLAN.qmd` — full design doc (Primary Key Strategy, etc.).
