#!/usr/bin/env Rscript
# Generate the ERDDAP <dataset> blocks for the CTD serving-backend benchmark:
# {ctd_thin, ctd_measurement} x {DuckDB (EDDTableFromDatabase), Parquet
# (EDDTableFromParquetFiles), CSV (EDDTableFromAsciiFiles)}. Reuses the shared
# dataVariable/type/units machinery in libs/erddap.R so the bench XML matches the
# production pattern. Writes one block per (table x approach) to
# data/bench_erddap/<datasetID>.xml; the harness splices them into the bench
# datasets.xml one at a time. Run inside the rstudio container:
#   docker exec rstudio Rscript /share/github/CalCOFI/workflows/scripts/gen_bench_datasets.R
suppressMessages({ library(glue); library(DBI) })
WF <- "/share/github/CalCOFI/workflows"
source(file.path(WF, "libs/erddap.R"))
source(file.path(WF, "libs/erddap_duckdb.R"))
out <- file.path(WF, "data/bench_erddap"); dir.create(out, recursive = TRUE, showWarnings = FALSE)

# --- denormalized view columns (same for all 3 approaches of a given table) ---
staged_thin <- data.frame(
  column = c("ctd_cast_uuid","time","latitude","longitude","depth","cruise_key",
             "site_key","line","sta","measurement_type","measurement_value",
             "measurement_qual","cast_dir","retained_reason","ctd_thin_uuid"),
  duckdb_type = c("VARCHAR","DOUBLE","DOUBLE","DOUBLE","DOUBLE","VARCHAR","VARCHAR",
                  "VARCHAR","VARCHAR","VARCHAR","DOUBLE","VARCHAR","VARCHAR","VARCHAR","VARCHAR"),
  stringsAsFactors = FALSE)
staged_meas <- data.frame(
  column = c("ctd_cast_uuid","time","latitude","longitude","depth","cruise_key",
             "site_key","line","sta","measurement_type","measurement_value",
             "measurement_qual","ctd_measurement_uuid"),
  duckdb_type = c("VARCHAR","DOUBLE","DOUBLE","DOUBLE","DOUBLE","VARCHAR","VARCHAR",
                  "VARCHAR","VARCHAR","VARCHAR","DOUBLE","VARCHAR","VARCHAR"),
  stringsAsFactors = FALSE)

SUBSET <- c("cruise_key","measurement_type")
CONN   <- c(`duckdb.read_only`="true", memory_limit="1024MB", threads="2",
            temp_directory="/ssd/erddap-bench/tmp")
DBURL  <- "jdbc:duckdb:/ssd/erddap-bench/duckdb/calcofi_ctd.db"
wr <- function(id, xml) { writeLines(xml, file.path(out, paste0(id, ".xml"))); cat("wrote", id, "\n") }

# ---- ctd_thin ----
wr("calcofi_ctd_thin_duckdb", erddap_duckdb_dataset_xml(
  staged_thin, "calcofi_ctd_thin_duckdb", "CalCOFI CTD thinned (DuckDB)",
  "Adaptively-thinned CTD profiles, long format, served via DuckDB views over partitioned Parquet.",
  source_url = DBURL, table_name = "ctd_thin_erddap", conn_props = CONN, subset_vars = SUBSET))
wr("calcofi_ctd_thin_parquet", erddap_dataset_xml(
  staged_thin, "calcofi_ctd_thin_parquet", "CalCOFI CTD thinned (Parquet)",
  "Adaptively-thinned CTD profiles, long format, served from a denormalized Parquet file.",
  file_dir = "/ssd/erddap-bench/staged/A_thin/ctd_thin/", subset_vars = SUBSET))
wr("calcofi_ctd_thin_csv", erddap_csv_dataset_xml(
  staged_thin, "calcofi_ctd_thin_csv", "CalCOFI CTD thinned (CSV)",
  "Adaptively-thinned CTD profiles, long format, served from a denormalized CSV file.",
  file_dir = "/ssd/erddap-bench/staged/C_thin/ctd_thin/", subset_vars = SUBSET))

# ---- ctd_measurement ----
wr("calcofi_ctd_measurement_duckdb", erddap_duckdb_dataset_xml(
  staged_meas, "calcofi_ctd_measurement_duckdb", "CalCOFI CTD measurements (DuckDB)",
  "Full long-format CTD measurements (~216M rows) served via DuckDB views over partitioned Parquet.",
  source_url = DBURL, table_name = "ctd_measurement_erddap", conn_props = CONN, subset_vars = SUBSET))
wr("calcofi_ctd_measurement_parquet", erddap_dataset_xml(
  staged_meas, "calcofi_ctd_measurement_parquet", "CalCOFI CTD measurements (Parquet)",
  "Full long-format CTD measurements (~216M rows) served from denormalized Parquet partitioned by cruise_key.",
  file_dir = "/ssd/erddap-bench/staged/A_measurement/", subset_vars = SUBSET))

cat("done ->", out, "\n")
