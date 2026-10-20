# libs/pic_net_match.R
# -----------------------------------------------------------------------------
# The rules explore_sio_pic-zooplankton_ichthyo-nets.qmd applies to match SIO
# Pelagic Invertebrate Collection (PIC) Parent Net Events (Linsey Sala, PNE
# table 2026-10-19) to the SWFSC ichthyoplankton nets in a CalCOFI release, so
# each PIC record can carry SWFSC's NetId. Kept here so
# tests/testthat/test-pic_net_match.R can assert them.
#
# - pic_tow_type(): PIC net type -> SWFSC tow type. Only the nets SWFSC sorts
#   for ichthyoplankton map; the rest (PRPOOS, HSN, ring nets, ...) are NA and
#   are reported, never matched.
# - pic_net_side(): preservative -> bongo side. The match is per net (cod end),
#   not per tow: on a CalCOFI bongo the starboard net goes to formaldehyde and
#   the port net to ethanol (Ed Weber 2026-02-09, Linsey Sala's PNE tips).
# - pic_local_to_utc(): PIC dates + HHMM times are local Pacific Standard Time
#   (PNE field details); the release keeps tow times in UTC.
# - pic_match_nets(): candidate tows of the same tow type at the same station
#   within a time window, else within a distance and a tighter time window;
#   the nearest wins, the net is picked by side, and every SWFSC net is
#   assigned to at most one PIC record.

#' SWFSC tow type for a PIC net type
#'
#' @param net_type character, PIC `NET_TYPE_pne` (any case)
#' @return character SWFSC tow type (`CB`, `C1`, `C2`, `CV`, `PV`, `MT`, `MB`)
#'   or NA when SWFSC does not sort that net for ichthyoplankton
pic_tow_type <- function(net_type) {
  map <- c(
    CALBOBL  = "CB",  # CalCOFI oblique bongo, 0.71 m
    BONGO    = "CB",
    CAL1MOBL = "C1",  # CalCOFI one meter oblique ring net
    CAL2MOBL = "C2",  # CalCOFI two meter oblique ring net
    CALVET   = "CV",  # CalCOFI vertical egg tow
    PAIROVET = "PV",  # paired CalVET tows
    MANTA    = "MT",  # manta, continuous-flow surface tow
    MARBOBL  = "MB")  # MARMAP oblique bongo
  key <- toupper(gsub("\\s+", "", net_type))
  unname(map[key])
}

#' Net side for a PIC preservative
#'
#' @param preservative character, PIC `PRESERVATIVE_pne` (any case)
#' @return `"S"` (starboard, formaldehyde / formalin), `"P"` (port, ethanol)
#'   or NA
pic_net_side <- function(preservative) {
  p <- tolower(trimws(preservative))
  ifelse(
    grepl("formal", p), "S",
    ifelse(grepl("ethanol|etoh", p), "P", NA_character_))
}

#' PIC local date and HHMM time to UTC
#'
#' PIC times are Pacific Standard Time all year (UTC-8, no daylight saving).
#' A missing time gives local midnight, flagged by `time_known = FALSE`.
#'
#' @param date Date (local)
#' @param hhmm character `HHMM` (3-digit `HMM` is padded)
#' @return data.frame with `datetime_utc` (POSIXct UTC) and `time_known`
pic_local_to_utc <- function(date, hhmm) {
  t     <- trimws(as.character(hhmm))
  t[t == ""] <- NA
  t     <- ifelse(is.na(t), NA, formatC(as.integer(t), width = 4, flag = "0"))
  ok    <- !is.na(t) & grepl("^[0-2][0-9][0-5][0-9]$", t) & as.integer(substr(t, 1, 2)) < 24
  hm    <- ifelse(ok, paste0(substr(t, 1, 2), ":", substr(t, 3, 4)), "00:00")
  local <- as.POSIXct(paste(format(as.Date(date)), hm), tz = "Etc/GMT+8")
  data.frame(
    datetime_utc = as.POSIXct(format(local, tz = "UTC"), tz = "UTC"),
    time_known   = ok & !is.na(date))
}

.km_between <- function(lat1, lon1, lat2, lon2) {
  r  <- pi / 180
  a  <- sin((lat2 - lat1) * r / 2)^2 +
    cos(lat1 * r) * cos(lat2 * r) * sin((lon2 - lon1) * r / 2)^2
  6371.0088 * 2 * asin(pmin(1, sqrt(a)))
}

