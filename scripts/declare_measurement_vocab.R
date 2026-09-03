# seed metadata/measurement_type.csv's `nerc_p01` (OBIS/DwC eMoF measurementTypeID, NERC BODC
# Parameter Usage Vocabulary P01) and `units_nerc_p06` (measurementUnitID, NERC P06) — through
# calcofi4db::declare_measurement_fields(), never a bare write_csv. Pre-release plan D-S2 (WS-H2).
#
# THE FILL RULE, and it is the whole point of this file: an id is written only on an EXACT
# vocabulary match — a concept every one of whose stated facets (quantity, matrix, phase, method)
# this registry, or the dataset's documented protocol, actually supplies. A *generic* concept is an
# exact match at coarser specificity (P01 TEMPPR01 "Temperature of the water body" for a QC'd bottle
# temperature); a concept that adds a facet nobody recorded is NOT (P01 IRRDUV01 pins PAR to a
# cosine-collector radiometer, which no CalCOFI metadata states). An empty cell therefore means "no
# concept says exactly this", never "not looked at" — the same discipline measurement bounds follow,
# where an invented bound silently deletes real data and an invented id silently misdescribes it.
#
# Concepts were resolved against the live NVS SPARQL endpoint (https://vocab.nerc.ac.uk/sparql/sparql)
# on 2026-09-03; deprecated concepts were excluded. Idempotent: re-running writes nothing unless a
# type is new or a mapping below changed (which needs overwrite = TRUE, deliberately).
#   Rscript scripts/declare_measurement_vocab.R
# CALCOFI4DB_DIR loads a development checkout instead of the sibling repo (as build_citation_files.R does)
suppressPackageStartupMessages({
  devtools::load_all(
    if (nzchar(Sys.getenv("CALCOFI4DB_DIR"))) Sys.getenv("CALCOFI4DB_DIR") else here::here("../calcofi4db"),
    quiet = TRUE)
  library(dplyr) })

path <- here::here("metadata/measurement_type.csv")
mt   <- read_measurement_type(path)

p01 <- function(code) paste0("http://vocab.nerc.ac.uk/collection/P01/current/", code, "/")
p06 <- function(code) paste0("http://vocab.nerc.ac.uk/collection/P06/current/", code, "/")

