# Release-level `metadata.json` sidecar for table/column descriptions and units

## Context

The pre-DuckLake CalCOFI pipeline stored table and column descriptions + units
in Postgres via `COMMENT ON`, exposed them via `api/plumber.R` endpoints
(`/db_tables`, `/db_columns`) using `pg_catalog.pg_description`, and rendered
them with `calcofi4r::cc_db_catalog()` (now deprecated). The DuckLake migration
dropped this end of the pipeline: parquet files uploaded to GCS carry no
descriptions/units, the release sidecars (`catalog.json`, `relationships.json`)
are purely structural, and `calcofi4r::cc_describe_table()` returns only
DuckDB `information_schema` (no descriptions).

Meanwhile, the source-of-truth metadata is already in this repo:
- `metadata/{provider}/{dataset}/tbls_redefine.csv` — table descriptions
- `metadata/{provider}/{dataset}/flds_redefine.csv` — column descriptions + units
- `metadata/{provider}/{dataset}/metadata_derived.csv` — markdown/units overlay
- `metadata/measurement_type.csv` — canonical measurement units + descriptions
- `metadata/dataset.csv` — dataset-level descriptions

And `calcofi4db::build_metadata_json()`
(`calcofi4db/R/wrangle.R:1577`) already produces a per-ingest `metadata.json` with the
right shape at `data/parquet/{provider}_{dataset}/metadata.json` (schema_version
1.0; `tables{name: {name_long, description_md}}` and
`columns{table.column: {name_long, units, description_md}}`).

The gap is just at the release boundary: per-ingest `metadata.json` files are
never merged into a release sidecar uploaded to GCS, and downstream consumers
(calcofi4r, docs, skills) still point at the dead Postgres machinery.

## Outcome

Each release directory and the matching GCS path will contain a
`metadata.json` sidecar covering every table in the release (including
cross-cutting and release-only tables). `calcofi4r::cc_describe_table()` will
JOIN it onto the DuckDB schema, `calcofi4r::cc_db_catalog()` will be rewired to
the sidecar (or hard-deprecated with a pointer), `docs/db.qmd` will document
the new pattern, and the ingest/validate skills will require populated
descriptions + units. The `total_size: 0` bug in `catalog.json` will be fixed
alongside.

## Approach

### 1. Producer side — release-level `metadata.json`

**New helper `merge_metadata_json()` in `calcofi4db/R/wrangle.R`**
(alongside `build_metadata_json()` and `merge_relationships_json()`).
Signature:
```
merge_metadata_json(
  paths_in,           # vector of per-ingest metadata.json paths
  release_tables_csv, # path to metadata/release_tables.csv
  release_columns_csv,# path to metadata/release_columns.csv (optional)
  measurement_type_csv, # path to metadata/measurement_type.csv
  dataset_csv,        # path to metadata/dataset.csv
  path_out,           # release metadata.json path
  release_version)    # for top-level `version` field
```
Output schema (extension of the per-ingest 1.0 schema):
```
{
  "schema_version": "1.1",
  "release_version": "v2026.05.14",
  "release_date": "2026-05-14",
  "datasets": { "calcofi_bottle": { ...from dataset.csv... }, ... },
  "tables":  { "<table>": {
      "name_long": "...", "description_md": "...",
      "provider": "calcofi", "dataset": "bottle"
  }, ... },
  "columns": { "<table>.<column>": {
      "name_long": "...", "units": "...", "description_md": "..."
  }, ... },
  "measurement_types": { "<type>": { "description": "...", "units": "..." } }
}
```
Conflict rule: when the same table/column key appears in more than one
per-ingest file, last-merge wins, but `merge_metadata_json()` logs a warning
listing the duplicates (so we catch genuine drift between ingests).

**New `metadata/release_tables.csv`** with columns:
`table, name_long, description_md, provider, dataset` — for tables built inside
`release_database.qmd` and not owned by any ingest:
`cruise_summary`, `_spatial`, `_spatial_attr`, `taxon`, `taxa_rank`, `lookup`,
`ship`, `cruise`. Populate descriptions from existing comments in
release_database.qmd chunks and the CLAUDE.md notes.

