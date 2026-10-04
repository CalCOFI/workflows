# libs/cufes.R
# -----------------------------------------------------------------------------
# The two rules ingest_swfsc_cufes.qmd applies to each CUFES sample, kept here so
# tests/testthat/test-cufes.R can assert them:
#
# - cufes_position(): where a sample is. A CUFES sample is a segment (the pump
#   runs while the ship steams), so its position is the midpoint of the start
#   and stop positions, else whichever end has BOTH coordinates. A position is a
#   pair: the source end is chosen first, and a NaN/NA/Inf component disqualifies
#   that end, so a latitude is never paired with the other end's longitude.
# - cufes_egg_concentration(): Ed Weber's standardization (SWFSC, 2026-09-25,
#   questions swfsc_cufes Q01): eggs / m^3 = (count / (stop time - start time))
#   / ((start pump speed + stop pump speed) / 2), pump speed in m3/min (Q02).
#   Defined only where the minutes and both pump speeds are finite and positive;
#   otherwise NA, never a guess.

.cufes_ok <- function(x) !is.na(x) & !is.nan(x) & is.finite(x)

#' Position of a CUFES sample from its start and stop ends
#'
#' @param start_lat,start_lon,stop_lat,stop_lon numeric vectors (one per sample)
#' @return a data.frame with `latitude`, `longitude` and `position_source`
#'   (`midpoint`, `start`, `stop`, or NA when neither end has both coordinates)
cufes_position <- function(start_lat, start_lon, stop_lat, stop_lon) {
  ok        <- .cufes_ok
  use_mid   <- ok(start_lat) & ok(start_lon) & ok(stop_lat) & ok(stop_lon)
  use_start <- !use_mid & ok(start_lat) & ok(start_lon)
  use_stop  <- !use_mid & !use_start & ok(stop_lat) & ok(stop_lon)
  pick <- function(mid, a, b) ifelse(use_mid, mid, ifelse(use_start, a, ifelse(use_stop, b, NA_real_)))
  data.frame(
    latitude        = pick((start_lat + stop_lat) / 2, start_lat, stop_lat),
    longitude       = pick((start_lon + stop_lon) / 2, start_lon, stop_lon),
    position_source = ifelse(use_mid, "midpoint", ifelse(use_start, "start",
                        ifelse(use_stop, "stop", NA_character_))),
    stringsAsFactors = FALSE)
}

#' Minutes sampled, mean pump speed and whether a CUFES sample can be standardized
#'
#' @param start,stop POSIXct start and stop of the sample
#' @param pump_start,pump_stop pump speed at start and stop (m3/min)
#' @return a data.frame with `duration_min`, `pump_speed_mean` (m3/min),
#'   `volume_pumped_m3` and `conc_ok` (TRUE where minutes and both pump speeds
#'   are finite and positive)
cufes_effort <- function(start, stop, pump_start, pump_stop) {
  ok  <- .cufes_ok
  mins <- as.numeric(difftime(stop, start, units = "mins"))
  pump <- (pump_start + pump_stop) / 2
  data.frame(
    duration_min     = mins,
    pump_speed_mean  = pump,
    volume_pumped_m3 = mins * pump,
    conc_ok          = ok(mins) & mins > 0 & ok(pump_start) & pump_start > 0 &
                       ok(pump_stop) & pump_stop > 0)
}

#' Eggs per m3 pumped (Ed Weber's standardization, swfsc_cufes Q01)
#'
#' @param count egg count
#' @param duration_min,pump_speed_mean,conc_ok from [cufes_effort()]
#' @return eggs per m3, NA where `conc_ok` is not TRUE or the count is NA
cufes_egg_concentration <- function(count, duration_min, pump_speed_mean, conc_ok) {
  # not ifelse(): its result takes the length of the TEST, so a scalar conc_ok
  # would recycle the first sample's concentration onto every row
  out <- (count / duration_min) / pump_speed_mean
  out[!(rep_len(conc_ok, length(out)) %in% TRUE)] <- NA_real_
  out
}
