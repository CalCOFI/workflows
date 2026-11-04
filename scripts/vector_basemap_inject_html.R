#!/usr/bin/env Rscript
# Draw CARTO basemaps from vector tiles in already-rendered notebooks.
#
# CARTO's raster basemaps (leaflet's `CartoDB.*` providers, the first two of
# mapview's default basemaps) answer every tile with an "API KEY REQUIRED"
# watermark since Sep 2026; its vector GL styles do not. A notebook rendered
# with calcofi4r::cc_vector_basemap_page() (calcofi4r >= 1.27.0) carries the fix
# natively. The others are ingest runs or 2022-era explorations nobody can
# re-render for a basemap, so the Pages workflow runs this instead: for each
# _output/*.html whose maps ask for a CARTO raster and that lacks the
# cc-vector-basemap.js shim, insert the scripts that swap each CARTO raster
# layer for its vector style, just before </head> (after Leaflet, which every
# such page loads in its head). Idempotent and marker-guarded, like
# brand_inject_html.R.
#
# The scripts load from _output/libs/cc-vector-basemap/, copied from the
# installed calcofi4r by `--update-libs` and committed, so the Pages runner
# needs no calcofi4r.
#
#   Rscript scripts/vector_basemap_inject_html.R               # inject in place
#   Rscript scripts/vector_basemap_inject_html.R --dry-run     # list what would change
#   Rscript scripts/vector_basemap_inject_html.R --update-libs # refresh the shared libs

args        <- commandArgs(trailingOnly = TRUE)
dry_run     <- "--dry-run" %in% args
update_libs <- "--update-libs" %in% args
wd          <- getwd()
if (!dir.exists(file.path(wd, "_output")))
  stop("run from the workflows/ repo root (no ./_output found)")

dir_lib <- file.path(wd, "_output/libs/cc-vector-basemap")
# relative to a page at the root of _output/
href    <- "libs/cc-vector-basemap"
LIBS    <- c(
  css    = "maplibre-gl.css",
  gl     = "maplibre-gl.js",
  bridge = "leaflet-maplibre-gl.js",
  shim   = "cc-vector-basemap.js")

if (update_libs) {
  stopifnot(requireNamespace("calcofi4r", quietly = TRUE),
            utils::packageVersion("calcofi4r") >= "1.27.0")
  deps <- calcofi4r::cc_vector_basemap_deps()
  deps <- deps[vapply(deps, `[[`, "", "name") %in%
                 c("maplibre-gl", "maplibre-gl-leaflet", "cc-vector-basemap")]
  dir.create(dir_lib, showWarnings = FALSE, recursive = TRUE)
  for (d in deps) {
    src <- system.file(d$src$file, package = d$package)
    for (f in c(d$script, d$stylesheet))
      stopifnot(file.copy(file.path(src, f), file.path(dir_lib, f), overwrite = TRUE))
  }
  writeLines(
    vapply(deps, \(d) paste(d$name, d$version), ""),
    file.path(dir_lib, "VERSIONS"))
  cat("updated", dir_lib, "from calcofi4r", as.character(utils::packageVersion("calcofi4r")), "\n")
}
stopifnot(all(file.exists(file.path(dir_lib, LIBS))))

marker <- "cc-vector-basemap.js"
snip   <- paste0(
  "<!-- cc-vector-basemap: CARTO basemaps as vector tiles (scripts/vector_basemap_inject_html.R) -->\n",
  '<link href="', href, "/", LIBS[["css"]], '" rel="stylesheet" />\n',
  '<script src="', href, "/", LIBS[["gl"]], '"></script>\n',
  '<script src="', href, "/", LIBS[["bridge"]], '"></script>\n',
  '<script src="', href, "/", LIBS[["shim"]], '"></script>\n')

# a map asking for a CARTO raster: a CartoDB.* provider in a widget's calls
# (mapview's default basemaps, addProviderTiles) or a raster tile url
rx_carto <- paste0(
  '"CartoDB(\\.[A-Za-z]+)?"|',
  'basemaps\\.cartocdn\\.com/(light_|dark_|rastertiles/)')

htmls  <- list.files(file.path(wd, "_output"), pattern = "[.]html$", full.names = TRUE)
n_done <- 0L
for (f in htmls) {
  x <- readChar(f, file.info(f)$size, useBytes = TRUE)
  Encoding(x) <- "UTF-8"
  if (grepl(marker, x, fixed = TRUE))   next
  if (!grepl(rx_carto, x, perl = TRUE)) next
  if (!grepl("</head>\\s*<body", x, perl = TRUE)) {
    cat("skip (no </head><body>):", basename(f), "\n"); next
  }
  x <- sub("</head>(\\s*<body)", paste0(snip, "</head>\\1"), x, perl = TRUE)
  n_done <- n_done + 1L
  if (dry_run) { cat("would inject:", basename(f), "\n"); next }
  writeLines(x, f, useBytes = TRUE, sep = "")
  cat("injected:", basename(f), "\n")
}
cat(sprintf("%s %d of %d pages\n", if (dry_run) "would inject" else "injected", n_done, length(htmls)))
