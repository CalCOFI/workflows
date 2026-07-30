---
description: Scaffold a new CalCOFI dataset ingest workflow from template
user_invocable: true
---

# /ingest-new

Scaffold a new `ingest_{provider}_{dataset}.qmd` Quarto notebook from the production ingest template, customized for the target dataset.

## Usage

```
/ingest-new {provider} {dataset} [--options]
```

## Arguments

- `provider`: Data provider identifier (e.g., `ncei`, `edi`, `pic`, `swfsc`, `calcofi`, `sccoos`)
- `dataset`: Dataset identifier (e.g., `dic`, `euphausiids`, `zooplankton`)

## Options

- `--has-taxonomy`: Include taxonomy standardization sections (species table, WoRMS/ITIS matching)
- `--has-pivot`: Include wide→long measurement pivoting sections
- `--merge-into={table}`: Merge into existing table instead of creating new (e.g., `bottle_measurement`)
- `--depends-on={prior_ingest}`: Declare dependency on prior ingest (e.g., `swfsc_ichthyo`)

## Instructions

When the user invokes this skill:

### 1. Verify prerequisites

Check that metadata files exist:
```bash
ls metadata/{provider}/{dataset}/tbls_redefine.csv metadata/{provider}/{dataset}/flds_redefine.csv
```

If not found, suggest running `/generate-metadata {provider} {dataset}` first.

### 2. Read template and customize

Read the ingest template from `.claude/skills/templates/ingest_template.qmd` and customize it with the provided parameters.

Key substitutions:
- `{{provider}}` → provider value
- `{{dataset}}` → dataset value
- `{{dataset_name}}` → human-readable name (derive from dataset or ask user)
- `{{dir_label}}` → `{provider}_{dataset}`
- `{{depends_on}}` → prior ingest dependency (default: `swfsc_ichthyo` for shared tables)

### 3. Determine ingest pattern

Based on the dataset characteristics (from `/explore-dataset` output or user input), select the appropriate pattern:

**Pattern A: Standalone ingest** (like ichthyo)
- Creates its own tables with dataset-prefixed names
- Generates own PKs (sequential or UUID)
- Full spatial/grid assignment
- Example: euphausiids, zooplankton

**Pattern B: Supplementary measurements** (like DIC)
- Creates own `{dataset}_sample` (position-only) and `{dataset}_measurement` tables
- Matches to existing casts/bottles via station + date window
- Keeps tables separate from bottle_measurement (different QC pipelines)
- Example: DIC/TA → dic_sample + dic_measurement + dic_summary

**Pattern C: Multi-source ingest** (like phytoplankton)
- Reads from multiple source formats (CSV, API, etc.)
- Requires source reconciliation
- Complex taxonomy mapping
- Example: phytoplankton from DataZoo + EDI

### 4. Generate the notebook

Write the customized notebook to:
```
ingest_{provider}_{dataset}.qmd
```

The notebook includes these sections (customize based on pattern):

#### Universal sections (always included):
1. **YAML frontmatter** — title, calcofi target metadata (including
   `calcofi.questions_file: metadata/{provider}/{dataset}/questions.csv`),
   editor options
2. **Overview** — Dataset description, source, Mermaid data flow diagram
3. **Setup** — Libraries, paths, DuckDB initialization, `overwrite <- FALSE`
4. **Read source data** — `read_csv_files(sync_archive = TRUE)` archives
   source CSVs to `gs://calcofi-files-public/archive/{provider}/{dataset}/`
   on every run. For non-CSV sources (shapefiles, zips), use
   `sync_to_gcs(local_dir, gcs_prefix = "archive/{provider}/{dataset}",
   bucket = "calcofi-files-public")` instead.
5. **Check data integrity** — `check_data_integrity()`, `render_integrity_message()`
6. **Show source files** — `show_source_files()`
7. **Show tables/fields** — Redefinition display
8. **Load into database** — `ingest_dataset()` or custom load
9. **Schema documentation** — Define PKs/FKs, color-code tables
  (`lightblue` = new tables, `lightyellow` = amended reference tables,
  `white` = shared metadata), draw with `cc_erd()`. This ERD documents the
  **source** shape; `relationships.json` is written later from
  `core_relationships(tbls_out)`, since the core is what gets published. Always
  pass `tables =` to `cc_erd()` — diagramming every table in the connection is
  slow and unreadable.
