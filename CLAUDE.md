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
  `measurement_qual`. A base `{dataset}_sample` table holds only position/time/FK
  columns; a `{dataset}_measurement` table holds the long-format values; a
  `{dataset}_summary` aggregates replicates (`AVG()` + `STDDEV_SAMP()`, filtering
  `NOT isnan(value) AND isfinite(value)`).
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