# ---- P01: measurementTypeID, per measurement type ----
# Grouped by concept so the reasoning is legible: each vector is "these types are exactly this".
p01_map <- list(
  # --- physics -------------------------------------------------------------------------------
  TEMPPR01 = c(                       # Temperature of the water body (no method stated)
    "temperature", "temperature_ave", "btl_temperature", "sst_c", "sst_c_corrected"),
  TEMPST01 = c("temperature_1", "ctdtemp_its90"),  # ... by CTD or STD
  TEMPST02 = "temperature_2",                      # ... by CTD or STD (second sensor)
  TEMPSZ01 = c("tsg1_temp_c", "tsg1_temp_c_calibrated", "tsg2_temp_c", "tsg2b_temp_c",
               "tsg3_temp_c", "tsg5_temp_c"),      # ... by thermosalinograph
  CTMPZZ01 = "air_temp_c",                         # Temperature of the atmosphere
  CDTASS01 = "dry_air_temp",                       # ... by dry bulb thermometer (sling psychrometer)
  CWETSS01 = "wet_air_temp",                       # Wet bulb temperature of the atmosphere by psychrometer
  PSLTZZ01 = c(                       # Practical salinity of the water body (no method stated)
    "salinity", "salinity_pss78", "salinity_btl", "salinity_ave_corr",
    "sss_psu", "sss_psu_corrected", "dic_salinity_psu"),
  PSALST01 = c("salinity_1", "salinity_1_corr"),   # ... by CTD and UNESCO 1983
  PSALST02 = c("salinity_2", "salinity_2_corr"),   # ... by CTD (second sensor) and UNESCO 1983
  PSALSZ01 = c("tsg1_salinity_psu", "tsg1_salinity_psu_calibrated", "tsg2_salinity_psu",
               "tsg3_salinity_psu", "tsg5_salinity_psu"),  # ... by thermosalinograph
  PRESPR01 = "pressure",              # Pressure exerted by the water body by profiling pressure sensor
  ADEPZZ01 = c("btl_depth", "r_depth"),            # Depth relative to water surface in the water body
  MBANZZ01 = c("bottom_depth_m", "bottom_depth_mb_m"),  # Sea-floor depth ... by echo sounder
  SIGTEQ01 = "sigma_theta",           # Sigma-theta by computation from salinity + potential temperature
  SIGTPR01 = "sigma_theta_1",         # ... by CTD
  SIGTPR02 = "sigma_theta_2",         # ... by CTD (second sensor)
  CNDCZZ01 = "ss_conductivity",       # Electrical conductivity of the water body
  CNDCSG01 = c("tsg1_conductivity", "tsg2_conductivity", "tsg3_conductivity"),  # ... by thermosalinograph
  SVELXXXX = c("tsg1_sound_velocity", "tsg2_sound_velocity", "tsg3_sound_velocity"),
  ATTNXXZZ = "beam_attenuation",      # Attenuation (unspecified wavelength) per unit length
  DOXYZZXX = c(                       # Concentration of oxygen per unit VOLUME of the water body
    "oxygen_ml_l", "oxygen_btl_ml_l", "oxygen_ml_l_1", "oxygen_ml_l_1_cruise_corr",
    "oxygen_ml_l_1_sta_corr", "oxygen_ml_l_2", "oxygen_ml_l_2_cruise_corr",
    "oxygen_ml_l_2_sta_corr", "oxygen_ml_l_ave_sta_corr"),
  DOXMZZXX = c(                       # Concentration of oxygen per unit MASS of the water body
    "oxygen_umol_kg", "oxygen_btl_umol_kg", "r_oxygen_umol_kg", "oxygen_umol_kg_1",
    "oxygen_umol_kg_1_cruise_corr", "oxygen_umol_kg_1_sta_corr", "oxygen_umol_kg_2",
    "oxygen_umol_kg_2_cruise_corr", "oxygen_umol_kg_2_sta_corr", "oxygen_umol_kg_ave_sta_corr"),
  OXYSZZ01 = c("oxygen_saturation", "oxygen_saturation_1", "oxygen_saturation_2", "oxygen_sat_pct"),
  # --- nutrients -----------------------------------------------------------------------------
  # the *ZZXX forms are "per unit volume of the water body [unknown phase]" — CalCOFI records
  # neither the filter cut nor the analytical method in this registry, so the phase- and
  # method-specific concepts (there are ~14 of each) would all be assertions.
  NTRAZZXX = c("nitrate", "btl_nitrate"),
  NTRIZZXX = c("nitrite", "btl_nitrite"),
  PHOSZZXX = c("phosphate", "btl_phosphate"),
  SLCAZZXX = c("silicate", "btl_silicate"),
  AMONZZXX = c("r_ammonium", "btl_ammonium"),  # NOT `ammonia` — see the un-filled list below
  # --- carbonate system ----------------------------------------------------------------------
  TCO2MSXX = c("dic", "dic_rep1", "dic_rep2"),          # total inorganic carbon per unit mass
  MDMAP014 = c("alkalinity", "alkalinity_rep1", "alkalinity_rep2"),  # total alkalinity per unit mass
  PHXXZZXX = c("ph", "ph_rep1", "ph_rep2", "sw_ph"),    # pH (unspecified scale) of the water body
  # --- pigments ------------------------------------------------------------------------------
  CPHLZZXX = c("chlorophyll_a", "btl_chlorophyll_a", "chl_fluor"),
  PHAEZZXX = c("phaeopigment", "btl_phaeopigment"),
  # --- meteorology & sea state ---------------------------------------------------------------
  CAPHZZ01 = c("atm_pressure_mb", "barometric_pressure"),  # Pressure exerted by the atmosphere
  CRELZZ01 = "rel_humidity_pct",                           # Relative humidity of the atmosphere
  EWSBZZ01 = c("wind_speed", "wind_speed_ms"),             # Speed of wind in the atmosphere
  EWDAZZ01 = c("wind_direction", "wind_dir_deg"),          # Direction (from) of wind rel. True North
  # the four WMO-coded observations name their own code table in `description`, which is exactly
  # the facet these concepts state ("by visual estimation and conversion to WMO code")
  WMOCCCAC = "cloud_amount",     # Cloud cover (all clouds)          — WMO 2700
  WMOCCTAC = "cloud_type",       # Cloud type (all clouds)           — WMO 0500
  WMOCHVXX = "visibility",       # Horizontal visibility, table 4300 — WMO 4300
  WMOCPWXX = "weather_code",     # Present weather, table 4677/4501  — WMO 4501
  WMOCWDXX = "wave_direction",   # Direction (from) of waves, table 0885/0877 ("abbreviated azimuth")
  CLFORULE = "water_color",      # Colour of the water body ... on the Forel-Ule scale
  SECCSDNX = "secchi_depth",     # Visibility in the water body by Secchi disk
  # --- picoplankton (flow cytometry, and the concept says so) --------------------------------
  P700A90Z = "synechococcus",    # Abundance of Synechococcus ... by flow cytometry
  P701A90Z = "prochlorococcus",  # Abundance of Prochlorococcus ... by flow cytometry
  # --- sub-occurrence attributes -------------------------------------------------------------
  OBSINDLX = "body_length",      # Length of biological entity specified elsewhere
  CAPLEN01 = "carapace_length")  # ... [Subcomponent: carapace]