10. **Emit core tables** — **MANDATORY, and the point of the whole ingest.** See
  "Emit the core" below. An ingest that stops at per-dataset tables is not
  finished: the core is what `release_database.qmd` publishes and what every
  consumer reads.
11. **Validate** — `validate_for_release()`, plus core parity assertions
12. **Enforce column types** — `enforce_column_types()` (run this BEFORE any
  geometry column exists; DuckDB ≥ 1.5.1 cannot rewrite a table carrying
  `GEOMETRY`)
13. **Data preview** — Individual `datatable()` calls per table (NOT
  `preview_tables()` in a loop, which has DT rendering issues). Prefer previewing
  *through the core*, the way a consumer will read it.
14. **Write parquet** — `write_parquet_outputs(tables = core_output_tables(con, extra = …))`
15. **Write metadata** — `build_metadata_json()`, passing
  `metadata_derived_csv = c(here("metadata/core_dictionary.csv"), <this dataset's>)`
  — without `core_dictionary.csv` every core table and column ships with an empty
  description
16. **Show metadata** — `listviewer::jsonedit()` for interactive JSON viewer
17. **Upload to GCS** — `sync_to_gcs()` for parquet outputs
18. **Cleanup** — `close_duckdb(con)`

#### Emit the core (step 10, in detail)

Per-dataset tables (`{dataset}_sample` / `{dataset}_measurement` / …) are an
**intermediate** wrangling shape, not the deliverable. Every ingest projects them
into the shared core family and then serves the per-dataset names as compat VIEWs.
Full pattern in `RUNBOOK.md` §3b and `templates/ingest_template.qmd`.

**The projection SQL belongs in the notebook.** The `append_*` helpers all take an
arbitrary `SELECT`, so adding a dataset needs **no `calcofi4db` change**:

```r
build_grid_reference(con)                  # idempotent shared grid
append_sample(con, "<event SELECT>")       # namespaced sample_key
append_obs(con, "<headline occurrence SELECT>")
append_obs_attribute(con, "<bin/count SELECT or skip>")
append_sample_measurement(con, "<event-effort SELECT or skip>")
```

Column contracts are **positional** (each helper wraps your SELECT in
`AS src(...)`), so emit columns in the documented order — see each helper's
roxygen. Then:

```r
# per-dataset names survive as VIEWs over the core (detail survives, bytes don't)
dbExecute(con, "ALTER TABLE {ds}_measurement RENAME TO {ds}_measurement_src")
dbExecute(con, "CREATE OR REPLACE VIEW {ds}_measurement AS
                SELECT … FROM obs WHERE dataset_key = '{provider}_{dataset}'")
```

`emit_core_tables()` is a convenience wrapper whose `switch(dataset_key, …)` arms
hold the already-migrated datasets' SQL. **Do not add an arm for a new dataset** —
that is how ~450 lines of dataset-specific SQL accumulated inside a general-purpose
module. Use the helpers above.

**Taxon resolution.** `obs.taxon_key` is global (`worms:<id>`, or `itis:<id>` for
birds). Datasets with a vocabulary table resolve through `dataset_taxon`; datasets
that bake the taxon into a column name (`sardine_eggs`, `megalopae_magister`)
resolve through `metadata/measurement_taxon.csv`, which maps each raw label to
`(measurement_type, taxon_key, life_stage)`. **A taxon-bearing column name is never
a `measurement_type`** — the quantity is `abundance`/`count`, the organism is
`taxon_key`. Then:

```r
mt <- readr::read_csv(here("metadata/measurement_taxon.csv"),
                      col_types = cols(worms_id = "i", itis_id = "i",
                                       bin_value = "d", .default = "c")) |>
  filter(dataset_key == ds_key)
dbWriteTable(con, "_measurement_taxon", as.data.frame(mt), overwrite = TRUE)
build_taxon_reference(con, mt, overrides); build_dataset_taxon(con, mt, overrides)
```

Read `worms_id`/`itis_id` as **integer**. Read as double, `CAST(… AS VARCHAR)`
yields `"440388.0"`, every `taxon_key` silently joins to nothing, and a NOT-NULL
check will not catch it.

**Assert the projection, don't eyeball it.** At minimum: one core `sample` per
source event; `obs` row count and value total equal the source; every
`obs.sample_key` resolves in `sample`; every `obs.taxon_key` resolves **in
`taxon`** (not merely non-NULL); every `obs.measurement_type` resolves in
`measurement_type`; sub-occurrence counts reconcile to the headline.

