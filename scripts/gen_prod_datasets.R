#!/usr/bin/env Rscript
# Generate the PRODUCTION EDDTableFromDatabase <dataset> blocks for serving the
# long CTD tables via DuckDB views (the benchmark winner), enriched with
# long_name / units / comment from metadata/calcofi/ctd-cast/metadata_derived.csv
# (+ measurement_type.csv for the per-type units note). Clean public IDs; prod
# .db + temp under /share/data/erddap-duckdb. Run in the rstudio container:
#   docker exec rstudio Rscript /share/github/CalCOFI/workflows/scripts/gen_prod_datasets.R
suppressMessages({ library(glue); library(DBI); library(readr); library(dplyr) })
options(readr.show_col_types = FALSE)
WF <- "/share/github/CalCOFI/workflows"
source(file.path(WF, "libs/erddap.R")); source(file.path(WF, "libs/erddap_duckdb.R"))
out <- file.path(WF, "data/bench_erddap"); dir.create(out, recursive = TRUE, showWarnings = FALSE)

md <- read_csv(file.path(WF, "metadata/calcofi/ctd-cast/metadata_derived.csv")) |>
  filter(!is.na(column), nzchar(column))
mt <- read_csv(file.path(WF, "metadata/measurement_type.csv"))
type_units <- mt |> filter(is_canonical %in% c(TRUE, "TRUE")) |>
  transmute(s = sprintf("%s (%s)", measurement_type, units)) |> pull(s) |> head(8) |>
  paste(collapse = ", ")
val_comment <- paste0("Units VARY by measurement_type — this long-format column holds the ",
  "numeric value for whichever sensor the row's measurement_type names. Canonical examples: ",
  type_units, ". See the measurement_type variable and https://calcofi.io/schema.")

# destination column -> source column in metadata_derived (renamed by the view)
src_of <- c(time = "datetime_start_utc", depth = "depth_m")
# lookups keyed by DESTINATION column, preferring the target table then ctd_cast
mk_lookups <- function(tbl, cols) {
  sub <- md |> filter(table %in% c(tbl, "ctd_cast")) |>
    arrange(table != tbl) |> distinct(column, .keep_all = TRUE)
  ln <- list(); un <- list(); cm <- list()
  for (d in cols) {
    s <- if (d %in% names(src_of)) src_of[[d]] else d
    r <- sub |> filter(column == s)
    if (nrow(r)) {
      if (nzchar(r$name_long[1] %||% "")) ln[[d]] <- r$name_long[1]
      if (!is.na(r$units[1]) && nzchar(r$units[1])) un[[d]] <- r$units[1]
      if (!is.na(r$description_md[1]) && nzchar(r$description_md[1])) cm[[d]] <- r$description_md[1]
    }
  }
  if ("measurement_value" %in% cols) cm[["measurement_value"]] <- val_comment
  list(longname = ln, units = un, comment = cm)
}

CONN <- c(`duckdb.read_only`="true", memory_limit="1024MB", threads="2",
          temp_directory="/share/data/erddap-duckdb/tmp")
DBURL <- "jdbc:duckdb:/share/data/erddap-duckdb/duckdb/calcofi_ctd.db"
SUBSET <- c("cruise_key","measurement_type")
GLOBAL <- list(
  keywords = "CalCOFI, CTD, ocean, temperature, salinity, oxygen, fluorescence, profiles, California Current, depth",
  comment = paste("Long format: one row per cast x depth x measurement_type. measurement_value units",
                  "depend on measurement_type. time/latitude/longitude are denormalized from ctd_cast",
                  "via a DuckDB view over Parquet (EDDTableFromDatabase) — see https://calcofi.io/schema."),
  references = "https://calcofi.io/schema ; https://calcofi.org/data/oceanographic-data/ctd-cast-files/",
  source = "CalCOFI CTD cast files (https://calcofi.org)",
  creator_email = "calcofi@ucsd.edu", publisher_name = "CalCOFI",
  publisher_url = "https://calcofi.org", project = "CalCOFI")

cols_thin <- c("ctd_cast_uuid","time","latitude","longitude","depth","cruise_key","site_key",
               "line","sta","measurement_type","measurement_value","measurement_qual",
               "cast_dir","retained_reason","ctd_thin_uuid")
