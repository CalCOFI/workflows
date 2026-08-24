---
name: validate-ingest
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
  - Available: `pks`, `fks`, `nulls`, `ranges`, `depth`, `counts`, `orphans`, `duplicates`, `spatial`, `temporal`, `schema_lint`, `questions`

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

#### D2. Declared measurement bounds (`ranges`)

The bounds check every dataset runs. Compares each measured value against the
`valid_min` / `valid_max` in `metadata/measurement_type.csv` **and reports the
types that declare no bound at all**, which is the majority case and the reason
this belongs here rather than only in `release_database.qmd`.

This check was listed in `--checks` for months without a section implementing it,
which is the same defect it exists to catch: a constraint that is declared,
displayed, and never applied. At v2026.08.07 that cost ~31k impossible CTD values
(pH to -10, oxygen to -79.5 ml/l) plus a `-99` sentinel sitting in
`calcofi_mets.sw_ph` at 16.6% of its rows — with the bound *declared* and unread.

```r
b <- calcofi4db::check_measurement_bounds(
  con,
  tbl = glue("{dataset}_measurement"),   # or "obs" once the core is emitted
  mt  = here("metadata/measurement_type.csv"))

oob <- dplyr::filter(b, status == "out_of_range")
und <- dplyr::filter(b, status == "undeclared")

# an out-of-range value is an ERROR: a bound was agreed and the data breaks it
for (i in seq_len(nrow(oob)))
  report_error("bounds out_of_range", oob$measurement_type[i], oob$finding[i])

# an undeclared type is a WARNING (error under --strict): nothing was checked,
# so a clean report here means nothing
for (i in seq_len(nrow(und)))
  report_warning("bounds undeclared", und$measurement_type[i], und$finding[i])
```

Render a `### Declared Bounds` table straight from `bounds_datatable(b)`, then
resolve every non-`ok` row one of two ways — **neither of which is "note it and
move on"**:

1. **Declare the bound** via `declare_measurement_bounds()` when the plausible
   range is known — `register_measurement_types()` only *appends*, so it cannot
   put a bound on a type that is already registered without one. Bounds are deliberately generous: they catch the impossible,
   they do not police oceanography. A one-sided `valid_min = 0` for a count,
   abundance or biomass is the common case and worth declaring even with no
   meaningful ceiling — it is what catches a negative sentinel.
2. **File a provider question** when it is not ours to decide. Append to
   `metadata/{provider}/{dataset}/questions.csv` using the `finding` column as
   the `context` verbatim — it already carries the counts and the observed range:

   ```r
   # status = "proposed", not "open": pre-answer everything the repo can settle,
   # so the provider confirms a bound rather than being handed a problem
   tibble::tibble(
     label           = "Q07",                       # next free label in this file
     id              = glue("{provider}_{dataset}_07"),
     question        = glue("What is the physically possible range for ",
                            "`{und$measurement_type[1]}`?"),
     context         = und$finding[1],
     status          = "proposed",
     priority        = if (grepl("^-9+$", und$v_min[1])) "high" else "normal",
     proposed_answer = "Propose valid_min = 0 (a negative abundance is impossible)",
     asked_date      = Sys.Date())
   ```

   Write it back with `readr::write_csv(q, q_path, na = "")` — never the default
   `na = "NA"` — and re-read with `read_questions()` so a malformed row fails
   here rather than in the notebook that renders it.

A value at exactly `-99` / `-999` / `-9999` is a sentinel until proven otherwise;
raise it as `priority = high` and say so in the question rather than quietly
declaring a bound that deletes it.

#### D3. Depth coordinates (`depth`)

A depth is a coordinate, and `check_measurement_bounds()` bounds **values**: the
CTD ingest deleted a 17,964 dbar `pressure` by its bound and shipped the 14,671 m
depth derived from it (v2026.08.14, cast `0010_001d`, over a 101 m seafloor).
Two checks, two consequences:

```r
# 1. absolute range — an ERROR. NaN, negative, or beyond CC_DEPTH_MAX_M (6,500 m)
d <- calcofi4db::check_depth_bounds(con, tbls = c("sample", "obs"))
for (i in which(d$status != "ok"))
  report_error("depth out_of_range", glue("{d$table[i]}.{d$depth_col[i]}"),
               glue("{d$n_nan[i]} NaN, {d$n_below[i]} < 0, {d$n_above[i]} > {CC_DEPTH_MAX_M} m"))

# 2. seafloor — a WARNING to take to the provider, never a delete. The deepest
#    depth attributed to each root sample against the deepest GEBCO cell within
#    one cell of its position, +10 m. Off-raster positions are `unknown`.
gebco <- Sys.getenv("CALCOFI_GEBCO_TIF",
  "~/_big/gebco_2025_sub_ice_topo_geotiff/gebco_2025_sub_ice_n90.0_s0.0_w-180.0_e-90.0.tif")
v <- calcofi4db::check_depth_vs_seafloor(con, path.expand(gebco), tolerance_m = 10)
for (i in seq_len(min(nrow(v), 20)))
  report_warning("deeper than seafloor", v$sample_key[i],
                 glue("{v$depth_m[i]} m at ({v$longitude[i]}, {v$latitude[i]}); ",
                      "seafloor {v$seafloor_max3x3_m[i]} m (+{round(v$excess_m[i])})"))
```