**Prune retired parquet.** When a table becomes a compat VIEW it must stop being
written, and any stale `.parquet` left on disk is still picked up by directory
scans and by `sync_to_gcs`. Delete files not in `tbls_out`.

Also keep the template's **Questions for Data Providers** section (renders
`metadata/{provider}/{dataset}/questions.csv` as a `datatable()`, placed after
"Load Dataset Metadata", before "Validate"). Every ingest workflow carries it.

#### Conditional sections:
- **Cross-dataset loading** — `load_prior_tables()` (if depends on prior ingest)
- **Primary key setup** — `assign_deterministic_uuids()` or `assign_sequential_ids()`
- **Pivot measurements** — Wide→long transformation (if `--has-pivot`)
- **Measurement summary** — Aggregate replicates with avg/stddev per unique
  position (station + date + depth + measurement_type). Filter out invalid
  values: `WHERE NOT isnan(measurement_value) AND isfinite(measurement_value)`.
  Use `STDDEV_SAMP()` with `CASE WHEN COUNT(*) = 1 THEN 0` for single
  observations. See `ctd_summary` in `ingest_calcofi_ctd-cast.qmd` and
  `dic_summary` in `ingest_calcofi_dic.qmd` for examples.
- **Taxonomy** — `standardize_species_local()`, `build_taxon_hierarchy()` (if `--has-taxonomy`)
- **Spatial** — `add_point_geom()`, `assign_grid_key()` (if has lat/lon; use
  canonical `latitude`/`longitude` per `metadata/field_dictionary.csv`).
  For datasets without direct cast_id/bottle_id FKs, match to existing
  casts/bottles with the calcofi4db helpers `match_by_site_datetime()`
  (site_key + datetime window) and `match_nearest_by_depth()` (nearest bottle
  by depth) — do NOT re-implement the SQL inline. These resolve issue #47.
- **Lookup tables** — `create_lookup_table()` (if categorical vocabularies exist)
- **Ship/cruise matching** — `derive_cruise_key_on_casts()` (if cross-dataset bridge needed)

### 5. Coding conventions

**Tidy data**: Apply tidy data principles throughout:
- The base `{dataset}_sample` table has only position/time/FK columns —
  NO measurement values as separate columns
- ALL measurements (including ancillary ones like temp, salinity) are
  pivoted into `{dataset}_measurement` with columns:
  `measurement_type`, `measurement_value`, `measurement_qual`
- Each row = one measurement at one position. Never mix different
  measured quantities on the same row.
- Example: DIC dataset pivots 4 types (dic, alkalinity, ctdtemp_its90,
  salinity_pss78) into `dic_measurement` — `dic_sample` has zero
  measurement columns.
- **This triple is an intermediate, not the deliverable.** It gets projected into
  the core (`sample` / `obs` / `obs_attribute` / `sample_measurement`) at step 10
  and survives only as compat VIEWs. Do not finish an ingest at the triple.

**Status output**: Use `cat()` (not `message()`) for user-facing status
output in chunks. `message()` sends to stderr which Quarto may not
render visibly with `code-fold: true`. Pattern:
```r
cat(glue("label: {value}"), "\n")
```

**Data preview**: Use individual `datatable()` calls per table in
separate chunks (one chunk per table). Do NOT use `preview_tables()`
in a loop — it has DT widget rendering issues where only the first
table displays.

### 6. Mark dataset-specific sections

In the generated notebook, mark sections requiring manual implementation with:

```r
#| label: TODO-{section}
# TODO: implement dataset-specific logic here
# - {specific guidance based on dataset characteristics}
```

### 6. Include dataset metadata and release_database update

Every ingest notebook MUST include these two standard sections:

**a. Load Dataset Metadata** — build the `dataset` row from this notebook's own
`calcofi.dataset_meta` YAML block. `metadata/dataset.csv` is **deprecated**: it
drifted from the notebooks and orphaned obs rows against `obs.dataset_key`. The
YAML cannot drift, because it is the same block that defines the pipeline:

