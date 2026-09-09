# Build the 2026-09-08 CalCOFI data-meeting deck (16:9, brand v2) with officer + flextable.
#
# Plan: .claude/plans/2026-09-07 Bringing the team along ….md § B (the slide table) and the facts
# table in § Context. Every number on a slide is either read from the file its speaker note names
# (release record, uptime API, package versions, registries) or copied from that facts table with
# its source; anything not covered is a [placeholder in square brackets] for Ben to fill.
#
# Run from the workflows/ root:  Rscript presentations/build_update_2026-09-08.R
# Assets (presentations/assets/): template_16x9.pptx (officer's default widened to 13.333 x 7.5 in),
# logo PNGs rendered from ../CalCOFI.github.io/brand/v2/*.svg, the landing / contour / sources /
# zenodo / releases shots, the site's images/*_light.png card shots, ../uptime graphs, ../docs figures.
suppressMessages({
  library(officer); library(flextable); library(dplyr); library(jsonlite); library(png)
})
stopifnot("run from the workflows/ root" = dir.exists("presentations/assets"))

# brand v2 (calcofi.io/brand/v2/theme.css, light) ----
NAVY   <- "#182b49"; BLUE  <- "#00629b"; YELLOW <- "#ffcd00"; SAND <- "#f5f0e6"
GOLD   <- "#c69214"; GRAY  <- "#66686a"; STONE  <- "#b6b1a9"; WHITE <- "#ffffff"
WATER  <- "#e6eef4"; RULE  <- "#dddddd"; PANEL  <- "#f5f5f5"
SANS   <- "Source Sans 3"; DISPLAY <- "Teko"; MONO <- "Source Code Pro"

# slide geometry (in) ----
W <- 13.333; H <- 7.5; M <- 0.6
TOP_BODY <- 1.85; BOT_BODY <- 6.45; IMG_H <- BOT_BODY - TOP_BODY   # a two-line headline ends ~1.75; a caption under an image ends before the footer rule at 6.93

# assets ----
# Everything under presentations/assets/ is either committed alongside this script or derived here
# (see § derived crops). The raw shots were taken with:
#   brand/brand_v2_{light,dark}.png   shot-scraper "https://calcofi.io/brand/v2/?theme={t}" -w 1440 -h 900 --retina
#   brand/icons_{light,dark}.png      shot-scraper "https://calcofi.io/brand/v2/icons/" -w 1440 --retina
#   brand/brand_{lockup,buttons,chips}_light.png
#                                     shot-scraper "https://calcofi.io/brand/v2/?theme=light" -w 1400 --retina
#                                       --selector '#chrome .cc-container > div:nth-of-type(1|2|4)' --padding 52
#   landing_bento_2026-09-08_{light,dark}.png, landing_apps_2026-09-08.png
#                                     shot-scraper "https://calcofi.io/?theme={t}&tour=off" -w 1440 --retina
#   docs/docs_index_{light,dark}.png, docs_doors_light.png, docs_sidebar_light.png
#                                     python3 -m http.server in ../docs/_book, then
#                                     shot-scraper "http://localhost:PORT/index.html?theme={t}" -w 1600 -h 1100 --retina
#                                       [--selector '#tbl-doors' | '#quarto-sidebar']
#   docs/docs_system.png, docs_core_erd.png
#                                     rsvg-convert -w 2400 -b white ../docs/diagrams/{system,core_erd}.svg
#   ../explore/shots/tour/*.png       node scripts/tour_shots.mjs (see that folder's README.md)
#   explore/{sources_modal,share_cite,feedback_annotate,header_explore}_light.png
#                                     cd ../explore && npm run build && npx vite preview --port 4173
#                                     node scripts/deck_shots.mjs http://localhost:4173/ \
#                                       ../workflows/presentations/assets/explore
#   cite/ds_cite_swfsc_ichthyo.png    python3 -m http.server 4174 in ../CalCOFI.github.io/_site, then
#                                     shot-scraper "http://localhost:4174/datasets/swfsc_ichthyo/?theme=light"
#                                       -w 1100 --retina --selector '#cite' --padding 20
#                                       --javascript "document.querySelectorAll('header,nav').forEach(e=>e.style.display='none')"
#   cite/docs_cite_table.png          python3 -m http.server 4175 in ../docs/_book, then
#                                     shot-scraper "http://localhost:4175/cite.html?theme=light" -w 1500 --retina
#                                       --selector '#tbl-dataset-citations' --padding 16
#   headers/hdr_calcofi_io.png        shot-scraper "http://localhost:4174/?theme=light" -w 1440 --retina
#                                       --selector 'header.cc-header'   (byte-identical on /datasets/)
#   headers/hdr_docs.png              shot-scraper "http://localhost:4175/cite.html?theme=light" -w 1500 --retina
#                                       --selector '.sidebar-tools-main' --padding 10
# EVERY shot in this deck is the LIGHT theme — the one exception is the brand slide's light/dark
# specimen pair, which is about the two themes.
A <- function(f) file.path("presentations/assets", f)
S <- function(f) file.path("../CalCOFI.github.io/images", f)
U <- function(f) file.path("../uptime/graphs", f)
X <- function(f) file.path("../explore/shots/tour", f)
assets <- c(
  template  = A("template_16x9.pptx"),
  logo      = A("logo_calcofi_h.png"),
  logo_lt   = A("logo_calcofi_h_light.png"),
  hero      = A("landing_hero_2026-09-07.png"),
  bento     = A("landing_bento_2026-09-08_light.png"),
  apps      = A("landing_apps_2026-09-08.png"),
  br_light  = A("brand/brand_v2_light.png"),
  br_dark   = A("brand/brand_v2_dark.png"),
  br_lock   = A("brand/brand_lockup_light.png"),
  br_btn    = A("brand/brand_buttons_light.png"),
  br_chip   = A("brand/brand_chips_light.png"),
  br_icons  = A("brand/icons_light.png"),
  stations  = X("stations_light.png"),
  hexagons  = X("hexagons.png"),
  contour   = X("contours_temperature_grid_labels.png"),
  cruises   = X("cruises.png"),
  regions   = X("regions.png"),
  sections  = X("sections_env.png"),
  sect_bio  = X("sections_bio.png"),
  layers    = X("layers_panel.png"),
  panebar   = X("pane_controls.png"),
  helpmenu  = X("help_menu.png"),
  d_index   = A("docs/docs_index_light.png"),
  d_doors   = A("docs/docs_doors_light.png"),
  d_side    = A("docs/docs_sidebar_light.png"),
  d_system  = A("docs/docs_system.png"),
  d_erd     = A("docs/docs_core_erd.png"),
  sources   = A("explore/sources_modal_light.png"),
  sharecite = A("explore/share_cite_light.png"),
  feedback  = A("explore/feedback_annotate_light.png"),
  hdr_expl  = A("explore/header_explore_light.png"),
  hdr_site  = A("headers/hdr_calcofi_io.png"),
  hdr_docs  = A("headers/hdr_docs.png"),
  ds_cite   = A("cite/ds_cite_swfsc_ichthyo.png"),
  docs_cite = A("cite/docs_cite_table.png"),
  zenodo    = A("zenodo_v2026.09.06.png"),
  releases  = A("releases_html.png"),
  sw2022    = A("sw_arch_2022.png"),
  flow      = A("catalog_flow.png"),
  sheet     = A("sheet_calcofi_metadata.png"),
  datasets  = S("datasets_light.png"),
  ichthyo   = S("dataset-ichthyo_light.png"),
  up_expl   = U("explore/response-time-week.png"),
  up_hex    = U("db-viz-hex/response-time-week.png"))
missing <- assets[!file.exists(assets)]
if (length(missing)) stop("missing assets:\n  ", paste(missing, collapse = "\n  "))

# derived crops ----
# every crop is a fraction of the source, written once into presentations/assets/crop/ and reused; delete
# the folder to rebuild after a re-shoot. keeping them here (rather than in a shell step) means the deck
# rebuilds from the raw shots with one command.
dir.create(A("crop"), showWarnings = FALSE)
crop_png <- function(src, name, x = c(0, 1), y = c(0, 1)) {
  dst <- A(file.path("crop", name))
  if (!file.exists(dst) || file.mtime(dst) < file.mtime(src)) {
    im <- readPNG(src); h <- dim(im)[1]; w <- dim(im)[2]
    xi <- max(1, round(x[1] * w)):min(w, round(x[2] * w))
    yi <- max(1, round(y[1] * h)):min(h, round(y[2] * h))
    writePNG(im[yi, xi, , drop = FALSE], dst)
  }
  dst
}
# the brand icon sprite: one <symbol> per glyph, rasterised in the brand navy by rsvg-convert
ICON_SVG <- "../CalCOFI.github.io/brand/v2/icons/calcofi-icons.svg"
icon_png <- function(id, px = 128, col = NAVY) {
  dst <- A(sprintf("crop/icon_%s.png", id))
  if (!file.exists(dst)) {
    stopifnot("brand icon sprite not found" = file.exists(ICON_SVG))
    ln   <- grep(sprintf('id="%s"', id), readLines(ICON_SVG, warn = FALSE), value = TRUE, fixed = TRUE)[1]
    stopifnot("icon id not in the sprite" = !is.na(ln))
    body <- sub("</symbol>.*$", "", sub("^.*?<symbol[^>]*>", "", ln, perl = TRUE))
    tmp  <- tempfile(fileext = ".svg")
    writeLines(sprintf('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="%d" height="%d" fill="%s">%s</svg>',
                       px, px, col, body), tmp)
    system2("rsvg-convert", c("-w", px, "-h", px, "-o", shQuote(dst), shQuote(tmp)))
  }
  dst
}

# zenodo shot carries a cookie banner in its bottom 75 px; crop it once
zen_crop <- A("zenodo_v2026.09.06_crop.png")
if (!file.exists(zen_crop)) {
  z <- readPNG(assets["zenodo"]); writePNG(z[1:785, , ], zen_crop)
}
assets["zenodo"] <- zen_crop

# the pieces each new slide shows (fractions of the raw shot above)
CROP <- c(
  bento     = crop_png(assets["bento"],    "bento.png",        y = c(0.425, 0.978)),
  apps      = crop_png(assets["apps"],     "apps_strip.png",   x = c(0.09, 0.94), y = c(0.045, 0.300)),
  br_light  = crop_png(assets["br_light"], "brand_light.png",  x = c(0.03, 0.62), y = c(0.000, 0.665)),
  br_dark   = crop_png(assets["br_dark"],  "brand_dark.png",   x = c(0.03, 0.62), y = c(0.000, 0.665)),
  br_btn    = crop_png(assets["br_btn"],   "brand_buttons.png",                   y = c(0.000, 0.620)),
  br_chip   = crop_png(assets["br_chip"],  "brand_chips.png",                     y = c(0.000, 0.600)),
  br_icons  = crop_png(assets["br_icons"], "brand_icons.png",  x = c(0.016, 0.495), y = c(0.089, 0.297)),
  helpmenu  = crop_png(assets["helpmenu"], "help_menu.png",    x = c(0.600, 1.000)),
  panebar   = crop_png(assets["panebar"],  "pane_bar.png",     x = c(0.680, 1.000), y = c(0.000, 0.470)),
  d_index   = crop_png(assets["d_index"],  "docs_index.png",   x = c(0.000, 0.620), y = c(0.000, 0.620)),
  d_side    = crop_png(assets["d_side"],   "docs_sidebar.png",                    y = c(0.000, 0.640)),
  # the dataset page's Cite section (its left column: the dataset's citation, then the release's)
  ds_cite   = crop_png(assets["ds_cite"],   "ds_cite.png",     x = c(0.000, 0.315), y = c(0.050, 0.365)),
  # the docs cite chapter's Table 3.1, its first rows — the blank licence / DOI / contact cells are the point
  docs_cite = crop_png(assets["docs_cite"], "docs_cite.png",                        y = c(0.000, 0.274)),
  # each product's header, cropped to the right-hand end: the same speech bubble beside the theme toggle
  hdr_site  = crop_png(assets["hdr_site"],  "hdr_site.png",    x = c(0.525, 1.000)),
  hdr_expl  = crop_png(assets["hdr_expl"],  "hdr_expl.png",    x = c(0.680, 1.000)),
  hdr_docs  = crop_png(assets["hdr_docs"],  "hdr_docs.png",    x = c(0.075, 1.000)),
  # the attribution modal reads at slide size only as its top: the promise, then a citation per row
  sources   = crop_png(assets["sources"],   "sources.png",                          y = c(0.000, 0.560)),
  # the "Register a product" row of the Share tab's Cite this data menu
  register  = crop_png(assets["sharecite"], "register.png",    x = c(0.050, 0.680), y = c(0.845, 0.950)))
