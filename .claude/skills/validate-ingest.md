---
description: Run post-ingest validation checks on a CalCOFI wrangling database
user_invocable: true
---

# /validate-ingest

Run comprehensive post-ingest validation on a DuckDB wrangling database or parquet output directory.

## Usage

```
/validate-ingest {provider} {dataset} [--strict] [--checks=all]
```

## Arguments

- `provider`: Data provider identifier (e.g., `ncei`, `edi`, `pic`, `swfsc`, `calcofi`)
- `dataset`: Dataset identifier (e.g., `dic`, `euphausiids`, `zooplankton`)

## Options

- `--strict`: Treat warnings as errors (fail on any issue)
- `--checks={check_list}`: Comma-separated list of checks to run (default: `all`)
  - Available: `pks`, `fks`, `nulls`, `ranges`, `counts`, `orphans`, `duplicates`, `spatial`, `temporal`

## Instructions

When the user invokes this skill:

### 1. Locate the database/parquet

Check for the wrangling DuckDB and parquet outputs:

```r
devtools::load_all(here::here("../calcofi4db"))
librarian::shelf(DBI, dplyr, glue, here, quiet = T)

provider    <- "{provider}"
dataset     <- "{dataset}"
dir_label   <- glue("{provider}_{dataset}")
db_path     <- here(glue("data/wrangling/{dir_label}.duckdb"))
parquet_dir <- here(glue("data/parquet/{dir_label}"))

# prefer wrangling DB if exists, otherwise load from parquet
if (file.exists(db_path)) {
  con <- get_duckdb_con(db_path)
  cat("Using wrangling DuckDB:", db_path, "\n")
} else if (dir.exists(parquet_dir)) {
  con <- get_duckdb_con(":memory:")
  load_prior_tables(con, parquet_dir)
  cat("Loaded from parquet:", parquet_dir, "\n")
} else {
  stop("No wrangling DB or parquet found for ", dir_label)
}
```

### 2. Run validation checks

Execute these checks and collect results:

#### A. Primary Key Uniqueness (`pks`)
```r
# for each table, check that declared PKs are unique
tables <- dbListTables(con)
for (tbl in tables) {
  # get PK columns from flds_redefine.csv or relationships.json
  pk_cols <- get_pk_columns(tbl)  # from metadata
  if (length(pk_cols) > 0) {
    n_total <- dbGetQuery(con, glue("SELECT COUNT(*) as n FROM {tbl}"))$n
    n_unique <- dbGetQuery(con, glue(
      "SELECT COUNT(*) as n FROM (SELECT DISTINCT {paste(pk_cols, collapse=', ')} FROM {tbl})"))$n
    if (n_total != n_unique) {
      report_error("PK violation", tbl, glue("{n_total - n_unique} duplicate keys"))
    }
  }
}
```

#### B. Foreign Key Integrity (`fks`)
```r
# use validate_fk_references() from calcofi4db
# check all FK relationships defined in flds_redefine.csv
flds <- readr::read_csv(here(glue("metadata/{provider}/{dataset}/flds_redefine.csv")))
fk_fields <- flds |> filter(is_fk == TRUE)
for (i in seq_len(nrow(fk_fields))) {
  orphans <- validate_fk_references(
    con,
    data_tbl  = fk_fields$table_new[i],
    fk_col    = fk_fields$field_new[i],
    ref_tbl   = fk_fields$fk_table[i],
    ref_col   = fk_fields$fk_field[i])
  if (nrow(orphans) > 0) {
    report_warning("FK orphans", fk_fields$table_new[i],
      glue("{nrow(orphans)} orphan rows in {fk_fields$field_new[i]}"))
  }
}
```

#### C. NULL Rate Analysis (`nulls`)
```r
# for each table/column, report NULL rates
# flag columns with >50% NULLs as warnings, >95% as errors
for (tbl in tables) {
  cols <- dbListFields(con, tbl)
  for (col in cols) {
    null_pct <- dbGetQuery(con, glue(
      "SELECT ROUND(100.0 * SUM(CASE WHEN \"{col}\" IS NULL THEN 1 ELSE 0 END) / COUNT(*), 1) as pct
       FROM {tbl}"))$pct
    if (null_pct > 95) report_error("NULL rate", tbl, glue("{col}: {null_pct}% NULL"))
    else if (null_pct > 50) report_warning("NULL rate", tbl, glue("{col}: {null_pct}% NULL"))
  }
}
```

#### D. Coordinate Ranges (`spatial`)
```r
# check lat/lon are within CalCOFI extent
# CalCOFI grid: ~23-51°N latitude, ~-170 to -117°W longitude
spatial_checks <- list(
  lat = list(min = 23, max = 51, col_patterns = c("lat", "latitude", "lat_dec")),
  lon = list(min = -170, max = -117, col_patterns = c("lon", "longitude", "lon_dec"))
)
```