Why the second is a warning: across the v2026.08.14 release 695 of 412,640 root
samples fail it, and all but the CTD cast are within 1.2 km — 1949–1975 casts
and tows on the slope and in canyons with minute-rounded positions. That is a
position-precision finding for a `questions.csv` row (`priority = normal`, with
the worst cases as `context`), not a row to drop: the measurement is fine, the
place is imprecise. `release_database.qmd`'s `depth_coverage` chunk fails a
release on check 1 and ratchets check 2 (`DEPTH_SEAFLOOR_OVER_MAX`, only ever
down), and stamps `seafloor_depth_m` on `sample` so consumers can look.

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

#### I0. Nullable-case reconciliation (do this before trusting the verdict)

`validate_for_release()`'s null check flags every `_id`/`_key`/`_uuid` column, so a
dataset with legitimately-nullable keys reports FAILED for non-defects. Do NOT
summarise that as "all expected" — declare each case with its count and reason and
hard-fail on anything undeclared or moved. See `ingest_cdfw_dungeness-crab.qmd`
("Validate") for the pattern. A blanket "expected" is what let a completely empty
`taxon` lineage sit unnoticed among 17 accepted null warnings.

#### I2. Core Table Projection Parity (`core_parity`)
```r
# every ingest emits the core tables (emit_core, RUNBOOK 3b) — assert its
# projection reproduces the per-dataset detail for this dataset_key:
# - count(*) in obs for this dataset_key == the per-dataset headline count
#   (bio base rows; env measurement rows — CTD counted via ctd_thin)
# - sample counts per sample_type match the distinct source event ids
# - every obs.sample_key resolves in sample; obs.measurement_type in the registry
# - obs_attribute stage bins SUM(count) == the abundance headline per occurrence
#   (report as a warning — a staged subsample may legitimately differ)
# The authoritative, cross-dataset version of these assertions runs in
# release_database.qmd's `core_parity` chunk (hard stopifnot); mirror the
# dataset-scoped subset here for early feedback.
```

#### J. Schema Lint vs the field dictionary (`schema_lint`)

Enforce cross-dataset consistency by comparing this dataset's
`flds_redefine.csv` against the canonical `metadata/field_dictionary.csv`.
Report findings as **warnings** by default (legitimate new canonical fields
exist and the dictionary grows over time); `--strict` promotes them to errors
for release gating.

```r
fd  <- readr::read_csv(here("metadata/field_dictionary.csv"), show_col_types = F)
fld <- readr::read_csv(here(glue("metadata/{provider}/{dataset}/flds_redefine.csv")),
                       show_col_types = F)

canon <- fd$fld_new
# raw pre-pivot measurement columns are exempt (they map to measurement_type.csv
# and get pivoted into *_measurement); skip obvious quality/identifier suffixes too
is_exempt <- function(x) grepl("(_qual|_flag|q$)$", x)

for (i in seq_len(nrow(fld))) {
  f <- fld$fld_new[i]
  hit <- fd[fd$fld_new == f, ]
  if (nrow(hit) == 1) {
    # (b) type mismatch vs dictionary
    if (!is.na(fld$type_new[i]) &&
        toupper(fld$type_new[i]) != toupper(hit$type_new))
      report_warning("schema_lint type", f,
        glue("dataset={fld$type_new[i]} vs dictionary={hit$type_new}"))
    # (c) units mismatch vs dictionary
    du <- fld$units[i] %||% ""; cu <- hit$units %||% ""
    if (nzchar(cu) && nzchar(du) && du != cu)
      report_warning("schema_lint units", f,
        glue("dataset='{du}' vs dictionary='{cu}'"))
  } else if (!is_exempt(f)) {
    # (a) fld_new not in dictionary and not an obvious raw/measurement column.
    # check whether it is a known alias that should have been normalized.
    alias_hit <- fd[grepl(paste0("(^|;)", f, "(;|$)"), fd$aliases, ignore.case = TRUE), ]
    if (nrow(alias_hit) >= 1)
      report_warning("schema_lint alias-not-normalized", f,
        glue("'{f}' is an alias of canonical '{alias_hit$fld_new[1]}' — rename it"))
    else
      report_warning("schema_lint new-field", f,
        "not in field_dictionary.csv — add a canonical row or confirm it is a raw measurement")
  }
}
# (d) cross-dataset collision: same fld_new used with different type/units than
#     any prior dataset is caught implicitly above because the dictionary is the
#     single source of truth — a prior dataset that drifted will itself lint.
```

Render a `### Schema Lint` table: `fld_new | issue | dictionary_says | dataset_has | status`.

#### K. Provider questions triaged (`questions`)

Confirm the dataset carries a questions file and that no release-blocking
question is still open.