# one thumbnail per lens for the six-lens grid: the map band of each tour shot (the section lens
# shows its own panel, which sits lower in the frame)
LENS_TH <- c(
  stations = crop_png(assets["stations"], "th_stations.png", x = c(0.20, 1), y = c(0.045, 0.50)),
  hexagons = crop_png(assets["hexagons"], "th_hexagons.png", x = c(0.20, 1), y = c(0.045, 0.50)),
  contours = crop_png(assets["contour"],  "th_contours.png", x = c(0.20, 1), y = c(0.045, 0.50)),
  cruises  = crop_png(assets["cruises"],  "th_cruises.png",  x = c(0.20, 1), y = c(0.045, 0.50)),
  regions  = crop_png(assets["regions"],  "th_regions.png",  x = c(0.20, 1), y = c(0.045, 0.50)),
  sections = crop_png(assets["sections"], "th_sections.png", x = c(0.20, 1), y = c(0.395, 0.845)))

# facts, read live where a file holds them ----
rel_dir  <- "data/releases/v2026.09.06"
dsj      <- fromJSON(file.path(rel_dir, "datasets.json"), simplifyVector = FALSE)
cat_json <- fromJSON(file.path(rel_dir, "catalog.json"),  simplifyVector = FALSE)
REL <- list(
  version   = dsj$release$version,
  date      = dsj$release$release_date,
  n_ds      = dsj$counts$datasets,
  n_hold    = dsj$counts$holdings,
  n_ref     = dsj$counts$reference,
  n_tables  = dsj$release$n_tables,
  n_rows    = dsj$release$total_rows,
  gb        = dsj$release$total_size / 1e9,
  doi       = cat_json$doi,
  cdoi      = cat_json$concept_doi,
  citation  = cat_json$citation)
hold_status <- table(vapply(dsj$holdings, function(h) h$status$stage %||% "", ""))
rows_m   <- sprintf("%d M", round(REL$n_rows / 1e6))
rows_fmt <- format(REL$n_rows, big.mark = ",")
gb_fmt   <- sprintf("%.2f GB", REL$gb)
SRC_REL  <- sprintf("%s/datasets.json (`release`, `counts`) and catalog.json (`doi`, `concept_doi`, `citation`)", rel_dir)

# uptime: CalCOFI/uptime api/*.json (git -C ../uptime pull first); the README is regenerated hourly
up_ms <- function(slug, win = "") {
  j <- fromJSON(sprintf("../uptime/api/%s/response-time%s.json", slug, win))
  as.integer(gsub("[^0-9]", "", j$message))
}
UP <- list(
  expl_all = up_ms("explore"),     expl_7d = up_ms("explore", "-week"),
  hex_all  = up_ms("db-viz-hex"),  hex_7d  = up_ms("db-viz-hex", "-week"),
  n_sites  = length(yaml::read_yaml("../uptime/.upptimerc.yml")$sites),
  n_up     = length(grep("🟩 Up", readLines("../uptime/README.md", warn = FALSE), fixed = TRUE)),
  pulled   = trimws(system("git -C ../uptime log -1 --format=%cs", intern = TRUE)))
ms <- function(x) paste0(format(x, big.mark = ","), " ms")

# packages
PKG <- list(
  r   = sub("^Version: *", "", grep("^Version:", readLines("../calcofi4r/DESCRIPTION"),  value = TRUE)),
  py  = gsub('^version *= *"|"$', "", grep("^version *=", readLines("../calcofi4py/pyproject.toml"), value = TRUE)[1]),
  db  = sub("^Version: *", "", grep("^Version:", readLines("../calcofi4db/DESCRIPTION"), value = TRUE)))

# provider Sheets
qs      <- yaml::read_yaml("metadata/questions_sheets.yml")
N_SHEET <- length(setdiff(names(qs), "_folder"))

# ERDDAP datasets answered by allDatasets (live; the facts table said 45 on 2026-09-07)
ERD_N <- tryCatch({
  x <- readLines("https://erddap.calcofi.io/erddap/tabledap/allDatasets.csv?datasetID", warn = FALSE)
  ids <- x[-(1:2)]; sum(ids != "allDatasets")
}, error = function(e) NA_integer_)
ERD_N_TXT <- if (is.na(ERD_N)) "45" else as.character(ERD_N)
ERD_SRC   <- if (is.na(ERD_N)) "facts table (allDatasets, 2026-09-07); live read failed at build time" else sprintf("erddap.calcofi.io allDatasets.csv read at build time (%s), excluding the allDatasets row", Sys.Date())

# from the plan's facts table (measured 2026-09-07; not re-measured here)
FT <- list(
  dwca   = "10", edi = "3",                     # gcloud storage ls gs://calcofi-db/publish/{dwca,edi}
  lenses = "six",                               # explore/src/state.ts LENS_ICON
  c_sites = "12,046", c_cells = "60,165", c_secs = "1.2 s", c_rmse = "1.46 °C", c_km = "60 km",
  c_grid_s = "0.3 s", c_idw = "1.72", c_ok = "0.91", c_tps = "0.83", c_n_surf = "eight",
  landing = "77 years · 842 cruises · 49 ships · 218 stations · 2,614 taxa · 349 M rows",
  # read off the fit line in the contours tour shot (station grid, kriging, labels on), 2026-09-08
  g_stns = "213", g_cells = "56,591", g_res = "0.06°", g_rmse = "0.79 °C", g_ms = "382 ms",
  hex_km = "8.5 km")

# GCP cost, read from the two billing CSVs ----
# The Cloud Billing API is disabled on project ucsd-sio-calcofi and calcofi-admin has no billing role,
# so nothing here can query it (see the slide 11 notes for what to grant). Ben read the Cloud Console
# on 2026-08-11 instead; presentations/assets/billing/ holds those figures as CSV with the console
# screenshots beside them, and every number below is computed from them — none is typed on the slide.
bill <- read.csv(A("billing/gcp_billing_2026.csv"),               comment.char = "#", stringsAsFactors = FALSE)
bsvc <- read.csv(A("billing/gcp_billing_2026_ytd_by_service.csv"), comment.char = "#", stringsAsFactors = FALSE)
usd  <- function(x, d = 0) paste0("$", formatC(x, format = "f", digits = d, big.mark = ","))
full <- bill[!is.na(bill$compute_engine), ]   # the months with a per-service split (Feb–Jul)
BILL <- list(
  read_on  = "2026-08-11",
  months   = sprintf("%s–%s", format(as.Date(paste0(min(full$month), "-01")), "%b"),
                              format(as.Date(paste0(max(full$month), "-01")), "%b %Y")),
  all      = mean(full$total),           all_lo = min(full$total),           all_hi = max(full$total),
  cmp      = mean(full$compute_engine),  cmp_lo = min(full$compute_engine),  cmp_hi = max(full$compute_engine),
  sto      = mean(full$cloud_storage),   sto_lo = min(full$cloud_storage),   sto_hi = max(full$cloud_storage),
  peak     = format(as.Date(paste0(full$month[which.max(full$total)], "-01")), "%B"),
  ytd      = sum(bsvc$subtotal),
  ytd_cmp  = bsvc$subtotal[bsvc$service == "Compute Engine"],
  ytd_sto  = bsvc$subtotal[bsvc$service == "Cloud Storage"],
  saved    = -sum(bsvc$other_savings))
BILL$year <- BILL$all * 12
BILL_SRC  <- sprintf("presentations/assets/billing/gcp_billing_2026{,_ytd_by_service}.csv — the Cloud Console billing pages of project ucsd-sio-calcofi read on %s (gconsole_spend_by_service_%s.png and gconsole_ytd_%s.png beside them); the monthly figures here are the %s months with a per-service split",
                     BILL$read_on, BILL$read_on, BILL$read_on, nrow(full))

# attribution gaps, read from the promoted release's own dataset table ----
# ../docs/data/release/dataset.csv is the pre-render snapshot the docs book's cite chapter tabulates
# (Table 3.1). Counting the empty cells here means the ask to providers is measured, never typed.
ATTR_CSV <- "../docs/data/release/dataset.csv"
attr_ds  <- read.csv(ATTR_CSV, stringsAsFactors = FALSE, check.names = FALSE)
ATTR_FLD <- c("citation_main", "license", "doi", "pi_names", "contact", "acknowledgement", "license_url")
attr_miss <- function(f) {
  v <- attr_ds[[f]]
  attr_ds$dataset_key[is.na(v) | trimws(v) == ""]
}
GAP <- do.call(rbind, lapply(ATTR_FLD, function(f) {
  miss <- attr_miss(f)
  data.frame(
    Field    = f,
    Missing  = sprintf("%d of %d", length(miss), nrow(attr_ds)),
    `Which datasets` = if (!length(miss)) "—"
                       else if (length(miss) == nrow(attr_ds)) "every dataset"
                       else paste(sub("^[^_]+_", "", miss), collapse = ", "),
    check.names = FALSE)
}))
GAP_SRC <- sprintf("%s (the promoted release %s dataset table), counted at build time", ATTR_CSV, REL$version)

# the docs book, counted from ../docs at build time ----
dq   <- yaml::read_yaml("../docs/_quarto.yml")
DOCS <- local({
  ch    <- dq$book$chapters
  parts <- Filter(function(x) is.list(x) && !is.null(x$part), ch)
  n_ch  <- sum(vapply(ch, function(x) if (is.list(x)) length(x$chapters) else 1L, 1L))
  qmd   <- setdiff(list.files("../docs", pattern = "\\.qmd$", full.names = TRUE), "../docs/_gates.qmd")
  txt   <- unlist(lapply(qmd, readLines, warn = FALSE))
  list(n_parts   = length(parts),
       n_parts_w = c("one", "two", "three", "four", "five", "six", "seven")[length(parts)],
       parts     = vapply(parts, function(p) p$part, ""),
       n_ch      = n_ch - 1L,   # index.qmd is "Start here", unnumbered in the sidebar

       n_app     = length(dq$book$appendices),
       n_fig     = length(grep("\\{#fig-", txt)),
       n_tbl     = length(grep("\\{#tbl-", txt)))
})

# ── officer helpers ─────────────────────────────────────────────────────────────────────────────
doc <- read_pptx(assets["template"])
MST <- "Office Theme"
n_slide <- 0L

fp <- function(size = 15, color = NAVY, family = SANS, bold = FALSE, italic = FALSE)
  fp_text(font.family = family, font.size = size, color = color, bold = bold, italic = italic)
fp_h    <- fp(36, NAVY, DISPLAY)
fp_eye  <- fp(11, GRAY, bold = TRUE)
fp_bul  <- fp(15)
fp_sm   <- fp(11, GRAY)
fp_link <- fp(11, BLUE)
fp_code <- fp(11.5, NAVY, MONO)
par_l <- function(pad_b = 5, align = "left", ls = 1.05)
  fp_par(text.align = align, padding.bottom = pad_b, padding.top = 0, padding.left = 0, padding.right = 0,
         line_spacing = ls)

new_slide <- function(layout = "Blank") { doc <<- add_slide(doc, layout, MST); n_slide <<- n_slide + 1L; invisible(NULL) }
loc <- function(left, top, width, height, ...) ph_location(left = left, top = top, width = width, height = height, ...)
rect <- function(left, top, width, height, bg, geom = "rect", ln_col = bg) {
  doc <<- ph_with(doc, empty_content(),
                  location = loc(left, top, width, height, bg = bg, geom = geom, ln = sp_line(color = ln_col, lwd = 0.75)))
}
txt <- function(lines, left, top, width, height, fp_t = fp_bul, align = "left", pad_b = 5, ls = 1.05, ...) {
  # lines: character vector (one paragraph each) or a list of fpar()s
  blocks <- if (is.list(lines)) lines else
    lapply(lines, function(s) fpar(ftext(s, fp_t), fp_p = par_l(pad_b, align, ls)))
  doc <<- ph_with(doc, do.call(block_list, blocks), location = loc(left, top, width, height, ...))
}
bullets <- function(items, left, top, width, height, fp_t = fp_bul, glyph = "•  ", pad_b = 7) {
  blocks <- lapply(items, function(s) fpar(ftext(glyph, fp_t), ftext(s, fp_t), fp_p = par_l(pad_b)))
  doc <<- ph_with(doc, do.call(block_list, blocks), location = loc(left, top, width, height))
}
img_dim <- function(path) { d <- dim(readPNG(path)); c(w = d[2], h = d[1]) }
fit_img <- function(path, left, top, w, h, align = "center", frame = TRUE) {
  d <- img_dim(path); r <- unname(d["w"] / d["h"])
  if (w / h > r) { ih <- h; iw <- h * r } else { iw <- w; ih <- w / r }
  dx <- switch(align, left = 0, center = (w - iw) / 2, right = w - iw)
  ln <- if (frame) sp_line(color = RULE, lwd = 0.75) else NULL
  doc <<- ph_with(doc, external_img(path, width = iw, height = ih, unit = "in"),
                  location = loc(left + dx, top, iw, ih, ln = ln))
  # unname() so a chained call (`x <- g["left"] + g["w"]`, fed back in as `left`) does not build up
  # names — c(left = <vector named "left">) becomes "left.left", and the next g["left"] is silently NA
  invisible(c(left = unname(left + dx), top = unname(top), w = unname(iw), h = unname(ih)))
}
caption <- function(s, left, top, width, color = GRAY, align = "left")
  txt(s, left, top, width, 0.42, fp_t = fp(10.5, color), align = align, pad_b = 0)