#### E. Date Ranges (`temporal`)
```r
# check dates are within reasonable CalCOFI range (1949-present)
# flag future dates and pre-1949 dates
date_cols <- c("datetime_utc", "date", "cruise_date")
```

#### F. Row Count Sanity (`counts`)
```r
# compare row counts against expectations
# - tables should have > 0 rows
# - fact tables should have reasonable ratios to dimension tables
# - compare against prior release if available
```

#### G. Orphan Records (`orphans`)
```r
# check for records that don't link to any parent/child
# e.g., casts with no measurements, species with no occurrences
```

#### H. Duplicate Detection (`duplicates`)
```r
# check for exact duplicate rows (all columns identical)
# check for near-duplicates (same key columns, different values)
```

#### I. Measurement Summary Consistency (`summary`)
```r
# if a *_measurement_summary table exists, validate:
# - all summary rows have n_obs >= 1
# - stddev == 0 when n_obs == 1
# - no NaN or Inf in avg or stddev columns
# - summary row count <= measurement row count
# - measurement types in summary match measurement table
for (tbl in tables) {
  if (grepl("_summary$", tbl)) {
    # check for NaN/Inf in summary values
    bad_vals <- dbGetQuery(con, glue(
      "SELECT COUNT(*) FROM {tbl}
       WHERE isnan(avg) OR NOT isfinite(avg)
          OR isnan(stddev) OR NOT isfinite(stddev)"))[[1]]
    if (bad_vals > 0) report_error("summary NaN/Inf", tbl, glue("{bad_vals} rows"))
    # check stddev = 0 when n_obs = 1
    bad_stddev <- dbGetQuery(con, glue(
      "SELECT COUNT(*) FROM {tbl}
       WHERE n_obs = 1 AND stddev != 0"))[[1]]
    if (bad_stddev > 0) report_warning("stddev != 0 for n_obs=1", tbl, bad_stddev)
  }
}
```

### 3. Cross-dataset validation

If prior ingest parquet exists, also validate cross-dataset integrity:

```r
# load shared tables from prior ingests
prior_dirs <- list(
  swfsc_ichthyo = here("data/parquet/swfsc_ichthyo"),
  calcofi_bottle = here("data/parquet/calcofi_bottle")
)

for (prior_name in names(prior_dirs)) {
  if (dir.exists(prior_dirs[[prior_name]])) {
    # check cruise_key references
    # check grid_key references
    # check ship_key references
    # check species_id references (if taxonomy dataset)
  }
}
```

### 4. Generate validation report

Format results as a structured markdown report:

```markdown
## Validation Report: {provider}_{dataset}

### Summary
- **Status**: {PASS/WARN/FAIL}
- **Tables checked**: {n}
- **Errors**: {n_errors}
- **Warnings**: {n_warnings}

### Primary Key Checks
| Table | PK Columns | Total Rows | Unique Keys | Status |
|-------|-----------|------------|-------------|--------|

### Foreign Key Checks
| Table | FK Column | Ref Table | Ref Column | Orphans | Status |
|-------|----------|-----------|------------|---------|--------|

### NULL Analysis
| Table | Column | NULL % | Status |
|-------|--------|--------|--------|

### Spatial Checks
| Table | Column | Min | Max | Out of Range | Status |
|-------|--------|-----|-----|-------------|--------|

### Temporal Checks
| Table | Column | Min Date | Max Date | Status |
|-------|--------|----------|----------|--------|

### Row Counts
| Table | Rows | Status |
|-------|------|--------|

### Cross-Dataset Integrity
| This Table.Column | Ref Table.Column | Match Rate | Status |
|-------------------|-----------------|------------|--------|
```

### 5. Also run calcofi4db's built-in validation

```r
results <- validate_for_release(con, checks = "all", strict = FALSE)
cat("Built-in validation:", ifelse(results$passed, "PASSED", "FAILED"), "\n")
if (length(results$errors) > 0) cat("Errors:\n", paste("-", results$errors, collapse = "\n"))
if (length(results$warnings) > 0) cat("Warnings:\n", paste("-", results$warnings, collapse = "\n"))
```

### 6. Save validation artifacts

```r
# save report to data/flagged/{provider}_{dataset}_validation.md
# save any orphan/invalid rows to data/flagged/
```

### 7. Present results

Show the validation report and recommend actions:
- For errors: specific fix instructions
- For warnings: whether they're acceptable or need attention
- If all pass: confirm ready for `release_database.qmd` inclusion
