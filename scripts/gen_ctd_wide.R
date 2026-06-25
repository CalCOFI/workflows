#!/usr/bin/env Rscript
# Generate WIDE-format CTD variants for the apples-to-apples (wide<->wide) benchmark,
# so format (NetCDF/DuckDB/Parquet) can be compared at a CONSTANT schema:
#   - DuckDB wide pivot VIEWS in a SEPARATE calcofi_ctd_wide.db (canonical sensors
#     pivoted to columns) — kept apart from the prod .db that the live erddap holds
#     open read-only, so we never need a write-lock on it.
#   - per-cruise WIDE Parquet (one file per cruise, cruise_key kept as a column) for
#     EDDTableFromParquetFiles — same canonical pivot, time as epoch-seconds double.
# Same pivot as the NetCDF generator (canonical measurement_types ∩ present per table).
# Run in the rstudio container:
#   docker exec rstudio Rscript /share/github/CalCOFI/workflows/scripts/gen_ctd_wide.R [thin|measurement|all] [n_cruises]
suppressMessages({ library(DBI); library(duckdb); library(glue); library(readr) })
WF     <- "/share/github/CalCOFI/workflows"
DATA   <- "/share/data/erddap-duckdb/datasets"
WIDEDB <- "/share/data/erddap-duckdb/duckdb/calcofi_ctd_wide.db"
PWIDE  <- "/share/data/erddap-duckdb/parquet_wide"
TMP    <- "/share/data/erddap-duckdb/tmp"

argv   <- commandArgs(trailingOnly = TRUE)
which_ <- if (length(argv) >= 1) argv[1] else "all"
ncru   <- if (length(argv) >= 2) as.integer(argv[2]) else NA_integer_
tables <- if (which_ == "all") c("ctd_thin", "ctd_measurement") else paste0("ctd_", sub("^ctd_", "", which_))

mt <- read_csv(file.path(WF, "metadata/measurement_type.csv"), show_col_types = FALSE)
canonical <- mt$measurement_type[mt$is_canonical %in% c(TRUE, "TRUE")]

# wide pivot SELECT; time_expr differs (TIMESTAMP for the DuckDB view -> getTimestamp;
# epoch DOUBLE for Parquet). cruise_key/cast/depth are GROUP keys so a cruise_key or
# depth predicate prunes at the Parquet scan; lat/lon/time/line/sta are per-cast (any_value).
wide_sql <- function(tbl, vars, time_expr, where = "") {
  val <- vapply(vars, function(v) glue(
    "MAX(t.measurement_value) FILTER (WHERE t.measurement_type='{v}')::DOUBLE AS \"{v}\""),
    character(1))
  glue("SELECT t.cruise_key, t.ctd_cast_uuid,
          {time_expr} AS time,
          any_value(c.latitude)::DOUBLE  AS latitude,
          any_value(c.longitude)::DOUBLE AS longitude,
          t.depth_m::DOUBLE              AS depth,
          any_value(c.line) AS line, any_value(c.sta) AS sta,
          {paste(val, collapse = ',\n          ')}
        FROM read_parquet('{DATA}/{tbl}/**/*.parquet', hive_partitioning=true) t
        JOIN read_parquet('{DATA}/ctd_cast.parquet') c USING (ctd_cast_uuid)
        {where}
        GROUP BY t.cruise_key, t.ctd_cast_uuid, t.depth_m")
}

con <- dbConnect(duckdb())
for (s in c("SET memory_limit='2GB'", "SET threads=2", glue("SET temp_directory='{TMP}'"),
            "SET preserve_insertion_order=false")) dbExecute(con, s)
present <- function(tbl) dbGetQuery(con, glue(
  "SELECT DISTINCT measurement_type FROM read_parquet('{DATA}/{tbl}/**/*.parquet', hive_partitioning=true)"))$measurement_type
vars_of <- setNames(lapply(tables, function(t) intersect(canonical, present(t))), tables)

# --- DuckDB wide views (separate .db; fresh) ---
if (file.exists(WIDEDB)) file.remove(WIDEDB)
con_db <- dbConnect(duckdb(), WIDEDB)
for (tbl in tables) {
  dbExecute(con_db, glue("CREATE OR REPLACE VIEW {tbl}_wide_erddap AS {wide_sql(tbl, vars_of[[tbl]], 'any_value(c.datetime_start_utc)')}"))
  cat(sprintf("view %-26s (%d vars)\n", paste0(tbl, "_wide_erddap"), length(vars_of[[tbl]])))
}
dbDisconnect(con_db, shutdown = TRUE)

# --- per-cruise wide Parquet (one file per cruise, cruise_key as a column) ---
for (tbl in tables) {
  vars <- vars_of[[tbl]]
  outdir <- file.path(PWIDE, tbl); dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
  cru <- setdiff(sort(sub("^cruise_key=", "", list.files(file.path(DATA, tbl), pattern = "^cruise_key="))),
                 "__HIVE_DEFAULT_PARTITION__")
  if (!is.na(ncru)) cru <- head(cru, ncru)
  for (i in seq_along(cru)) {
    ck <- cru[i]; f <- file.path(outdir, paste0(ck, ".parquet"))
    sql <- wide_sql(tbl, vars, "epoch(any_value(c.datetime_start_utc))::DOUBLE", glue("WHERE t.cruise_key='{ck}'"))
    n <- dbExecute(con, glue("COPY ({sql}) TO '{f}' (FORMAT parquet)"))
    if (i %% 10 == 0 || i == length(cru)) cat(sprintf("  %s parquet %d/%d\n", tbl, i, length(cru)))
  }
  cat(sprintf("DONE %s wide parquet -> %s (%d files, %s)\n", tbl, outdir, length(cru),
              format(sum(file.size(list.files(outdir, full.names = TRUE))) / 1048576, digits = 4)))
}
dbDisconnect(con, shutdown = TRUE)
cat("done\n")