notes <- function(...) {
  doc <<- set_notes(doc, value = c(...), location = notes_location_type("body"))
}

headline <- function(eyebrow, h) {
  txt(toupper(eyebrow), M, 0.32, W - 2 * M - 1.7, 0.3, fp_t = fp_eye, pad_b = 0)
  txt(h, M, 0.56, W - 2 * M - 1.7, 1.25, fp_t = fp_h, pad_b = 0, ls = 0.9)
  fit_img(assets["logo"], W - M - 1.55, 0.36, 1.55, 0.37, align = "right", frame = FALSE)
}
footer <- function(url) {
  rect(M, 6.93, W - 2 * M, 0.02, NAVY)
  txt(url, M, 7.0, 8.5, 0.32, fp_t = fp_link, pad_b = 0)
  txt(sprintf("CalCOFI data meeting · 2026-09-08 · %d", n_slide), W - M - 4.5, 7.0, 4.5, 0.32,
      fp_t = fp_sm, align = "right", pad_b = 0)
}
stat_tile <- function(big, small, left, top, w = 2.35, h = 1.15, bg = SAND, big_col = BLUE, small_col = NAVY) {
  rect(left, top, w, h, bg, geom = "roundRect")
  txt(big,   left + 0.15, top + 0.05, w - 0.3, 0.65, fp_t = fp(30, big_col, DISPLAY), pad_b = 0)
  txt(small, left + 0.15, top + 0.68, w - 0.3, 0.42, fp_t = fp(11.5, small_col), pad_b = 0)
}
# a numbered callout dropped on top of a screenshot: a yellow disc with the number, centred on (cx, cy)
callout <- function(n, cx, cy, d = 0.30, bg = YELLOW, col = NAVY) {
  rect(cx - d / 2, cy - d / 2, d, d, bg, geom = "ellipse", ln_col = NAVY)
  txt(as.character(n), cx - d / 2, cy - d / 2 + 0.015, d, d,
      fp_t = fp(13, col, SANS, bold = TRUE), align = "center", pad_b = 0)
}
# the same disc inline, as the bullet of a legend line
legend_lines <- function(items, left, top, width, height, size = 12, d = 0.26, gap = 0.30) {
  for (i in seq_along(items)) {
    y <- top + (i - 1) * gap
    callout(i, left + d / 2, y + 0.115, d = d)
    txt(items[[i]], left + d + 0.10, y, width - d - 0.10, gap,
        fp_t = fp(size, NAVY), pad_b = 0, ls = 1.0)
  }
}
code_box <- function(title, lines, left, top, w, h) {
  rect(left, top, w, h, SAND, geom = "roundRect")
  txt(toupper(title), left + 0.2, top + 0.1, w - 0.4, 0.3, fp_t = fp_eye, pad_b = 0)
  txt(lines, left + 0.2, top + 0.42, w - 0.4, h - 0.5, fp_t = fp_code, pad_b = 2, ls = 1.0)
}
ft_tbl <- function(df, size = 12, widths = NULL, bold_first = TRUE) {
  ft <- flextable(df) |>
    font(fontname = SANS, part = "all") |>
    fontsize(size = size, part = "all") |>
    bold(part = "header") |> color(color = WHITE, part = "header") |> bg(bg = NAVY, part = "header") |>
    color(color = NAVY, part = "body") |>
    border_remove() |>
    hline(border = fp_border(color = RULE, width = 0.75), part = "body") |>
    padding(padding.top = 4, padding.bottom = 4, padding.left = 6, padding.right = 6, part = "all") |>
    valign(valign = "top", part = "body") |> align(align = "left", part = "all")
  if (nrow(df) > 1) ft <- bg(ft, i = seq(1, nrow(df), 2), bg = SAND, part = "body")
  if (bold_first) ft <- bold(ft, j = 1, part = "body")
  if (!is.null(widths)) ft <- width(ft, width = widths) else ft <- autofit(ft)
  ft
}

# ── 1 · title ──────────────────────────────────────────────────────────────────────────────────
new_slide()
rect(0, 0, W, H, NAVY)
fit_img(assets["logo_lt"], M, 0.55, 3.6, 0.86, align = "left", frame = FALSE)
txt(c("CalCOFI.io — what landed since Aug 25,", "and what we need from each other"),
    M, 1.65, W - 2 * M, 2.3, fp_t = fp(48, WHITE, DISPLAY), pad_b = 0, ls = 0.95)
rect(M, 4.1, 1.6, 0.06, YELLOW)
txt("CalCOFI data meeting · Tuesday 8 September 2026 · 15 minutes, then discussion",
    M, 4.3, W - 2 * M, 0.4, fp_t = fp(16, WATER), pad_b = 0)
tiles <- list(c(REL$version, sprintf("release, %s", REL$date)),
              c(sprintf("%d datasets", REL$n_ds), sprintf("%d tables · %d holdings", REL$n_tables, REL$n_hold)),
              c(sprintf("%s rows", rows_m), sprintf("%s · %s", rows_fmt, gb_fmt)),
              c("DOI", REL$doi))
for (i in seq_along(tiles))
  stat_tile(tiles[[i]][1], tiles[[i]][2], M + (i - 1) * 3.05, 5.1, w = 2.85, h = 1.2,
            bg = "#21375c", big_col = YELLOW, small_col = WATER)
txt("Ben Best · Ocean Metrics · ben@oceanmetrics.io · data@calcofi.io", M, 6.75, W - 2 * M, 0.35, fp_t = fp(12, STONE), pad_b = 0)
notes(
  "Thanks for the time. Fifteen minutes on what has landed on CalCOFI.io since we last met, then I would rather discuss than present: your reactions matter more than the features.",
  sprintf("Everything in this deck reads one frozen database release: %s, published %s, %d datasets, %d tables, %s rows (%s), %s, with its own DOI (%s; concept DOI %s).",
          REL$version, REL$date, REL$n_ds, REL$n_tables, rows_fmt, rows_m, gb_fmt, REL$doi, REL$cdoi),
  sprintf("Sources: %s.", SRC_REL))

# ── 2 · five things, one database ───────────────────────────────────────────────────────────────
new_slide(); headline("the map of the talk", "Five things, one database")
five <- list(
  c("The front door", "calcofi.io", "A Line 90 section drawn from the release; six numbers; where, when; the ship's log"),
  c("The Explorer", "calcofi.io/explore", "One app, six lenses, no server: stations · hexagons · contours · cruises · regions · sections"),
  c("Datasets catalog", "calcofi.io/datasets", sprintf("One page per dataset with every endpoint: %d in the database, %d holdings", REL$n_ds, REL$n_hold)),
  c("The publishers", "OBIS · EDI · ERDDAP · netCDF", "Generic, idempotent, staged; the 2022 'publish' box made real"),
  c("Packages + DOI", "calcofi4r · calcofi4py · Zenodo", "The same bytes from R, Python and the browser; a citable DOI per release"))
tw <- (W - 2 * M - 4 * 0.22) / 5
for (i in seq_along(five)) {
  x <- M + (i - 1) * (tw + 0.22)
  rect(x, TOP_BODY + 0.1, tw, 3.5, SAND, geom = "roundRect")
  rect(x + 0.2, TOP_BODY + 0.32, 0.45, 0.06, YELLOW)
  txt(five[[i]][1], x + 0.2, TOP_BODY + 0.46, tw - 0.4, 1.1, fp_t = fp(22, NAVY, DISPLAY), pad_b = 0, ls = 0.9)
  txt(five[[i]][2], x + 0.2, TOP_BODY + 1.6, tw - 0.4, 0.4, fp_t = fp(11.5, BLUE, bold = TRUE), pad_b = 0)
  txt(five[[i]][3], x + 0.2, TOP_BODY + 2.02, tw - 0.4, 1.5, fp_t = fp(12.5, NAVY), pad_b = 0, ls = 1.1)
}
txt(sprintf("Everything reads the same frozen release — %s — so a number is the same in the app, the CSV, the R session and the portal.", REL$version),
    M, 5.7, W - 2 * M, 0.8, fp_t = fp(16, NAVY), pad_b = 0)
footer("calcofi.io")
notes(
  "The map of the talk: five things, in the order we will see them. The point that ties them together is that all five read the same frozen release — the front door, the Explorer, the dataset pages, the portal exports and the packages cannot disagree with each other.",
  sprintf("Sources: release facts from %s; lens list from explore/src/state.ts (LENS_ICON: station, hex, contour, cruise, region, section).", SRC_REL))

# ── 3 · the front door ──────────────────────────────────────────────────────────────────────────
new_slide(); headline("the front door · calcofi.io", "The front door: from ship to screen")
g <- fit_img(assets["hero"], M, TOP_BODY, 8.9, 4.4, align = "left")
caption("calcofi.io, 2026-09-07, light theme, tour off — the hero and the six numbers, all computed from the release.", M, g["top"] + g["h"] + 0.06, 8.9)
bullets(c(
  "Opens on a Line 90 section drawn to scale from the release: the ship, the CTD wire and its bottle depths, the bongo, PairoVET, manta, CUFES, the GEBCO sea floor.",
  "14 pins sit at the depth each measurement lives; every pin links to calcofi.org's method page, so calcofi.io never explains a net.",
  "The six numbers, the Where map (the real 218-cell grid) and the When strip (measured coverage per dataset) come from the record, never typed.",
  "The ship's log writes itself from releases, datasets and apps; calcofi.org can pull it as a feed."),
  M + 9.15, TOP_BODY, W - 2 * M - 9.15, 4.9, fp_t = fp(13))
footer("calcofi.io")
notes(
  "calcofi.io now opens on a Line 90 section drawn to scale from the release and the brand's own sprite: the ship, the CTD wire with its 14 bottle depths to 515 m, the bongo at 210 m, PairoVET, manta, the CUFES intake, the GEBCO sea floor, and 14 pins placed at the depth each measurement lives. Every pin links out to calcofi.org's method page — calcofi.io never explains a net.",
  sprintf("The six numbers (%s), the Where map (the real 218-cell grid) and the When strip (measured coverage per dataset; the two asserted rows hatched) all come from the record, never typed. The ship's log writes itself: 77 entries from releases, datasets and apps, a hand-written file only for features, and a feed calcofi.org can pull.", FT$landing),
  "Deployed 2026-09-07 (CalCOFI.github.io PR #6). Note for Ben: the numbers band says 349 M rows and the catalog strip 348 M for the same 348,657,010 (rounding vs truncation) — the landing session was handed that.",
  "Sources: plan § B slide 3 (the landing re-cut plan of 2026-09-07, measured L1–L5); the screenshot is presentations/assets/landing_hero_2026-09-07.png (shot-scraper, 1440 wide).")

# ── 4 · the rest of the front door ──────────────────────────────────────────────────────────────
new_slide(); headline("the front door · below the hero", "Seven ways in, and every app is still there")
g <- fit_img(CROP["bento"], M, TOP_BODY - 0.03, 6.5, 4.3, align = "left")
caption("calcofi.io below the hero — Where · When · Latest release · Ship's log · Explore · Get the data · Life.",
        M, g["top"] + g["h"] + 0.06, 6.5)
bullets(c(
  "Seven tiles, each a way in: the 218-cell grid, coverage per dataset, the release with its DOI, what shipped, the Explorer, code in four languages, and the taxa.",
  "Every tile is generated from the release; the code tile is copy-and-paste, not a picture of code.",
  "Nothing was removed: the apps are one click down, under Explore · Access · Build · Students.",
  "[Which of the older apps are superseded, and which should be removed rather than demoted — TBD with the group]"),
  M + 6.85, TOP_BODY - 0.03, W - 2 * M - 6.85, 2.5, fp_t = fp(12.5))
g2 <- fit_img(CROP["apps"], M + 6.85, 4.45, W - 2 * M - 6.85, 1.75, align = "left")
caption("The catalog strip and the Explore section — 8 products under Explore, 5 Access, 4 Build, 9 Students.",
        M + 6.85, g2["top"] + g2["h"] + 0.06, W - 2 * M - 6.85)
footer("calcofi.io")
notes(
  "Below the hero the page is a bento of seven tiles, each a way in and each generated from the release: Where (the real 218-cell grid, 67 standard, 37 extended, 114 historical), When (coverage per dataset, 16 datasets, 1949 → 2026), the latest release with its tables, rows and DOI, the Ship's log of what shipped, the Explorer card, Get the data (R, Python, SQL, ERDDAP, parquet — copy-and-paste, not a picture of code), and Life (2,614 taxa, every organism resolved to one accepted WoRMS id).",
  "The point to make out loud: nothing was taken away. Every app that was on the page before is still there, one click down, sorted under Explore (8), Access (5), Build (4) and Students (9). What changed is that the front page now leads with the data rather than with a wall of app cards.",
  "Open question for the group: which of the older apps are superseded by the Explorer's lenses and should be demoted or removed altogether (the Contour Explorer already is), and which stay because they go deep on one grain — the Station, Hexagon and Cruise Explorers.",
  "Sources: shots of calcofi.io taken 2026-09-08 (shot-scraper, 1440 wide, light, tour off): presentations/assets/landing_bento_2026-09-08_light.png and landing_apps_2026-09-08.png; the counts are the page's own category strip.")

