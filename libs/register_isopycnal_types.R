# register the isopycnal table's measurement types (iso_* = calcofi4r::cc_isopycnal_type() of each
# cc_isopycnal() variable) in metadata/measurement_type.csv, so isopycnal.measurement_type and the
# isopycnal cells of climatology resolve their foreign key to measurement_type (calcofi4db 4.39.0).
# Append-only and idempotent (register_measurement_types()): run once, commit the CSV.
# `_source_datasets` is empty on purpose: no ingest emits these, the release builds them
# (calcofi4db::build_isopycnal() in release_database.qmd), and a dataset named there would make
# that ingest try to pivot them. `nerc_p01` is left empty under the exact-match rule (a value on a
# density surface is not what any P01 concept states).
# Rscript libs/register_isopycnal_types.R
librarian::shelf(here, tibble, quiet = TRUE)

how <- paste(
  "calcofi4r::cc_isopycnal() via calcofi4db::build_isopycnal() at release, on the 1 m bins of obs_ctd_full:",
  "the down cast of each occupation; sigma-theta the flag-aware sensor-pair average; the surface's depth",
  "the shallowest bin reaching it, interpolated with the bin above (profile_threshold_depth(direction = 'above'));")
on_surface <- function(src) paste(how, glue::glue(
  "{src} interpolated linearly to that depth from its own unflagged 1 m profile. One row per cast x surface,",
  " only where status = 'ok'; Rasmus Swalethorp 2026-11-12/13."))

iso <- tibble::tribble(
  ~measurement_type,                ~description,                                                                     ~units,  ~valid_min, ~valid_max, ~category,                ~src,
  "iso_depth_m",                    "Depth of a sigma-theta surface: where a CTD down cast first reaches it",         "m",     0,          6500,       "Physical Oceanography",  NA,
  "iso_temperature_ave",            "Temperature on a sigma-theta surface (sensor-pair average)",                     "degC",  -2,         40,         "Physical Oceanography",  "temperature_ave",
  "iso_salinity_ave_corr",          "Salinity on a sigma-theta surface (corrected sensor-pair average)",              "PSU",   0,          45,         "Physical Oceanography",  "salinity_ave_corr",
  "iso_oxygen_ml_l_ave_sta_corr",   "Dissolved oxygen on a sigma-theta surface (station-corrected average)",          "ml/L",  0,          15,         "Physical Oceanography",  "oxygen_ml_l_ave_sta_corr",
  "iso_est_nitrate_sta_corr",       "Estimated nitrate on a sigma-theta surface (station-corrected ISUS estimate)",   "umol/L", 0,         200,        "Nutrients & Chemistry",  "est_nitrate_sta_corr",
  "iso_spiciness0",                 "Spice (spiciness at 0 dbar, TEOS-10) on a sigma-theta surface",                  "kg/m3", -25,        18,         "Physical Oceanography",  "temperature_ave; salinity_ave_corr")

iso$derivation <- ifelse(
  iso$measurement_type == "iso_depth_m",
  paste(how, "status says why a surface has no depth (at_surface, no_bracket, not_reached, no_data); Rasmus Swalethorp 2026-11-12/13."),
  ifelse(iso$measurement_type == "iso_spiciness0",
         paste(how, "gsw_spiciness0() of the temperature and salinity interpolated to that depth (calcofi4db::ctd_spice()'s recipe), at its pressure and the cast's latitude; Rasmus Swalethorp 2026-11-12/13."),
         vapply(iso$src, on_surface, character(1))))
iso$is_canonical       <- TRUE
iso$`_source_column`   <- ifelse(is.na(iso$src), "sigma_theta_1; sigma_theta_2", iso$src)
iso$`_source_table`    <- "isopycnal"
iso$`_source_datasets` <- ""
iso$grain              <- "isopycnal"
iso$src <- NULL

d <- calcofi4db::register_measurement_types(iso, here("metadata/measurement_type.csv"))
stopifnot(all(iso$measurement_type %in% d$measurement_type))
cat("registered:", paste(iso$measurement_type, collapse = ", "), "\n")
