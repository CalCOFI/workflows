# libs/build_ctd_measurement_registry.R
# -----------------------------------------------------------------------------
# Two CTD registry decisions, applied to metadata/measurement_type.csv.
# Re-runnable and idempotent: it recomputes the target state and writes only if
# something actually differs.
#
# 1. CANONICAL BOTTLE-REFERENCE TYPES.
#    The CTD source ships bottle values alongside the sensor scans (BTL_Temp,
#    SaltB, OxB, Chl-a, NO3, ...). They are the reference side of the classic CTD
#    calibration check — sensor vs Winkler/Portosal at matched depth — and
#    `ctd-qaqc` cannot do that check without them. Only `btl_ammonium` was flagged
#    canonical, which left the other ten out of `obs` and looks like a stray edit
#    rather than a decision. Flag the group.
#
#    Thinning does NOT apply to these. `ctd_thin` keeps a ~10 m depth grid, but a
#    bottle fires at a handful of discrete depths that no interpolation can
#    reconstruct; subsetting them to the grid discarded ~73% of the real lab
#    samples when btl_ammonium was first promoted. The ingest already handles this
#    (`canon_btl` / `btl_clause`, retained_reason = 'bottle') and its filter is
#    prefix-based, so the whole group is covered automatically once flagged.
#
# 2. valid_min / valid_max.
#    Moved out of the `plaus` tribble that lived inline in the Data Quality
#    Diagnostics chunk of ingest_calcofi_ctd-cast.qmd, where the comment asked for
#    exactly this. Same values, now declared once in the registry: reviewable in a
#    diff, usable by the CF netCDF writer as real valid_min/valid_max variable
#    attributes, and available to any QC rule rather than only to that one chunk.
#
#    These are deliberately GENEROUS physical bounds — the point is to catch
#    impossible values, not to police oceanography. They are NOT the agreed
#    oceanographic ranges; nothing here drops a row.

suppressMessages({
  library(dplyr); library(readr); library(stringr); library(tibble); library(here)
})

path_reg <- here("metadata/measurement_type.csv")
d0 <- calcofi4db::read_measurement_type(path_reg)

# -- 1. bottle-reference types that belong in the canonical set ----------------
# prefix-based, matching the ingest's own `canon_btl` filter so the two cannot drift
btl_types <- d0$measurement_type[
  str_starts(d0$measurement_type, "btl_") |
    d0$measurement_type %in% c("salinity_btl", "oxygen_btl_ml_l", "oxygen_btl_umol_kg")]

# -- 2. uncorrected sensor series that belong in the canonical set -------------
# Only the bottle-CORRECTED salinity and oxygen were canonical, following the
# provider's own guidance that "station-corrected data are the best". True for a
# cruise that has been through the bottle merge — and quietly catastrophic for one
# that has not: the correction waits on the merge, so a `preliminary_without_bottle` cruise
# reached the release with ELEVEN measurement types and no salinity or oxygen at
# all. Not because the sensors failed (Salt1/Salt2/Ox1/Ox2/Ox1uM are 100% populated
# in those files) but because only the corrected forms were published. Anyone
# plotting recent salinity got nothing back, with no error. That was 2507SR,
# 2511SR, 2601RL, 2604SH and 2607SH — the five most recent cruises.
#
# So publish the raw sensor series too, on every cruise, clearly labelled. The
# corrected forms stay canonical and stay preferable where they exist; this is the
# floor, not a replacement. The types already existed here with is_canonical FALSE,
# so they are already parsed into ctd_measurement — this only lets them through to
# ctd_thin and obs.
sensor_types <- c(
  "salinity_1", "salinity_2",
  "oxygen_ml_l_1", "oxygen_ml_l_2",
  "oxygen_umol_kg_1", "oxygen_umol_kg_2")

# say so in the description: "Salinity sensor 1" does not tell a consumer that this
# is the pre-calibration value, and the units column cannot carry that.
sensor_desc <- tribble(
  ~measurement_type,    ~description,
  "salinity_1",         "Salinity sensor 1 (uncorrected)",
  "salinity_2",         "Salinity sensor 2 (uncorrected)",
  "oxygen_ml_l_1",      "DO sensor 1 (uncorrected)",
  "oxygen_ml_l_2",      "DO sensor 2 (uncorrected)",
  "oxygen_umol_kg_1",   "DO sensor 1 (uncorrected)",
  "oxygen_umol_kg_2",   "DO sensor 2 (uncorrected)")