# ── 5 · the brand kit ───────────────────────────────────────────────────────────────────────────
new_slide(); headline("the brand · calcofi.io/brand/v2", "One brand kit, every product")
g1 <- fit_img(CROP["br_light"], M, TOP_BODY - 0.05, 3.55, 2.55, align = "left")
g2 <- fit_img(CROP["br_dark"],  M + 3.70, TOP_BODY - 0.05, 3.55, 2.55, align = "left")
caption("The specimen page, light (the default) and navy dark — one click away, remembered across every calcofi.io site and app.",
        M, g1["top"] + g1["h"] + 0.06, 7.25)
g3 <- fit_img(CROP["br_btn"],  M, 4.78, 7.25, 0.60, align = "left")
g4 <- fit_img(CROP["br_chip"], M, 5.48, 7.25, 0.68, align = "left")
caption("Buttons & links (one yellow per view) and chips — a fact, or a state.", M, g4["top"] + g4["h"] + 0.05, 7.25)
bx <- M + 7.55; bw <- W - M - bx
g5 <- fit_img(assets["br_lock"], bx, TOP_BODY - 0.05, bw, 0.75, align = "left")
bullets(c(
  "UC San Diego's brand (brand.ucsd.edu) by way of the SIO look: navy, blue, one yellow accent, sand and navy bands.",
  "Source Sans 3 and Teko are the free stand-ins UCSD names for Brix Sans and Refrigerator Deluxe; the real ones later are a one-file swap.",
  "A horizontal lockup in every header; light is the default, navy dark one click away and remembered across every site and app.",
  "Every colour pair passes AA in both themes.",
  "54 custom glyphs — the lenses, the categories, the actions (calcofi.io/brand/v2/icons/).",
  "One shared place — so all of it is tweakable."),
  bx, 2.68, bw, 3.05, fp_t = fp(11.5), pad_b = 6)
g6 <- fit_img(CROP["br_icons"], bx, 5.82, bw, 0.90, align = "left")
footer("calcofi.io/brand/v2/  (linked at the bottom of calcofi.io)")
notes(
  "The idea in one line, from the 8/30 email: the SIO look becomes CalCOFI's brand kit — UC San Diego's colours (navy, blue, the yellow accent, the sand and navy bands), its fonts, a proper horizontal CalCOFI lockup in the header, and light as the default — while each app keeps its own layout and density. The whitespace of the SIO site is a reading layout for pages; it does not transfer to an app crammed with a map, and it is not supposed to. What transfers is the type, the palette, the header and the buttons.",
  "For Erin: dark stays first-class — one click on the sun/moon in any header, remembered across every calcofi.io site and app, and the dark theme is navy rather than gray or black, so it is the same brand after dark. Add ?theme=dark to any link to force it, which is handy for a slide or a paper figure. For Mark: the fonts are the free stand-ins UC San Diego's brand guide names for Brix Sans and Refrigerator Deluxe; if the SIO web team's licence can cover calcofi.io as a UCSD programme, swapping in the real ones is a one-file change — worth asking them, and worth asking whether they would like to supply a CalCOFI lockup in their font (I drew one from the existing mark in the meantime).",
  "Every colour pair was checked for accessibility and passes AA in both themes. Because every CalCOFI product reads its look from one shared place, a change is a one-line change per product — which is also the point to make: none of this is fixed. Colours, fonts, the lockup, which theme opens first, the partner logos in the footer rather than a UCSD lockup in the masthead — all of it is tweakable, and today is the day to say so. Decided with the group on 9/8; flipped live 2026-09-04.",
  "Sources: Ben's email of 2026-08-30 to Mark, Erin and Betty; the specimen page calcofi.io/brand/v2/ (README = the contract, theme.css = the tokens), shot in both themes on 2026-09-08; the icon sheet at calcofi.io/brand/v2/icons/ (54 glyphs, generated from CalCOFI/explore scripts/build_icons.mjs).")

# ── 6 · one app, six lenses ─────────────────────────────────────────────────────────────────────
new_slide(); headline("the explorer · calcofi.io/explore", "One app, six lenses")
g <- fit_img(assets["stations"], M, TOP_BODY, 8.4, IMG_H, align = "left")
caption("The default view: Stations — Pacific sardine larvae per 10 m² at each station, over the GEBCO sea floor (release v2026.09.06, light theme, tour off).",
        M, g["top"] + g["h"] + 0.06, W - 2 * M)
bullets(c(
  "We had five apps with slightly different grains; switching between them was confusing and every feature was built five times.",
  "Now one app, and the grains are lenses in one picker: stations, hexagons, contours, cruises, regions, sections.",
  "The URL is the view: send a link, get the exact map.",
  "Erin's friendlier names from 8/26 still apply — to the lenses."),
  M + 8.65, TOP_BODY, W - 2 * M - 8.65, 4.9, fp_t = fp(13.5))
footer("calcofi.io/explore")
notes(
  "We had five apps with slightly different grains — station, hexagon, cruise, contour, CTD transect — and switching between them was confusing; every feature (theme, share, export, feedback) was built five times. Now there is one app, and the grains are lenses in one picker: stations, hexagons, contours, cruises, regions and sections. The URL is the view: send a link and the recipient gets the exact map, variable, depth and dates.",
  "Erin proposed friendlier app names on 8/26 (Data Finder, Cruise Data Inventory, …); those names still apply, to the lenses rather than to separate apps.",
  "The next three slides are the orientation a first-time user needs: where everything is, the controls that are the same everywhere, and what each lens is for. The full tour is the docs Explore chapter and the in-app tour (? in the header).",
  "Sources: lens list from explore/src/state.ts (LENS_ICON); the screenshot is explore/shots/tour/stations_light.png — the app's default view, shot from a local production build reading the real release v2026.09.06 (see that folder's README.md; every view is named by URL parameters, so a re-shoot is one command).")

# ── 7 · explorer anatomy ────────────────────────────────────────────────────────────────────────
new_slide(); headline("the explorer · how to read it", "One screen: a sentence, three steps, and x·y·z·t")
iw <- 7.35; ih <- 4.60; ix <- M; iy <- TOP_BODY - 0.02
g <- fit_img(assets["stations"], ix, iy, iw, ih, align = "left")
# callouts, placed on the shot by fraction of its own frame
cx <- function(f) g["left"] + f * g["w"]; cy <- function(f) g["top"] + f * g["h"]
callout(1, cx(0.345), cy(0.048))   # the title sentence
callout(2, cx(0.098), cy(0.104))   # the Controls tabs ① Select ② Refine ③ Share
callout(3, cx(0.560), cy(0.470))   # the map
callout(4, cx(0.045), cy(0.868))   # the Time strip
callout(5, cx(0.957), cy(0.245))   # the Depth control
callout(6, cx(0.957), cy(0.070))   # the map-layers button
caption("calcofi.io/explore/?tour=off&theme=light — the default view, release v2026.09.06.", ix, iy + ih + 0.06, iw)
lx <- M + 7.65; lw <- W - M - lx
legend_lines(list(
  "The sentence says what you are looking at — and every chip in it is a control: click one and its dropdown is the same picker as the panel.",
  "Controls, in order: ① Select what · ② Refine when, where and how deep · ③ Share the link, the data, the code, the citation.",
  "The map is x and y, full screen; every panel floats over it and can be moved, collapsed, expanded or closed.",
  "Time (t) along the bottom: observations per year — drag to filter, or switch it to mean ± se, or cruises.",
  "Depth (z) on the right, environment only: the mean profile with its spread; drag to brush a band.",
  "The layers button: the sea floor, the boundary layers, the data's own ramp and order."),
  lx, TOP_BODY - 0.05, lw, 4.9, size = 11.5, gap = 0.80)
footer("calcofi.io/docs/explore.html  ·  Help → Take the tour")
notes(
  "This is the orientation slide — say it once, slowly, because everything after it assumes the layout. The sentence at the top is the view stated in words, and it is also the controls: every chip in it opens the same picker as the panel, so you can drive the whole app from the sentence if you prefer.",
  "The Controls panel is deliberately numbered, left to right: ① Select — realm (biology or environment), the organism or the ocean variable, life stage, and View as (the lens). ② Refine — years, season, depth band, datasets, quality flags. ③ Share — download the zip, copy the code, cite, copy the link, copy the image, register a product, send feedback, and see the SQL and its timing.",
  "The rest is the four dimensions of the data: the map is x and y and takes the whole screen; Time (t) runs along the bottom (observations per year, switchable to mean ± se or to cruises, drag to filter); Depth (z) is on the right for environment variables only (the mean profile with its spread, drag to brush a band); and the layers button opens the sea floor and the boundary layers. Every panel floats — move it, collapse it, expand it — and the layout is remembered in the URL.",
  "Say where the long version lives: the Explorer guide in the docs (calcofi.io/docs/explore.html, linked from Help ▾) and the twelve-step in-app tour, which the ? button replays any time.",
  "Sources: explore/shots/tour/stations_light.png and that folder's README.md (the URL of every shot); the callout positions are fractions of that frame, set in this script.")

# ── 8 · the controls that are the same everywhere ───────────────────────────────────────────────
new_slide(); headline("the explorer · the same controls everywhere", "The same layers, exports and help in every lens")
g <- fit_img(assets["layers"], M, TOP_BODY - 0.02, 5.60, 3.70, align = "left")
caption("The Layers card (the map's layers button): Data on/off with its ramp and opacity, the GEBCO 2025 sea floor, and On the map in draw order.",
        M, g["top"] + g["h"] + 0.06, 5.60)
px <- M + 5.75; pw <- 2.95
g2 <- fit_img(CROP["panebar"], px, TOP_BODY - 0.02, pw, 1.50, align = "left")
caption("Every viz pane: drag grip · ⬇ PNG 2× / SVG / CSV · collapse · expand.", px, g2["top"] + g2["h"] + 0.05, pw)
g3 <- fit_img(CROP["helpmenu"], px, 3.95, pw, 1.70, align = "left")
caption("Help ▾, the feedback bubble and the theme toggle.", px, g3["top"] + g3["h"] + 0.05, pw)
bullets(c(
  "Layers: turn a layer on or off, set its colour ramp and opacity, drag ▲ ▼ to reorder — the data can draw above or below a boundary.",
  "The sea floor is GEBCO 2025 as three switches: shaded relief, depth colour, contours.",
  "19 boundary layers to add: maritime zones, protected areas, administrative, ecological, energy & industry.",
  "Every panel exports the same three ways: PNG at 2× with the selection and release stamped, SVG for papers, CSV of that panel's table.",
  "Help ▾ now carries the Explorer guide — the written tour, at calcofi.io/docs/explore.html."),
  M + 8.90, TOP_BODY - 0.02, W - M - (M + 8.90), 4.9, fp_t = fp(11.5))
footer("calcofi.io/explore  ·  Help ▾ → Explorer guide")
notes(
  "The second half of the orientation: the controls that do not change between lenses, so learning them once is enough.",
  "Layers (the stack button on the map): Data is a layer like any other — on or off, its own colour ramp (cmocean, viridis, GEBCO by convention per variable) and opacity — and its place in the draw order is a row you can drag, so the data can sit above or below a boundary. The sea floor is GEBCO 2025 as three independent switches (shaded relief, depth colour, contours) with its own opacity. Nineteen boundary layers can be added, grouped as maritime zones, protected areas, administrative, ecological, and energy & industry.",
  "Every viz pane carries the same bar: a drag grip, a ⬇ menu with PNG at 2× (the selection and release stamped into the image), SVG for papers, and CSV of that panel's own table — plus collapse and expand. And in the header: Help ▾ (Take the tour, the Explorer guide at calcofi.io/docs/explore.html, Start here, About, Data Sources & Attribution, Register a product, Keyboard), the feedback bubble, and the light/dark toggle.",
  "Sources: explore/shots/tour/{layers_panel,pane_controls,help_menu}.png, shot 2026-09-08 from a local production build on release v2026.09.06; the boundary-layer groups are the Add a layer list in that shot.")

# ── 9 · the six lenses ──────────────────────────────────────────────────────────────────────────
new_slide(); headline("the explorer · the picker", "Six lenses, one selection")
lens <- list(
  list("lens-stations", "Stations", LENS_TH["stations"],
       "Per-station values — one dot per station, the default view."),
  list("lens-hexagons", "Hexagons", LENS_TH["hexagons"],
       sprintf("The same selection pooled into H3 cells of ~%s — density and pattern, not places.", FT$hex_km)),
  list("lens-contours", "Contours", LENS_TH["contours"],
       "A kriged, IDW or spline surface between the stations, with its error, inputs and labels."),
  list("lens-cruises", "Cruises", LENS_TH["cruises"],
       "One voyage along its track: its casts, coloured, and the whole series behind it."),
  list("lens-regions", "Regions", LENS_TH["regions"],
       "Averaged within a boundary — sanctuaries, zones, basins — with the regions ranked."),
  list("lens-sections", "Sections", LENS_TH["sections"],
       "A line of stations: depth × station for one cruise (environment), station × year (biology); 3-D over the sea floor."))
