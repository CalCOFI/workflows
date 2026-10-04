# libs/download_station_positions.R
# -----------------------------------------------------------------------------
# Reproducible acquisition of the official CalCOFI station positions used by
# explore_grid_voronoi.qmd (CalCOFI/workflows#130).
#
# Source: https://calcofi.org/sampling-info/station-positions/ ("Station
# Positions"). On 2026-10-02 the page carried three HTML tables and these links:
#
#   1. "Station Position (Lat/Lon), Depth, and Type" — 113 rows (Order Occ,
#      Line, Sta, Lat/Lon in decimal and degree-minute forms, Est Depth,
#      Sta Type ROS | SCCOOS). The same rows are linked as
#      https://calcofi.org/downloads/maps/CalCOFIStationOrder.csv; this script
#      reads both and stops if they disagree.
#   2. "SCCOOS Station Positions" — the 9 inshore ~20 m SCCOOS stations, all of
#      which are also rows of table 1 (Sta Type SCCOOS). Its "Download as CSV"
#      link (https://calcofi.org/files/SCCOOS_stations.csv) returned 404, and the
#      SCCOOS KML (https://sccoos.org/kml/calcofi_sccoos.kml) returned 403.
#   3. "Navy Stations" — 25 stations of the standard pattern that Navy
#      operations may close, with the operations area; its CSV link
#      (https://calcofi.org/files/Navy_Stations.csv) returned 404.
#
#   The page's prose: the 75-station pattern (standard since 1984; summer and
#   fall) is 66 stations on 6 lines 93.3 to 76.7 plus 9 SCCOOS stations; the
#   104-station pattern (winter and spring) adds 29 stations on lines 73.3 to
#   60.0; the 113-station pattern adds 9 more, every 20 nm on line 66.7 (MBARI
#   "SECRET"). Two KMLs are linked: CalCOFI_75StandardStations.kml and
#   CalCOFI_113StationMap.kml; the 113 one is read here as a cross-check.
#
# Output (under dir_out, default cc_stage_path("reference",
# "calcofi.org_station-positions")): the page snapshot (station-positions.html),
# the linked CSV and KML as fetched, and the tidy station_positions.csv
# (one row per station: line, station, latitude, longitude, depth, type, the
# patterns it belongs to, and the Navy operations area when it has one). The
# tidy CSV is rebuilt from the cached snapshot unless overwrite = TRUE.

SP_URL     <- "https://calcofi.org/sampling-info/station-positions/"
SP_CSV_URL <- "https://calcofi.org/downloads/maps/CalCOFIStationOrder.csv"
SP_KML_URL <- "https://calcofi.org/downloads/CalCOFI_113StationMap.kml"

#' fetch a URL to a file unless it is cached; a browser user agent, since the
#' site's CDN refuses R's default one on some paths
sp_fetch <- function(url, dest, overwrite = FALSE) {
  if (overwrite || !file.exists(dest))
    utils::download.file(url, dest, quiet = TRUE, mode = "wb",
                         headers = c("User-Agent" = "Mozilla/5.0 (CalCOFI workflows)"))
  dest
}

#' parse a "32.41795 N" / "119.95935 W" string to signed decimal degrees
sp_signed_deg <- function(x) {
  v <- as.numeric(sub("\\s*[NSEW]\\s*$", "", x))
  ifelse(grepl("[SW]\\s*$", x), -v, v)
}

