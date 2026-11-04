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
#' a tow with a single net gives that net when the net or the record has no
#' side (`single_net`); a record whose side the tow lacks gets no net
#' (`side_absent`), and a two-net tow with no side on the record gives no net
#' (`side_unknown`).
#' Each SWFSC net goes to one PIC record only and each record to one net: the
#' (record, net) pairs are taken in rank order while both are free, so a record
#' whose best net went to a closer claim falls back to its next candidate; a
#' record left with none is `conflict`.
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

  # the net each candidate tow offers the PIC record: the net on its side, or
  # a single-net tow's only net; an unknown side never pairs with an unknown side
  cand <- merge(cand, p[, c("pic_id", "net_side")], by = "pic_id")
  cand$rank_m <- ifelse(cand$method == "station", 1L, 2L)
  n_per_tow   <- table(nets$tow_key)
  cand$n_nets <- as.integer(n_per_tow[cand$tow_key])
  side_id <- function(tow, side) ifelse(is.na(side), NA, paste(tow, side))
  cand$net_key <- nets$net_key[match(
    side_id(cand$tow_key, cand$net_side), side_id(nets$tow_key, nets$net_side),
    incomparables = NA)]
  # a tow's only net goes to a record of either side only when that net has no
  # side (C1, CalVET, Manta) or the record has none: a bongo tow whose port net
  # SWFSC does not hold gives its starboard net to the formaldehyde record only
  single_net  <- nets$net_key[match(cand$tow_key, nets$tow_key)]
  single_side <- nets$net_side[match(cand$tow_key, nets$tow_key)]
  single      <- cand$n_nets == 1 & is.na(cand$net_key) &
    (is.na(single_side) | is.na(cand$net_side))
  cand$net_key[single] <- single_net[single]
  cand$net_rule <- ifelse(
    !is.na(cand$net_key) & !single, "side",
    ifelse(single, "single_net",
      ifelse(is.na(cand$net_side), "side_unknown", "side_absent")))

  # one PIC record per SWFSC net and one net per PIC record: take the pairs in
  # rank order (station first, then time, then distance), keeping a pair only
  # while both its record and its net are free, so a record whose best net is
  # taken falls back to its next candidate
  cand <- cand[order(cand$rank_m, cand$dt_hr, cand$dist_km, cand$pic_id), ]
  cand$taken <- rep(FALSE, nrow(cand))
  pairs  <- which(!is.na(cand$net_key))
  used_p <- new.env(hash = TRUE, size = length(pairs))
  used_n <- new.env(hash = TRUE, size = length(pairs))
  for (k in pairs) {
    pk <- as.character(cand$pic_id[k]); nk <- cand$net_key[k]
    if (is.null(used_p[[pk]]) && is.null(used_n[[nk]])) {
      used_p[[pk]] <- TRUE; used_n[[nk]] <- TRUE; cand$taken[k] <- TRUE }
  }

  # per record: the pair it took, else its best candidate
  cand$status <- ifelse(cand$taken, "matched", ifelse(is.na(cand$net_key), "no_net", "conflict"))
  has_net     <- tapply(!is.na(cand$net_key), cand$pic_id, any)
  cand$o      <- ifelse(cand$taken, 0L, ifelse(!is.na(cand$net_key), 1L, 2L))
  best <- cand[order(cand$pic_id, cand$o, cand$rank_m, cand$dt_hr, cand$dist_km), ]
  best <- best[!duplicated(best$pic_id), ]
  # a record with no net-bearing candidate is no_net; one whose nets all went
  # to closer claims is conflict
  best$status[best$status == "no_net" & has_net[as.character(best$pic_id)]] <- "conflict"
  best$net_key[best$status != "matched"] <- NA

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

#' First PIC record each record duplicates
#'
#' Two records with the same values in every `keys` column describe one net
#' event; the first by `pic_id` is kept and the others point to it.
#'
#' @param pic data.frame with `pic_id` and the `keys` columns
#' @param keys character column names; a record with any NA key is never a
#'   duplicate
#' @return integer `pic_id` of the first record with the same keys, NA for the
#'   first itself and for a record with no duplicate
pic_duplicate_of <- function(pic, keys) {
  o   <- order(pic$pic_id)
  key <- do.call(paste, c(lapply(pic[o, keys, drop = FALSE], as.character), sep = "\r"))
  key[!stats::complete.cases(pic[o, keys, drop = FALSE])] <- NA
  first <- pic$pic_id[o][match(key, key, incomparables = NA)]
  first[first == pic$pic_id[o]] <- NA
  out <- rep(NA_integer_, nrow(pic)); out[o] <- as.integer(first)
  out
}
