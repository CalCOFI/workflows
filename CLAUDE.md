# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> General R/Quarto/plumber conventions live in the parent `../../CLAUDE.md`
> (2-space indent, snake_case, `|>`, roxygen2, `librarian::shelf()` outside
> packages, etc.). This file covers what is specific to the `workflows` repo.
>
> **Rules here, stories in skills.** Each rule below is stated once and names the
> skill under `.claude/skills/` that holds its mechanics, measurements and the
> incident that produced it. Load that skill before working in its area; do not
> re-derive the rule from the code.

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

Source files sit on Google Drive and rclone to `gs://calcofi-files/`; `targets`
runs each `ingest_*.qmd`, which stages bulk parquet at `$CALCOFI_STAGE_DIR` and
JSON sidecars in `data/parquet/` (both mirrored to `gs://calcofi-db/parquet/`);
`release_database.qmd` assembles those shards in memory, validates, freezes and
uploads `gs://calcofi-db/ducklake/releases/{version}/`.

## The documentation is the compendium — `docs-compendium` skill

- **`../docs` (calcofi.io/docs) is the authoritative description of the system**; this file and
  the skills are the engineering rules for changing it. Start work in an area by reading its
  chapter (the chapter → area table is in the skill), then the skill, then the code.
- **A change that alters what a chapter states updates that chapter in the same change** — the
  prose, `diagrams/*.mmd` + its rendered `.svg`, the caption, the cross-reference — and the
  render is checked. A rule the pipeline enforces is stated with how it is enforced; one nobody
  enforces is stated as intent.
- Prose is authored, facts are generated: never type a number, count, column list, status or
  version into a chapter; surface it through `libs/pre-render.R`'s snapshot under `data/`.
- Every figure and table is numbered, captioned (`{#fig-…}`, `{#tbl-…}` / `tbl-cap`) and
  referenced from the prose; citations are BibTeX keys in `refs/*.bib`, never pasted text.
- The book is a release consumer: `scripts/deploy_consumers.sh` re-renders it after
  `latest.txt` is promoted; a stale version on the site means that step was skipped.

## Commands

The pipeline is the source of truth — prefer running notebooks through `targets`
(which renders the `.qmd` and tracks dependencies) over rendering by hand.

```r
# from the workflows/ directory
Rscript -e 'targets::tar_unblock_process()'            # clear a locked db process

# install/update the engine packages (sibling repos, not on CRAN)
Rscript -e 'remotes::install_github("calcofi/calcofi4db"); remotes::install_github("calcofi/calcofi4r")'

# regenerate the calcofi.io/workflows landing index after adding/removing a notebook
Rscript scripts/build_workflows_index.R
```

## Pipeline rules — `pipeline-targets` skill

- `_targets.R` calls `calcofi4db::build_targets_list()`, which discovers targets
  and dependencies from the `calcofi:` YAML block of every `*.qmd`. Add a dataset
  by adding a notebook with that block; never hand-edit the targets list. Use
  `exclude =` in `_targets.R` to drop a target temporarily.
- **A target's `output:` is a single file that target alone writes, never a
  directory.** `check_nested_outputs()` fails the build otherwise. When a target
  looks permanently outdated, ask what else writes inside its declared output.
- **Editing a `.qmd` does not outdate its target.** `tar_invalidate()` first, and
  confirm the render happened by `_output/*.html` mtime, never by exit code or
  an unchanged hash.
- `tar_make()` / `tar_invalidate()` take tidyselect, not a string. From a loop or
  an `Rscript`, substitute the value:
  `eval(bquote(targets::tar_make(names = tidyselect::all_of(.(tgt)))))`; name the
  variable `tgt` (never `t`, `c`, `df`, `data`); invalidate only
  `intersect(tgts, targets::tar_meta()$name)` because a never-run target errors.
- There is no test suite or linter here; correctness is the `/validate-ingest`
  checks and the validation chunks in `release_database.qmd`.
- There is **no Working DuckLake** and no ingest calls `finalize_ingest()`; every
  data ingest ends with `write_parquet_outputs()` + `build_metadata_json()` +
  `sync_to_gcs()`. `README_PLAN.qmd` describes design intent, not what is built.
- `in_release: false` in a `calcofi:` block stages an ingest without releasing it
  (`release_excluded_datasets()` is the single source of truth). New measurement
  types and GCS uploads do not follow automatically; handle them in the notebook.
- **Bulk inputs and outputs live under `cc_stage_dir()`** (default
  `~/_big/calcofi`), never in Google Drive or the git tree. Never unzip into
  Drive: it evicts files to empty placeholders and mints conflict copies.
- Open DuckDB only via `calcofi4db::get_duckdb_con()`; never `UPDATE` or index a
  table holding a CRS-tagged `geom`.
- **`mermaid-format: png` stays disabled** in `_quarto.yml`; headless Chrome hangs
  renders indefinitely. If a render hangs, check parentage, `kill -9`, then clear
  the targets lock and the orphaned `rmd.R`.
