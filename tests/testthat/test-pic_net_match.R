# PIC net event -> SWFSC net matching rules (libs/pic_net_match.R), used by
# explore_sio_pic-zooplankton_ichthyo-nets.qmd.
# Run from the repo root: testthat::test_file("tests/testthat/test-pic_net_match.R")

root <- normalizePath(file.path(testthat::test_path(), "..", ".."))
source(file.path(root, "libs", "pic_net_match.R"))

utc <- function(x) as.POSIXct(x, tz = "UTC")

# one bongo tow (two nets), one ring-net tow (one net), 10 km apart
nets <- data.frame(
  net_key      = c("n_bs", "n_bp", "n_c1"),
  tow_key      = c("t_b",  "t_b",  "t_c1"),
  site_key     = c("093.3 030.0", "093.3 030.0", "090.0 060.0"),
  datetime_utc = utc(c("2024-03-26 18:00", "2024-03-26 18:00", "1960-05-01 12:00")),
  latitude     = c(32.9, 32.9, 33.0),
  longitude    = c(-117.5, -117.5, -118.0),
  tow_type     = c("CB", "CB", "C1"),
  net_side     = c("S", "P", "S"))

pic <- function(...) {
  d <- data.frame(
    pic_id = 1L, site_key = "093.3 030.0", datetime_utc = utc("2024-03-26 18:30"),
    latitude = 32.9, longitude = -117.5, tow_type = "CB", net_side = "S",
    stringsAsFactors = FALSE)
  a <- list(...)
  for (k in names(a)) d[[k]] <- a[[k]]
  d
}

test_that("net types map to SWFSC tow types; unsorted nets are NA", {
  expect_equal(
    pic_tow_type(c("CALBOBL", "cal1mobl", "CAL2MOBL", "CALVET", "PAIROVET", "MANTA", "PRPOOS", "HSN", "1 m")),
    c("CB", "C1", "C2", "CV", "PV", "MT", NA, NA, NA))
})

test_that("formaldehyde is starboard, ethanol is port, case-insensitive", {
  expect_equal(
    pic_net_side(c("formaldehyde", "Formaldehyde", "formalin", "ethanol", "Ethanol", NA, "")),
    c("S", "S", "S", "P", "P", NA, NA))
})

test_that("local PST times convert to UTC (+8 h, no daylight saving)", {
  x <- pic_local_to_utc(as.Date(c("1998-07-24", "1998-01-10", "1998-07-24")), c("1530", "945", NA))
  expect_equal(x$datetime_utc, utc(c("1998-07-24 23:30", "1998-01-10 17:45", "1998-07-24 08:00")))
  expect_equal(x$time_known, c(TRUE, TRUE, FALSE))
  # an impossible time is not trusted
  expect_false(pic_local_to_utc(as.Date("1998-07-24"), "2575")$time_known)
})

test_that("the preservative picks the net within a bongo tow", {
  m <- pic_match_nets(rbind(pic(), pic(pic_id = 2L, net_side = "P")), nets)
  expect_equal(m$net_key, c("n_bs", "n_bp"))
  expect_equal(m$net_rule, c("side", "side"))
  expect_equal(m$match_method, c("station", "station"))
  expect_equal(m$status, c("matched", "matched"))
})

test_that("a single-net tow gives its net whatever the side", {
  m <- pic_match_nets(
    pic(site_key = "090.0 060.0", datetime_utc = utc("1960-05-01 13:00"),
        latitude = 33, longitude = -118, tow_type = "C1", net_side = "P"), nets)
  expect_equal(m$net_key, "n_c1")
  expect_equal(m$net_rule, "single_net")
})

test_that("a bongo record with no preservative gets the tow but no net", {
  m <- pic_match_nets(pic(net_side = NA_character_), nets)
  expect_true(is.na(m$net_key))
  expect_equal(m$tow_key, "t_b")
  expect_equal(m$net_rule, "side_unknown")
  expect_equal(m$status, "no_net")
})

test_that("the tow type must agree", {
  m <- pic_match_nets(pic(tow_type = "C1"), nets)
  expect_equal(m$status, "no_candidate")
})

test_that("station window: 36 h at the same station, not beyond", {
  expect_equal(pic_match_nets(pic(datetime_utc = utc("2024-03-28 05:00")), nets)$status, "matched")
  expect_equal(pic_match_nets(pic(datetime_utc = utc("2024-03-28 07:00"), latitude = 40), nets)$status, "no_candidate")
})

test_that("space-time catches a station-code mismatch within 5 km and 12 h", {
  m <- pic_match_nets(pic(site_key = "093.3 031.0", latitude = 32.92), nets)
  expect_equal(m$match_method, "space_time")
  expect_equal(m$net_key, "n_bs")
  # 10 km off: no
  expect_equal(pic_match_nets(pic(site_key = "093.3 031.0", latitude = 32.99), nets)$status, "no_candidate")
})

test_that("an unsorted net type is reported, never matched", {
  m <- pic_match_nets(pic(tow_type = NA_character_), nets)
  expect_equal(m$status, "not_sorted")
  expect_true(is.na(m$net_key))
})

test_that("each SWFSC net goes to one PIC record: the closer claim wins", {
  m <- pic_match_nets(rbind(
    pic(pic_id = 1L, datetime_utc = utc("2024-03-26 20:00")),
    pic(pic_id = 2L, datetime_utc = utc("2024-03-26 18:10"))), nets)
  expect_equal(m$status, c("conflict", "matched"))
  expect_equal(m$net_key, c(NA, "n_bs"))
})

test_that("a station match outranks a closer space-time match", {
  nets2 <- rbind(nets, data.frame(
    net_key = "n_x", tow_key = "t_x", site_key = "093.3 029.0",
    datetime_utc = utc("2024-03-26 18:29"), latitude = 32.9, longitude = -117.5,
    tow_type = "CB", net_side = "S"))
  m <- pic_match_nets(pic(), nets2)
  expect_equal(m$net_key, "n_bs")
  expect_equal(m$match_method, "station")
})