#' Download and tidy the official CalCOFI station positions
#'
#' @param dir_out   directory for the snapshot and the tidy CSV
#' @param overwrite re-fetch the page and the linked files
#' @param verbose   print what the page lists
#' @return the tidy table (also written to `station_positions.csv` in `dir_out`),
#'   with the fetch time as attribute `fetched`
download_station_positions <- function(
    dir_out   = calcofi4db::cc_stage_path("reference", "calcofi.org_station-positions", create = TRUE),
    overwrite = FALSE,
    verbose   = TRUE) {
  dir.create(dir_out, recursive = TRUE, showWarnings = FALSE)
  f_html <- sp_fetch(SP_URL,     file.path(dir_out, "station-positions.html"), overwrite)
  f_csv  <- sp_fetch(SP_CSV_URL, file.path(dir_out, basename(SP_CSV_URL)),     overwrite)
  f_kml  <- sp_fetch(SP_KML_URL, file.path(dir_out, basename(SP_KML_URL)),     overwrite)

  h     <- rvest::read_html(f_html)
  tbls  <- rvest::html_table(rvest::html_elements(h, "table"))
  heads <- rvest::html_text2(rvest::html_elements(h, "h2"))
  stopifnot(
    "the page no longer carries the three station tables this script reads" =
      length(tbls) == 3,
    "table 1 is not the 113-station table" =
      all(c("Order Occ", "Line", "Sta", "Lat (dec)", "Lon (dec)", "Sta Type") %in% names(tbls[[1]])))

  # table 1: every station of the 113-station pattern, ROS + SCCOOS ----
  t_all <- tbls[[1]] |>
    dplyr::transmute(
      order_occ   = as.integer(.data$`Order Occ`),
      line        = as.numeric(.data$Line),
      station     = as.numeric(.data$Sta),
      latitude    = as.numeric(.data$`Lat (dec)`),
      longitude   = as.numeric(.data$`Lon (dec)`),
      depth_est_m = suppressWarnings(as.integer(.data$`Est Depth`)),
      sta_type    = .data$`Sta Type`)

  # the linked CSV must say the same thing as the table ----
  t_csv <- readr::read_csv(f_csv, show_col_types = FALSE)
  stopifnot(
    "CalCOFIStationOrder.csv disagrees with the page's table" =
      nrow(t_csv) == nrow(t_all) &&
      isTRUE(all.equal(as.numeric(t_csv$Line), t_all$line)) &&
      isTRUE(all.equal(as.numeric(t_csv$Sta),  t_all$station)) &&
      max(abs(as.numeric(t_csv$`Lat (dec)`) - t_all$latitude))  < 1e-6 &&
      max(abs(as.numeric(t_csv$`Lon (dec)`) - t_all$longitude)) < 1e-6)

  # the 113-station KML names the same stations ----
  kml   <- sf::st_read(f_kml, quiet = TRUE)
  k_key <- sub("\\s+SCCOOS$", "", trimws(kml$Name))
  t_key <- sprintf("%.1f %.1f", t_all$line, t_all$station)
  stopifnot(
    "CalCOFI_113StationMap.kml names different stations" =
      setequal(k_key, t_key))

  # table 2: SCCOOS (all must already be SCCOOS rows of table 1) ----
  t_sccoos <- tbls[[2]] |>
    dplyr::transmute(line = as.numeric(.data$Line), station = as.numeric(.data$Station))
  sccoos_key <- sprintf("%.1f %.1f", t_sccoos$line, t_sccoos$station)
  stopifnot(
    "an SCCOOS station is missing from the 113 table or typed otherwise" =
      setequal(sccoos_key, t_key[t_all$sta_type == "SCCOOS"]))

  # table 3: Navy stations, keep the operations area ----
  t_navy <- tbls[[3]] |>
    dplyr::transmute(
      line     = as.numeric(.data$Line),
      station  = as.numeric(.data$Station),
      navy_lat = sp_signed_deg(.data$Latitude),
      navy_lon = sp_signed_deg(.data$Longitude),
      navy_ops_area = .data$`Operations Area - Comments`)

  # patterns, from the page's prose: 75 = lines 76.7-93.3 (66 ROS + 9 SCCOOS);
  # 113 = all. The page does not say which 9 stations of line 66.7 the 104
  # pattern drops, so no in_104 column is guessed ----
  d <- t_all |>
    dplyr::left_join(t_navy, by = c("line", "station")) |>
    dplyr::mutate(
      station_key = sprintf("%05.1f %05.1f", .data$line, .data$station),
      in_75       = .data$line >= 76.7,
      in_113      = TRUE,
      source      = SP_URL) |>
    dplyr::relocate("station_key")

  if (verbose) {
    cat(sprintf(
      "station positions (%s): %d stations (%d ROS, %d SCCOOS) on %d lines; %d in the 75-station pattern; %d Navy rows\n",
      format(file.mtime(f_html), "%Y-%m-%d"), nrow(d), sum(d$sta_type == "ROS"),
      sum(d$sta_type == "SCCOOS"), dplyr::n_distinct(d$line), sum(d$in_75), sum(!is.na(d$navy_ops_area))))
    heads <- unique(heads[nzchar(heads) & !grepl("Guest|California Cooperative", heads)])
    cat("page sections:", paste(heads, collapse = " | "), "\n")
  }

  f_out <- file.path(dir_out, "station_positions.csv")
  readr::write_csv(d, f_out, na = "")
  attr(d, "fetched") <- file.mtime(f_html)
  attr(d, "navy")    <- t_navy
  d
}
