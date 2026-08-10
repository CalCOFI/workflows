---
name: ingest-new
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

   ::: Steps 5 and 6 apply to ingests that read their source through
   `read_csv_files()`. Both take *that function's result object* —
   `check_data_integrity()` calls `detect_csv_changes(d)`, and
   `show_source_files()` reads `d$source_files` — so they cannot be bolted onto an
   ingest with a different source shape, and their absence in such a notebook is
   **not** a gap to close. `ingest_calcofi_ctd-cast.qmd` is the case in point: it
   assembles its own file list from ~62 GB of zipped CTD files, and covers the same
   two purposes its own way — a "Files to Ingest" + "rows read per file" table for
   provenance, and `check_dupes` / `dedup_ctd_raw` / `ctd_thin_verify_pairing` /
   `ctd_thin_verify` / `diag_ranges` for integrity. A non-CSV ingest owes the
   *purpose* (show what was read; check it before loading), not these two calls. :::
7. **Show tables/fields** — Redefinition display
8. **Load into database** — `ingest_dataset()` or custom load
9. **Schema documentation** — **two ERDs plus a mapping**, because they answer
  different questions: what the source looks like, what the ingest *publishes*
  (`cc_erd(con, tables = core_tbls, rels = core_relationships(core_tbls))`), and
  how one becomes the other. A source-only ERD is not sufficient — a reader cannot
  tell what a consumer will see. The source→core mapping is a table of
  `source table.field → core table.field → transform`, and it must also list what
  is **deliberately not published** and why. Define PKs/FKs, color-code tables
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
11. **Validate** — `validate_for_release()`, plus core parity assertions. **Never
  report "FAILED, but all expected."** Its null check treats every column ending
  `_id`/`_key`/`_uuid` as required, which is a heuristic, not your dataset's
  contract — `parent_taxon_key` is legitimately NULL for a root taxon, `cruise_key`
  for a record that names no ship. Accepting a wall of "expected" errors is how a
  real defect hides in the noise; it hid a whole missing taxon lineage. Instead
  declare each nullable case **with its count and reason** in a `tribble`, reconcile
  against what the validator reports, and hard-fail on anything undeclared or whose
  count has moved:

  ```r
  nullable <- tribble(~table, ~column, ~n, ~reason,
    "sample", "cruise_key", 1639L, "log records no ship; resolves only where YYYY-MM is unambiguous",
    ...)
  # reconcile, then:
  stopifnot("a NULL appeared with no declared reason" = nrow(unexplained) == 0,
            "a declared NULL count has changed"       = nrow(moved) == 0)
  ```

  Report cases that no longer occur too, so the list gets pruned rather than
  accumulating. And when a reconciled case turns out to be a genuine gap rather
  than an expected null, **assert the gap's current size** so the assertion fails
  once it is fixed and the note cannot outlive it.
12. **Enforce column types** — `enforce_column_types()` (run this BEFORE any
  geometry column exists; DuckDB ≥ 1.5.1 cannot rewrite a table carrying
  `GEOMETRY`)
13. **Data preview** — Individual `datatable()` calls per table (NOT
  `preview_tables()` in a loop, which has DT rendering issues). Prefer previewing
  *through the core*, the way a consumer will read it.
14. **Write parquet** — **the core and nothing else**:
  `write_parquet_outputs(tables = core_output_tables(con, extra = c("measurement_type", "dataset")))`.
  Do NOT publish per-dataset source tables (see "Publish the core only" below).
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
Full pattern in `RUNBOOK.md` §3b and `.claude/skills/templates/ingest_template.qmd`.

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