```r
this_provider <- provider; this_dataset <- dataset  # also column names
d_dataset <- ingest_yaml_to_dataset_df(read_ingest_yaml(here())) |>
  filter(provider == this_provider, dataset == this_dataset)
stopifnot(nrow(d_dataset) == 1)
dbWriteTable(con, "dataset", as.data.frame(d_dataset), overwrite = TRUE)
```

**b. CalCOFI.org page check** — Before ingesting, scrape the CalCOFI.org
landing page for the dataset (from `link_calcofi_org` in the YAML block)
to check for updated data, new download links, or changed metadata.

**c. Update `release_database.qmd`** — `release_database.qmd` auto-discovers
every `data/parquet/*/relationships.json` and `data/parquet/*` output via
`Sys.glob()`, so you do NOT need to hand-edit `parquet_dirs`/`rels_paths` for a
new dataset. Two things still need attention:
- If the dataset introduces a **cross-dataset** foreign key (a FK whose target
  lives in another ingest, e.g. `{dataset}_sample.cast_id → casts.cast_id`),
  add a row to `metadata/relationships_cross.csv`. Intra-dataset FKs stay in
  the ingest's own `relationships.json` and are picked up automatically.
- Optionally add the dataset's tables to the ERD color grouping and the release
  notes data-sources list.

### 7. Provider naming convention

The `provider` value represents the **organization curating the data**,
not the data portal where it's hosted:

| Provider | Organization | Example datasets |
|----------|-------------|------------------|
| `calcofi` | CalCOFI program | bottle, ctd-cast, dic |
| `swfsc` | NOAA SWFSC | ichthyo |
| `pic` | SIO Pelagic Invertebrates Collection | zooplankton |
| `sccoos` | SCCOOS | underway |

Data portals (NCEI, EDI, ERDDAP) are recorded in `link_data_source`
in the notebook's `calcofi.dataset_meta` block, not in the provider name.

### 8. Update `_targets.R`

Add a new target entry for the ingest workflow:

```r
tar_target(
  ingest_{provider}_{dataset_snake},
  {
    quarto::quarto_render(
      here("ingest_{provider}_{dataset}.qmd"),
      output_file = here("_output/ingest_{provider}_{dataset}.html"))
    here("data/parquet/{provider}_{dataset}/manifest.json")
  },
  format = "file"
)
```

Insert it in the correct dependency order (after its `depends_on` target, before `release_database`).

### 9. Present results

Show the user:
- Created file path
- Section outline with TODO markers
- Dependencies added to `_targets.R`
- Next steps:
  1. Fill in TODO sections with dataset-specific transforms
  2. Run the notebook to test
  3. Run `/validate-ingest {provider} {dataset}` to verify

### 10. Post-ingest metadata.json completeness scan

After the first successful render of the new ingest notebook (which runs
`finalize_ingest()` → `build_metadata_json()`), scan the produced sidecar
for empty descriptions and units. These ship verbatim to the release
`metadata.json` and on to calcofi4r `cc_describe_table()` /
`cc_db_catalog()`, so empties should be surfaced as TODOs, not ignored.

```r
librarian::shelf(jsonlite, glue, here, quiet = T)
provider <- "{provider}"; dataset <- "{dataset}"
meta_path <- here(glue("data/parquet/{provider}_{dataset}/metadata.json"))
m <- fromJSON(meta_path, simplifyVector = FALSE)

empty_tbl_desc <- Filter(function(t) !nzchar(t$description_md %||% ""), m$tables)
empty_col_desc <- Filter(function(c) !nzchar(c$description_md %||% ""), m$columns)
empty_col_unit <- Filter(function(c) is.null(c$units),                   m$columns)

cat(glue("\nmetadata.json gaps for {provider}_{dataset}:\n"))
cat(glue("  tables with empty description_md: {length(empty_tbl_desc)}\n"))
cat(glue("  columns with empty description_md: {length(empty_col_desc)}\n"))
cat(glue("  columns with NULL units (review numeric only): {length(empty_col_unit)}\n"))
if (length(empty_tbl_desc) > 0)
  cat("  ", paste(names(empty_tbl_desc), collapse = ", "), "\n")
if (length(empty_col_desc) > 0)
  cat("  ", paste(head(names(empty_col_desc), 20), collapse = ", "),
      if (length(empty_col_desc) > 20) glue(" (+{length(empty_col_desc)-20} more)") else "", "\n")
```

Report the counts back to the user along with the top offenders so they
can backfill `flds_redefine.csv` and re-run.
