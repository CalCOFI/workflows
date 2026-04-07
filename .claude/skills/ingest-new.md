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
1. **YAML frontmatter** — title, calcofi target metadata, editor options
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
  `white` = shared metadata), draw with `cc_erd()`, then write
  `relationships.json` sidecar via `build_relationships_json()`
10. **Validate** — `validate_for_release()`
11. **Enforce column types** — `enforce_column_types()`
12. **Data preview** — Individual `datatable()` calls per table (NOT
  `preview_tables()` in a loop, which has DT rendering issues)
13. **Write parquet** — `write_parquet_outputs()`
14. **Write metadata** — `build_metadata_json()`
15. **Show metadata** — `listviewer::jsonedit()` for interactive JSON viewer
16. **Upload to GCS** — `sync_to_gcs()` for parquet outputs
17. **Cleanup** — `close_duckdb(con)`

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
- **Spatial** — `add_point_geom()`, `assign_grid_key()` (if has lat/lon).
  For datasets without direct cast_id/bottle_id FKs, match via station +
  date window (±3 days) or lat/lon spatial join. See issue #47 for the
  site/grid/segment matching roadmap.
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

**a. Load Dataset Metadata** — Load `metadata/dataset.csv` into the
wrangling DB so it's included in the parquet output and flows into
`release_database.qmd`:

```r
d_dataset <- read_csv(here("metadata/dataset.csv"))
dbWriteTable(con, "dataset", d_dataset, overwrite = TRUE)
```

**b. CalCOFI.org page check** — Before ingesting, scrape the CalCOFI.org
landing page for the dataset (from `link_calcofi_org` in `dataset.csv`)
to check for updated data, new download links, or changed metadata.

**c. Update `release_database.qmd`** — Add the new dataset's parquet
directory and relationships.json path to the release workflow:

```r
# in release_database.qmd, add to parquet_dirs:
parquet_dirs <- c(
  ...,
  here("data/parquet/{provider}_{dataset}")
)

# and to rels_paths:
rels_paths <- c(
  ...,
  here("data/parquet/{provider}_{dataset}/relationships.json")
)
```

Also add the dataset's tables to the color grouping section and update
the release notes data sources list.

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
in `metadata/dataset.csv`, not in the provider name.

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