**There is no `switch(dataset_key, …)` to add an arm to, and there must not be
one again.** `calcofi4db` used to hold one per core table — ~600 lines of
dataset-specific SQL in a general-purpose module — plus `emit_core_tables()` /
`build_sample_reference()` / `create_compat_views()` over them. All deleted in
calcofi4db 3.0.0. The package now exposes only *generic shapes*
(`append_obs()` / `append_obs_attribute()` / `append_sample()` /
`append_sample_measurement()` / `sample_arm_self()` / `compat_event_sql()` /
`compat_measurement_sql()` / `ns_key()` / `ensure_measurement_taxon()` /
`prune_taxon_shard()`), and each dataset's projection lives in its own notebook.
The reason is not tidiness: `release_database.qmd` kept a second copy of every
arm, the two drifted, and each divergence was a silent data error (37 euphausiid
species flattened to one family key; every unresolved seabird on a transect
merged into one row; phytoplankton emitting zero observations; cufes and
phyllosoma losing their taxa). Copy the pattern from any `ingest_*.qmd`.

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

**Publish the core only.** `tbls_out` is `core_output_tables(con, extra =
c("measurement_type", "dataset"))`. No per-dataset source table goes to parquet:
the source files are already archived to
`gs://calcofi-files-public/archive/{provider}/{dataset}/`, so a per-dataset copy is
redundant, and publishing both gives consumers two representations of the same data
to choose between. Compat VIEWs are views over the core, so writing them would
duplicate the same bytes under a second name.

If a source column carries real information with no core home, **give it a core
home** — do not use that as a reason to publish the source table. Worked example:
the Dungeness sorting log's `sorted`/`unsorted` status looked like it needed its own
column, but "examined, found none" is an occurrence with `measurement_value = 0`,
and "not examined" is the absence of an `obs` row. Encoding it that way made the
status column unnecessary and turned an inventory into queryable absence data.
Free-text notes and gear detail the core genuinely does not model stay in the
archived source, and the mapping table says so explicitly.

Beware a statistic quietly changing meaning when you add rows like this: adding 216
examined-but-empty samples moved an occurrence rate from 15/310 to 15/526. Both are
true; report the scope.

**Number questions by priority, and show the number.** Labels are referenced from
prose, commit messages and provider emails, so they have to be visible in the
rendered table — a `select()` without `label` leaves every "Q01" in the notebook
pointing at nothing. Assign ids in priority order so the blocker is Q01 rather
than whatever was written last.

Keep the template's **Questions for Data Providers** section (placed after
"Load Dataset Metadata", before "Validate"). Every ingest workflow carries it,
and every one of them renders it the same way:

```r
questions_datatable(here(cc$questions_file), caption = "Questions for the … (ranked)")
```

Do **not** hand-write a `read_csv() |> arrange(factor(priority, …)) |> select(…)`
chain. All 16 notebooks used to, each with its own factor level vector and its own
column list; a status nobody's vector listed sorted silently to the bottom and was
never seen again — `ingest_calcofi_mets.qmd` ranked by a vector containing
"blocker" and "asked", neither of which is a status. `calcofi4db::read_questions()`
holds the vocabulary and errors on anything outside it.

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

### 10. Post-ingest metadata.json completeness scan — now automatic

`build_metadata_json()` calls `calcofi4db::scan_metadata_gaps()` on every write, so
**every** ingest reports its own documentation gaps as part of the render. There is
nothing to run by hand.

This used to be the snippet below, which a human was expected to run once, after
the first render, from memory. It never appeared in a single notebook
(`grep description_md *.qmd` returned nothing), so in practice empty descriptions
and units shipped unnoticed — verbatim into the release `metadata.json` and on to
`calcofi4r::cc_describe_table()` / `cc_db_catalog()`, where they render as blank
documentation.

Read the scan's output in the render and **backfill
`metadata/{provider}/{dataset}/flds_redefine.csv`**, then re-run. A missing `units`
is only reported for columns where a unit could exist — keys, names, flags,
timestamps and free text are exempt, because reporting them would bury the real
gaps.

```r
# to scan an existing sidecar without re-running the ingest:
calcofi4db::scan_metadata_gaps(
  here::here(glue::glue("data/parquet/{provider}_{dataset}/metadata.json")))
```

Report the counts back to the user along with the top offenders.