- **Never depend on the CTD team's live PostgreSQL in a pipeline run.** The
  bridge is the nightly `gs://calcofi-db/qc/ctd/flag_accepted.parquet` snapshot.
- Notebook chunks use `cat()` not `message()`, one `datatable()` call per
  preview, and `----`-suffixed section headings in long chunks.

## Release rules — `release-run` skill

- **A staging run is a staging run everywhere.** Set
  `CALCOFI_RELEASE_PREFIX=ducklake-staging/releases` **and**
  `CALCOFI_TABLES_PREFIX=ducklake-staging/tables`; before it,
  `grep -n '"ducklake/releases' *.qmd` shows only `Sys.getenv()` defaults; after
  it, the real prefix has no object for that version and
  `data/releases-staging/<version>/test_results.json` exists.
- `latest.txt` is promoted only after `test_release.qmd`'s consumer-contract
  query suite passes.
- **`RELEASES.md` is the database's NEWS file.** Every change that alters release
  content adds to `# Unreleased` in the same commit; `promote_unreleased()` stops
  the release without a section for the version. Notes are re-rendered any time
  with `Rscript scripts/publish_release_notes.R`.
- **Anything `release_database.qmd` rebuilds in `con_wdl` must appear in both
  `core_single` and the `gcs_prefix = NA` list.** Most tables upload by GCS
  server-side copy and never pass through the connection; the published bytes are
  the only thing worth asserting on.
- All released geometry is tagged `EPSG:4326` at release; normalize both sides of
  a spatial join in a consumer.
- `NaN` is not `NULL` and survives `IS NOT NULL`; test `isnan()` / `isinf()` on
  coordinates.
- **Depth is a coordinate.** `check_depth_bounds()` (NaN, negative, above
  `CC_DEPTH_MAX_M` = 6,500 m) fails the release; `check_depth_vs_seafloor()` is a
  report and a ratchet, never a delete; `seafloor_depth_m` is stamped on `sample`.
- **Coverage is measured, never asserted.** Do not add `coverage_temporal` /
  `coverage_spatial` to a `dataset_meta` block; `observed_coverage()` measures
  them at release (the one exception, `calcofi_phytoplankton`, is commented).

## Data model — `core-model` skill

- An ingest's bulk `.parquet` stages at `dir_stage` (outside the repo); the JSON
  sidecars `manifest.json` / `metadata.json` / `relationships.json` stay in
  `data/parquet/{provider}_{dataset}/` (`dir_parquet`) and are tracked in git.
- **Each dataset's projection into the core family (`sample`, `obs`,
  `obs_attribute`, `sample_measurement`, `obs_ctd_full`) lives in its own
  notebook's "Emit Core Tables" section.** `calcofi4db` holds only generic shapes
  (`append_*()`, `sample_arm_self()`, `compat_*_sql()`, `ns_key()`); never
  reintroduce a `switch(dataset_key, …)` arm there.
- **`obs_bio` + `obs_env` are what the release publishes; `obs` is a catalog
  view** (`catalog.json` `views.obs`). `check_obs_pair_parity()` must pass. Do not
  rename `value`, `root_id` or `hex7`; append columns. A catalog view carries a
  `{{table}}` token, never a path.
- Every `sample_key` is `dataset_key:sample_type:id`; `grid_key` / `cruise_key`
  stay denormalized on `obs`; `hex_id` is H3 res 10 on `obs`, aggregate with
  `h3_cell_to_parent()`; `geom` lives on `sample`, never on `obs`.
- `*_id` = integer key, `*_key` = string natural key, `*_seq` = sequence; a
  character identifier is `_key`. Measurements are tidy long
  (`measurement_type` / `measurement_value` / `measurement_qual`); records lacking
  a cast FK use `match_by_site_datetime()` then `match_nearest_by_depth()`.
- **`measurement_qual` is each dataset's own vocabulary, uninterpreted**
  (`metadata/measurement_qual.csv`); a flag reaches a user only if the consumer
  applies `cc_qual_ok_sql()` / `qual_ok_sql()` / `qualOkSQL()`.
- **One `climatology` table for every anomaly** (`build_climatology()`:
  1993–2013, dataset × `grid_key` × calendar month × 10 m bin × type, ≥ 3
  cruises). Month-matched always; pass an explicit color ramp, Plotly's `"RdBu"`
  runs blue → red.

## Cruise keys and provider ids — `cruise-key` skill

- **`cruise_key` is `YYYY-MM-NODC` with the month SWFSC designates for the
  cruise, never the event month.** Key events with `resolve_cruise_key()` (span
  containment, then the source's own designation, then the month, recorded in
  `cruise_key_method`); the ichthyo reference wins when sources disagree; never
  drop a source cruise column as "derivable".
- `create_cruise_key()` runs after ship corrections and refuses a blank or
  malformed `ship_nodc`.
- Provider identifiers are typed columns beside the namespaced keys
  (`cruise.cruise_uuid`, `sample.source_uuid`, `sample.station_uuid` +
  `station_uuid_method`); no `cruise_uuid` on `sample`.