# ---- P06: measurementUnitID, keyed on the registry's own `units` string ----
# Normalisation is only orthographic (`umol/L` = `umol/l`, `kg/m3` = `kg/m^3`) or substance-naming
# (`mgC/m2` is milligrams per square metre; P06 is a UNIT vocabulary, the carbon belongs to the
# parameter). Anything needing arithmetic — `count/1000m3` is not P06's `#/m^3` — stays empty.
p06_map <- c(
  "count"                 = "UCNT",  # Counts
  "umol/kg"               = "KGUM",  # Micromoles per kilogram
  "PSU"                   = "PSUX",  # Practical salinity units
  "PSS-78"                = "PSUX",  # (the scale those units are on)
  "umol/L"                = "UPOX",  # Micromoles per litre
  "deg_C"                 = "UPAA",  # Degrees Celsius
  "degC"                  = "UPAA",
  "ml/L"                  = "UMLL",  # Millilitres per litre
  "ug/L"                  = "UGPL",  # Micrograms per litre
  "kg/m3"                 = "UKMC",  # Kilograms per cubic metre
  "m"                     = "ULAA",  # Metres
  "meters"                = "ULAA",
  "%"                     = "UPCT",  # Percent
  "percent"               = "UPCT",
  "number/ml"             = "UCML",  # Number per millilitre
  "S/m"                   = "UECA",  # Siemens per metre
  "m/s"                   = "UVAA",  # Metres per second
  "mm"                    = "UXMM",  # Millimetres
  "V"                     = "UVLT",  # Volts
  "pH"                    = "UUPH",  # pH units
  "degrees"               = "UAAA",  # Degrees
  "mb"                    = "UPBB",  # Millibars
  "millibars"             = "UPBB",
  "W/m2"                  = "UFAA",  # Watts per square metre
  "uE/m2/s"               = "UMES",  # MicroEinsteins per square metre per second
  "dimensionless"         = "UUUU",  # Dimensionless
  "10^-8 m3/kg"           = "UMKS",  # 10^-8 * Cubic metres per kilogram
  "mL"                    = "VVML",  # Millilitres
  "ml"                    = "VVML",
  "count/m2"              = "UPMS",  # Number per square metre
  "numberPerMeterSquared" = "UPMS",
  "mgC/m2"                = "UMMS",  # Milligrams per square metre
  "1/m"                   = "UPRM",  # per metre
  "cells/L"               = "UCPL",  # Number per litre
  "dbar"                  = "UPDB",  # Decibars
  "L/min"                 = "ULPM",  # Litres per minute
  "m3"                    = "MCUB",  # Cubic metres
  "seconds"               = "UTBB",  # Seconds
  "knots"                 = "UKNT",  # Knots (nautical miles per hour)
  "ugC"                   = "UGUG")  # Micrograms

