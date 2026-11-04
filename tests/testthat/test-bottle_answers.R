# Provider answers on the bottle database (libs/bottle_answers.R), used by ingest_calcofi_bottle.qmd.
# Run from the repo root: testthat::test_file("tests/testthat/test-bottle_answers.R")

root <- normalizePath(file.path(testthat::test_path(), "..", ".."))
source(file.path(root, "libs", "bottle_answers.R"))

fixture <- function() {
  con <- DBI::dbConnect(duckdb::duckdb())
  DBI::dbWriteTable(con, "casts", data.frame(
    cast_id = c(1, 2, 3), cruise_key = c("2021-05-3322", "2021-05-3322", "1976-02-31AX")))
  DBI::dbWriteTable(con, "bottle", data.frame(
    bottle_id = c(10, 11, 20, 30, 31), cast_id = c(1, 1, 2, 3, 3)))
  DBI::dbWriteTable(con, "bottle_measurement", data.frame(
    bottle_id        = c(10, 10, 11, 20, 20, 30, 30, 31),
    measurement_type = c("salinity", "temperature", "salinity", "salinity", "nitrate",
                         "nitrate", "salinity", "nitrate"),
    measurement_value = c(25, 12, 26, 27, 1, 56, 33.5, 2),
    # a NULL code, a '6', the '8.0' spelling an old build wrote, and plain codes
    measurement_qual = c(NA, NA, "6", "8.0", NA, NA, NA, "4")))
  DBI::dbWriteTable(con, "cast_condition", data.frame(
    cast_id = c(1, 3, 3), condition_type = "wind_speed", condition_value = c(1, 2, 3)))
  con
}

ov_of <- function(...) {
  d <- tibble::tribble(~scope, ~scope_value, ~measurement_type, ~qual, ...)
  d$reason <- "test"; d$question_label <- "Q00"; d$answered_by <- "x"; d$answered_date <- "2026-11-01"
  d
}

qual_of <- function(con, b, t) DBI::dbGetQuery(con, glue::glue(
  "SELECT measurement_qual AS q FROM bottle_measurement WHERE bottle_id = {b} AND measurement_type = '{t}'"))$q

test_that("a cruise_key override flags every value of that type on the cruise, and only it", {
  con <- fixture(); withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  r <- apply_qual_overrides(con, ov_of("cruise_key", "2021-05-3322", "salinity", "8"))
  expect_equal(r$n_matched, 3)
  # bottle 20's '8.0' is already code 8: matched, not changed
  expect_equal(r$n_changed, 2)
  expect_equal(qual_of(con, 10, "salinity"), "8")
  expect_equal(qual_of(con, 11, "salinity"), "8")
  expect_equal(qual_of(con, 10, "temperature"), NA_character_)  # another type untouched
  expect_equal(qual_of(con, 20, "nitrate"), NA_character_)
  expect_equal(qual_of(con, 30, "salinity"), NA_character_)     # another cruise untouched
  # the value stays
  expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM bottle_measurement")$n, 8)
})

test_that("bottle_id and cast_id scopes reach only their bottles", {
  con <- fixture(); withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  r <- apply_qual_overrides(con, ov_of(
    "bottle_id", "30", "nitrate", "8",
    "cast_id",   "1",  "temperature", "8"))
  expect_equal(r$n_matched, c(1, 1))
  expect_equal(qual_of(con, 30, "nitrate"), "8")
  expect_equal(qual_of(con, 31, "nitrate"), "4")
  expect_equal(qual_of(con, 10, "temperature"), "8")
})

test_that("an override whose values were removed upstream counts them, one that matches nothing is zero", {
  con <- fixture(); withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  DBI::dbWriteTable(con, "removed", data.frame(bottle_id = 99, measurement_type = "salinity"))
  DBI::dbWriteTable(con, "bottle", data.frame(bottle_id = 99, cast_id = 1), append = TRUE)
  r <- apply_qual_overrides(con, ov_of(
    "bottle_id", "99", "salinity", "8",
    "bottle_id", "11", "oxygen_ml_l", "8"), removed_tbl = "removed")
  expect_equal(r$n_matched, c(0, 0))
  expect_equal(r$n_removed_upstream, c(1, 0))
})

test_that("a cast exclusion removes the cast, its bottles, their values and its conditions", {
  con <- fixture(); withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  ex <- tibble::tibble(scope = "cast_id", scope_value = "3", reason = "on land",
                       question_label = "Q15", answered_by = "x", answered_date = "2026-11-01")
  r <- apply_sample_exclusions(con, ex)
  expect_equal(c(r$n_casts, r$n_bottles, r$n_measurements, r$n_conditions), c(1, 2, 3, 2))
  n <- function(sql) DBI::dbGetQuery(con, sql)$n
  expect_equal(n("SELECT COUNT(*) AS n FROM casts WHERE cast_id = 3"), 0)
  expect_equal(n("SELECT COUNT(*) AS n FROM bottle WHERE cast_id = 3"), 0)
  expect_equal(n("SELECT COUNT(*) AS n FROM bottle_measurement WHERE bottle_id IN (30, 31)"), 0)
  expect_equal(n("SELECT COUNT(*) AS n FROM cast_condition"), 1)
  # the other casts are untouched
  expect_equal(n("SELECT COUNT(*) AS n FROM bottle_measurement"), 5)
})

test_that("the registries are validated on read", {
  f <- withr::local_tempfile(fileext = ".csv")
  readr::write_csv(ov_of("station", "1", "salinity", "8"), f, na = "")
  expect_error(read_qual_overrides(f), "scope must be")
  readr::write_csv(ov_of("cruise_key", "2021-05-3322", "salinity", "suspect"), f, na = "")
  expect_error(read_qual_overrides(f), "single-digit")
  readr::write_csv(ov_of("bottle_id", "1", "salinity", "8", "bottle_id", "1", "salinity", "9"), f, na = "")
  expect_error(read_qual_overrides(f), "one row per")
  readr::write_csv(ov_of("bottle_id", "1", "salinity", "8"), f, na = "")
  expect_equal(nrow(read_qual_overrides(f)), 1)
})

test_that("the committed registries read clean", {
  expect_no_error(ov <- read_qual_overrides(file.path(root, "metadata/calcofi/bottle/qual_overrides.csv")))
  expect_no_error(ex <- read_sample_exclusions(file.path(root, "metadata/calcofi/bottle/sample_exclusions.csv")))
  expect_true(all(ov$qual == "8"))
  expect_equal(ex$scope_value, "24415")
})