#' Match PIC net events to SWFSC nets
#'
#' Two ways to be a candidate, both requiring the same tow type:
#' `station`: same `site_key` and tow start within `max_hr_station` hours;
#' `space_time`: within `max_km` km and `max_hr_space` hours. Among candidate
#' tows the station match ranks first, then the smallest time difference, then
#' distance. Within the chosen tow the net is the one on the PIC record's side;
#' a tow with a single net gives that net whatever its side (`single_net`); a
#' two-net tow with no side on the PIC record gives no net (`side_unknown`).
#' Each SWFSC net goes to one PIC record only: the best-ranked claim keeps it,
#' the others become `conflict`.
#'
#' @param pic data.frame: `pic_id`, `site_key`, `datetime_utc`, `latitude`,
#'   `longitude`, `tow_type`, `net_side`
#' @param nets data.frame: `net_key`, `tow_key`, `site_key`, `datetime_utc`,
#'   `latitude`, `longitude`, `tow_type`, `net_side`
#' @param max_hr_station,max_km,max_hr_space match windows
#' @return one row per `pic_id`: `net_key`, `tow_key`, `match_method`
#'   (`station` | `space_time` | NA), `net_rule` (`side` | `single_net` |
#'   `side_unknown` | `side_absent`), `dt_hr`, `dist_km`, `status`
#'   (`matched` | `conflict` | `no_net` | `no_candidate` | `not_sorted`)
pic_match_nets <- function(
    pic, nets, max_hr_station = 36, max_km = 5, max_hr_space = 12) {

  stopifnot(
    !anyDuplicated(pic$pic_id), !anyDuplicated(nets$net_key),
    inherits(pic$datetime_utc, "POSIXct"), inherits(nets$datetime_utc, "POSIXct"))

  tows <- unique(nets[, c("tow_key", "site_key", "datetime_utc", "latitude", "longitude", "tow_type")])
  tows <- tows[!duplicated(tows$tow_key), ]
  p    <- pic[!is.na(pic$tow_type), ]

  # candidate tows: by station, and by space + time (bucketed by day to keep
  # the join small; the window is applied exactly after)
  by_station <- merge(
    p[, c("pic_id", "site_key", "tow_type", "datetime_utc", "latitude", "longitude")],
    tows, by = c("site_key", "tow_type"), suffixes = c("", ".n"))
  by_station$method <- rep("station", nrow(by_station))

  day <- function(x) as.integer(floor(as.numeric(x) / 86400))
  span <- ceiling(max_hr_space / 24)
  pd <- do.call(rbind, lapply(-span:span, function(o) {
    x <- p[, c("pic_id", "site_key", "tow_type", "datetime_utc", "latitude", "longitude")]
    x$day <- day(x$datetime_utc) + o
    x }))
  td <- tows; td$day <- day(td$datetime_utc)
  by_space <- merge(pd, td, by = c("day", "tow_type"), suffixes = c("", ".n"))
  by_space$day <- NULL
  by_space$method <- rep("space_time", nrow(by_space))

  cand <- rbind(
    by_station[, c("pic_id", "tow_key", "method", "datetime_utc", "datetime_utc.n",
                   "latitude", "longitude", "latitude.n", "longitude.n")],
    by_space[,   c("pic_id", "tow_key", "method", "datetime_utc", "datetime_utc.n",
                   "latitude", "longitude", "latitude.n", "longitude.n")])
  cand$dt_hr   <- abs(as.numeric(difftime(cand$datetime_utc.n, cand$datetime_utc, units = "hours")))
  cand$dist_km <- .km_between(cand$latitude, cand$longitude, cand$latitude.n, cand$longitude.n)
  keep <- (cand$method == "station"    & cand$dt_hr <= max_hr_station) |
          (cand$method == "space_time" & cand$dt_hr <= max_hr_space & !is.na(cand$dist_km) & cand$dist_km <= max_km)
  cand <- cand[keep %in% TRUE, ]

  # best tow per PIC record
  cand$rank_m <- ifelse(cand$method == "station", 1L, 2L)
  cand <- cand[order(cand$pic_id, cand$rank_m, cand$dt_hr, cand$dist_km), ]
  best <- cand[!duplicated(cand$pic_id), c("pic_id", "tow_key", "method", "dt_hr", "dist_km", "rank_m")]

  # pick the net within the tow
  best <- merge(best, p[, c("pic_id", "net_side")], by = "pic_id")
  n_per_tow <- table(nets$tow_key)
  best$n_nets <- as.integer(n_per_tow[best$tow_key])
  # an unknown side never pairs with an unknown side
  side_id <- function(tow, side) ifelse(is.na(side), NA, paste(tow, side))
  best$net_key  <- nets$net_key[match(
    side_id(best$tow_key, best$net_side), side_id(nets$tow_key, nets$net_side),
    incomparables = NA)]
  single        <- best$n_nets == 1 & is.na(best$net_key)
  single_net    <- nets$net_key[match(best$tow_key, nets$tow_key)]
  best$net_key[single] <- single_net[single]
  best$net_rule <- ifelse(
    !is.na(best$net_key) & !single, "side",
    ifelse(single, "single_net",
      ifelse(is.na(best$net_side), "side_unknown", "side_absent")))

  # one PIC record per SWFSC net: best-ranked claim keeps it
  best <- best[order(best$rank_m, best$dt_hr, best$dist_km, best$pic_id), ]
  dup  <- !is.na(best$net_key) & duplicated(best$net_key)
  best$status <- ifelse(dup, "conflict", ifelse(is.na(best$net_key), "no_net", "matched"))
  best$net_key[dup] <- NA

  out <- data.frame(pic_id = pic$pic_id, stringsAsFactors = FALSE)
  i   <- match(out$pic_id, best$pic_id)
  out$net_key      <- best$net_key[i]
  out$tow_key      <- best$tow_key[i]
  out$match_method <- best$method[i]
  out$net_rule     <- best$net_rule[i]
  out$dt_hr        <- best$dt_hr[i]
  out$dist_km      <- best$dist_km[i]
  out$status       <- ifelse(
    is.na(pic$tow_type), "not_sorted",
    ifelse(is.na(i), "no_candidate", best$status[i]))
  out
}