**New `metadata/release_columns.csv`** (optional, parallel to `flds_redefine.csv`
but for release-only tables) with columns:
`table, column, name_long, units, description_md`. Start with the small high-value
tables (`cruise_summary`, `_spatial`, `taxon`); empty `description_md` is acceptable
for the rest initially.

**Edit `workflows/release_database.qmd`** at lines 679–704
(the catalog+relationships+RELEASE_NOTES upload block):
- Compute `total_size` by summing `file.size()` across all uploaded parquet
  files (we already iterate `freeze_stats` to upload them at lines 644–677, so
  accumulate sizes there into a `total_bytes` variable). Replace
  `total_size = 0` at line 687.
- After the relationships.json merge (current line 444+), add a parallel
  block that calls `calcofi4db::merge_metadata_json()` over
  `data/parquet/*/metadata.json` plus `metadata/release_tables.csv` and
  `metadata/release_columns.csv`, writing `dir_frozen/metadata.json`.
- After line 704, add the GCS upload:
  ```r
  meta_json <- file.path(dir_frozen, "metadata.json")
  if (file.exists(meta_json))
    put_gcs_file(meta_json,
      glue("gs://{gcs_bucket}/{gcs_release}/metadata.json"))
  ```

### 2. Consumer side — calcofi4r

**`calcofi4r/R/read.R` — rewrite `cc_describe_table()`**
- Keep DuckDB `information_schema.columns` as the schema source.
- Fetch (and cache locally for the active release) `metadata.json` from
  GCS via the same `https_base` URL pattern used for `catalog.json` in
  `release_database.qmd:717` (`https_base = "https://storage.googleapis.com/<bucket>/ducklake/releases"`).
- Left-join `columns["{table}.{column}"]` onto the information_schema result so
  the returned tibble adds `name_long, units, description_md`. Also return a
  table-level `description_md` (attr or scalar in a header row).
- Resolve `version` argument via `cc_db_info()`/`cc_list_versions()` so users
  can pin metadata to a release.

**`calcofi4r/R/database.R` — rewire `cc_db_catalog()`**
- Stop calling the dead `api.calcofi.io/db_tables` / `/db_columns` endpoints.
- Either: (a) re-implement on top of the new sidecar (read `metadata.json`,
  return the same DT::datatable() of tables + columns), or (b) hard-deprecate
  with `lifecycle::deprecate_stop("0.x", "cc_db_catalog()", "cc_describe_table()")`
  pointing users at `cc_describe_table()` and `cc_list_tables()`.
  Recommend (a) — implementation is ~30 lines now that the sidecar exists.

### 3. Documentation

**`docs/db.qmd` lines 201–310** — Replace the "PostgreSQL workflow (legacy)"
and "Metadata and documentation" sections.
- New section "Metadata and documentation" should describe:
  - Sources of truth: `tbls_redefine.csv`, `flds_redefine.csv`,
    `metadata_derived.csv` (per provider/dataset) and `release_tables.csv` /
    `release_columns.csv` (release-only).
  - Per-ingest output: `data/parquet/{provider}_{dataset}/metadata.json`.
  - Release output: `gs://<bucket>/ducklake/releases/<version>/metadata.json`
    next to `catalog.json` and `relationships.json`.
  - Consumer entry point: `calcofi4r::cc_describe_table()` (recommended) or
    `cc_db_catalog()` (interactive browse).
- Drop or short-archive references to `cc_db_connect()`, `api.calcofi.io/db_tables`,
  `pg_description`, and the Postgres-COMMENT pattern.

### 4. Skills

**`workflows/.claude/skills/generate-metadata.md`**
- Strengthen instructions so the agent must populate `tbl_description` for
  every row of `tbls_redefine.csv` and `fld_description` + `units` for every
  row of `flds_redefine.csv` it scaffolds. Add a checklist line at the end:
  "Verify no `fld_description` or `units` is empty for canonical/PK/measurement
  columns before handing off."

**`workflows/.claude/skills/ingest-new.md`**
- Add a step after `finalize_ingest()` to open
  `data/parquet/{provider}_{dataset}/metadata.json` and grep for empty
  `description_md` / `units`; report a warning count.

