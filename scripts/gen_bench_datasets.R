#!/usr/bin/env Rscript
# Generate the ERDDAP <dataset> blocks for the CTD serving-backend benchmark, across
# four axes: format (NetCDF/Parquet/CSV/DuckDB) x schema (wide/long) x granularity
# (split per-cruise / lumped single-file) x table (thin/measurement). datasetID == the
# cell name == the block filename, so the harness reads data/bench_erddap/<cell>.xml.
# Reuses the shared dataVariable/type/units helpers in libs/erddap.R. Run in rstudio:
#   docker exec rstudio Rscript /share/github/CalCOFI/workflows/scripts/gen_bench_datasets.R
suppressMessages({ library(glue); library(DBI); library(readr) })
WF <- "/share/github/CalCOFI/workflows"
source(file.path(WF, "libs/erddap.R"))
source(file.path(WF, "libs/erddap_duckdb.R"))
source(file.path(WF, "libs/erddap_netcdf.R"))
out <- file.path(WF, "data/bench_erddap"); dir.create(out, recursive = TRUE, showWarnings = FALSE)
wr <- function(id, xml) { writeLines(xml, file.path(out, paste0(id, ".xml"))); cat("wrote", id, "\n") }

# canonical measurement_types -> wide variables (canonical∩present per table)
mt <- read_csv(file.path(WF, "metadata/measurement_type.csv"), show_col_types = FALSE)
units_lk    <- setNames(as.list(mt$units),       mt$measurement_type)
longname_lk <- setNames(as.list(mt$description),  mt$measurement_type)
vars_thin <- c("temperature_ave","salinity_ave_corr","oxygen_ml_l_ave_sta_corr",
               "oxygen_umol_kg_ave_sta_corr","fluorescence_v","isus_v","sigma_theta_1",
               "dynamic_height","specific_volume_anomaly","par","spar","beam_attenuation",
               "transmissometer","ph","pressure")
vars_meas <- setdiff(vars_thin, "oxygen_umol_kg_ave_sta_corr")  # 14 present in ctd_measurement
vars_of   <- list(thin = vars_thin, measurement = vars_meas)

# wide flat-table column spec (for Parquet/CSV/DuckDB wide blocks)
wide_staged <- function(vars) data.frame(
  column = c("cruise_key","ctd_cast_uuid","time","latitude","longitude","depth","line","sta", vars),
  duckdb_type = c("VARCHAR","VARCHAR","TIMESTAMP","DOUBLE","DOUBLE","DOUBLE","VARCHAR","VARCHAR",
                  rep("DOUBLE", length(vars))), stringsAsFactors = FALSE)
WSUB   <- c("cruise_key","line","sta")
DATA   <- "/share/data/erddap-duckdb"
CONNW  <- c(`duckdb.read_only`="true", memory_limit="1024MB", threads="2",
            temp_directory = file.path(DATA, "tmp"))
WIDEDB <- glue("jdbc:duckdb:{DATA}/duckdb/calcofi_ctd_wide.db")

# ---------- WIDE (canonical sensors as columns) ----------
for (tb in c("thin","measurement")) {
  vars <- vars_of[[tb]]; st <- wide_staged(vars); pre <- substr(tb,1,4)
  tlab <- if (tb=="thin") "thin" else "full"
  ttl <- function(f,g) glue("CalCOFI CTD {tlab} wide {f} {g}")
  # NetCDF (EDDTableFromNcCFFiles) — split per-cruise vs lumped single file
  wr(glue("{pre}_netcdf_wide_split"), erddap_nccf_dataset_xml(
    glue("{pre}_netcdf_wide_split"), ttl("NetCDF","split"), "Per-cruise CF profile NetCDF (split).",
    file_dir = glue("{DATA}/netcdf/{tb}/"), vars = vars, units_lookup = units_lk, longname_lookup = longname_lk))
  wr(glue("{pre}_netcdf_wide_lumped"), erddap_nccf_dataset_xml(
    glue("{pre}_netcdf_wide_lumped"), ttl("NetCDF","lumped"), "Single-file CF profile NetCDF (lumped).",
    file_dir = glue("{DATA}/serving/wide_lumped_netcdf/ctd_{tb}/"), vars = vars,
    units_lookup = units_lk, longname_lookup = longname_lk))
  # Parquet (EDDTableFromParquetFiles) — split vs lumped
  wr(glue("{pre}_parquet_wide_split"), erddap_dataset_xml(
    st, glue("{pre}_parquet_wide_split"), ttl("Parquet","split"), "Per-cruise wide Parquet (split).",
    file_dir = glue("{DATA}/parquet_wide/ctd_{tb}/"), subset_vars = WSUB,
    units_lookup = units_lk, longname_lookup = longname_lk))
  wr(glue("{pre}_parquet_wide_lumped"), erddap_dataset_xml(
    st, glue("{pre}_parquet_wide_lumped"), ttl("Parquet","lumped"), "Single-file wide Parquet (lumped).",
    file_dir = glue("{DATA}/serving/wide_lumped_parquet/ctd_{tb}/"), subset_vars = WSUB,
    units_lookup = units_lk, longname_lookup = longname_lk))
  # DuckDB wide pivot view (EDDTableFromDatabase) — granularity-agnostic
  wr(glue("{pre}_duckdb_wide"), erddap_duckdb_dataset_xml(
    st, glue("{pre}_duckdb_wide"), ttl("DuckDB","view"), "Wide DuckDB pivot view over partitioned Parquet.",
    source_url = WIDEDB, table_name = glue("ctd_{tb}_wide_erddap"), conn_props = CONNW,
    subset_vars = WSUB, units_lookup = units_lk, longname_lookup = longname_lk))
}
# CSV (EDDTableFromAsciiFiles), thin only (measurement CSV is tens of GB)
st <- wide_staged(vars_thin)
wr("thin_csv_wide_split", erddap_csv_dataset_xml(
  st, "thin_csv_wide_split", "CalCOFI CTD thin wide CSV split", "Per-cruise wide CSV (split).",
  file_dir = glue("{DATA}/serving/wide_split_csv/thin/"), subset_vars = WSUB,
  units_lookup = units_lk, longname_lookup = longname_lk))
wr("thin_csv_wide_lumped", erddap_csv_dataset_xml(
  st, "thin_csv_wide_lumped", "CalCOFI CTD thin wide CSV lumped", "Single-file wide CSV (lumped).",
  file_dir = glue("{DATA}/serving/wide_lumped_csv/thin/"), subset_vars = WSUB,
  units_lookup = units_lk, longname_lookup = longname_lk))

cat("done ->", out, "\n")