cw <- (W - 2 * M - 2 * 0.22) / 3; ch <- 2.28
for (i in seq_along(lens)) {
  col <- (i - 1) %% 3; row <- (i - 1) %/% 3
  x <- M + col * (cw + 0.22); y <- TOP_BODY - 0.05 + row * (ch + 0.16)
  fit_img(icon_png(lens[[i]][[1]]), x, y + 0.02, 0.26, 0.26, align = "left", frame = FALSE)
  txt(lens[[i]][[2]], x + 0.36, y - 0.03, cw - 0.36, 0.36, fp_t = fp(22, NAVY, DISPLAY), pad_b = 0)
  fit_img(lens[[i]][[3]], x, y + 0.36, cw, 1.36, align = "left")
  txt(lens[[i]][[4]], x, y + 1.78, cw, 0.55, fp_t = fp(11.5, NAVY), pad_b = 0, ls = 1.05)
}
footer("calcofi.io/explore/?lens={station,hex,contour,cruise,region,section}")
notes(
  "Six lenses, one selection: change the lens and the organism, variable, years and depth band stay put — only the way of looking changes. The icons are the brand's own lens glyphs, the same ones in the picker, on the landing page and on the dataset pages.",
  "Stations: per-station values, one dot per station — the default. Hexagons: the same selection pooled into H3 cells of about 8.5 km, for density and pattern rather than places. Contours: a surface between the stations by IDW, ordinary kriging or a thin-plate spline, with its error, its inputs drawn on top and its labels — the next slide. Cruises: one voyage along its track with its casts coloured, and the whole series behind it for context. Regions: averaged within a boundary layer — sanctuaries, maritime zones, basins — with the regions ranked so you can read them off. Sections: a line of stations, which for an environment variable is depth × station on one cruise and for biology is station × year across all cruises, because the tows are depth-integrated; and the 3-D curtain over the GEBCO sea floor.",
  "Erin's friendlier names from 8/26 apply here, to the lenses. Sources: explore/src/state.ts (LENS_ICON) for the list and the icon ids; the thumbnails are crops of explore/shots/tour/{stations_light,hexagons,contours_temperature_grid_labels,cruises,regions,sections_env}.png; the icons are rasterised from CalCOFI.github.io/brand/v2/icons/calcofi-icons.svg.")

# ── 10 · contours ───────────────────────────────────────────────────────────────────────────────
new_slide(); headline("the explorer · the sixth lens, live 2026-09-07",
                      "Contours: a surface between the stations, with its error, computed in your browser")
g <- fit_img(assets["contour"], M, TOP_BODY, 8.4, IMG_H, align = "left")
caption(sprintf("Temperature, ordinary kriging over the station grid, inputs and labels drawn: %s stations → %s cells of %s in %s; leave-one-out error %s.",
                FT$g_stns, FT$g_cells, FT$g_res, FT$g_ms, FT$g_rmse), M, g["top"] + g["h"] + 0.06, W - 2 * M)
bullets(c(
  "Replaces the Contour Explorer, which read the legacy PostgreSQL; its URL now redirects here.",
  sprintf("Three methods — IDW for parity with the old app, ordinary kriging by default, a thin-plate spline; the model-based two halve IDW's error (leave-one-out %s vs %s °C) and say where they are unsure.", FT$c_ok, FT$c_idw),
  sprintf("%s surfaces from one table: the statistic, its error, observation density, first and last year, the 5th/95th percentiles and their spread.", tools::toTitleCase(FT$c_n_surf)),
  "The same algorithm runs in R (cc_interpolate) and Python (interpolate), tested cell for cell against a fixture the browser wrote. No server."),
  M + 8.65, TOP_BODY, W - 2 * M - 8.65, 4.9, fp_t = fp(12.5))
footer("calcofi.io/explore/?lens=contour&var=temperature")
notes(
  "The sixth lens, live today, replaces the Contour Explorer (which read the legacy PostgreSQL; app.calcofi.io/contour now redirects to this lens). Three methods: IDW for parity with the old app, ordinary kriging by default, and a thin-plate spline. The model-based two halve IDW's error and say where they are unsure — the error is a surface you can switch to.",
  sprintf("The fit line under the method says what you are looking at: %s sites → %s cells in %s, leave-one-out error %s, blank beyond %s of a point and over land. The station grid fits in %s. On 213 station means the leave-one-out error is IDW %s, kriging %s, spline %s °C.",
          FT$c_sites, FT$c_cells, FT$c_secs, FT$c_rmse, FT$c_km, FT$c_grid_s, FT$c_idw, FT$c_ok, FT$c_tps),
  sprintf("%s surfaces from one table (value, error, n, first/last year, p05/p95, spread); the inputs can be drawn on top; ramps follow oceanographic convention per variable (cmocean / viridis / GEBCO). Honesty is built in: the sentence says 'by ordinary kriging', never just 'temperature'. The same algorithm runs in R (calcofi4r::cc_interpolate(), since 1.21.0) and Python (calcofi4py.interpolate(), since 0.8.0), tested cell for cell against a fixture the browser's own worker wrote, so a figure is reproducible outside the app.",
          tools::toTitleCase(FT$c_n_surf)),
  sprintf("Sources: the live fit line on 2026-09-07 and the contours plan (2026-09-07) § The take, D32, D39, D40 — via the facts table. The screenshot is explore/shots/tour/contours_temperature_grid_labels.png (?lens=contour&var=temperature&grain=station&labels=on, release v2026.09.06); the caption's numbers are that shot's own fit line: %s stations → %s cells of %s, leave-one-out RMSE %s, %s, variogram nugget 0.46 · sill 13.91 · range 2634 km.",
          FT$g_stns, FT$g_cells, FT$g_res, FT$g_rmse, FT$g_ms))

# ── 11 · speed and cost ──────────────────────────────────────────────────────────────────────────
new_slide(); headline("the explorer · hosting", sprintf("It answers in %.2f s, and it costs nothing to host", UP$expl_all / 1000))
gw <- 3.75
txt("CalCOFI Explorer · calcofi.io/explore", M, TOP_BODY, gw + 0.32, 0.3, fp_t = fp(12, GRAY, bold = TRUE), pad_b = 0)
txt(ms(UP$expl_all), M, TOP_BODY + 0.28, gw, 0.7, fp_t = fp(40, BLUE, DISPLAY), pad_b = 0)
fit_img(assets["up_expl"], M, TOP_BODY + 1.05, gw, 2.75, align = "left")
txt("Hexagon Explorer (Shiny) · app.calcofi.io/hex", M + gw + 0.35, TOP_BODY, gw + 0.32, 0.3, fp_t = fp(12, GRAY, bold = TRUE), pad_b = 0)
txt(ms(UP$hex_all), M + gw + 0.35, TOP_BODY + 0.28, gw, 0.7, fp_t = fp(40, GOLD, DISPLAY), pad_b = 0)
fit_img(assets["up_hex"], M + gw + 0.35, TOP_BODY + 1.05, gw, 2.75, align = "left")
caption(sprintf("Response time, all-time average; the graphs are the last week. status.calcofi.io checks %d sites every 15 min (%d up at the pull, %s).",
                UP$n_sites, UP$n_up, UP$pulled), M, TOP_BODY + 3.9, 2 * gw + 0.35)
bullets(c(
  "No server: the page is on GitHub Pages, the tables are public objects on GCS, and the SQL runs in the browser (DuckDB-WASM).",
  "No server also means no security surface and no downtime. Today's outage is the example: a crawler asked ERDDAP for a whole table as JSON and wedged the VM for hours — the Explorer never noticed.",
  sprintf("The Shiny apps, ERDDAP and the CTD team's PostgreSQL share one VM: about %s/month of compute (%s–%s, peaking in %s) and %s/month of storage — %s so far in 2026, roughly %s a year. The Explorer's own share of that is nothing beyond its bytes on GCS.",
          usd(BILL$cmp), usd(BILL$cmp_lo), usd(BILL$cmp_hi), BILL$peak, usd(BILL$sto), usd(BILL$ytd), usd(BILL$year)),
  "The honest downside: it is a large TypeScript app. Maintaining it presumes AI-assisted development, and it needs a second pair of eyes — that is one of the asks."),
  M + 2 * gw + 0.75, TOP_BODY, W - 2 * M - 2 * gw - 0.75, 4.9, fp_t = fp(12))
footer("status.calcofi.io")
notes(
  sprintf("The Explorer answers in %s on average (%s over the last 7 days); the Hexagon Explorer, a Shiny app on the VM, in %s (%s over 7 days). No server: the page is on GitHub Pages, the tables are public objects on GCS, and the SQL runs in the browser.",
          ms(UP$expl_all), ms(UP$expl_7d), ms(UP$hex_all), ms(UP$hex_7d)),
  "The second bullet, told as today's story rather than as a claim. At 03:27 UTC this morning a crawler (Meta's range, a spoofed browser user-agent) asked erddap.calcofi.io for /erddap/tabledap/calcofi_ctd-cast_full.json with NO query string — an unconstrained dump of the largest table. The client gave up after 25 seconds; ERDDAP does not cancel the query when the client disconnects, so it kept materialising it. From 03:34 the VM's disk sat pinned at its read-throughput ceiling for five hours and forty minutes with writes at zero: the working set was file-backed, so the kernel just evicted and re-read the same pages — no OOM kill, no panic, and it cannot self-heal. Ports answered, sshd never sent a banner. Only a reset cleared it. Fixed the same day: Caddy now 403s any tabledap/griddap data-format request with an empty query string (metadata requests still pass), and the post-mortem is in CalCOFI/server INCIDENTS.md. Still open: a constrained but huge query reproduces it, which needs a size or duration cap in ERDDAP.",
  "The point for this slide is the contrast, not the incident: ERDDAP, the Shiny apps and the CTD team's PostgreSQL were all down for six hours; the Explorer was not, because there is nothing of ours to knock over — GitHub Pages and public objects on GCS. A static product has no attack surface and no uptime to defend.",
  sprintf("The cost, so nobody has to guess. They share one GCE VM (shiny-server, n2-standard-4, 16 GB, 200 GB disk) on project ucsd-sio-calcofi. Over %s the bill averaged %s a month all in — %s of Compute Engine (%s to %s; the %s peak is the CTD PostgreSQL build) and %s of Cloud Storage (%s to %s). January to 11 August came to %s, of which %s was compute and %s storage, after %s of committed-use and free-tier savings. Call it %s a year at today's shape. The Explorer adds nothing to it: GitHub Pages is free and its tables are the same GCS objects everything else reads.",
          BILL$months, usd(BILL$all), usd(BILL$cmp), usd(BILL$cmp_lo), usd(BILL$cmp_hi), BILL$peak,
          usd(BILL$sto), usd(BILL$sto_lo), usd(BILL$sto_hi),
          usd(BILL$ytd, 2), usd(BILL$ytd_cmp, 2), usd(BILL$ytd_sto, 2), usd(BILL$saved, 2), usd(BILL$year)),
  "How to read it next time without a screenshot: grant calcofi-admin@ucsd-sio-calcofi.iam.gserviceaccount.com the Billing Account Viewer role (roles/billing.viewer) on the billing account, or set up a BigQuery billing export and point this script at it. Today the Cloud Billing API is disabled on the project and that account has no compute.* or serviceusage.* permission either, so both the API call and `gcloud compute instances list` return PERMISSION_DENIED — which is why these figures come from a console reading rather than a live query. One fewer app since today, either way: the Contour Explorer is retired and its URL redirects to the Contours lens.",
  "The honest downside, said on the same slide as the upside: it is a large TypeScript app; maintaining it presumes AI-assisted development and it needs a second pair of eyes. That is one of the asks (the decisions slide), not an apology.",
  sprintf("Sources: CalCOFI/uptime api/{explore,db-viz-hex}/response-time{,-week}.json and graphs/*/response-time-week.png, pulled %s (the README regenerates hourly — pull once more in the morning and rebuild); %d sites from .upptimerc.yml; the VM from server/README.md; the outage from CalCOFI/server INCIDENTS.md (2026-09-08) and /share/logs/caddy/erddap.log; the cost from %s.",
          UP$pulled, UP$n_sites, BILL_SRC))

# ── 12 · attribution ─────────────────────────────────────────────────────────────────────────────
new_slide(); headline("the explorer · attribution", "\"Cite this dataset\" is built in everywhere")
ix <- M; ih <- 1.75
g1 <- fit_img(CROP["sources"],     ix, TOP_BODY, 5, ih, align = "left"); ix <- g1["left"] + g1["w"] + 0.28
g2 <- fit_img(assets["sharecite"], ix, TOP_BODY, 5, ih, align = "left"); ix <- g2["left"] + g2["w"] + 0.28
g3 <- fit_img(CROP["ds_cite"],     ix, TOP_BODY, 5, ih, align = "left"); ix <- g3["left"] + g3["w"] + 0.28
g4 <- fit_img(CROP["docs_cite"],   ix, TOP_BODY, 5, ih, align = "left")
cy <- TOP_BODY + ih + 0.06
caption("Explorer · Data Sources",                     g1["left"], cy, g1["w"])
caption("Explorer · Share ③ → Cite",                   g2["left"], cy, g2["w"])
caption("A dataset page's Cite section — the dataset, then the release", g3["left"], cy, g3["w"])
caption("The docs · Cite This Data — every dataset's citation, licence, DOI, contact", g4["left"], cy, g4["w"])
txt(c("One row per dataset in the Explorer, a Cite section on every dataset page, one chapter in the docs — and every download (PNG, SVG, CSV, SQL, zip) carries the citations of only the datasets it used.",
      sprintf("What still needs filling, counted at build time from the %s dataset table:", REL$version)),
    M, 4.06, W - 2 * M, 0.66, fp_t = fp(12.5, NAVY), pad_b = 3)