fields <- tibble::tibble(
  measurement_type = mt$measurement_type,
  nerc_p01 = NA_character_,
  units_nerc_p06 = unname(ifelse(mt$units %in% names(p06_map), p06(p06_map[mt$units]), NA_character_)))
for (code in names(p01_map)) {
  i <- match(p01_map[[code]], fields$measurement_type)
  if (anyNA(i)) stop("p01_map names a type not in the registry: ",
                     paste(p01_map[[code]][is.na(i)], collapse = ", "))
  fields$nerc_p01[i] <- p01(code)
}
fields <- fields |> filter(!is.na(nerc_p01) | !is.na(units_nerc_p06))

d <- declare_measurement_fields(fields, path)

# ---- report: the gate is the count with and without a P01 id ----
n <- nrow(d)
cat(glue::glue(
  "\nmeasurement types: {n}\n",
  "  nerc_p01       : {sum(!is.na(d$nerc_p01))} filled / {sum(is.na(d$nerc_p01))} empty\n",
  "  units_nerc_p06 : {sum(!is.na(d$units_nerc_p06))} filled / {sum(is.na(d$units_nerc_p06))} empty\n\n"))
cat("types with NO exact P01 concept (grouped by category):\n")
d |> filter(is.na(nerc_p01)) |> count(category) |> arrange(desc(n)) |> as.data.frame() |> print()
cat("\nunits with NO exact P06 concept:\n")
d |> filter(is.na(units_nerc_p06)) |> count(units) |> arrange(desc(n)) |> as.data.frame() |> print()
check_registry_na_strings(d, path)

# ---- the two hand-authored vocabulary registries, validated the same way ----
# metadata/life_stage.csv and metadata/gear.csv are edited by hand (like category.csv and
# provider.csv), so nothing writes them here — but a URI typo or a `write_csv(na = "NA")` round trip
# would reach an export just as silently, so they are read strictly and checked.
uri_ok <- function(x, coll) {
  x <- x[!is.na(x)]
  bad <- x[!grepl(paste0("^http://vocab\\.nerc\\.ac\\.uk/collection/", coll,
                         "/current/[A-Za-z0-9_]+/$"), x)]
  if (length(bad)) stop(coll, " URIs malformed: ", paste(bad, collapse = ", "), call. = FALSE)
  length(x)
}
ls_path <- here::here("metadata/life_stage.csv")
gr_path <- here::here("metadata/gear.csv")
d_ls <- readr::read_csv(ls_path, na = "", show_col_types = FALSE) |> check_registry_na_strings(ls_path)
d_gr <- readr::read_csv(gr_path, na = "", show_col_types = FALSE) |> check_registry_na_strings(gr_path)
stopifnot(
  "life_stage must be unique"            = !any(duplicated(d_ls$life_stage)),
  "tow_type must be unique"              = !any(duplicated(d_gr$tow_type)),
  # the whole discipline in one line: an id without a label, or a label without an id, means one of
  # the two was guessed
  "dwc_lifeStage and nerc_s11 are filled together" =
    identical(is.na(d_ls$dwc_lifeStage), is.na(d_ls$nerc_s11)),
  "life_stage_parent must itself be a registered life stage" =
    all(stats::na.omit(d_ls$life_stage_parent) %in% d_ls$life_stage))
cat(glue::glue(
  "\nlife_stage.csv : {nrow(d_ls)} stages, {uri_ok(d_ls$nerc_s11, 'S11')} with an S11 id\n",
  "gear.csv       : {nrow(d_gr)} gear codes, {uri_ok(d_gr$nerc_l22, 'L22')} with an L22 id\n\n"))