- `complete_cruise_reference()` adds the cruises the SWFSC export lacks, and
  `check_cruise_key_integrity()` is the hard gate with three ratchets that only
  ever go down.

## Metadata registries — `metadata-registries` skill

- `metadata/` holds the single sources of truth: `field_dictionary.csv`
  (authored by `libs/build_field_dictionary.R`, add rows there),
  `measurement_type.csv` (read with `read_measurement_type()`, append with
  `register_measurement_types()`, set fields with
  `declare_measurement_fields()`), `category.csv`, `life_stage.csv`, `gear.csv`,
  `provider.csv`, `license.csv`, `distribution.csv` (never delete a row; status
  it), `portal.csv`, `measurement_taxon.csv`, `taxon_override.csv`,
  `relationships_cross.csv`, and per dataset `metadata/{provider}/{dataset}/`
  (`tbls_redefine.csv`, `flds_redefine.csv`, `questions.csv`, `dataset_meta.yml`).
  Generated files (`holdings.csv`, `distribution_observed.json`,
  `taxon_lineage.csv`, `taxon_xref.csv`, `citation_authority.json`) are never
  hand-edited. `dataset.csv` is deprecated.
- **A controlled-vocabulary id (`nerc_p01`, `nerc_s11`, `nerc_l22`, `dwc_term`)
  is filled only on an exact match**; an empty cell means "no concept says exactly
  this", never "not looked at".
- **Every ingest that emits measurements calls `check_measurement_bounds()` and
  resolves every non-`ok` row** by `declare_measurement_bounds()` or a `proposed`
  question; never invent a bound or set one to the observed range
  (`measurement-bounds` skill).
- `questions.csv`: `id` is the global key, `label` (`Q15`) the display form;
  `status` ∈ open | proposed | answered | wontfix, `priority` ∈ blocker | high |
  normal | low; `proposed` carries a `proposed_answer`. Read with
  `read_questions()`, render with `questions_datatable()`. The provider Sheets
  sync only through the calcofi-admin service account.
- The descriptive half of `calcofi.dataset_meta` lives in `dataset_meta.yml`, the
  structural keys in the notebook YAML; `check_dataset_meta_split()` enforces it.
- **`provider` is the organization curating the data**, registered in
  `provider.csv`; a `link_*` field holds an `http(s)` URL or is empty.
- **Never `write_csv()` a registry without `na = ""`**; use the registry helpers.

## Taxa — `taxon-reference` skill

- The ingest declares its vocabulary with `append_dataset_taxon()`, then
  `ensure_taxon_xref()` → `ensure_taxon_lineage()` → `resolve_dataset_taxon()` →
  the builders → `check_dataset_taxon()`. There are no per-dataset arms in
  `calcofi4db`.
- `clean_taxon_name()` output is the lookup query, never `ds_taxa_code`. Stage
  `measurement_taxon.csv` with `ensure_measurement_taxon()`.
- An override never replaces an id the source supplied; a group label is never a
  `common_name`; assert coverage by rank position, never blanket non-NULL.
- `check_taxon_ids()` fails the release on a dataset-local key outside its
  explicit allowlist.

## Attribution — `attribution` skill

- Every dataset's `citation_main`, `license` and `doi` are checked by
  `check_dataset_citation()` in the index build and the release; `license` must be
  in `metadata/license.csv`; **never invent a license**; a gap is exempt only
  while an open question names the field.
- `source_accessed` is measured at release, never authored. The release cites
  itself (`release_citation()`, `.zenodo.json`, `CITATION.cff`).
- A citation reaches a user only if a consumer shows it; the Explorer is the
  worked example and every attribution column it reads is optional at the UI.

## Other contracts (each has its skill)

- **Brand** (`brand-contract`): every product wears `calcofi.io/brand/v2/`,
  honours `?theme=` and `?tour=off`, and is checked weekly. Quarto renders get it
  from `libs/brand/quarto_head.html` + `quarto_header.html`.
- **Deploy** (`deploy-consumers`): the per-app refresh after a release is
  promoted, ending with the hosted consumers — db-viz-station, ctd-transects and
  the docs book — dispatched on GitHub Actions.
- **Release objects** (`release-objects`): released parquet is content-addressed
  under `ducklake/tables/{table}/{hash}/`; never build a
  `releases/{v}/parquet/` path by hand, go through `cc_catalog()` /
  `cc_release_sources()` / `release_sources()`.
- **Bathymetry** (`bathymetry-tiles`): GEBCO 2025 artefacts on
  `gs://calcofi-db/bathymetry/`, described by `gebco_2025.json`; not release
  content.

## The ingest skills loop (`.claude/skills/`, see `RUNBOOK.md`)

```
/explore-dataset {path|url}  →  /generate-metadata {provider} {dataset}
   →  /ingest-new {provider} {dataset}  →  run the notebook
   →  /validate-ingest {provider} {dataset}  →  re-render release_database.qmd
```

Each skill updates the shared tracking artifacts so the loop is
self-documenting; human review happens at every hand-off. Scaffolds come from
`.claude/skills/templates/`.