```r
q_path <- here(glue("metadata/{provider}/{dataset}/questions.csv"))
if (!file.exists(q_path)) {
  report_warning("questions", dataset, "no questions.csv — run /explore-dataset to seed one")
} else {
  # read_questions() enforces the controlled vocabulary (open | proposed |
  # answered | wontfix; blocker | high | normal | low) and the label rules, so a
  # registry that invents a status fails here rather than dropping out of the
  # filter below unnoticed
  q <- calcofi4db::read_questions(q_path)
  open_blockers <- dplyr::filter(q, status == "open", priority == "blocker")
  if (nrow(open_blockers) > 0)
    report_warning("questions blocker-open", dataset,  # error under --strict
      glue("{nrow(open_blockers)} blocker question(s) still open: {paste(open_blockers$label, collapse=', ')}"))
  # `proposed` is NOT open — we have an answer awaiting confirmation — but it is
  # not settled either, so report the count rather than letting it read as done
  n_prop <- sum(q$status == "proposed")
  if (n_prop > 0)
    cat(glue("questions proposed | {dataset} | {n_prop} awaiting provider ",
             "confirmation: {paste(q$label[q$status == 'proposed'], collapse=', ')}\n"))
}
```

Under `--strict`, an open `blocker` question is an **error** (gates release);
otherwise a warning. A `proposed` question never gates. Include both lists in
the report.

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
    # check cruise_key format (YYYY-MM-NODC)
    # validate: grepl("^\\d{4}-\\d{2}-.+$", cruise_key)
    # check site_key format (NNN.N NNN.N)
    # validate: grepl("^\\d{3}\\.\\d \\d{3}\\.\\d$", site_key)
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

### Declared Bounds
| Measurement Type | Status | Rows | Out of Range | % | Observed | Declared |
|------------------|--------|------|--------------|---|----------|----------|

Report `undeclared` rows in this table too — a bounds section listing only
violations reads as "checked and clean" when most types were never checked.

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

### 7. Validate metadata.json completeness

Open `data/parquet/{provider}_{dataset}/metadata.json` and enforce three
hard assertions. Failures should appear in the validation report as
**errors** (not warnings) since these fields are user-facing in
`cc_describe_table()` and `cc_db_catalog()`.

```r
librarian::shelf(jsonlite, glue, here, dplyr, quiet = T)
provider <- "{provider}"; dataset <- "{dataset}"
meta_path <- here(glue("data/parquet/{provider}_{dataset}/metadata.json"))
stopifnot(file.exists(meta_path))
m <- fromJSON(meta_path, simplifyVector = FALSE)

# (a) every table has non-empty description_md
no_tbl_desc <- names(Filter(function(t) !nzchar(t$description_md %||% ""), m$tables))

# (b) every non-identifier, non-geometry, non-qual column has non-empty description_md
is_identifier <- function(col) grepl("(_id|_key|_uuid|_qual|_flag|_status|_at|geom|datetime|date)$", col)
no_col_desc <- vapply(names(m$columns), function(k) {
  col <- sub("^[^.]+\\.", "", k)
  !is_identifier(col) && !nzchar(m$columns[[k]]$description_md %||% "")
}, logical(1))
no_col_desc <- names(m$columns)[no_col_desc]

# (c) measurement_value / avg / stddev columns must have a unit (either inline
#     or via the measurement_type CSV)
mt <- read.csv(here("metadata/measurement_type.csv"), stringsAsFactors = FALSE)
measurement_cols <- grep("\\.(measurement_value|avg|stddev|value)$",
                         names(m$columns), value = TRUE)
no_unit <- vapply(measurement_cols, function(k) {
  is.null(m$columns[[k]]$units) || !nzchar(m$columns[[k]]$units)
}, logical(1))
no_unit <- measurement_cols[no_unit]
# any of these MUST be paired with a measurement_type column whose values are
# all registered in measurement_type.csv. Flag if not.

cat(glue("\nMetadata completeness for {provider}_{dataset}:\n"))
cat(glue("  tables with empty description_md: {length(no_tbl_desc)}\n"))
cat(glue("  non-identifier columns with empty description_md: {length(no_col_desc)}\n"))
cat(glue("  measurement columns with NULL units: {length(no_unit)}\n"))

# Hard fail if any tables are undocumented or > 25% of non-ID columns are undocumented
status <- "PASS"
if (length(no_tbl_desc) > 0) status <- "ERROR"
n_doc_cols <- sum(!vapply(names(m$columns), function(k) {
  col <- sub("^[^.]+\\.", "", k); is_identifier(col)
}, logical(1)))
if (n_doc_cols > 0 && length(no_col_desc) / n_doc_cols > 0.25) status <- "ERROR"
if (length(no_unit) > 0) status <- "ERROR"
cat(glue("  metadata.json status: {status}\n"))
```

Include the lists of offending tables/columns in the report so the user
has a copy-paste TODO for the underlying `tbls_redefine.csv` and
`flds_redefine.csv`.

### 8. Present results

Show the validation report and recommend actions:
- For errors: specific fix instructions
- For warnings: whether they're acceptable or need attention
- If all pass: confirm ready for `release_database.qmd` inclusion
