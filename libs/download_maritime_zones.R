# libs/download_maritime_zones.R
# -----------------------------------------------------------------------------
# Reproducible acquisition of the US maritime zones off the Pacific coast as
# POLYGONS, from the Marine Regions Maritime Boundaries Geodatabase (Flanders
# Marine Institute, VLIZ; CC BY 4.0; https://www.marineregions.org):
#
#   eez      200 NM exclusive economic zone (`MarineRegions:eez`, v12)
#   ts       12 NM territorial sea        (`MarineRegions:eez_12nm`, v4)
#   cz       24 NM contiguous zone, the band from 12 to 24 NM (`MarineRegions:eez_24nm`, v4)
#
# Why: the NOAA Office of Coast Survey limits in `NOAA_maritime-boundaries` are
# LINES, and `sample_spatial` membership (the Explorer's Area filter and Regions
# lens) needs a polygon, so the registry's `noaa_maritime_eez` / `_ts` / `_cz`
# matched no sample (workflows#169). One GeoJSON holds the three zones, each
# feature flagged `eez` / `ts` / `cz` = 1 and named by `region`, so the registry's
# existing filter expressions (`["==", ["get", "eez"], 1]`) and name field select
# them unchanged.
#
# The US EEZ in Marine Regions (`mrgid_eez = 8456`) is the contiguous US, both
# coasts; the Pacific coast is the polygon parts lying west of 110°W.
#
# Sourced + invoked from ingest_spatial.qmd (guarded so it only queries the WFS
# when the GeoJSON is missing or `overwrite = TRUE`).

MR_WFS <- "https://geo.vliz.be/geoserver/MarineRegions/wfs"

MR_ZONES <- tibble::tribble(
  ~zone, ~type_name,  ~layer,                 ~mr_version,
  "ts",  "eez_12nm",  "12NM Territorial Sea", "4",
  "cz",  "eez_24nm",  "24NM Contiguous Zone", "4",
  "eez", "eez",       "200NM EEZ",            "12")

#' Download the US Pacific-coast maritime zones as polygons
#'
#' @param out_geojson path of the GeoJSON to write
#' @param overwrite   if FALSE (default) and `out_geojson` exists, return it untouched
#' @param mrgid_eez   Marine Regions id of the EEZ (8456 = United States, contiguous)
#' @param xmax_west   a polygon part belongs to the Pacific coast when its bounding box
#'   lies entirely west of this longitude
#' @return `out_geojson`, invisibly
download_maritime_zones <- function(
    out_geojson,
    overwrite = FALSE,
    mrgid_eez = 8456,
    xmax_west = -110) {

  if (!overwrite && file.exists(out_geojson)) {
    cat("maritime zones: using cached", basename(out_geojson), "\n")
    return(invisible(out_geojson))
  }

  zones <- lapply(seq_len(nrow(MR_ZONES)), function(i) {
    z   <- MR_ZONES[i, ]
    url <- paste0(
      MR_WFS, "?service=WFS&version=1.0.0&request=GetFeature",
      "&typeName=MarineRegions:", z$type_name,
      "&outputFormat=application/json&CQL_FILTER=mrgid_eez=", mrgid_eez)
    tmp <- tempfile(fileext = ".json")
    on.exit(unlink(tmp), add = TRUE)
    utils::download.file(url, tmp, quiet = TRUE, mode = "wb")
    x <- sf::st_read(tmp, quiet = TRUE)
    stopifnot(
      "Marine Regions returned no feature" = nrow(x) >= 1,
      "Marine Regions returned another EEZ" = all(x$mrgid_eez == mrgid_eez))

    parts <- sf::st_cast(sf::st_geometry(x), "POLYGON")
    west  <- vapply(parts, function(g) sf::st_bbox(g)[["xmax"]] < xmax_west, logical(1))
    stopifnot("no polygon part on the Pacific coast" = any(west))

    sf::st_sf(
      zone       = z$zone,
      layer      = z$layer,
      region     = "Pacific Coast",   # the registry's name_field, as in the NOAA lines' REGION
      ts         = as.integer(z$zone == "ts"),
      cz         = as.integer(z$zone == "cz"),
      eez        = as.integer(z$zone == "eez"),
      mrgid      = as.integer(x$mrgid[1]),
      geoname    = x$geoname[1],
      mr_layer   = paste0("MarineRegions:", z$type_name),
      mr_version = z$mr_version,
      geometry   = sf::st_combine(parts[west]))
  })
  zones <- do.call(rbind, zones)

  # the Pacific EEZ of the contiguous US: Mexico border (~30.5°N) to Canada (~49°N)
  bb <- sf::st_bbox(zones)
  stopifnot(
    "zones fall outside the US Pacific coast" =
      bb[["xmin"]] > -135 && bb[["xmax"]] < -115 && bb[["ymin"]] > 29 && bb[["ymax"]] < 50)

  dir.create(dirname(out_geojson), recursive = TRUE, showWarnings = FALSE)
  sf::st_write(zones, out_geojson, delete_dsn = TRUE, quiet = TRUE)
  cat("maritime zones: wrote", basename(out_geojson), "(",
      paste(zones$zone, collapse = ", "), ")\n")
  invisible(out_geojson)
}
