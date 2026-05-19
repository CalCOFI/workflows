---
description: Create metadata redefinition files for a new CalCOFI dataset ingestion
user_invocable: true
---

# /generate-metadata

Create the `metadata/{provider}/{dataset}/` directory structure with scaffolded `tbls_redefine.csv` and `flds_redefine.csv` files for a new dataset ingestion.

## Usage

```
/generate-metadata {provider} {dataset} [csv_path_or_directory]
```

## Arguments

- `provider`: Data provider identifier (e.g., `ncei`, `edi`, `pic`, `swfsc`, `calcofi`, `sccoos`)
- `dataset`: Dataset identifier (e.g., `dic`, `euphausiids`, `zooplankton`)
- `csv_path_or_directory` (optional): Path to source CSV files for auto-discovery

## Instructions

When the user invokes this skill:

### 1. Create directory structure

```
metadata/{provider}/{dataset}/
├── tbls_redefine.csv
├── flds_redefine.csv
└── metadata_derived.csv  (if needed)
```

Create the directory:
```bash
mkdir -p metadata/{provider}/{dataset}
```

### 2. If CSV path provided, auto-discover schema

Run R to extract table and field metadata from the source CSVs:

```r
devtools::load_all(here::here("../calcofi4db"))
librarian::shelf(dplyr, readr, here, glue, quiet = T)

provider  <- "{provider}"
dataset   <- "{dataset}"
csv_path  <- "{csv_path_or_directory}"

# read all CSVs and extract metadata
d <- read_csv_metadata(csv_path, here(glue("metadata/{provider}/{dataset}")))
```

If `read_csv_metadata()` is not available or the data is not in CSV format, manually create the metadata by reading the files:

```r
# read each CSV and extract column info
files <- list.files(csv_path, pattern = "\\.csv$", full.names = TRUE)
for (f in files) {
  d <- readr::read_csv(f, n_max = 100)
  cat(glue("\n## {basename(f)}: {nrow(d)} rows, {ncol(d)} cols\n"))
  cat(paste(names(d), collapse = ", "), "\n")
}
```

### 3. Create `tbls_redefine.csv`

Format (matching existing pattern from `metadata/swfsc/ichthyo/tbls_redefine.csv`):

```csv
tbl_old,tbl_new,tbl_description
{source_table_1},{new_table_1},{description}
{source_table_2},{new_table_2},{description}
```

Rules:
- `tbl_old`: Original CSV filename (without `.csv`) or source table name
- `tbl_new`: snake_case name following `{dataset}_{purpose}` convention
- `tbl_description`: **Required** — brief description of table contents.
  Markdown allowed. Must explain what one row represents.

### 4. Create `flds_redefine.csv`

Format (matching existing pattern):

```csv
tbl_old,tbl_new,fld_old,fld_new,type_old,type_new,order_old,order_new,fld_description,units,notes,mutation
{tbl_src},{tbl_new},{fld_src},{fld_new},{type_src},{type_new},{ord_src},{ord_new},{desc},{units},{notes},{mutation}
```

Rules:
- `fld_old`: Original column name from source CSV
- `fld_new`: snake_case name following CalCOFI conventions
- `type_new`: DuckDB type (`INTEGER`, `SMALLINT`, `DOUBLE`, `VARCHAR`, `DATE`, `TIMESTAMP`, `UUID`, `BOOLEAN`)
- `fld_description`: **Required** for every column. Markdown allowed.
  Empty descriptions land verbatim in the release `metadata.json` and
  break downstream catalogs.
- `units`: **Required** for any numeric/measurement column (e.g. `m`,
  `degC`, `PSS-78`, `decimal degrees`, `count`). Leave empty only for
  identifiers (PKs/FKs, `*_key`, `*_id`, `*_uuid`), categorical strings,
  timestamps, and geometry.
- `notes`: Optional QA notes (e.g. "renamed from `t_qual` for clarity")
- `mutation`: Optional SQL/dplyr expression for derived transformations

Standard column name mappings to apply:
- Latitude → `lat_dec` or `latitude` (type: double)
- Longitude → `lon_dec` or `longitude` (type: double)
- Date/DateTime → `datetime_utc` (type: timestamp)
- Station → `site_key` (type: varchar)
- Line → `line_key` (type: varchar)
- Depth → `depth_m` (type: double, units: m)
- Species/SppCode → `species_id` (type: smallint)
- CruiseID → `cruise_key` (type: varchar)

### 5. Create `metadata_derived.csv` (if needed)

