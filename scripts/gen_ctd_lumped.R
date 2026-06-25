#!/usr/bin/env Rscript
# Build the LUMPED (single-file) wide variants + wide CSV (split+lumped, thin) for the
# split-vs-lumped granularity experiment. (Wide SPLIT parquet -> gen_ctd_wide.R; wide
# SPLIT netcdf -> gen_ctd_netcdf.R; wide DuckDB views -> gen_ctd_wide.R.) Run in rstudio:
#   docker exec rstudio Rscript /share/github/CalCOFI/workflows/scripts/gen_ctd_lumped.R
suppressMessages({ library(DBI); library(duckdb); library(glue); library(readr); library(ncdf4) })
WF   <- "/share/github/CalCOFI/workflows"
DATA <- "/share/data/erddap-duckdb/datasets"
SERV <- "/share/data/erddap-duckdb/serving"
TMP  <- "/share/data/erddap-duckdb/tmp"
source(file.path(WF, "libs/erddap.R")); source(file.path(WF, "libs/erddap_netcdf.R"))

mt <- read_csv(file.path(WF, "metadata/measurement_type.csv"), show_col_types = FALSE)
canonical   <- mt$measurement_type[mt$is_canonical %in% c(TRUE, "TRUE")]
units_lk    <- setNames(as.list(mt$units),       mt$measurement_type)
longname_lk <- setNames(as.list(mt$description),  mt$measurement_type)
nc_title <- c(ctd_thin = "CalCOFI CTD Profiles (thinned, NetCDF lumped)",
              ctd_measurement = "CalCOFI CTD Profiles (full, NetCDF lumped)")
nc_summ  <- "Single-file CF profile NetCDF of all cruises (lumped granularity, split-vs-lumped benchmark)."

wide_sql <- function(tbl, vars, time_expr, where = "") {
  val <- vapply(vars, function(v) glue(
    "MAX(t.measurement_value) FILTER (WHERE t.measurement_type='{v}')::DOUBLE AS \"{v}\""), character(1))
  glue("SELECT t.cruise_key, t.ctd_cast_uuid,
          {time_expr} AS time,
          any_value(c.latitude)::DOUBLE AS latitude, any_value(c.longitude)::DOUBLE AS longitude,
          t.depth_m::DOUBLE AS depth, any_value(c.line) AS line, any_value(c.sta) AS sta,
          {paste(val, collapse = ',\n          ')}
        FROM read_parquet('{DATA}/{tbl}/**/*.parquet', hive_partitioning=true) t
        JOIN read_parquet('{DATA}/ctd_cast.parquet') c USING (ctd_cast_uuid)
        {where} GROUP BY t.cruise_key, t.ctd_cast_uuid, t.depth_m")
}
epoch_t <- "epoch(any_value(c.datetime_start_utc))::DOUBLE"
mkdir <- function(...) { d <- file.path(...); dir.create(d, recursive = TRUE, showWarnings = FALSE); d }

con <- dbConnect(duckdb())
for (s in c("SET memory_limit='3GB'", "SET threads=2", glue("SET temp_directory='{TMP}'"),
            "SET preserve_insertion_order=false")) dbExecute(con, s)
present <- function(tbl) dbGetQuery(con, glue(
  "SELECT DISTINCT measurement_type FROM read_parquet('{DATA}/{tbl}/**/*.parquet', hive_partitioning=true)"))$measurement_type

# --- wide LUMPED parquet (single file per table) ---
for (tbl in c("ctd_thin", "ctd_measurement")) {
  vars <- intersect(canonical, present(tbl))
  f <- file.path(mkdir(SERV, "wide_lumped_parquet", tbl), paste0(tbl, ".parquet"))
  dbExecute(con, glue("COPY ({wide_sql(tbl, vars, epoch_t)}) TO '{f}' (FORMAT parquet)"))
  cat(sprintf("lumped parquet %s  %.1f MB\n", tbl, file.size(f) / 1048576))
}

# --- wide CSV, thin only (measurement CSV is tens of GB) ---
vars <- intersect(canonical, present("ctd_thin"))
f <- file.path(mkdir(SERV, "wide_lumped_csv", "thin"), "ctd_thin.csv")
dbExecute(con, glue("COPY ({wide_sql('ctd_thin', vars, epoch_t)}) TO '{f}' (FORMAT csv, HEADER)"))
cat(sprintf("lumped csv thin  %.1f MB\n", file.size(f) / 1048576))
d <- mkdir(SERV, "wide_split_csv", "thin")
cru <- setdiff(sort(sub("^cruise_key=", "", list.files(file.path(DATA, "ctd_thin"), pattern = "^cruise_key="))),
               "__HIVE_DEFAULT_PARTITION__")
for (ck in cru) {
  sql <- wide_sql("ctd_thin", vars, epoch_t, glue("WHERE t.cruise_key='{ck}'"))
  dbExecute(con, glue("COPY ({sql}) TO '{file.path(d, paste0(ck, '.csv'))}' (FORMAT csv, HEADER)"))
}
cat(sprintf("split csv thin  %d files\n", length(cru)))

# --- wide LUMPED netcdf (single CF file per table; heavy for measurement) ---
for (tbl in c("ctd_thin", "ctd_measurement")) {
  vars <- intersect(canonical, present(tbl))
  f <- file.path(mkdir(SERV, "wide_lumped_netcdf", tbl), paste0(tbl, ".nc"))
  dims <- build_ctd_netcdf_lumped(con, DATA, f, tbl, vars, nc_title[[tbl]], nc_summ, units_lk, longname_lk)
  cat(sprintf("lumped netcdf %s  profiles=%d obs=%d  %.1f MB\n",
              tbl, dims["nprof"], dims["nobs"], file.size(f) / 1048576))
}
dbDisconnect(con, shutdown = TRUE)
cat("done\n")