doc <- ph_with(doc, ft_tbl(GAP, size = 9, widths = c(1.35, 0.85, 9.93)), location = loc(M, 4.80, W - 2 * M, 2.05))
footer("calcofi.io/explore/?modal=sources  ·  calcofi.io/datasets/  ·  calcofi.io/docs/cite.html")
notes(
  "Erin's asks from 9/2 are all in, and the same answer is now in three places rather than one. In the Explorer: the source sits beside the variable (one chip per dataset the view pools), Data Sources & Attribution is one row per DATASET — never per taxon, so the phytoplankton dataset is one row and not 393 — and Share ③ → Cite this data copies the release citation plus every dataset in view, as text or BibTeX. Every download carries the citations of only the datasets it actually used: the zip has a CITATION file, every CSV carries a dataset_key column (a column, never a comment line), and every PNG and SVG is stamped with the selection, the release and 'cite: calcofi.io/explore → Cite this data'.",
  "In the catalog: every dataset page has a Cite section with its own citation and the release it came from, both with BibTeX, and it links out to the docs chapter rather than restating it. In the docs: calcofi.io/docs/cite.html is the one answer to 'how do I cite CalCOFI data?' — cite BOTH the release and every dataset you used — and it tabulates the citation, licence, DOI and contact of all sixteen datasets.",
  sprintf("The table is the ask to providers, and it is measured, not typed: %s. Read it as 'this field is still empty for these datasets'. Who holds each one: citation_main, pi_names and acknowledgement are the provider's to state; license and license_url are the provider's decision (never invented here — a licence must already be in metadata/license.csv); doi is whatever the source archive minted; contact is the person or address a user should reach, and it is empty for all sixteen, which is the single biggest gap on this slide. A gap is exempt only while an open question names the field, in metadata/{provider}/{dataset}/questions.csv — which is exactly what the per-provider Sheets are for (the metadata slide), and this table is what the next round of those Sheets should close.",
          GAP_SRC),
  "Sources: explore/README.md § Attribution; CLAUDE.md § Attribution; the docs cite chapter. Screenshots, all light theme, shot 2026-09-08 from local production builds: presentations/assets/explore/{sources_modal,share_cite}_light.png (../explore scripts/deck_shots.mjs), assets/cite/ds_cite_swfsc_ichthyo.png (the Jekyll _site) and assets/cite/docs_cite_table.png (the rendered ../docs/_book).")

# ── 13 · feedback ────────────────────────────────────────────────────────────────────────────────
new_slide(); headline("the explorer · feedback", "One button, everywhere")
gf <- fit_img(assets["feedback"], M, TOP_BODY, 6.20, 4.45, align = "left")
caption("The Explorer, Send feedback → edit: the captured view, the tools (arrow · circle · rectangle · pen · text, three colours, undo, clear) and two marks drawn on it.",
        gf["left"], gf["top"] + gf["h"] + 0.06, gf["w"])
rx <- gf["left"] + gf["w"] + 0.32; rw <- W - M - rx
txt("THE SAME BUTTON IN EVERY PRODUCT", rx, TOP_BODY - 0.04, rw, 0.26, fp_t = fp_eye, pad_b = 0)
hy <- TOP_BODY + 0.22
hdr_bars <- list(
  list("calcofi.io — the landing page and the Datasets catalog share one header", CROP[["hdr_site"]], rw),
  list("calcofi.io/docs/ — the book's sidebar tools",                             CROP[["hdr_docs"]], 1.10),
  list("calcofi.io/explore — the Explorer's own header",                          CROP[["hdr_expl"]], rw))
for (h in hdr_bars) {
  txt(h[[1]], rx, hy, rw, 0.24, fp_t = fp(10.5, GRAY), pad_b = 0)
  gh <- fit_img(h[[2]], rx, hy + 0.26, h[[3]], 0.34, align = "left")
  hy <- gh["top"] + gh["h"] + 0.12
}
gr <- fit_img(CROP["register"], rx, hy + 0.06, 2.85, 0.52, align = "left")
caption("Share ③, Help ▾ and the Sources modal all carry it: \"I used CalCOFI data in …\".", rx, gr["top"] + gr["h"] + 0.04, rw)
bullets(c(
  "A report carries your note, the view's URL, the release, the datasets in view, the viewport and theme, and the marked-up screenshot — nothing else.",
  "It goes to the \"CalCOFI app feedback\" Sheet, an email to Ben, Erin and Betty with the screenshot inline, and a public issue in that product's own repo.",
  "Register a product uses the same dialog and the same pipe — how someone tells us where the data ended up."),
  rx, gr["top"] + gr["h"] + 0.38, rw, 1.85, fp_t = fp(11), pad_b = 5)
footer("Help ▾ → Send feedback  ·  the same button on calcofi.io, /datasets/, /docs/ and /explore")
notes(
  "One button, and it is the same button everywhere: a speech bubble immediately left of the light/dark toggle on calcofi.io, on every dataset page, on every page of the docs book, and in the Explorer's header (calcofi.io's _layouts/default.html sets the shape — .cc-icon-button.cc-feedback beside .cc-theme-toggle — and the Explorer and the docs book wear it).",
  "What it does: it captures the view you are looking at, lets you mark it up — arrow, circle, rectangle, pen, text, in three colours that read on any map, with undo and clear — and sends your note with the view's URL, the release, the datasets in view, the viewport and the theme. Nothing else: no cookies, no tracking, and the email address is optional (you get a copy and any reply; it is never public).",
  "Where it lands: the \"CalCOFI app feedback\" Google Sheet and its recipients tab, an email to Ben, Erin and Betty with the screenshot inline, and a public GitHub issue in the product's own repo — CalCOFI/explore, CalCOFI/CalCOFI.github.io, CalCOFI/docs — with the email stripped out. \"Open as GitHub issue myself\" files a prefilled issue without the Apps Script and copies the screenshot to your clipboard to paste.",
  "Register a product is the second kind of the same dialog, labelled derived-product: the title of the paper, product or project, a link or DOI, and the datasets in view already filled in. It is how someone tells us \"I used CalCOFI data in …\", which is how the program shows what six decades of sampling is for. It is reachable from Share ③, from Help ▾ and from the bottom of the Data Sources & Attribution modal.",
  "The ask (the decisions slide): use it. Thirty minutes each in the Explorer, and file what you find with the button rather than in an email thread.",
  "Sources: explore/src/feedback.tsx and annotate.tsx; CalCOFI.github.io _config.yml (the shared Apps Script endpoint and feedback_repo) and _layouts/default.html; ../docs README § Feedback. Screenshots, light theme, 2026-09-08: presentations/assets/explore/feedback_annotate_light.png and header_explore_light.png (../explore scripts/deck_shots.mjs, which drives the dialog and draws the marks), assets/headers/hdr_calcofi_io.png and hdr_docs.png (shot-scraper against the local Jekyll _site and the rendered docs _book).")

# ── 14 · the datasets grid ───────────────────────────────────────────────────────────────────────
new_slide(); headline("the datasets catalog · calcofi.io/datasets", "Every dataset has one page, and every page has every endpoint")
g <- fit_img(assets["datasets"], M, TOP_BODY, 5.2, IMG_H, align = "left")
caption("calcofi.io/datasets/ — 12 categories in Biology ‖ Environment columns; holdings collapsed under \"not yet in the database\".", g["left"], g["top"] + g["h"] + 0.06, W - 2 * M)
bullets(c(
  "We were stuck showing datasets with credit inside the apps, and nobody could find \"the ERDDAP one\" or \"the netCDF one\".",
  sprintf("Now: %d datasets in the database + %d holdings, by category with the brand icons, generated from the release.", REL$n_ds, REL$n_hold),
  "Hover or tap a card for its years bar and station map.",
  sprintf("The %d holdings are all public archives already (EDI, Stanford SDR, Zenodo, NCBI, CoastWatch ERDDAP, IFCB) — %s external, %s archived; one line hides any of them.",
          REL$n_hold, hold_status[["external"]] %||% "[n]", hold_status[["archived"]] %||% "[n]")),
  M + 5.5, TOP_BODY, W - 2 * M - 5.5, 4.9, fp_t = fp(13.5))
footer("calcofi.io/datasets/")
notes(
  sprintf("We were stuck showing datasets — with credit — inside the apps, and nobody could find 'the ERDDAP one' or 'the netCDF one'. Now every dataset has one page: %d in the database plus %d holdings (datasets CalCOFI has but has not ingested), by category with the brand icons, generated from the release record. The grid is 12 categories in Biology and Environment columns, alphabetical; holdings are collapsed under 'not yet in the database'; hover or tap a card for its years bar and station map.",
          REL$n_ds, REL$n_hold),
  sprintf("Holdings: %d, all visibility: public, statuses external (%s) / archived (%s), none planned; every one already sits in a public archive. If any should stay off the page until a provider conversation happens, visibility: internal hides it from every public surface in one line — offered, not applied (email item 2).",
          REL$n_hold, hold_status[["external"]] %||% "?", hold_status[["archived"]] %||% "?"),
  sprintf("Sources: %s (counts, holdings[].status); the screenshot is CalCOFI.github.io/images/datasets_light.png (the site's card shot).", SRC_REL))

# ── 15 · a dataset page ──────────────────────────────────────────────────────────────────────────
new_slide(); headline("the datasets catalog · one page", "A dataset page, top to bottom")
g <- fit_img(assets["ichthyo"], M, TOP_BODY, 7.0, IMG_H, align = "left")
caption("calcofi.io/datasets/swfsc_ichthyo/ — the SWFSC ichthyoplankton page.", g["left"], g["top"] + g["h"] + 0.06, W - 2 * M)
bullets(c(
  "Explore — which app opens on it · Get the data · Code (R ‖ Python).",
  "Metadata records: STAC, EML, JSON-LD.",
  "Archives & portals, with the policy sentence above the table: archive of record OBIS through the IPT; NCEI is SWFSC's; EDI does not apply.",
  "Source files · measured coverage."),
  M + 7.3, TOP_BODY, W - 2 * M - 7.3, 4.9, fp_t = fp(13.5))
footer("calcofi.io/datasets/swfsc_ichthyo/")
notes(
  "One page, top to bottom: Explore (which app opens on this dataset), Get the data, Code in R and Python side by side, Metadata records (STAC item, EML, JSON-LD), then Archives & portals — a table of every endpoint with the archive-of-record policy sentence above it (for ichthyo: the archive of record is OBIS through the IPT; NCEI is SWFSC's own; EDI does not apply) — then the source files and the measured coverage. Coverage is measured at release, never typed.",
  "Sources: plan § B slide 9 and the facts table row 'Dataset page'; the screenshot is CalCOFI.github.io/images/dataset-ichthyo_light.png (the site's card shot).")

# ── 16 · the publishers ─────────────────────────────────────────────────────────────────────────
new_slide(); headline("publishing", "The generic publishers work, and they wait for a decision, not a build")
pub <- data.frame(
  Portal = c("OBIS", "EDI", "ERDDAP", "netCDF"),
  What   = c("Darwin Core archives (DwC-A), one per bio dataset",
             "Data packages: bottle, CTD casts, METS",
             "Datasets served by erddap.calcofi.io",
             "CF netCDF, one per dataset"),
  `How many` = c(FT$dwca, FT$edi, ERD_N_TXT, "one per dataset"),
  State  = c("staged at gs://calcofi-db/publish/dwca/",
             "staged (built, byte-stable; deposited when we say so)",
             "live",
             "live at storage.calcofi.io/calcofi-files-public/netcdf/"),
  check.names = FALSE)
doc <- ph_with(doc, ft_tbl(pub, size = 13, widths = c(1.3, 4.3, 1.5, 5.0)), location = loc(M, TOP_BODY + 0.1, W - 2 * M, 2.6))
bullets(c(
  "\"Staged\" means built and byte-stable: a re-run is a hash comparison; a deposit happens only when we say so.",
  "The ichthyo archive matches the hand-built one that is on OBIS today; two data questions go to SWFSC (depth asserted 0/NULL; biomass in whole mL).",
  "This is the 'publish' box of the 2022 architecture figure, made real (next slide)."),
  M, 4.9, W - 2 * M, 1.9, fp_t = fp(14))
