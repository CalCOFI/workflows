#!/usr/bin/env Rscript
# Generate per-cruise CF "profile" NetCDF for the long CTD tables (the NATIVE
# ERDDAP serving path: EDDTableFromNcCFFiles). Each cruise -> one <cruise_key>.nc
# of canonical sensors pivoted WIDE (profile = cast, obs = depth). ~5.55M casts
# make per-cast files infeasible, so we bundle by cruise (96 files/table).
# Reads Parquet from and writes NetCDF to the shared /share/data tree so the paths
# resolve identically when ERDDAP later reads them. Run in the rstudio container:
#   docker exec rstudio Rscript /share/github/CalCOFI/workflows/scripts/gen_ctd_netcdf.R [thin|measurement|all] [n_cruises]
# (n_cruises limits to the first N cruises for a quick validation run.)
suppressMessages({ library(DBI); library(duckdb); library(glue); library(readr); library(ncdf4) })
options(readr.show_col_types = FALSE)
WF <- "/share/github/CalCOFI/workflows"
source(file.path(WF, "libs/erddap.R")); source(file.path(WF, "libs/erddap_netcdf.R"))

DATA <- "/share/data/erddap-duckdb/datasets"
NCDIR <- "/share/data/erddap-duckdb/netcdf"
TMP  <- "/share/data/erddap-duckdb/tmp"

argv   <- commandArgs(trailingOnly = TRUE)
which_ <- if (length(argv) >= 1) argv[1] else "all"
ncru   <- if (length(argv) >= 2) as.integer(argv[2]) else NA_integer_
tables <- if (which_ == "all") c("ctd_thin", "ctd_measurement") else paste0("ctd_", sub("^ctd_", "", which_))

# canonical measurement_types + units / long_name lookups
mt <- read_csv(file.path(WF, "metadata/measurement_type.csv"))
canonical <- mt$measurement_type[mt$is_canonical %in% c(TRUE, "TRUE")]
units_lk    <- setNames(as.list(mt$units),       mt$measurement_type)
longname_lk <- setNames(as.list(mt$description), mt$measurement_type)

con <- dbConnect(duckdb())   # one connection, reused for present-types + all builds
for (s in c("SET memory_limit='2GB'", "SET threads=2", glue("SET temp_directory='{TMP}'"))) dbExecute(con, s)
present_types <- function(tbl) dbGetQuery(con, glue(
  "SELECT DISTINCT measurement_type FROM read_parquet('{DATA}/{tbl}/**/*.parquet', hive_partitioning=true)"))$measurement_type

titles <- c(ctd_thin = "CalCOFI CTD Profiles (thinned, NetCDF)",
            ctd_measurement = "CalCOFI CTD Profiles (full, NetCDF)")
summaries <- c(
  ctd_thin = paste("Adaptively-thinned CalCOFI CTD profiles as CF Discrete-Sampling-Geometry",
    "profile files, one per cruise (profile = cast, obs = depth; canonical sensors as variables).",
    "The native ERDDAP representation (EDDTableFromNcCFFiles) of the long ctd_thin table."),
  ctd_measurement = paste("Full-resolution CalCOFI CTD profiles as CF Discrete-Sampling-Geometry",
    "profile files, one per cruise (profile = cast, obs = depth; canonical sensors as variables).",
    "The native ERDDAP representation (EDDTableFromNcCFFiles) of the long ctd_measurement table."))

for (tbl in tables) {
  present <- present_types(tbl)
  vars <- intersect(canonical, present)            # canonical order, only those present
  out  <- file.path(NCDIR, sub("^ctd_", "", tbl))
  cru  <- sort(sub("^cruise_key=", "", list.files(file.path(DATA, tbl), pattern = "^cruise_key=")))
  if (!is.na(ncru)) cru <- head(cru, ncru)
  cat(sprintf("\n=== %s -> %s : %d vars, %d cruises ===\n  vars: %s\n",
              tbl, out, length(vars), length(cru), paste(vars, collapse = ", ")))
  res <- build_ctd_netcdf(
    con = con, data_dir = DATA, out_dir = out, table = tbl, vars = vars,
    title = titles[[tbl]], summary = summaries[[tbl]],
    units_lookup = units_lk, longname_lookup = longname_lk,
    cruises = cru, mem_limit = "2GB", threads = 2, tmp_dir = TMP)
  tot_mb <- sum(res$mb, na.rm = TRUE)
  cat(sprintf("  DONE %s: %d files, %.1f MB total\n", tbl, nrow(res), tot_mb))
  write_csv(res, file.path(out, "_manifest.csv"))
}
dbDisconnect(con, shutdown = TRUE)
cat("\nall done\n")
