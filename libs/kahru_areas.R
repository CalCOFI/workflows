# Mati Kahru's satellite areas as polygons (ingest_spatial.qmd, "Kahru satellite areas")
#
# Kahru et al. 2012 (Deep-Sea Research II, "Trends in the surface chlorophyll of the California
# Current: merging data from multiple ocean color satellites") average satellite chlorophyll over six
# areas of the CalCOFI grid: north of line 80 the coastal band 0-100 km from shore is area 3, 100-300 km
# area 2, offshore area 1; south of it 6 (coastal), 5 (transition), 4 (offshore). Kahru sent the nominal
# stations of each area (forwarded by Rasmus Swalethorp, 2026-10-27, "Fwd: Nino and CCE meeting");
# they are metadata/spatial/kahru_areas_stations.csv. Rasmus asked for areas 2-6 (area 1 holds too few
# stations to average).
#
# An area's polygon is the union of the calcofi4r::cc_grid cells of its stations (the official
# station cells, matched on line + station). Version 1 keeps whole cells: the line-80 cells belong to
# the one area Kahru listed them in, and the cells straddling the 100 km and 300 km borders are whole
# too. Rasmus would like those border cells counted at half weight in an average; that needs half-cells
# (or a weight per cell), which is not built.

KAHRU_AREA_LABELS <- c(
  `1` = "offshore, north of line 80",
  `2` = "transition, north of line 80",
  `3` = "coastal, north of line 80",
  `4` = "offshore, south of line 80",
  `5` = "transition, south of line 80",
  `6` = "coastal, south of line 80")

#' Kahru's satellite areas as one polygon per area
#'
#' @param stations_csv metadata/spatial/kahru_areas_stations.csv (area, line, station, ...)
#' @param grid the CalCOFI grid (calcofi4r::cc_grid): sta_lin, sta_pos, sta_source, grid_key, geom
#' @param areas the areas to build (Rasmus, 2026-10-27: 2-6)
#' @return an sf, one row per area: area, name, zone, side, n_stations, grid_keys, geometry
#'   (EPSG:4326); attribute `unmatched` holds the listed stations that match no station cell
build_kahru_areas <- function(stations_csv, grid, areas = 2:6) {
  d_sta <- readr::read_csv(stations_csv, show_col_types = FALSE, col_types = "iddddc") |>
    dplyr::filter(area %in% areas)
  stopifnot(
    "a station is listed in two areas" = !anyDuplicated(d_sta[c("line", "station")]))

  # match on the numbers, not on a formatted key ("80" vs "80.0"); the station cells only, so a
  # kept historical cell never stands in for a station
  cells <- grid |>
    dplyr::filter(sta_source == "official") |>
    dplyr::mutate(.lin = round(sta_lin, 1), .pos = round(sta_pos, 1)) |>
    dplyr::select(grid_key, .lin, .pos)
  sf::st_geometry(cells) <- "geometry"
  stopifnot("the grid's station cells repeat a line + station" =
    !anyDuplicated(sf::st_drop_geometry(cells)[c(".lin", ".pos")]))

  d_sta <- d_sta |>
    dplyr::mutate(.lin = round(line, 1), .pos = round(station, 1)) |>
    dplyr::left_join(sf::st_drop_geometry(cells), by = c(".lin", ".pos"))
  unmatched <- d_sta |> dplyr::filter(is.na(grid_key)) |> dplyr::select(area, line, station)

  s2_was <- sf::sf_use_s2(FALSE) # the cells' edges are straight in lon/lat; union them planar
  on.exit(sf::sf_use_s2(s2_was), add = TRUE)
  out <- d_sta |>
    dplyr::filter(!is.na(grid_key)) |>
    dplyr::inner_join(cells |> dplyr::select(grid_key), by = "grid_key") |>
    sf::st_as_sf() |>
    dplyr::group_by(area) |>
    dplyr::summarise(
      n_stations = dplyr::n(),
      grid_keys  = paste(sort(grid_key), collapse = "|"),
      geometry   = sf::st_union(geometry),
      .groups    = "drop") |>
    sf::st_make_valid() |>
    dplyr::mutate(
      area       = as.integer(area),
      n_stations = as.integer(n_stations),
      zone       = sub(",.*$", "", KAHRU_AREA_LABELS[as.character(area)]),
      side       = ifelse(area <= 3, "north of line 80", "south of line 80"),
      name       = glue::glue("Kahru area {area} ({KAHRU_AREA_LABELS[as.character(area)]})") |> as.character()) |>
    dplyr::arrange(area) |>
    dplyr::select(area, name, zone, side, n_stations, grid_keys, geometry)
  sf::st_crs(out) <- 4326
  attr(out, "unmatched") <- unmatched
  out
}