footer("calcofi.io/workflows/  (publish_to-obis · publish_to-edi · publish_to-erddap · publish_to-netcdf)")
notes(
  sprintf("Four generic publishers, one per portal. OBIS: %s Darwin Core archives, staged at gs://calcofi-db/publish/dwca/. EDI: %s packages (bottle, CTD casts, METS), staged. ERDDAP: %s datasets live on erddap.calcofi.io. netCDF: one CF file per dataset at storage.calcofi.io/calcofi-files-public/netcdf/. All idempotent since 9/6 — a re-run is a hash comparison.",
          FT$dwca, FT$edi, ERD_N_TXT),
  "'Staged' = built and byte-stable, deposited only when we say so — the deposits wait for the decisions on the asks slide (the EDI account, the OBIS resources and contacts). The ichthyo archive was compared with the hand-built one on OBIS today: the data are unchanged; two gaps to raise with SWFSC — depth asserted 0/NULL, biomass in whole mL.",
  sprintf("Sources: DwC-A and EDI counts from the facts table (gcloud storage ls, 2026-09-07); ERDDAP count: %s; ichthyo parity from artifact d58f5c49; RELEASES.md § Unreleased.", ERD_SRC))

# ── 17 · the 2022 picture and what it became ────────────────────────────────────────────────────
new_slide(); headline("publishing · the architecture", "The 2022 picture, and what it became")
txt("2022 — the software architecture figure (docs/figs/sw_arch.svg)", M, TOP_BODY, 5.9, 0.3, fp_t = fp(12, GRAY, bold = TRUE), pad_b = 0)
g1 <- fit_img(assets["sw2022"], M, TOP_BODY + 0.35, 5.9, 3.0, align = "left")
txt("2026 — one record per dataset → surfaces → readers", M + 6.25, TOP_BODY, W - 2 * M - 6.25, 0.3, fp_t = fp(12, GRAY, bold = TRUE), pad_b = 0)
g2 <- fit_img(assets["flow"], M + 6.25, TOP_BODY + 0.35, W - 2 * M - 6.25, 3.0, align = "left")
bullets(c(
  "The 'publish' box is now real. Everything a portal sees is generated from one record per dataset; the dotted boxes are catalogs run by others, each pointed at a static file we already publish.",
  "Old routes still there: OBIS, EDI, ERDDAP, NCEI. New: STAC, DCAT data.json, JSON-LD + sitemap (Google Dataset Search, ODIS), Zenodo.",
  "The only server-shaped option, pycsw, waits for a partner asking for CSW."),
  M, 5.3, W - 2 * M, 1.55, fp_t = fp(13))
footer("calcofi.io/docs/portals.html · calcofi.io/stac/ · calcofi.io/data.json · calcofi.io/datasets/sitemap.xml")
notes(
  "Left, the 2022 Google Drawing: data → ingest → database → API → apps / reports → publish → portals (ERDDAP, OBIS, DataOne/NCEI, InPort). Right, its successor: sources → one record per dataset (datasets.json + EML) → generated surfaces → who reads them. The publish box is now real.",
  "Ben's caption, verbatim: 'Everything a portal sees is generated from one record per dataset. The dotted boxes are catalogs run by others; each is pointed at a static file we already publish. The one server-shaped option, pycsw, is gated on a partner asking for CSW.'",
  "Machine surfaces live today: STAC at calcofi.io/stac/ (and gs://calcofi-db/stac/catalog.json), datasets.json schema 1.1, EML × 16, ISO 19115 WAF via ERDDAP, DCAT-US data.json, JSON-LD per page, and the sitemap at calcofi.io/datasets/sitemap.xml (the root /sitemap.xml is 404 — say the right path).",
  "Sources: docs/figs/sw_arch.svg rendered with rsvg; docs/diagrams/catalog_flow.mmd rendered with mmdc (2026-09-07); the surfaces row of the facts table (curl, 2026-09-07).")

# ── 18 · every release has a DOI ────────────────────────────────────────────────────────────────
new_slide(); headline("the release", "Every release has a DOI")
g1 <- fit_img(assets["zenodo"], M, TOP_BODY, 6.0, 3.45, align = "left")
caption(sprintf("zenodo.org — the %s record; the concept DOI %s always resolves to the latest.", REL$version, REL$cdoi), g1["left"], g1["top"] + g1["h"] + 0.06, 6.0)
g2 <- fit_img(assets["releases"], M + 6.25, TOP_BODY, W - 2 * M - 6.25, 3.45, align = "left")
caption("RELEASES.html — what changed and why, per release, with a table of contents.", g2["left"], g2["top"] + g2["h"] + 0.06, W - 2 * M - 6.25)
rect(M, 5.95, W - 2 * M, 0.9, SAND, geom = "roundRect")
txt(toupper("how to cite"), M + 0.2, 6.0, 3, 0.25, fp_t = fp_eye, pad_b = 0)
txt(REL$citation, M + 0.2, 6.24, W - 2 * M - 0.4, 0.6, fp_t = fp(12, NAVY), pad_b = 0)
footer(sprintf("doi.org/%s · storage.calcofi.io/calcofi-db/ducklake/releases/RELEASES.html", REL$doi))
notes(
  sprintf("Every release has a DOI now: a version DOI per release (%s for %s) and a concept DOI for 'the database' (%s), which always resolves to the latest. The citation string is on the slide, and the Explorer, the packages and every dataset page write it for you.", REL$doi, REL$version, REL$cdoi),
  "The changelog, RELEASES.html, says what changed and why, per release, with a table of contents; each version's release notes are its section plus a generated appendix (tables and rows, datasets, the consumer-contract test result, package versions).",
  sprintf("Sources: %s; the Zenodo record (zenodo.org/records/22514953) and RELEASES.html shot with shot-scraper on 2026-09-07 (the Zenodo cookie banner cropped).", SRC_REL))

# ── 19 · packages ───────────────────────────────────────────────────────────────────────────────
new_slide(); headline("packages", "The same bytes from R, Python and the browser")
cw <- (W - 2 * M - 0.3) / 2
code_box(sprintf("R · calcofi4r %s", PKG$r), c(
  "library(calcofi4r)",
  "con <- cc_get_db()  # latest frozen release, tables as views",
  sprintf("con <- cc_get_db(version = \"%s\")  # pin a version (reproducible)", REL$version),
  "cc_query(\"SELECT count(*) FROM obs\")",
  "cc_qual_ok_sql(\"o\")  # quality flags, one predicate",
  "cc_interpolate(...)  # the Contours surface, cell for cell",
  "con_pg <- cc_pg_connect()  # the CTD team's PostgreSQL"),
  M, TOP_BODY, cw, 3.3)
code_box(sprintf("Python · calcofi4py %s", PKG$py), c(
  "import calcofi4py as cc",
  "con = cc.cc_get_db()  # latest release, every table as a view",
  sprintf("con = cc.cc_get_db(\"%s\")  # pin a version", REL$version),
  "cc.cc_query(\"SELECT count(*) FROM obs\").fetchone()",
  "cc.qual_ok_sql(\"o\")  # the same predicate",
  "cc.interpolate(...)  # the same surface",
  "con = cc.cc_pg_connect(tunnel=True)  # SSH tunnel + ~/.pgpass; no credentials in code"),
  M + cw + 0.3, TOP_BODY, cw, 3.3)
bullets(c(
  sprintf("calcofi4py %s for the CTD group: release access plus their PostgreSQL; calcofi4r %s; calcofi4db %s runs the pipeline.", PKG$py, PKG$r, PKG$db),
  "Quality flags reach a consumer only if the consumer applies them: one NULL-safe predicate per language, and every app and static consumer uses it.",
  "No credentials in code: the release is public objects; PostgreSQL goes through an SSH tunnel and ~/.pgpass."),
  M, 5.3, W - 2 * M, 1.55, fp_t = fp(13.5))
footer("calcofi.io/calcofi4r · calcofi.io/calcofi4py")
notes(
  sprintf("The same bytes from R, Python and the browser: calcofi4r %s and calcofi4py %s both open the frozen release as DuckDB views (pin a version for a reproducible figure), run one-shot queries, apply the quality-flag predicate, reproduce the Contours surface (cc_interpolate() / interpolate(), tested cell for cell against a fixture the browser wrote), and — for the CTD group — connect to their PostgreSQL through an SSH tunnel with ~/.pgpass. calcofi4db %s is the pipeline engine.", PKG$r, PKG$py, PKG$db),
  "Quality flags: obs.measurement_qual is each dataset's own vocabulary (bottle 8 = suspect, CTD 8/9, DIC WOCE 3/4/9); a flagged value is still a row. One predicate exists in each language — cc_qual_ok_sql(), qual_ok_sql(), db-query's qualOkSQL() — and every static consumer's build SQL and every Shiny app's prep_db.R apply it (after Ralf's 1955 oxygen spike in August).",
  "Sources: versions read at build time from ../calcofi4r/DESCRIPTION, ../calcofi4py/pyproject.toml, ../calcofi4db/DESCRIPTION; the snippets follow each package's README (calcofi4r README § Connect / § Execute Custom Queries; calcofi4py README § Use / § The CTD team's PostgreSQL).")

# ── 20 · sheets ↔ git ↔ release ─────────────────────────────────────────────────────────────────
new_slide(); headline("metadata & the ingest loop", "Providers edit a Sheet; git keeps the record; the release publishes it")
g <- fit_img(assets["sheet"], M, TOP_BODY, 6.5, 4.2, align = "left")
caption("The CalCOFI provider Sheet, metadata tab — long form, tiered required → recommended → optional; only value / edited_by / edited_date are editable.",
        g["left"], g["top"] + g["h"] + 0.06, 6.5)
fx <- M + 6.8; fw <- W - 2 * M - 6.8; bh <- 0.72; gap <- 0.26
flow <- list(
  c("Provider Sheet", "one per provider · tabs: a dataset's questions · metadata · holdings (ours)"),
  c("The record, in git", "metadata/{provider}/{dataset}/dataset_meta.yml + questions.csv"),
  c("The release", "monthly; coverage, counts and access dates measured, never typed"),
  c("Public surfaces", "calcofi.io/datasets · EML · STAC · DCAT · DwC-A · EDI · ERDDAP"))
arrows <- c("⇅  push / pull, only the answer columns", "↓  build", "↓  generate")
for (i in seq_along(flow)) {
  y <- TOP_BODY + (i - 1) * (bh + gap)
  rect(fx, y, fw, bh, if (i == 2) "#fff3d1" else SAND, geom = "roundRect", ln_col = if (i == 2) GOLD else SAND)
  txt(flow[[i]][1], fx + 0.15, y + 0.03, fw - 0.3, 0.3, fp_t = fp(13, NAVY, bold = TRUE), pad_b = 0)
  txt(flow[[i]][2], fx + 0.15, y + 0.3,  fw - 0.3, 0.42, fp_t = fp(10.5, GRAY), pad_b = 0)
  if (i < 4) txt(arrows[i], fx + 0.15, y + bh - 0.02, fw - 0.3, gap + 0.04, fp_t = fp(10.5, BLUE), pad_b = 0)
}
bullets(c(
  sprintf("%d provider Sheets, three kinds of tab; only the answer columns are editable.", N_SHEET),
  "The weekly observer files a proposed question when a portal changes something.",
  "Erin: this overlaps with your attribution sheet — which one do providers see? (the asks slide)"),
  fx, TOP_BODY + 4 * (bh + gap) - gap + 0.1, fw, 1.25, fp_t = fp(11), pad_b = 4)
footer("calcofi.io/docs/metadata.html")
notes(
  sprintf("One Sheet per provider (%d: calcofi, swfsc, sio, cce-lter, cdfw, farallon, sccoos) in the Shared Drive folder 'questions', each titled 'CalCOFI integrated database — questions for <provider>'. Three kinds of tab: one per dataset (questions: edit answer, status, answered_date, who), metadata (long form, tiered required → recommended → optional: edit value; edited_by and edited_date stamp themselves), and on the CalCOFI Sheet a holdings tab, the team's triage board. Everything else is protected on purpose. Service-account auth; pull writes only those columns back into the versioned record, validated, one commit.", N_SHEET),
  "The record is git: metadata/{provider}/{dataset}/dataset_meta.yml (the descriptive half) and questions.csv. The monthly release measures coverage, counts and source-access dates and regenerates every public surface from the record: the dataset page, datasets.json, EML, STAC, DCAT, the DwC-A / EDI package / ERDDAP globals. The weekly observer (observe_distributions()) files a proposed question when a portal's record drifts.",
  "This is where the two-sheets question gets asked (the asks slide): Erin's attribution sheet stays the outreach form for this round and is imported; from the next round the per-provider Sheets are the one place — or we add her columns to those Sheets now. The long version is calcofi.io/docs/metadata.html.",
  "Sources: metadata/questions_sheets.yml (count read at build time); scripts/sync_questions_sheets.R and sync_dataset_meta_sheets.R; the screenshot is the CalCOFI Sheet's metadata tab (Chrome, 2026-09-07).")

# ── 21 · the revamped docs ──────────────────────────────────────────────────────────────────────
new_slide(); headline("documentation · calcofi.io/docs",
                      sprintf("%s parts, and a door for each of us", tools::toTitleCase(DOCS$n_parts_w)))
