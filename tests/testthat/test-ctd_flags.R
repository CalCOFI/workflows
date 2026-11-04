# CTD flag inheritance (libs/ctd_flags.R), used by ingest_calcofi_ctd-cast.qmd.
# Run from the repo root: testthat::test_file("tests/testthat/test-ctd_flags.R")

root <- normalizePath(file.path(testthat::test_path(), "..", ".."))
source(file.path(root, "libs", "ctd_flags.R"))

fixture <- function() {
  con <- DBI::dbConnect(duckdb::duckdb())
  DBI::dbExecute(con, "CREATE TABLE ctd_measurement (ctd_cast_uuid VARCHAR, depth_m DOUBLE,
                         measurement_type VARCHAR, measurement_value DOUBLE, measurement_qual VARCHAR)")
  rows <- data.frame(
    ctd_cast_uuid = c(
      # bin 1: Temp2 bad, sigma_2 blank -> sigma_2 inherits 9
      "c1", "c1", "c1", "c1",
      # bin 2: Salt2 questionable (8.0), Temp2 fine -> inherits 8
      "c1", "c1", "c1",
      # bin 3: both Temp2 8 and Salt2 9 -> 9 wins
      "c1", "c1", "c1",
      # bin 4: provider already flagged sigma_2 8 while Temp2 is 9 -> kept at 8
      "c1", "c1",
      # bin 5: nothing flagged -> untouched
      "c1", "c1", "c1",
      # bin 6: sensor 1 bad, sensor 2 fine -> sigma_1 flagged, sigma_2 not
      "c2", "c2", "c2", "c2",
      # bin 7: a different cast with the same depth as bin 1 and no flag
      "c3", "c3"),
    depth_m = c(1, 1, 1, 1,  2, 2, 2,  3, 3, 3,  4, 4,  5, 5, 5,  1, 1, 1, 1,  1, 1),
    measurement_type = c(
      "temperature_2", "salinity_2", "sigma_theta_2", "sigma_theta_1",
      "temperature_2", "salinity_2", "sigma_theta_2",
      "temperature_2", "salinity_2", "sigma_theta_2",
      "temperature_2", "sigma_theta_2",
      "temperature_2", "salinity_2", "sigma_theta_2",
      "temperature_1", "salinity_1", "sigma_theta_1", "sigma_theta_2",
      "temperature_2", "sigma_theta_2"),
    measurement_qual = c(
      "9", NA, NA, NA,
      NA, "8.0", NA,
      "8", "9", NA,
      "9", "8",
      NA, NA, NA,
      "9", NA, NA, NA,
      NA, NA),
    stringsAsFactors = FALSE)
  rows$measurement_value <- 1
  DBI::dbWriteTable(con, "ctd_measurement", rows, append = TRUE)
  con
}
qual_of <- function(con, uuid, depth, type)
  DBI::dbGetQuery(con, sprintf("SELECT measurement_qual FROM ctd_measurement
    WHERE ctd_cast_uuid = '%s' AND depth_m = %s AND measurement_type = '%s'", uuid, depth, type))[[1]]

test_that("a derived row inherits its sensor's 8/9, 9 over 8, and keeps its own 8/9", {
  con <- fixture(); on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  expect_equal(count_uninherited_flags(con, "sigma_theta_2", c("temperature_2", "salinity_2")), 3L)
  n <- inherit_sensor_flags(con, "sigma_theta_2", c("temperature_2", "salinity_2"))
  expect_equal(n, 3L)
  expect_equal(qual_of(con, "c1", 1, "sigma_theta_2"), "9")
  expect_equal(qual_of(con, "c1", 2, "sigma_theta_2"), "8")
  expect_equal(qual_of(con, "c1", 3, "sigma_theta_2"), "9")
  expect_equal(qual_of(con, "c1", 4, "sigma_theta_2"), "8")   # the provider's own flag is kept
  expect_true(is.na(qual_of(con, "c1", 5, "sigma_theta_2")))  # nothing flagged: untouched
  expect_true(is.na(qual_of(con, "c3", 1, "sigma_theta_2")))  # another cast, same depth: untouched
  expect_equal(count_uninherited_flags(con, "sigma_theta_2", c("temperature_2", "salinity_2")), 0L)
})

test_that("sensor 1 and sensor 2 do not cross, and the rule is idempotent", {
  con <- fixture(); on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  inherit_sensor_flags(con, "sigma_theta_1", c("temperature_1", "salinity_1"))
  expect_equal(qual_of(con, "c2", 1, "sigma_theta_1"), "9")
  expect_true(is.na(qual_of(con, "c2", 1, "sigma_theta_2")))   # sensor 2 is fine on that bin
  expect_true(is.na(qual_of(con, "c1", 1, "sigma_theta_1")))   # c1's sensor 1 series are not flagged
  inherit_sensor_flags(con, "sigma_theta_2", c("temperature_2", "salinity_2"))
  expect_equal(inherit_sensor_flags(con, "sigma_theta_2", c("temperature_2", "salinity_2")), 0L)
})
