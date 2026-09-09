# the map's REFERENCE layers (plan 2026-09-09, D47–D54): the OpenStreetMap land mask and the GEBCO
# gazetteer's undersea feature names, built as PMTiles beside the boundary archives on
# gs://calcofi-files-public/_spatial/ and registered in metadata/spatial_layers.csv with
# `role = reference`. Sourced by ingest_spatial.qmd (its "Reference layers" section). Every bulk
# input and output stages under cc_stage_path("reference"): nothing under Drive, nothing in git.
#
# sources (both open; the manifest records each one's version beside the archive it produced):
#   - OSM land polygons  https://osmdata.openstreetmap.de/data/land-polygons.html  (ODbL)
#     `land-polygons-split-4326.zip` (~926 MB): the coastline CARTO's water polygons derive from, so the
#     mask's coast IS the basemap's coast (D48). Read through /vsizip with a bbox filter: 45,249
#     polygons, 3.8 M vertices, 10 s (2026-09-09). The bathymetry build caches the same zip under
#     ~/_big/calcofi/bathymetry/src/; it is reused when present.
#   - GEBCO Gazetteer of Undersea Feature Names, the IHO DCDB feature service (points, lines, polygons;
#     fields NAME, TYPE, FEATURE_ID), https://www.gebco.net/data-products/undersea-feature-names.
#     Cite: "IHO-IOC GEBCO Gazetteer of Undersea Feature Names, www.gebco.net".

REF_BBOX     <- c(xmin = -140, ymin = 15, xmax = -105, ymax = 56) # = CORE_BBOX in scripts/build_bathymetry_tiles.py: the mask covers exactly where the sea floor draws at z6+
OSM_LAND_URL <- "https://osmdata.openstreetmap.de/download/land-polygons-split-4326.zip"
OSM_LAND_ZIP <- "land-polygons-split-4326.zip"
GAZ_SERVICE  <- "https://services2.arcgis.com/C8EMgrsFcRFL6LrL/arcgis/rest/services/Undersea_Features/FeatureServer"
GAZ_LAYERS   <- c(points = 0L, lines = 1L, polygons = 2L)
GAZ_CITATION <- "IHO-IOC GEBCO Gazetteer of Undersea Feature Names, www.gebco.net"
OSM_CITATION <- "© OpenStreetMap contributors (ODbL), land polygons by osmdata.openstreetmap.de"

# label ranks (D50): which generic terms read at which zoom — rank 1 from z4, 2 from z6, 3 from z8.
# a term in neither list is rank 2 (Basin, Bank, Canyon, Seamount, Guyot, Tablemount, Trough, Seachannel …)
GAZ_RANK1    <- c("Escarpment", "Fracture Zone", "Ridge", "Ridges", "Rise", "Trench", "Seamount Chain",
                  "Seamount Province", "Fan", "Plateau", "Abyssal Plain", "Shelf", "Slope")
GAZ_RANK3    <- c("Knoll", "Knolls", "Hill", "Hills", "Valley", "Terrace", "Channel", "Seamounts", "Reef",
                  "Reefs", "Shoal", "Shoals", "Spur", "Spurs", "Sill", "Saddle", "Gap", "Hole", "Pinnacle")
GAZ_MIN_ZOOM <- c(`1` = 4, `2` = 6, `3` = 8)

# tippecanoe: the boundary archives' recipe (ingest_spatial.qmd), plus every feature kept at every zoom
# for the label points (-r1: no point dropping) — the style gates them by `min_zoom`, not the tiler
TIPPECANOE_BASE <- c("-z10", "-Z0", "--simplification=10", "--simplify-only-low-zooms",
                     "--no-tiny-polygon-reduction", "--no-tile-size-limit", "--no-feature-limit", "--force")

ref_bbox_sfc <- function(bbox = REF_BBOX) sf::st_as_sfc(sf::st_bbox(bbox, crs = 4326))

# ── acquire ──────────────────────────────────────────────────────────────────

#' the OSM land-polygons zip: reuse the bathymetry build's copy, else download once (~926 MB)
download_osm_land <- function(dir, force = FALSE) {
  zip <- file.path(dir, OSM_LAND_ZIP)
  bathy_copy <- calcofi4db::cc_stage_path("bathymetry", "src", OSM_LAND_ZIP)
  if (!file.exists(zip) && file.exists(bathy_copy)) {
    cat("osm land: reusing the bathymetry build's zip\n")
    file.symlink(bathy_copy, zip)
  }
  if (force || !file.exists(zip)) {
    cat("osm land: downloading", OSM_LAND_URL, "\n")
    utils::download.file(OSM_LAND_URL, zip, mode = "wb", quiet = TRUE)
  }
  zip
}