**`workflows/.claude/skills/validate-ingest.md`**
- Add a check: load the freshly written per-ingest `metadata.json` and assert
  - all tables have non-empty `description_md`
  - all non-`*_id`, non-`geom`, non-`*_qual` columns have non-empty `description_md`
  - all measurement-type columns (`measurement_value`, `avg`, `stddev`) have
    a unit either inline or recoverable via `measurement_type` join.

**`workflows/.claude/skills/publish-template.md`**
- Add a smoke test after the release: download
  `gs://<bucket>/ducklake/releases/<v>/metadata.json`, assert it parses and
  contains every table named in `catalog.json`.

## Critical files

- `calcofi4db/R/wrangle.R:1577` — `build_metadata_json()` (reference for new function)
- `calcofi4db/R/wrangle.R` — add `merge_metadata_json()` near `merge_relationships_json()`
- `calcofi4db/R/workflow.R:252` — `finalize_ingest()` (unchanged; already produces per-ingest metadata.json)
- `workflows/release_database.qmd:444–475` — relationships.json merge (model the metadata merge here)
- `workflows/release_database.qmd:679–704` — catalog/relationships/release_notes upload block (add metadata.json build + upload, fix total_size)
- `workflows/release_database.qmd:644–677` — parquet upload loop (accumulate `total_bytes`)
- `workflows/metadata/release_tables.csv` — NEW
- `workflows/metadata/release_columns.csv` — NEW
- `calcofi4r/R/read.R:436–463` — `cc_describe_table()` rewrite
- `calcofi4r/R/database.R:961–1032` — `cc_db_catalog()` rewire or deprecate
- `docs/db.qmd:201–310` — metadata section rewrite
- `workflows/.claude/skills/generate-metadata.md` — strengthen description/units guidance
- `workflows/.claude/skills/ingest-new.md` — post-ingest empty-fields warning
- `workflows/.claude/skills/validate-ingest.md` — metadata completeness check
- `workflows/.claude/skills/publish-template.md` — release sidecar smoke test

## Reused utilities

- `calcofi4db::build_metadata_json()` (wrangle.R:1577) — per-ingest metadata,
  already wired into every `ingest_*.qmd` via `finalize_ingest()`. Output is
  the input to the new `merge_metadata_json()`.
- `calcofi4db::merge_relationships_json()` — exact precedent for the merge
  pattern; mirror its signature, error handling, and write style.
- `put_gcs_file()` (used at release_database.qmd:692/697/703) — for uploading
  the new sidecar.
- `cc_db_info()` / `cc_list_versions()` (calcofi4r) — version resolution in
  `cc_describe_table()`.

## Verification

End-to-end test after implementation:

1. **calcofi4db**: `devtools::document()` and `devtools::test()` (add unit tests
   for `merge_metadata_json()`: conflict warning, empty-list, missing CSV).
2. **Per-ingest regeneration**: re-run one fast ingest (`ingest_calcofi_dic.qmd`)
   end-to-end; verify `data/parquet/calcofi_dic/metadata.json` is unchanged in
   schema but more populated in `description_md`/`units` after CSV backfills.
3. **Release**: render `release_database.qmd`. Confirm:
   - `data/releases/v<next>/metadata.json` exists, schema_version 1.1, covers
     every table named in `catalog.json` (set-diff = ∅).
   - `catalog.json` `total_size` > 0 and matches sum of GCS-uploaded parquet
     sizes within ~1%.
   - GCS object listing shows `metadata.json` alongside `catalog.json`,
     `relationships.json`, `RELEASE_NOTES.md`.
4. **calcofi4r**: in a fresh R session,
   ```r
   tbl <- calcofi4r::cc_describe_table("bottle")
   stopifnot("description_md" %in% names(tbl),
             any(nzchar(tbl$description_md)),
             any(!is.na(tbl$units)))
   calcofi4r::cc_db_catalog()  # renders without hitting api.calcofi.io
   ```
5. **Docs**: render `docs/db.qmd`; visually confirm the metadata section no
   longer mentions Postgres / `pg_description` / `api.calcofi.io/db_tables`.
6. **Skills**: run `/validate-ingest` against the `calcofi_dic` parquet dir;
   confirm it reports remaining empty `description_md` rows (acts as TODO list
   for backfill) and does not error.