For datasets that derive new columns not in the source:

```csv
table_new,field_new,field_type,field_description,derivation
{table},{field},{type},{desc},{how_derived}
```

### 6. Check measurement_type compatibility

If the dataset contains measurement columns, check against the existing `metadata/measurement_type.csv`:

```r
mt <- readr::read_csv(here("metadata/measurement_type.csv"))
# list existing measurement types
cat(paste(mt$measurement_type, collapse = "\n"))
```

Report which measurements already exist and which need to be added.

### 7. Register in `metadata/dataset.csv`

Add a row to the unified `dataset` reference table with:

```csv
provider,dataset,dataset_name,description,citation_main,citation_others,link_calcofi_org,link_data_source,link_others,tables,coverage_temporal,coverage_spatial,license,pi_names
```

Fields:
- `provider`: Organization curating the data (e.g., `calcofi`, `swfsc`, `pic`)
  — NOT the data portal (NCEI, EDI, ERDDAP)
- `citation_main`: Primary dataset citation (from DOI or data portal)
- `link_calcofi_org`: CalCOFI.org landing page for the dataset
- `link_data_source`: Data portal URL (NCEI accession, EDI package, ERDDAP endpoint)
- `link_others`: Semicolon-delimited additional links (DOI, publications)
- `tables`: Semicolon-delimited list of tables contributed to the database

Scrape the CalCOFI.org page and data portal landing page for citation,
DOI, PI names, and other metadata before filling in this row.

### 8. Present results to user

Show:
- Created file paths
- Table mapping summary
- Field mapping summary with any that need manual review
- Measurement types to add (if any)
- Dataset metadata row added to `metadata/dataset.csv`
- Instructions for next steps:
  1. Review and edit `flds_redefine.csv` (rename decisions, type overrides)
  2. Add new entries to `metadata/measurement_type.csv` if needed
  3. Run `/ingest-new {provider} {dataset}` to scaffold the ingest notebook

### 9. Hand-off completeness check

Before declaring the metadata scaffolding done, verify no row of
`tbls_redefine.csv` or `flds_redefine.csv` is missing the fields that
flow into the release `metadata.json` sidecar:

```r
librarian::shelf(readr, dplyr, glue, here, quiet = T)
provider <- "{provider}"; dataset <- "{dataset}"
dir_meta <- here(glue("metadata/{provider}/{dataset}"))

t <- read_csv(file.path(dir_meta, "tbls_redefine.csv"), show_col_types = F)
f <- read_csv(file.path(dir_meta, "flds_redefine.csv"), show_col_types = F)

bad_t <- t |> filter(is.na(tbl_description) | tbl_description == "")
bad_d <- f |> filter(is.na(fld_description) | fld_description == "")
bad_u <- f |>
  filter(
    !grepl("(_id|_key|_uuid|_qual|_flag|_status|_at|datetime|date|geom)$", fld_new),
    !type_new %in% c("VARCHAR", "TEXT", "TIMESTAMP", "DATE", "BOOLEAN", "UUID"),
    is.na(units) | units == "")

if (nrow(bad_t) + nrow(bad_d) + nrow(bad_u) > 0) {
  cat(glue("\nMETADATA GAPS:\n"))
  cat(glue("  tables missing tbl_description: {nrow(bad_t)}\n"))
  cat(glue("  fields missing fld_description: {nrow(bad_d)}\n"))
  cat(glue("  numeric fields missing units:   {nrow(bad_u)}\n"))
  print(bind_rows(bad_t |> mutate(gap = "tbl_description"),
                  bad_d |> mutate(gap = "fld_description"),
                  bad_u |> mutate(gap = "units")) |>
        select(any_of(c("tbl_new", "fld_new", "type_new", "gap"))))
} else {
  cat("All required descriptions and units populated.\n")
}
```

Resolve every gap (or justify it in the row's `notes` column) before
moving on to `/ingest-new`. The release `metadata.json` is the user-
facing source of truth — empty `description_md` / `units` ship straight
to consumers (calcofi4r `cc_describe_table()`, `cc_db_catalog()`).

## Example

```
/generate-metadata calcofi dic ~/My\ Drive/projects/calcofi/data-public/calcofi/dic
```

Creates:
```
metadata/calcofi/dic/
├── tbls_redefine.csv    # Maps CalCOFI_DIC_data → dic_measurement
├── flds_redefine.csv    # Maps DIC, TA, pH → standard names
└── metadata_derived.csv # (empty, no derived columns needed)
```