# -- 3. plausible physical ranges (verbatim from the notebook's `plaus`) -------
plaus <- tribble(
  ~measurement_type,              ~valid_min, ~valid_max,
  "temperature_ave",              -2,     40,
  "temperature_1",                -2,     40,
  "temperature_2",                -2,     40,
  "potential_temperature_1",      -2,     40,
  "potential_temperature_2",      -2,     40,
  "btl_temperature",              -2,     40,
  "salinity_ave_corr",             0,     45,
  "salinity_1",                    0,     45,
  "salinity_2",                    0,     45,
  "salinity_1_corr",               0,     45,
  "salinity_2_corr",               0,     45,
  "salinity_btl",                  0,     45,
  "pressure",                      0,   6500,
  "ph",                            6,      9,
  "sw_ph",                         6,      9,
  "oxygen_ml_l_ave_sta_corr",      0,     15,
  "oxygen_ml_l_1",                 0,     15,
  "oxygen_ml_l_2",                 0,     15,
  "oxygen_btl_ml_l",               0,     15,
  "oxygen_umol_kg_ave_sta_corr",   0,    700,
  "oxygen_umol_kg_1",              0,    700,
  "oxygen_umol_kg_2",              0,    700,
  "oxygen_btl_umol_kg",            0,    700,
  "sigma_theta_1",                15,     35,
  "sigma_theta_2",                15,     35,
  "btl_ammonium",                  0,    100,
  "btl_nitrate",                   0,    100,
  "btl_nitrite",                   0,     10,
  "btl_phosphate",                 0,     10,
  "btl_silicate",                  0,    300,
  "btl_chlorophyll_a",             0,    100,
  "btl_phaeopigment",              0,    100)

# a range declared for a type that does not exist is a typo, not a no-op — the
# left_join would swallow it silently, so surface it
unknown <- setdiff(plaus$measurement_type, d0$measurement_type)
if (length(unknown)) {
  cat("WARNING: range declared for unregistered type(s):",
      paste(unknown, collapse = ", "), "\n")
  plaus <- filter(plaus, !measurement_type %in% unknown)
}

# -- apply --------------------------------------------------------------------
d1 <- d0
if (!"valid_min" %in% names(d1)) d1$valid_min <- NA_real_
if (!"valid_max" %in% names(d1)) d1$valid_max <- NA_real_

# a sensor type declared here but absent from the registry is a typo the
# rows_update would swallow — same reasoning as `unknown` above
missing_sensor <- setdiff(sensor_types, d0$measurement_type)
stopifnot("uncorrected sensor type(s) not in the registry" =
            length(missing_sensor) == 0)

d1 <- d1 |>
  rows_update(plaus, by = "measurement_type", unmatched = "ignore") |>
  rows_update(sensor_desc, by = "measurement_type", unmatched = "ignore") |>
  mutate(is_canonical = if_else(
    measurement_type %in% c(btl_types, sensor_types), TRUE, is_canonical))

# keep valid_min/valid_max next to units rather than tacked on the end
d1 <- d1 |> relocate(valid_min, valid_max, .after = units)

newly <- function(types) sum(!d0$is_canonical[d0$measurement_type %in% types])

if (isTRUE(all.equal(as.data.frame(d0), as.data.frame(d1)))) {
  cat("measurement_type.csv already at target state — nothing written\n")
} else {
  # na = "" is the whole point; the default na = "NA" is what corrupts this file
  write_csv(d1, path_reg, na = "")
  cat("measurement_type.csv updated:\n")
  cat("  bottle-reference types canonical:", length(btl_types),
      sprintf("(+%d newly flagged)", newly(btl_types)), "\n")
  cat("  uncorrected sensor types canonical:", length(sensor_types),
      sprintf("(+%d newly flagged)", newly(sensor_types)), "\n")
  cat("  valid_min/valid_max populated   :", nrow(plaus), "types\n")
}

# re-read so a bad write trips the validator here rather than at some later reader
d2 <- calcofi4db::read_measurement_type(path_reg)
stopifnot(
  "btl group must be canonical"  = all(d2$is_canonical[d2$measurement_type %in% btl_types]),
  "sensor group must be canonical" =
    all(d2$is_canonical[d2$measurement_type %in% sensor_types]),
  # the point of the sensor group is that a sensor-only cruise still has both
  # variables; one of each is the minimum that guarantees it
  "an uncorrected salinity AND oxygen must both be canonical" =
    any(d2$is_canonical[d2$measurement_type %in% c("salinity_1", "salinity_2")]) &&
    any(d2$is_canonical[d2$measurement_type %in% c("oxygen_ml_l_1", "oxygen_ml_l_2")]),
  "ranges must round-trip"       = sum(!is.na(d2$valid_min)) == nrow(plaus),
  "valid_min <= valid_max"       = all(d2$valid_min <= d2$valid_max, na.rm = TRUE))

ctd <- filter(d2, str_detect(`_source_datasets`, "calcofi_ctd-cast"))
cat("\nCTD types:", nrow(ctd), "| canonical:", sum(ctd$is_canonical),
    "| with a declared range:", sum(!is.na(ctd$valid_min)), "\n")