#' the extract date of the zip's shapefile — the source version the manifest records
osm_land_version <- function(zip) {
  z <- utils::unzip(zip, list = TRUE)
  as.character(as.Date(z$Date[grepl("land_polygons\\.shp$", z$Name)][1]))
}

#' the land polygons inside the box, cropped to it: `id`, `layer`, `name` like every boundary archive
read_osm_land <- function(zip, bbox = REF_BBOX) {
  src <- sprintf("/vsizip/%s/land-polygons-split-4326/land_polygons.shp", normalizePath(zip))
  x <- sf::st_read(src, wkt_filter = sf::st_as_text(ref_bbox_sfc(bbox)), quiet = TRUE)
  x <- suppressWarnings(sf::st_crop(sf::st_make_valid(x), sf::st_bbox(bbox, crs = 4326)))
  x <- x[!sf::st_is_empty(x), ]
  sf::st_sf(id = seq_len(nrow(x)), layer = "Land", name = "land", geometry = sf::st_geometry(x))
}

#' the gazetteer's three layers inside the box, as GeoJSON files (paged at the service's 2,000-record cap)
download_gazetteer <- function(dir, bbox = REF_BBOX, force = FALSE) {
  files <- file.path(dir, sprintf("gebco_gazetteer_%s.geojson", names(GAZ_LAYERS)))
  names(files) <- names(GAZ_LAYERS)
  for (k in names(GAZ_LAYERS)) {
    if (!force && file.exists(files[[k]])) next
    feats <- list(); offset <- 0L; page <- 2000L
    repeat {
      u <- sprintf(paste0("%s/%d/query?where=1%%3D1&geometry=%s&geometryType=esriGeometryEnvelope&inSR=4326",
                          "&spatialRel=esriSpatialRelIntersects&outFields=NAME,TYPE,FEATURE_ID&outSR=4326",
                          "&f=geojson&resultOffset=%d&resultRecordCount=%d"),
                   GAZ_SERVICE, GAZ_LAYERS[[k]], paste(bbox[c("xmin", "ymin", "xmax", "ymax")], collapse = ","), offset, page)
      j <- jsonlite::fromJSON(u, simplifyVector = FALSE)
      if (!is.null(j$error)) stop("gazetteer ", k, ": ", j$error$message)
      feats <- c(feats, j$features)
      if (length(j$features) < page) break
      offset <- offset + page
    }
    jsonlite::write_json(list(type = "FeatureCollection", features = feats), files[[k]],
                         auto_unbox = TRUE, digits = NA, null = "null")
    cat(sprintf("gazetteer %s: %d features\n", k, length(feats)))
  }
  files
}

# ── build ────────────────────────────────────────────────────────────────────

gaz_rank <- function(type) ifelse(type %in% GAZ_RANK1, 1L, ifelse(type %in% GAZ_RANK3, 3L, 2L))

#' one labelled feature per gazetteer record: points and polygon centroids as POINT, lines as lines;
#' `label` = name + generic term, `rank` and `min_zoom` per D50, `kind` says which layer it came from
build_gazetteer_labels <- function(files, bbox = REF_BBOX) {
  one <- function(k) {
    x <- sf::st_read(files[[k]], quiet = TRUE)
    if (nrow(x) == 0) return(NULL)
    g <- sf::st_geometry(x)
    g <- switch(k,
      points   = suppressWarnings(sf::st_centroid(g)),          # a MultiPoint record → its centre
      polygons = suppressWarnings(sf::st_point_on_surface(g)),  # a polygon record → a point inside it
      lines    = g)
    sf::st_sf(
      feature_id = as.integer(x$FEATURE_ID), name = x$NAME, type = x$TYPE,
      label = trimws(paste(x$NAME, x$TYPE)), kind = k,
      rank = gaz_rank(x$TYPE), geometry = g)
  }
  out <- do.call(rbind, Filter(Negate(is.null), lapply(names(files), one)))
  out$min_zoom <- unname(GAZ_MIN_ZOOM[as.character(out$rank)])
  sf::st_crs(out) <- 4326
  out <- out[lengths(sf::st_intersects(out, ref_bbox_sfc(bbox))) > 0, ]
  out[order(out$rank, out$label), ]
}

