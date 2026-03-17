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
table_source,table_new,table_description,include
{source_table_1},{new_table_1},{description},TRUE
{source_table_2},{new_table_2},{description},TRUE
```

Rules:
- `table_source`: Original CSV filename (without .csv extension) or table name
- `table_new`: snake_case name following `{dataset}_{purpose}` convention
- `table_description`: Brief description of table contents
- `include`: TRUE to include in ingest, FALSE to skip

### 4. Create `flds_redefine.csv`

Format (matching existing pattern):

```csv
table_source,table_new,field_source,field_new,field_type,field_description,field_units,include,is_pk,is_fk,fk_table,fk_field,field_order
{tbl_src},{tbl_new},{fld_src},{fld_new},{type},{desc},{units},TRUE,FALSE,FALSE,,,1
```

Rules:
- `field_source`: Original column name from CSV
- `field_new`: snake_case name following CalCOFI conventions
- `field_type`: DuckDB/PostgreSQL type (integer, smallint, double, varchar, date, timestamp, uuid, boolean)
- `field_units`: SI units where applicable
- `include`: TRUE to include, FALSE to drop
- `is_pk`: TRUE if primary key
- `is_fk`: TRUE if foreign key referencing another table
- `fk_table`, `fk_field`: Referenced table and field for FKs

Standard column name mappings to apply:
- Latitude → `lat_dec` or `latitude` (type: double)
- Longitude → `lon_dec` or `longitude` (type: double)
- Date/DateTime → `datetime_utc` (type: timestamp)
- Station → `sta_key` (type: varchar)
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

### 7. Present results to user

Show:
- Created file paths
- Table mapping summary
- Field mapping summary with any that need manual review
- Measurement types to add (if any)
- Instructions for next steps:
  1. Review and edit `flds_redefine.csv` (rename decisions, type overrides, include/exclude)
  2. Add new entries to `metadata/measurement_type.csv` if needed
  3. Run `/ingest-new {provider} {dataset}` to scaffold the ingest notebook

## Example

```
/generate-metadata ncei dic ~/My\ Drive/projects/calcofi/data-public/ncei/dic
```

Creates:
```
metadata/ncei/dic/
├── tbls_redefine.csv    # Maps CalCOFI_DIC_data → dic_measurement
├── flds_redefine.csv    # Maps DIC, TA, pH → standard names
└── metadata_derived.csv # (empty, no derived columns needed)
```
