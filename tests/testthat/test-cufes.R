# CUFES sample position and eggs/m3 rules (libs/cufes.R), used by ingest_swfsc_cufes.qmd.
# Run from the repo root: testthat::test_file("tests/testthat/test-cufes.R")

root <- normalizePath(file.path(testthat::test_path(), "..", ".."))
source(file.path(root, "libs", "cufes.R"))

test_that("a sample with both ends takes the midpoint", {
  p <- cufes_position(32, -118, 33, -119)
  expect_equal(p$latitude, 32.5)
  expect_equal(p$longitude, -118.5)
  expect_equal(p$position_source, "midpoint")
})

test_that("a missing stop takes the start, a missing start takes the stop", {
  p <- cufes_position(c(32, NaN), c(-118, NaN), c(NA, 34), c(NA, -120))
  expect_equal(p$latitude, c(32, 34))
  expect_equal(p$longitude, c(-118, -120))
  expect_equal(p$position_source, c("start", "stop"))
})

test_that("a position is a pair: half an end never pairs with the other end", {
  # start has a latitude but a NaN longitude; stop has a longitude but no latitude
  p <- cufes_position(42, NaN, NA, -120)
  expect_true(is.na(p$latitude))
  expect_true(is.na(p$longitude))
  expect_true(is.na(p$position_source))
  # an Inf component disqualifies its end too
  p <- cufes_position(32, Inf, 33, -119)
  expect_equal(c(p$latitude, p$longitude), c(33, -119))
  expect_equal(p$position_source, "stop")
})

test_that("effort: minutes = stop - start, pump speed = mean of the two ends", {
  t0 <- as.POSIXct("1996-03-18 07:27:00", tz = "UTC")
  e <- cufes_effort(t0, t0 + 30 * 60, 0.6, 0.8)
  expect_equal(e$duration_min, 30)
  expect_equal(e$pump_speed_mean, 0.7)
  expect_equal(e$volume_pumped_m3, 21)
  expect_true(e$conc_ok)
})

test_that("eggs/m3 = (count / minutes) / mean pump speed (Ed Weber, swfsc_cufes Q01)", {
  t0 <- as.POSIXct("1996-03-18 07:27:00", tz = "UTC")
  e <- cufes_effort(t0, t0 + 3 * 60, 0.64, 0.64)
  # the export's first sample: 15 sardine eggs in 3 minutes at 0.64 m3/min
  expect_equal(cufes_egg_concentration(15, e$duration_min, e$pump_speed_mean, e$conc_ok),
               (15 / 3) / 0.64)
  expect_equal(cufes_egg_concentration(0, e$duration_min, e$pump_speed_mean, e$conc_ok), 0)
  expect_true(is.na(cufes_egg_concentration(NA, e$duration_min, e$pump_speed_mean, e$conc_ok)))
})

test_that("a scalar conc_ok keeps one concentration per count (regression: ifelse recycled the first)", {
  # the notebook passes conc_ok = TRUE after filtering to standardizable samples;
  # an ifelse() implementation returned the FIRST row's value for every row
  v <- cufes_egg_concentration(c(15, 30, 0), c(3, 3, 30), c(0.64, 0.5, 0.64), conc_ok = TRUE)
  expect_equal(v, c((15 / 3) / 0.64, (30 / 3) / 0.5, 0))
})

test_that("no concentration without positive minutes and positive pump speeds at both ends", {
  t0 <- as.POSIXct("2000-01-01 00:00:00", tz = "UTC")
  e <- cufes_effort(
    start      = c(t0, t0, t0, t0, t0),
    stop       = c(t0, t0 - 60, t0 + 60, t0 + 60, t0 + 60),
    pump_start = c(0.64, 0.64, 0, NA, 0.64),
    pump_stop  = c(0.64, 0.64, 0.64, 0.64, NaN))
  expect_equal(e$conc_ok, rep(FALSE, 5))
  expect_true(all(is.na(cufes_egg_concentration(10, e$duration_min, e$pump_speed_mean, e$conc_ok))))
})