#' GeoJSON → tippecanoe → PMTiles; returns what the manifest records
write_pmtiles <- function(x, path, layer, keep_all_points = FALSE) {
  geojson <- tempfile(fileext = ".geojson"); on.exit(unlink(geojson), add = TRUE)
  sf::st_write(x, geojson, delete_dsn = TRUE, quiet = TRUE)
  args <- c("-o", path, TIPPECANOE_BASE, if (keep_all_points) "-r1", "-l", layer, geojson)
  log <- system2("tippecanoe", args, stdout = TRUE, stderr = TRUE)
  if (!file.exists(path)) stop("tippecanoe failed for ", layer, ":\n", paste(tail(log, 20), collapse = "\n"))
  bb <- sf::st_bbox(x)
  list(pmtiles = basename(path), source_layer = layer, n_features = nrow(x),
       bbox = unname(round(c(bb$xmin, bb$ymin, bb$xmax, bb$ymax), 4)),
       bytes = file.size(path), sha256 = strsplit(system2("shasum", c("-a", "256", shQuote(path)), stdout = TRUE), " ")[[1]][1])
}

#' both reference archives into `dir_pmtiles`; the manifest list `data/parquet/spatial/reference_layers.json` holds
build_reference_layers <- function(dir_reference, dir_pmtiles, bbox = REF_BBOX, overwrite = FALSE) {
  dir.create(dir_reference, showWarnings = FALSE, recursive = TRUE)
  layers <- list()
  # the land mask (D47/D48)
  p_land <- file.path(dir_pmtiles, "osm_land.pmtiles")
  zip <- download_osm_land(dir_reference)
  if (overwrite || !file.exists(p_land)) {
    land <- read_osm_land(zip, bbox)
    cat(sprintf("osm land: %d polygons in the box, %s vertices\n", nrow(land),
                format(sum(vapply(sf::st_geometry(land), function(g) nrow(sf::st_coordinates(g)), 1)), big.mark = ",")))
    layers$osm_land <- c(write_pmtiles(land, p_land, "osm_land"),
                         list(source = list(url = OSM_LAND_URL, version = osm_land_version(zip), citation = OSM_CITATION)))
  } else cat("osm land: skipped (exists)\n")
  # the undersea feature names (D50)
  p_gaz <- file.path(dir_pmtiles, "gebco_gazetteer.pmtiles")
  files <- download_gazetteer(dir_reference, bbox)
  if (overwrite || !file.exists(p_gaz)) {
    gaz <- build_gazetteer_labels(files, bbox)
    cat(sprintf("gazetteer: %d labels (rank 1/2/3 = %s)\n", nrow(gaz), paste(tabulate(gaz$rank, 3), collapse = "/")))
    layers$gebco_gazetteer <- c(write_pmtiles(gaz, p_gaz, "gebco_gazetteer", keep_all_points = TRUE),
                                list(ranks = list(`1` = GAZ_RANK1, `3` = GAZ_RANK3, min_zoom = as.list(GAZ_MIN_ZOOM)),
                                     n_by_kind = as.list(table(gaz$kind)),
                                     source = list(url = GAZ_SERVICE, version = format(Sys.Date()), citation = GAZ_CITATION)))
  } else cat("gazetteer: skipped (exists)\n")
  list(built = format(Sys.Date()), bbox = unname(bbox[c("xmin", "ymin", "xmax", "ymax")]),
       tippecanoe = trimws(sub("^tippecanoe ", "", system2("tippecanoe", "-v", stdout = TRUE, stderr = TRUE)[1])),
       layers = layers)
}

#' merge a build into the manifest on disk (a skipped layer keeps its previous record) and write it
write_reference_manifest <- function(m, path) {
  if (file.exists(path)) {
    prev <- jsonlite::fromJSON(path, simplifyVector = FALSE)
    for (k in setdiff(names(prev$layers), names(m$layers))) m$layers[[k]] <- prev$layers[[k]]
  }
  jsonlite::write_json(m, path, auto_unbox = TRUE, digits = NA, null = "null", pretty = TRUE)
  invisible(path)
}
