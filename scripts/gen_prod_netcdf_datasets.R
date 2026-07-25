#!/usr/bin/env Rscript
# Generate the PRODUCTION EDDTableFromNcCFFiles <dataset> block for serving the
# per-cruise CF Profile NetCDF built by gen_ctd_netcdf.R — the NATIVE ERDDAP path
# (profile = cast, obs = depth level), which is what makes .ncCF/.ncCFMA downloads
# proper CF Discrete Sampling Geometry rather than the flat "Point" dump the
# DuckDB-backed calcofi_ctd_thin / calcofi_ctd_measurement datasets emit.
#
# Companion to gen_prod_datasets.R (DuckDB/EDDTableFromDatabase blocks); reuses the
# same metadata_derived.csv long_name/units lookups so both representations of the
# CTD agree on variable documentation. Run in the rstudio container:
#   docker exec rstudio Rscript /share/github/CalCOFI/workflows/scripts/gen_prod_netcdf_datasets.R
# then paste data/bench_erddap/prod_calcofi_ctd_thin_nc.xml into
# CalCOFI/erddap content/datasets.xml.
suppressMessages({ library(glue); library(readr); library(dplyr) })
options(readr.show_col_types = FALSE)
WF <- if (nzchar(Sys.getenv("CALCOFI_WORKFLOWS"))) Sys.getenv("CALCOFI_WORKFLOWS") else
  "/share/github/CalCOFI/workflows"
source(file.path(WF, "libs/erddap.R")); source(file.path(WF, "libs/erddap_netcdf.R"))
out <- file.path(WF, "data/bench_erddap"); dir.create(out, recursive = TRUE, showWarnings = FALSE)

# served location: /share/erddap/datasets is bind-mounted into the erddap container
# at /datasets (see CalCOFI/erddap README), so fileDir is the CONTAINER path.
FILE_DIR <- "/datasets/calcofi_ctd_thin_nc/"

# canonical sensors actually written into the .nc files by gen_ctd_netcdf.R
vars <- c("temperature_ave", "salinity_ave_corr", "oxygen_ml_l_ave_sta_corr",
          "oxygen_umol_kg_ave_sta_corr", "fluorescence_v", "isus_v", "sigma_theta_1",
          "dynamic_height", "specific_volume_anomaly", "par", "spar",
          "beam_attenuation", "transmissometer", "ph", "pressure")

md <- read_csv(file.path(WF, "metadata/calcofi/ctd-cast/metadata_derived.csv")) |>
  filter(!is.na(column), nzchar(column))
mt <- read_csv(file.path(WF, "metadata/measurement_type.csv"))

# units/long_name: prefer the per-measurement_type registry (these are real columns
# in the wide NetCDF, unlike the long tables where units vary by row), then fall
# back to metadata_derived for the profile/coordinate columns.
units_lk    <- setNames(as.list(mt$units),       mt$measurement_type)
longname_lk <- setNames(as.list(mt$description), mt$measurement_type)
sub <- md |> filter(table %in% c("ctd_thin", "ctd_cast")) |>
  arrange(table != "ctd_thin") |> distinct(column, .keep_all = TRUE)
src_of <- c(time = "datetime_start_utc", depth = "depth_m", profile_id = "ctd_cast_uuid")
for (d in c("profile_id", "time", "latitude", "longitude", "depth", "cruise_key", "line", "sta")) {
  s <- if (d %in% names(src_of)) src_of[[d]] else d
  r <- sub |> filter(column == s)
  if (!nrow(r)) next
  if (nzchar(r$name_long[1] %||% ""))                     longname_lk[[d]] <- r$name_long[1]
  if (!is.na(r$units[1]) && nzchar(r$units[1]))           units_lk[[d]]    <- r$units[1]
}

GLOBAL <- list(
  keywords = paste("CalCOFI, CTD, ocean, temperature, salinity, oxygen, fluorescence,",
                   "profiles, California Current, depth, CF, discrete sampling geometry"),
  comment = paste("CF Discrete Sampling Geometry 'profile' files, ONE FILE PER CRUISE",
                  "(profile = CTD cast, obs = depth level), each canonical sensor its own",
                  "variable. ERDDAP aggregates all files into this single dataset; the",
                  "per-cruise split is storage only. Because cdm_data_type=Profile, the",
                  ".ncCF / .ncCFMA download types return true CF profile files —",
                  "calcofi_ctd_thin (DuckDB-backed, long format) serves the same data as",
                  "cdm_data_type=Point. See https://calcofi.io/workflows/bench_erddap_ctd.html"),
  references = paste("https://calcofi.io/db-schema ;",
                     "https://calcofi.io/workflows/bench_erddap_ctd.html ;",
                     "https://calcofi.org/data/oceanographic-data/ctd-cast-files/"),
  source = "CalCOFI CTD cast files (https://calcofi.org)",
  creator_email = "calcofi@ucsd.edu", publisher_name = "CalCOFI",
  publisher_url = "https://calcofi.org", project = "CalCOFI")

xml <- erddap_nccf_dataset_xml(
  dataset_id = "calcofi_ctd_thin_nc",
  title      = "CalCOFI CTD Profiles (thinned, CF NetCDF)",
  summary    = paste("Adaptively-thinned CalCOFI CTD profiles as CF Discrete-Sampling-Geometry",
                     "profile files, one per cruise (profile = cast, obs = depth; canonical",
                     "sensors as variables). The native ERDDAP representation of ctd_thin:",
                     "downloadable as true CF NetCDF (.ncCF/.ncCFMA) and as source .nc files."),
  file_dir        = FILE_DIR,
  vars            = vars,
  units_lookup    = units_lk,
  longname_lookup = longname_lk,
  global_atts     = GLOBAL)

f <- file.path(out, "prod_calcofi_ctd_thin_nc.xml")
writeLines(xml, f)
cat("wrote", f, "\n")