cols_meas <- c("ctd_cast_uuid","time","latitude","longitude","depth","cruise_key","site_key",
               "line","sta","measurement_type","measurement_value","measurement_qual","ctd_measurement_uuid")
typ_v <- function(c) ifelse(c=="time","TIMESTAMP", ifelse(c %in% c("latitude","longitude","depth","measurement_value"),"DOUBLE","VARCHAR"))
staged_thin <- data.frame(column=cols_thin, duckdb_type=typ_v(cols_thin), stringsAsFactors=FALSE)
staged_meas <- data.frame(column=cols_meas, duckdb_type=typ_v(cols_meas), stringsAsFactors=FALSE)
lk_thin <- mk_lookups("ctd_thin", cols_thin); lk_meas <- mk_lookups("ctd_measurement", cols_meas)

# Coordinate ranges — EDDTableFromDatabase does NOT auto-compute them, so without
# these the form shows no min/max or sliders. Recompute on each data update via:
#   SELECT epoch(min(time)),epoch(max(time)),min(latitude),max(latitude),
#          min(longitude),max(longitude),min(depth),max(depth) FROM <view>;
RANGES <- list(
  ctd_thin = list(time=c(885554065,1776981672), latitude=c(29.82682,37.84907),
                  longitude=c(-126.4843,-117.2734), depth=c(0.968,3630)),
  ctd_measurement = list(time=c(885554065,1769791140), latitude=c(29.80726,37.85147),
                  longitude=c(-126.4843,-117.2734), depth=c(1.0,3630)))
iso <- function(e) format(as.POSIXct(e, origin="1970-01-01", tz="UTC"), "%Y-%m-%dT%H:%M:%SZ")
geo_globals <- function(r) c(GLOBAL, list(
  geospatial_lat_min=r$latitude[1], geospatial_lat_max=r$latitude[2], geospatial_lat_units="degrees_north",
  geospatial_lon_min=r$longitude[1], geospatial_lon_max=r$longitude[2], geospatial_lon_units="degrees_east",
  geospatial_vertical_min=r$depth[1], geospatial_vertical_max=r$depth[2],
  geospatial_vertical_positive="down", geospatial_vertical_units="m",
  time_coverage_start=iso(r$time[1]), time_coverage_end=iso(r$time[2])))
wr <- function(id, xml){ writeLines(xml, file.path(out, paste0("prod_", id, ".xml"))); cat("wrote", id, "\n") }

wr("calcofi_ctd_thin", erddap_duckdb_dataset_xml(
  staged_thin, "calcofi_ctd_thin", "CalCOFI CTD Profiles (thinned)",
  paste("Adaptively-thinned CTD profiles (long format, one row per cast/depth/measurement_type;",
        "canonical sensors only, ~10 m depth grid with inflection points preserved), joined to cast",
        "coordinates/time. Served via DuckDB views over partitioned Parquet (EDDTableFromDatabase)."),
  source_url = DBURL, table_name = "ctd_thin_erddap", conn_props = CONN, subset_vars = SUBSET,
  cdm_data_type = "Point", units_lookup = lk_thin$units, longname_lookup = lk_thin$longname,
  comment_lookup = lk_thin$comment, range_lookup = RANGES$ctd_thin,
  global_atts = geo_globals(RANGES$ctd_thin)))

wr("calcofi_ctd_measurement", erddap_duckdb_dataset_xml(
  staged_meas, "calcofi_ctd_measurement", "CalCOFI CTD Measurements (full)",
  paste("Full long-format CTD measurements (~216M rows, all sensor variants), joined to cast",
        "coordinates/time. Served via DuckDB views over Parquet partitioned by cruise_key",
        "(EDDTableFromDatabase). The adaptively-thinned calcofi_ctd_thin is the lighter headline table."),
  source_url = DBURL, table_name = "ctd_measurement_erddap", conn_props = CONN, subset_vars = SUBSET,
  cdm_data_type = "Point", units_lookup = lk_meas$units, longname_lookup = lk_meas$longname,
  comment_lookup = lk_meas$comment, range_lookup = RANGES$ctd_measurement,
  global_atts = geo_globals(RANGES$ctd_measurement)))
cat("done\n")