g1 <- fit_img(CROP["d_index"], M, TOP_BODY - 0.05, 4.60, 3.30, align = "left")
caption("calcofi.io/docs — Start here: the sidebar's five parts, and every number on the page read from the release when the book renders.",
        M, g1["top"] + g1["h"] + 0.06, 4.60)
dx <- M + 4.85; dw <- 3.55
g2 <- fit_img(assets["d_doors"], dx, TOP_BODY - 0.05, dw, 2.35, align = "left")
caption("\"Which door is yours\" — six rows, each naming where to start and what to read next.", dx, g2["top"] + g2["h"] + 0.05, dw)
g3 <- fit_img(assets["d_system"], dx, 4.70, dw, 0.85, align = "left")
caption("The system, read left to right along the DMP's five phases (docs/diagrams/system.svg).",
        dx, g3["top"] + g3["h"] + 0.05, dw)
rx <- M + 8.65; rw <- W - M - rx
bullets(c(
  sprintf("%d numbered chapters in five parts along the DMP's phases — %s — plus %d appendices.",
          DOCS$n_ch, paste(DOCS$parts, collapse = " · "), DOCS$n_app),
  "Start here answers \"which door is yours\": curious or scientist · data scientist · data provider · CTD team · data team and product builders · reporting on the program.",
  sprintf("Prose is authored, facts are generated: %d numbered figures and %d tables, every count read from the release and the registries at render time.",
          DOCS$n_fig, DOCS$n_tbl),
  "Diagrams that pan, zoom and open full-screen — the system figure here, the core ERD in The database.",
  "One source, three formats: HTML light and dark, PDF and DOCX from the sidebar.",
  "The same feedback button as the Explorer, on every page."),
  rx, TOP_BODY - 0.05, rw, 4.7, fp_t = fp(11.5), pad_b = 6)
footer("calcofi.io/docs/  ·  explore.html · db.html · metadata.html · dmp.html · status.html")
notes(
  sprintf("The docs were one long page; they are now a book with %d parts and %d numbered chapters plus %d appendices, and the parts are the data management plan's own five phases — %s — so the documentation and the plan cannot describe different systems.",
          DOCS$n_parts, DOCS$n_ch, DOCS$n_app, paste(DOCS$parts, collapse = ", ")),
  "The first page is an orientation, not an introduction: 'Which door is yours' is a table with a row per person — curious about the ocean or a scientist who wants to see the data; a data scientist writing queries; a data provider now or in future; the CTD team; the data team or someone building a CalCOFI.io product; and reporting on the program. Each row names one chapter to start with and two to read next. Say your own row out loud when you present this.",
  sprintf("How it stays true: prose is authored, facts are generated. Every table of counts, columns, keys, datasets, portals or statuses is read from the promoted release's own sidecars and the workflows registries when the book renders — %d numbered figures and %d numbered tables, none of them typed. Where a chapter states a rule, the rule is one the pipeline enforces, and the chapter says how.",
          DOCS$n_fig, DOCS$n_tbl),
  "Three formats from one source: HTML in light and dark (the same ?theme= contract as every other product), and a PDF and a DOCX built by a second CI job and linked from the sidebar, so a Word reader is not left out. The diagrams are SVG with pan, zoom and full-screen — no headless Chrome in CI, which is what used to break the build. And every page carries the same feedback bubble as the Explorer: annotate a screenshot of the page and it reaches the Sheet, our inboxes and a public issue in CalCOFI/docs.",
  sprintf("Sources: ../docs/_quarto.yml (parts, chapters and appendices counted at build time), ../docs/*.qmd ({#fig- and {#tbl- labels counted: %d and %d), and ../docs/index.qmd for the wording of the doors table; the shots are of the locally rendered book (../docs/_book) on 2026-09-08, and the system figure is ../docs/diagrams/system.svg rendered with rsvg-convert (the core ERD, diagrams/core_erd.svg, is rendered too and lives in the Database chapter — it is too dense to read on a slide).",
          DOCS$n_fig, DOCS$n_tbl))

# ── 22 · asks ───────────────────────────────────────────────────────────────────────────────────
new_slide(); headline("decisions and asks", "Decisions and asks, with an owner each")
asks <- data.frame(
  Ask   = c("Long-term target for data@calcofi.io (forwarding live since 9/7)",
            "Which holdings stay public",
            "One outreach channel for providers",
            "Who holds the CalCOFI EDI account",
            "OBIS: one IPT resource per bio dataset, and a contact per resource",
            "CalOOS ↔ our ERDDAP",
            "Explorer review",
            "Crab answers from CDFW",
            "calcofi.org ↔ calcofi.io links"),
  Owner = c("Erin", "Erin, Mark", "Erin, Ben", "Erin (recommended)", "Erin (contacts), Ben (upload)",
            "Erin → Iwen Su", "Erin, Betty — by a date", "Betty (Sept 16)", "Erin, Mark, with the SIO web team"),
  `Proposed answer already on the table` = c(
    "A Google Group calcofi-data@ucsd.edu, or one ITS ticket; the public address never changes",
    sprintf("All %d are public archives already; visibility: internal hides one from every public surface in one line", REL$n_hold),
    "Erin's attribution sheet stays the form this round and is imported; from the next round the per-provider Sheets are the one place",
    "Scope edi, one package per program dataset; CCE-LTER's stay in knb-lter-cce — ask Kathy / Mike once",
    sprintf("%s archives staged; existing OBIS records checked with their owners first", FT$dwca),
    "Does CalOOS harvest erddap.calcofi.io directly; the CoastWatch handoff; propagation to data.ioos.us",
    "Use the feedback button; 30 minutes each; Betty as second pair of eyes on the code",
    "The ingest already ships examined-only; the remaining questions are in the cdfw Sheet",
    "The hero's pins already link to calcofi.org's method pages; a link back from calcofi.org/data to calcofi.io/datasets/{key}/ closes the loop"),
  check.names = FALSE)
doc <- ph_with(doc, ft_tbl(asks, size = 11, widths = c(3.6, 2.2, 6.33)), location = loc(M, TOP_BODY - 0.05, W - 2 * M, 5.1))
footer("calcofi.io/docs/metadata.html · calcofi.io/datasets/ · calcofi.io/explore")
notes(
  "Nine lines, no more; each small, specific and dated, with an owner and a proposed answer already on the table. Read the owner first.",
  "1 data@calcofi.io: forwarding to the three of us is live since 9/7; the public address is already printed in the catalog and metadata we publish and never changes — Erin, a Google Group calcofi-data@ucsd.edu as its long-term target, or one ITS ticket? 2 Holdings: all public archives already; the switch exists and is offered, not applied. 3 Outreach: Erin's attribution sheet is respected this round (import_caloos_sheet.R); per-provider Sheets from the next round, or her columns added to them now. 4 EDI account: Erin recommended; one package per program dataset; CCE-LTER's packages stay in knb-lter-cce. 5 OBIS: archives staged; existing records checked with their owners first. 6 CalOOS: does it harvest erddap.calcofi.io directly, the CoastWatch handoff, propagation to data.ioos.us. 7 Explorer review: the feedback button, 30 minutes each, Betty as second pair of eyes on the code. 8 Crab: CDFW's answers are due Sept 16; the ingest already ships examined-only. 9 calcofi.org ↔ calcofi.io: cosmetic, whenever the web team has a slot.",
  "Sources: plan § B 'Asks (slide 15)'.")

# ── 23 · closing ────────────────────────────────────────────────────────────────────────────────
new_slide()
rect(0, 0, W, H, NAVY)
fit_img(assets["logo_lt"], M, 0.55, 3.0, 0.72, align = "left", frame = FALSE)
txt("Software is no longer the bottleneck.", M, 2.1, W - 2 * M, 1.9, fp_t = fp(54, WHITE, DISPLAY), pad_b = 0, ls = 0.95)
rect(M, 4.15, 1.6, 0.06, YELLOW)
txt("Building is now fast. Deciding what to build, checking it, and telling people about it are what set the pace. That is where I need you.",
    M, 4.35, W - 2 * M, 0.9, fp_t = fp(20, WATER), pad_b = 0, ls = 1.1)
txt("Proposed cadence: a monthly release · a 20-minute demo in the data meeting when something ships · questions to providers only through the Sheets",
    M, 5.9, W - 2 * M, 0.5, fp_t = fp(14, STONE), pad_b = 0)
txt("Ben Best · Ocean Metrics · ben@oceanmetrics.io · data@calcofi.io", M, 6.75, W - 2 * M, 0.35, fp_t = fp(12, STONE), pad_b = 0)
notes(
  "Said once, evenly: building is now fast. Deciding what to build, checking it, and telling people about it are what set the pace. That is where I need you.",
  "Then the cadence, one line: a monthly release (already the rhythm since August), a 20-minute demo in the data meeting when something ships, and questions to providers only through the Sheets. Then stop and listen.",
  "Sources: plan § B slide 16 and 'Proposed cadence'.")

# ── A1 · appendix: URLs ─────────────────────────────────────────────────────────────────────────
new_slide(); headline("appendix", "Every URL shown")
urls <- list(
  c("The front door",            "calcofi.io"),
  c("The Explorer",              "calcofi.io/explore  ·  ?lens=contour&var=temperature  ·  ?modal=sources"),
  c("Status page",               "status.calcofi.io"),
  c("Datasets catalog",          "calcofi.io/datasets/  ·  calcofi.io/datasets/swfsc_ichthyo/"),
  c("Machine surfaces",          "calcofi.io/stac/  ·  calcofi.io/data.json  ·  calcofi.io/datasets/sitemap.xml"),
  c("Publishers (notebooks)",    "calcofi.io/workflows/publish_to-{obis,edi,erddap,netcdf}.html"),
  c("ERDDAP · netCDF",           "erddap.calcofi.io/erddap/  ·  storage.calcofi.io/calcofi-files-public/netcdf/"),
  c("Release DOI",               sprintf("doi.org/%s  (concept: doi.org/%s)", REL$doi, REL$cdoi)),
  c("Release notes",             "storage.calcofi.io/calcofi-db/ducklake/releases/RELEASES.html"),
  c("Schema",                    "calcofi.io/db-schema/"),
  c("Packages",                  "calcofi.io/calcofi4r  ·  calcofi.io/calcofi4py"),
  c("Brand kit",                 "calcofi.io/brand/v2/  ·  calcofi.io/brand/v2/icons/"),
  c("Documentation",             "calcofi.io/docs/  ·  /explore.html  ·  /cite.html  ·  /dmp.html  ·  /status.html"),
  c("Metadata & the ingest loop","calcofi.io/docs/metadata.html  ·  calcofi.io/docs/portals.html"),
  c("Feedback / issues",         "the speech bubble in any header  ·  github.com/CalCOFI/{explore,CalCOFI.github.io,docs}/issues"),
  c("Contact",                   "data@calcofi.io"))
blocks <- lapply(urls, function(u) fpar(ftext(paste0(u[1], "   "), fp(12.5, GRAY, bold = TRUE)),
                                        ftext(u[2], fp(12.5, BLUE)), fp_p = par_l(5)))
txt(blocks, M, TOP_BODY, W - 2 * M, 5.1)
footer("calcofi.io")
notes("Every URL shown in the deck, for the PDF. All answered 200/206 (ranged GET) on 2026-09-07; doi.org answers 302 to the Zenodo record.")

# ── write ───────────────────────────────────────────────────────────────────────────────────────
out <- "presentations/2026-09-08_CalCOFI.io_update.pptx"
print(doc, target = out)

# officer writes every manual shape as a placeholder (<p:ph>), so an empty rectangle shows
# "Click to edit Master text styles" in PowerPoint's edit view, LibreOffice and Google Slides.
# Every shape carries its own <a:xfrm> and run properties, so dropping the tag changes nothing else.
strip_ph <- function(pptx) {
  pptx <- normalizePath(pptx); tmp <- file.path(tempdir(), "strip_ph")
  unlink(tmp, recursive = TRUE); dir.create(tmp); unzip(pptx, exdir = tmp)
  for (f in list.files(file.path(tmp, "ppt/slides"), pattern = "^slide[0-9]+\\.xml$", full.names = TRUE)) {
    x <- readLines(f, warn = FALSE, encoding = "UTF-8")
    x <- gsub("<p:ph[^>]*/>", "", x)
    writeLines(enc2utf8(x), f, useBytes = TRUE)
  }
  unlink(pptx); owd <- setwd(tmp); on.exit(setwd(owd), add = TRUE)
  zip(pptx, list.files(".", recursive = TRUE, all.files = TRUE, include.dirs = FALSE), flags = "-r9Xq")
}
strip_ph(out)
cat("wrote", out, "\n")
cat("slides:", length(doc), "| size:", paste(round(unlist(slide_size(doc)[c("width", "height")]), 3), collapse = " x "), "in\n")
cat("live facts:", REL$version, "|", REL$n_ds, "datasets |", rows_fmt, "rows |", gb_fmt, "| explore", ms(UP$expl_all),
    "| hex", ms(UP$hex_all), "| uptime pulled", UP$pulled, "| erddap", ERD_N_TXT, "| calcofi4r", PKG$r, "| calcofi4py", PKG$py, "\n")
