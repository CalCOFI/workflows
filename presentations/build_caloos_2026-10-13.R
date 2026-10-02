# Build Ben's slides for Mark Gold's CalOOS summit keynote (2026-10-13), 16:9, brand v2, officer + png.
#
# Plan: .claude/plans/2026-10-02 After v2026.10.01 ... agent-scaled.md, WS-G (brief .claude/plans_todo/WS-1002G.md).
# Skeleton (Erin's "Slides for Mark_Keynote_CalOOS summit"): 1 Statewide monitoring inventory (Betty) | 2 Getting
# CalCOFI-platform data into the CalOOS portal (Erin) | 3 FAIR vision (Ben) | 4 Integrated database (Ben) |
# 5 Data finder app (Betty) | 6 Explore data (Ben) | 7 CTD data visualizer (Ben) | 8 Observing the upcoming El Niño (offered).
#
# Every number on a slide is read from the promoted release's record (data/releases/<version>/{datasets,catalog,
# coverage,measurements}.json), the docs book's registry (portal.csv) and the docs' "Which door is yours" table.
# The two facts that live nowhere in those records (the El Niño cruise dates, the 1993-2013 baseline printed in the
# ctd-transects shot) are named in CRUISE and in the notes with their source.
#
# Run from the workflows/ root:  Rscript presentations/build_caloos_2026-10-13.R
# Outputs: presentations/2026-10-13 CalOOS keynote - CalCOFI.io slides.pptx
#          (PNGs: presentations/caloos_2026-10-13/slide_NN.png, made by the render step at the end if soffice exists)
suppressMessages({
  library(officer); library(png); library(jsonlite)
})
stopifnot("run from the workflows/ root" = dir.exists("presentations/assets"))

# helpers to find sibling checkouts (the main tree or a worktree under .claude/worktrees/) ----
first_existing <- function(paths, what) {
  hit <- paths[file.exists(paths)]
  if (!length(hit)) stop(sprintf("cannot find %s in: %s", what, paste(paths, collapse = ", ")))
  hit[[1]]
}
DOCS <- first_existing(c(Sys.getenv("CALCOFI_DOCS_DIR", "../docs"), "../docs", "../../../../docs"),
                       "the docs checkout")

# the release record (read, never typed) ----
rel_dirs <- sort(list.files("data/releases", pattern = "^v[0-9]{4}\\.[0-9]{2}\\.[0-9]{2}$"))
VERSION  <- Sys.getenv("CALCOFI_DECK_RELEASE", rel_dirs[length(rel_dirs)])
RD       <- file.path("data/releases", VERSION)
rj       <- function(f) read_json(file.path(RD, f), simplifyVector = FALSE)
ds_rec   <- rj("datasets.json"); cat_rec <- rj("catalog.json"); cov_rec <- rj("coverage.json"); meas_rec <- rj("measurements.json")
tbl_rows <- function(nm) { h <- Filter(function(t) identical(t[["name"]], nm), cat_rec[["tables"]]); stopifnot(length(h) == 1); h[[1]][["rows"]] }
ref_rows <- function(k)  { h <- Filter(function(r) identical(r[["key"]], k), ds_rec[["reference"]]); stopifnot(length(h) == 1); h[[1]][["rows"]] }
fmt_int  <- function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)
fmt_m    <- function(x) if (x >= 1e8) sprintf("%s M", format(round(x / 1e6), trim = TRUE)) else sprintf("%.1f M", x / 1e6)

year_min   <- min(unlist(lapply(ds_rec[["datasets"]], function(d) d[["coverage"]][["year_min"]])))
rel_year   <- as.integer(substr(ds_rec[["release"]][["release_date"]], 1, 4))
N <- list(
  version    = cat_rec[["version"]],
  doi        = cat_rec[["doi"]],
  since      = year_min,
  years      = rel_year - year_min,                                     # the landing band's rule (datasets.rb numbers)
  datasets   = ds_rec[["counts"]][["datasets"]],
  cruises    = ref_rows("cruise"),
  species    = sum(vapply(cov_rec[["taxa"]], function(t) identical(t[["rank"]], "Species"), logical(1))),
  organism   = tbl_rows("obs_bio"),
  measured   = sum(vapply(c("obs_env", "obs_ctd_full", "obs_mets_full"), tbl_rows, numeric(1))),
  meas_keys  = meas_rec[["counts"]][["measurements"]])
stopifnot(N$years > 70, N$datasets > 10, N$species > 500, !is.null(N$doi))

# El Niño cruise: not in any release record. Source: Tactiq 9/23 DMP meeting, the 10/1 deck (slide 13), plan 2026-10-02.
CRUISE <- list(leaves = "31 October", returns = "10 November", source = "Tactiq 9/23 DMP meeting; 2026-10-01 deck slide 13")

# the docs book's "Which door is yours" table and the portal registry ----
idx   <- readLines(file.path(DOCS, "index.qmd"), warn = FALSE, encoding = "UTF-8")
i0    <- grep("^## Which door is yours", idx); i1 <- grep("\\{#tbl-doors\\}", idx)
rows  <- idx[(i0 + 1):i1]; rows <- rows[grepl("^\\|", rows) & !grepl("^\\|---", rows)][-1]   # drop the header row
DOORS <- do.call(rbind, lapply(strsplit(rows, "\\|"), function(p) {
  link <- function(s) sub("^\\s*\\[([^]]+)\\].*$", "\\1", trimws(s))
  data.frame(who = trimws(p[2]), door = link(p[3]), stringsAsFactors = FALSE)
}))
stopifnot(nrow(DOORS) == 6)
# plain-English faces for the six doors (keyed by the door's own name, which the check below ties to the docs)
FACE <- list(
  "Explore"                      = c("Curious about the ocean off California, or a scientist",   "see the data on a map, in a browser"),
  "Access the data"              = c("A data scientist writing queries",                         "R, Python and open files"),
  "Providing data to CalCOFI"    = c("A data provider, now or in future",                        "send us your data, step by step"),
  "CTD QA/QC, start to release"  = c("On the CTD team",                                          "quality control, cast to release"),
  "Ingesting a dataset"          = c("On the data team, or building a CalCOFI product",          "add a dataset, build an app"),
  "The data management plan"     = c("Reporting on the program",                                 "the plan and its status"))
stopifnot(all(DOORS$door %in% names(FACE)))
portal <- read.csv(file.path(DOCS, "data/registry/portal.csv"), stringsAsFactors = FALSE)
stopifnot(all(c("caloos", "obis", "edi", "erddap", "google-dataset-search", "data-gov") %in% portal$portal))
PORTALS <- list(   # key, short name, one plain line; the registry's key must exist (checked above)
  list("caloos",   "CalOOS",             "California's ocean portal"),
  list("obis",     "OBIS",               "global biodiversity archive"),
  list("edi",      "EDI",                "environmental data archive"),
  list("erddap",   "ERDDAP",             "data servers, ours too"),
  list("google-dataset-search", "Google Dataset Search", "and data.gov, via search"))

# brand v2 (calcofi.io/brand/v2/theme.css, light) ----
NAVY   <- "#182b49"; BLUE  <- "#00629b"; YELLOW <- "#ffcd00"; SAND <- "#f5f0e6"
GOLD   <- "#c69214"; GRAY  <- "#66686a"; STONE  <- "#b6b1a9"; WHITE <- "#ffffff"
RULE   <- "#dddddd"; DARK  <- "#0f1a2e"
SANS   <- "Source Sans 3"; DISPLAY <- "Teko"

# slide geometry (in) ----
W <- 13.333; H <- 7.5; M <- 0.6
TOP_BODY <- 1.85

A <- function(f) file.path("presentations/assets", f)
assets <- c(
  template = A("template_16x9.pptx"), logo = A("logo_calcofi_h.png"), logo_lt = A("logo_calcofi_h_light.png"),
  stations = A("caloos/explore_stations.png"), lenses = A("caloos/explore_sentence_lenses.png"),
  hexagons = A("caloos/explore_hexagons.png"), contours = A("caloos/explore_contours.png"),
  cruises  = A("caloos/explore_cruises.png"),  regions  = A("caloos/explore_regions.png"),
  section  = A("caloos/explore_sections_line90.png"),
  transect = A("caloos/ctd_transects_line90_anomaly.png"),
  before   = A("caloos/ctd_line90_before.png"), after = A("caloos/ctd_line90_after.png"))
stopifnot(all(file.exists(assets)))

# officer helpers (from build_update_2026-10-01.R: same template, logo, palette) ----
doc <- read_pptx(assets["template"])
MST <- "Office Theme"
n_slide <- 0L

fp <- function(size = 15, color = NAVY, family = SANS, bold = FALSE, italic = FALSE)
  fp_text(font.family = family, font.size = size, color = color, bold = bold, italic = italic)
fp_h    <- fp(36, NAVY, DISPLAY)
fp_eye  <- fp(11, GRAY, bold = TRUE)
fp_sm   <- fp(11, GRAY)
fp_link <- fp(11, BLUE)
par_l <- function(pad_b = 5, align = "left", ls = 1.05)
  fp_par(text.align = align, padding.bottom = pad_b, padding.top = 0, padding.left = 0, padding.right = 0,
         line_spacing = ls)

new_slide <- function(layout = "Blank") { doc <<- add_slide(doc, layout, MST); n_slide <<- n_slide + 1L; invisible(NULL) }
loc <- function(left, top, width, height, ...) ph_location(left = left, top = top, width = width, height = height, ...)
rect <- function(left, top, width, height, bg, geom = "rect", ln_col = bg) {
  doc <<- ph_with(doc, empty_content(),
                  location = loc(left, top, width, height, bg = bg, geom = geom, ln = sp_line(color = ln_col, lwd = 0.75)))
}
txt <- function(lines, left, top, width, height, fp_t = fp(15), align = "left", pad_b = 5, ls = 1.05, ...) {
  blocks <- if (is.list(lines)) lines else
    lapply(lines, function(s) fpar(ftext(s, fp_t), fp_p = par_l(pad_b, align, ls)))
  doc <<- ph_with(doc, do.call(block_list, blocks), location = loc(left, top, width, height, ...))
}
img_dim <- function(path) { d <- dim(readPNG(path)); c(w = d[2], h = d[1]) }
fit_img <- function(path, left, top, w, h, align = "center", frame = TRUE) {
  d <- img_dim(path); r <- unname(d["w"] / d["h"])
  if (w / h > r) { ih <- h; iw <- h * r } else { iw <- w; ih <- w / r }
  dx <- switch(align, left = 0, center = (w - iw) / 2, right = w - iw)
  ln <- if (frame) sp_line(color = RULE, lwd = 0.75) else NULL
  doc <<- ph_with(doc, external_img(path, width = iw, height = ih, unit = "in"),
                  location = loc(left + dx, top, iw, ih, ln = ln))
  invisible(c(left = unname(left + dx), top = unname(top), w = unname(iw), h = unname(ih)))
}
notes <- function(...) doc <<- set_notes(doc, value = paste(c(...), collapse = "\n\n"), location = notes_location_type("body"))
RESHOOT <- function(url, why) sprintf("RESHOOT 10/5-10/6: %s -- %s", url, why)
RESHOOT_LOG <- list()                                   # collected for the hand-back (slide, url, why)
log_reshoot <- function(url, why) RESHOOT_LOG[[length(RESHOOT_LOG) + 1]] <<- list(slide = n_slide, url = url, why = why)

headline <- function(eyebrow, h) {
  txt(toupper(eyebrow), M, 0.32, W - 2 * M - 1.7, 0.3, fp_t = fp_eye, pad_b = 0)
  txt(h, M, 0.56, W - 2 * M - 1.7, 1.25, fp_t = fp_h, pad_b = 0, ls = 0.9)
  fit_img(assets["logo_lt"], W - M - 1.55, 0.36, 1.55, 0.37, align = "right", frame = FALSE)
}
footer <- function(url = "calcofi.io") {
  rect(M, 6.93, W - 2 * M, 0.02, NAVY)
  txt(url, M, 7.0, 8.5, 0.32, fp_t = fp_link, pad_b = 0)
  txt(sprintf("CalOOS summit · 2026-10-13 · %d", n_slide), W - M - 4.5, 7.0, 4.5, 0.32, fp_t = fp_sm, align = "right", pad_b = 0)
}
stat_tile <- function(big, small, left, top, w = 3.9, h = 1.7, bg = SAND, big_col = BLUE) {
  rect(left, top, w, h, bg, geom = "roundRect")
  txt(big,   left + 0.25, top + 0.1,  w - 0.5, 0.95, fp_t = fp(54, big_col, DISPLAY), pad_b = 0)
  txt(small, left + 0.25, top + 1.05, w - 0.5, 0.6,  fp_t = fp(15, NAVY), pad_b = 0)
}
rich <- function(runs, pad_b = 0, align = "left", ls = 1.05)
  do.call(fpar, c(runs, list(fp_p = par_l(pad_b, align, ls))))

# ── 1 · title ──────────────────────────────────────────────────────────────────────────────────
new_slide()
rect(0, 0, W, H, DARK)
fit_img(assets["logo"], M, 0.6, 3.2, 0.8, align = "left", frame = FALSE)
txt("MARK GOLD · CALOOS SUMMIT KEYNOTE · 13 OCTOBER 2026", M, 2.3, 11, 0.4, fp_t = fp(13, YELLOW, bold = TRUE), pad_b = 0)
txt(sprintf("%d years of one ocean, now one record, with a door for everyone", N$years),
    M, 2.7, 11.8, 1.9, fp_t = fp(54, WHITE, DISPLAY), pad_b = 0, ls = 0.9)
txt("Draft 1 from Ben Best for Erin's deck, sections 3, 4, 6, 7 and 8 · calcofi.io", M, 4.95, 11, 0.4, fp_t = fp(18, STONE), pad_b = 0)
notes(sprintf("Opening line for Mark: for %d years, ships have gone out to the same stations off California and measured the same ocean. Today I want to show what happens when all of it, from every team that has ever sampled there, lives in one place that anyone can open.", N$years),
      "The story in five beats, which the slides follow in order: the ocean's record has been scattered across files; we turn each dataset into one record; every audience gets its own door; the same water can be seen four ways; and in two weeks a ship leaves to watch an El Niño, and we want you to see it as it happens.",
      "For Ben: this is a first full draft. Sections 1, 2 and 5 are titled placeholders for Betty and Erin. The Explorer shots are from the 9/8 and 9/23 decks and carry a visible old release stamp; each such slide has a RESHOOT line in these notes (and the list is in the hand-back).")

# ── 2 · section 1 placeholder (Betty) ──────────────────────────────────────────────────────────
ph_slide <- function(num, title, owner, body_lines, url = "calcofi.io") {
  new_slide()
  headline(sprintf("Part %d · %s", num, owner), title)
  rect(M, TOP_BODY, W - 2 * M, 4.55, SAND)
  txt("PLACEHOLDER", M + 0.35, TOP_BODY + 0.3, 6, 0.3, fp_t = fp_eye, pad_b = 0)
  txt(body_lines, M + 0.35, TOP_BODY + 0.75, W - 2 * M - 0.7, 3.5, fp_t = fp(20, NAVY), pad_b = 10)
  footer(url)
}
ph_slide(1, "Statewide monitoring inventory", "Betty", c(
  "Betty's slides go here.",
  "Owner and content per Erin's skeleton: Betty."))
notes("Placeholder for Betty's part 1, the statewide monitoring inventory. Ben has not written it.")

# ── 3 · section 2 placeholder (Erin) with her message ──────────────────────────────────────────
new_slide()
headline("Part 2 · Erin", "Getting data collected on the CalCOFI platform into the CalOOS portal")
rect(M, TOP_BODY, W - 2 * M, 2.1, SAND)
txt("PLACEHOLDER · ERIN'S SLIDE", M + 0.35, TOP_BODY + 0.25, 8, 0.3, fp_t = fp_eye, pad_b = 0)
txt("This is not the data. It is metadata.", M + 0.35, TOP_BODY + 0.65, W - 2 * M - 0.7, 0.6, fp_t = fp(30, NAVY, DISPLAY), pad_b = 0)
txt("CalOOS links to the authoritative dataset. Nothing is copied.", M + 0.35, TOP_BODY + 1.3, W - 2 * M - 0.7, 0.6, fp_t = fp(22, BLUE, bold = TRUE), pad_b = 0)
txt(c("Erin's note on this slide in the skeleton: \"Key point is that this is not the data; metadata.\"",
      "Ben's part 3 (the next slides) ends on the same message, so the two parts meet."),
    M, TOP_BODY + 2.4, W - 2 * M, 2.0, fp_t = fp(16, NAVY), pad_b = 8)
footer("data.caloos.org")
notes("Erin owns this slide. Her note in the skeleton says: 'Key point is that this is not the data; metadata.' That is kept on the slide as the working title.",
      "Say it plainly: CalOOS is a front window. A person finds CalCOFI data there, and a click takes them to the dataset where we keep it. Nothing is copied into CalOOS, so there is only ever one version of the truth.")

# ── 4 · part 3: the FAIR vision ────────────────────────────────────────────────────────────────
new_slide()
headline("Part 3 · the FAIR vision", sprintf("%d years of one ocean, kept in many files", N$years))
txt("Findable, accessible, interoperable, reusable: three steps get there.", M, TOP_BODY - 0.05, W - 2 * M, 0.4, fp_t = fp(18, GRAY), pad_b = 0)
step_box <- function(i, title, body, x) {
  w <- 3.75
  rect(x, 2.5, w, 3.2, SAND)
  rect(x, 2.5, w, 0.08, if (i == 2) YELLOW else BLUE)
  txt(sprintf("%d", i), x + 0.3, 2.7, 0.8, 0.7, fp_t = fp(44, BLUE, DISPLAY), pad_b = 0)
  txt(toupper(title), x + 0.95, 2.85, w - 1.1, 0.6, fp_t = fp(28, NAVY, DISPLAY), pad_b = 0)
  txt(body, x + 0.3, 3.65, w - 0.6, 2.0, fp_t = fp(16, NAVY), pad_b = 0, ls = 1.1)
}
x0 <- M; gap <- (W - 2 * M - 3 * 3.75) / 2
step_box(1, "Ingest",    "Each provider sends files in their own format. We read every one the same way and keep their answers to our questions with it.", x0)
step_box(2, "Publish",   "From one record per dataset we generate everything a portal needs: the description, the citation, the DOI.", x0 + 3.75 + gap)
step_box(3, "Visualize", "People open the data in a browser, or in R and Python. Everyone sees the same numbers.", x0 + 2 * (3.75 + gap))
for (xa in c(x0 + 3.75 + gap / 2 - 0.15, x0 + 2 * 3.75 + 1.5 * gap - 0.15)) rect(xa, 3.95, 0.3, 0.24, STONE, geom = "rightArrow")
txt("A release is cut only after its keys and its bounds have been checked.", M, 5.95, W - 2 * M, 0.4, fp_t = fp(16, BLUE, bold = TRUE), pad_b = 0)
footer("calcofi.io/docs")
notes("Mark: this is the whole idea in three words. Ingest, publish, visualize.",
      "Ingest: a ship's measurements, a net's catch, a whale survey. They each arrive in their own shape. We read every one the same way, and when we are unsure what a column means, we ask the provider and keep the answer with the data.",
      "Publish: from that, we produce one record per dataset, written once. Everything a portal needs, including the description and the citation, is generated from that single record, so a description cannot disagree with itself in two places.",
      "Visualize: the same data opens in a web browser with no software, or in R and Python for people who analyse it. Same numbers everywhere.",
      "The sentence at the bottom is a rule the pipeline enforces: a release is built only after the keys that join the datasets, and the limits on what a measurement can be, pass their checks.",
      "Sources: ../docs/index.qmd (the Ingest, Integrate, Publish, Visualize paragraphs) and ../docs/diagrams/system.mmd.")

# ── 5-8 · the centrepiece: who you are -> your door -> one database -> portals, four build steps ─
COL <- list(who = c(M, 3.0), door = c(3.9, 3.0), db = c(7.2, 2.6), portal = c(10.1, W - M - 10.1))
ROW0 <- 2.15; ROW_H <- 0.62; ROW_GAP <- 0.10; ROWS_END <- ROW0 + 6 * ROW_H + 5 * ROW_GAP
arch <- function(step) {
  new_slide()
  ttl <- c("Who needs CalCOFI data?", "Everyone gets a door", "Behind every door, one database", "CalOOS and the portals read from it")[step]
  headline(sprintf("Part 3 · who you are, your door, one database, the portals · step %d of 4", step), ttl)
  head_lab <- c("WHO YOU ARE", "YOUR DOOR", "ONE DATABASE", "THE PORTALS")
  for (k in seq_len(step)) {
    x <- COL[[k]][1]
    txt(head_lab[k], x, 1.72, COL[[k]][2], 0.3, fp_t = fp_eye, pad_b = 0)
    if (k == step) rect(x, 2.02, 0.7, 0.05, YELLOW)             # the one accent: the column that just appeared
  }
  row_y <- function(i) ROW0 + (i - 1) * (ROW_H + ROW_GAP)
  for (i in 1:6) {                                              # who you are
    rect(COL$who[1], row_y(i), COL$who[2], ROW_H, SAND, geom = "roundRect")
    lab <- FACE[[DOORS$door[i]]][1]; one_line <- nchar(lab) <= 34       # centre a one-line label by hand (no anchor in officer)
    txt(lab, COL$who[1] + 0.15, row_y(i) + if (one_line) 0.17 else 0.06, COL$who[2] - 0.3, ROW_H - 0.1, fp_t = fp(12.5, NAVY), pad_b = 0, ls = 1)
  }
  if (step >= 2) for (i in 1:6) {                               # your door
    rect(COL$who[1] + COL$who[2] + 0.04, row_y(i) + ROW_H / 2 - 0.1, 0.22, 0.2, STONE, geom = "rightArrow")
    rect(COL$door[1], row_y(i), COL$door[2], ROW_H, WHITE, geom = "roundRect", ln_col = BLUE)
    txt(list(rich(list(ftext(DOORS$door[i], fp(13, BLUE, bold = TRUE)))),
             rich(list(ftext(FACE[[DOORS$door[i]]][2], fp(10.5, GRAY))))),
        COL$door[1] + 0.15, row_y(i) + 0.06, COL$door[2] - 0.3, ROW_H - 0.1, ls = 1)
  }
  if (step >= 3) {                                              # one database
    for (i in 1:6) rect(COL$door[1] + COL$door[2] + 0.04, row_y(i) + ROW_H / 2 - 0.1, 0.22, 0.2, STONE, geom = "rightArrow")
    rect(COL$db[1], ROW0, COL$db[2], ROWS_END - ROW0, NAVY)
    txt(c("ONE", "DATABASE"), COL$db[1] + 0.2, ROW0 + 0.2, COL$db[2] - 0.4, 1.2, fp_t = fp(22, WHITE, DISPLAY), pad_b = 0, ls = 0.9)
    txt(list(
      rich(list(ftext(sprintf("%d datasets", N$datasets), fp(16, WHITE, bold = TRUE))), pad_b = 2),
      rich(list(ftext(sprintf("%d years", N$years), fp(16, WHITE, bold = TRUE))), pad_b = 10),
      rich(list(ftext("One record per dataset, frozen, fingerprinted and citable with a DOI.", fp(13, WHITE))), pad_b = 10),
      rich(list(ftext(sprintf("Release %s", N$version), fp(11.5, STONE))))),
      COL$db[1] + 0.2, ROW0 + 1.4, COL$db[2] - 0.4, 2.7, ls = 1.1)
  }
  if (step >= 4) {                                              # the portals
    ph <- (ROWS_END - ROW0 - 4 * ROW_GAP) / 5
    for (i in seq_along(PORTALS)) {
      y <- ROW0 + (i - 1) * (ph + ROW_GAP); p <- PORTALS[[i]]; is_caloos <- p[[1]] == "caloos"
      rect(COL$db[1] + COL$db[2] + 0.04, y + ph / 2 - 0.1, 0.22, 0.2, STONE, geom = "rightArrow")
      rect(COL$portal[1], y, COL$portal[2], ph, if (is_caloos) BLUE else WHITE, geom = "roundRect", ln_col = BLUE)
      txt(list(rich(list(ftext(p[[2]], fp(14, if (is_caloos) WHITE else BLUE, bold = TRUE)))),
               rich(list(ftext(p[[3]], fp(11, if (is_caloos) WHITE else GRAY))))),
          COL$portal[1] + 0.15, y + 0.1, COL$portal[2] - 0.3, ph - 0.12, ls = 1)
    }
  }
  cap <- c("Every audience that asks for CalCOFI data, in plain words.",
           "Each one starts at its own door. None needs to know how the rest of it works.",
           "All the doors lead to the same place, so a number is the same wherever you read it.",
           "CalOOS links to the authoritative dataset. Nothing is copied.")[step]
  txt(cap, M, 6.47, W - 2 * M, 0.4, fp_t = fp(15, if (step == 4) BLUE else NAVY, bold = (step == 4)), pad_b = 0)
  footer("calcofi.io/docs · Which door is yours")
}
arch(1)
notes("Start with people, not technology. Who wants CalCOFI data? A curious person or a scientist who wants to see it. A data scientist writing queries. A provider who wants to contribute theirs. The CTD team that checks the instrument data. The team that builds products on it. And the program, which has to report on all of this.",
      "Say: six audiences, and they do not want the same thing. Today most data systems answer one of them and leave the rest to work it out.",
      "Next slide adds the doors. (Build slide 1 of 4: it stays four separate slides so it animates the same way in Google Slides, a PDF or a projector.)",
      "Source: the six rows of 'Which door is yours' (../docs/index.qmd, tbl-doors), read by the build script.")
arch(2)
notes("Now each audience gets a door. Explore is a map in a web browser: you click, you see. Access the data gives R, Python and open files to people who write code. Providing data is the step-by-step guide for a provider. The CTD team has its own route from the instrument to the release. The data team has the guide for adding a dataset. The program has the data management plan and its status page.",
      "Say: the point is that nobody has to read about everything to get what they came for. Each door is a short path.",
      "Arrows run one way on the slide for simplicity; for a provider the arrow means 'your data goes in here'.",
      "Source: ../docs/index.qmd tbl-doors; the door names on the slide are the ones in that table.")
arch(3)
notes("Behind every door is the same database. This is the important idea. It is one integrated record of every dataset: the numbers on this slide (datasets, years) are read from the release itself when the slide is built.",
      "Each release is frozen. Think of it as a sealed, numbered edition: it carries a fingerprint, and it has a DOI so anyone can cite exactly what they used. That is what makes the data findable and reusable, the F and the R of FAIR.",
      "Say: whether you came through the map or through Python, you read the same bytes. A figure in a paper and a figure on the website cannot disagree.",
      "Source: the release record (data/releases/<version>/datasets.json and catalog.json).")
arch(4)
notes("The last step is where CalOOS comes in. From the one database we generate the descriptions that other portals want: CalOOS, the global ocean biodiversity archive OBIS, the EDI environmental archive, ERDDAP data servers, and the ordinary web search that finds datasets.",
      "This is Erin's message, and it is the one to land: CalOOS links to the authoritative dataset. Nothing is copied. The portal is a window onto the CalCOFI record, so the CalCOFI team stays the source and the numbers stay consistent.",
      "Say: write it once, publish everywhere, copy nothing.",
      "Source: ../docs/diagrams/catalog_flow.mmd (the 'Who reads them' column; CalOOS harvests the ERDDAP metadata) and ../docs/data/registry/portal.csv for the portal names.")

# ── 9 · part 4: the integrated database, one number slide ──────────────────────────────────────
new_slide()
headline("Part 4 · the integrated database", "One database, from the first cruise to the next")
tx <- c(M, M + 4.115, M + 8.23); ty <- c(1.85, 3.7)
stat_tile(sprintf("%d", N$years),        sprintf("years of sampling, since %d", N$since), tx[1], ty[1])
stat_tile(sprintf("%d", N$datasets),     "datasets in one database",                  tx[2], ty[1])
stat_tile(fmt_int(N$species),            "species identified",                       tx[3], ty[1])
stat_tile(fmt_m(N$organism),             "organism observations",                    tx[1], ty[2])
stat_tile(fmt_m(N$measured),             "measurement values, from the ocean's chemistry and physics", tx[2], ty[2])
stat_tile(sprintf("%d", N$meas_keys),    "kinds of measurement, each with its own page",              tx[3], ty[2], big_col = GOLD)
rect(M, 5.65, W - 2 * M, 1.1, SAND, geom = "roundRect")
txt(list(rich(list(ftext(sprintf("Release %s · DOI %s", N$version, N$doi), fp(15, BLUE, bold = TRUE))), pad_b = 4),
         rich(list(ftext("Every release is frozen and fingerprinted: cite the DOI, and anyone gets exactly the files we published.", fp(15, NAVY))))),
    M + 0.3, 5.8, W - 2 * M - 0.6, 0.9, ls = 1.05)
footer(sprintf("doi.org/%s", N$doi))
notes(sprintf("Read the tiles left to right. %d years since %d. %d datasets in one database. %s species identified. %s organism observations: a count of an animal or plant in a sample. %s measurement values, mostly from instruments lowered into the water. And %d kinds of measurement, each with its own page.",
              N$years, N$since, N$datasets, fmt_int(N$species), fmt_m(N$organism), fmt_m(N$measured), N$meas_keys),
      "The one sentence for the room: every release is frozen and fingerprinted. In plain words, we publish a numbered edition of the database, and its DOI is a permanent address. Cite it and anyone can fetch exactly what you used, years from now.",
      sprintf("For Ben: every number is read from data/releases/%s/ when the deck is built (years = release year minus the earliest dataset start, the landing page's own rule; species = coverage.json taxa at rank Species; organism observations = obs_bio rows; measurement values = obs_env + obs_ctd_full + obs_mets_full rows, the landing band's definition; kinds = measurements.json counts). Re-run the script after the next release.", N$version))

# ── 10 · part 5 placeholder (Betty) ────────────────────────────────────────────────────────────
ph_slide(5, "Data finder app", "Betty", c(
  "Betty's slides go here.",
  "From Erin's skeleton: \"Curious what data have/are being collected on the CalCOFI platform?\""))
notes("Placeholder for Betty's part 5, the data finder app. Erin's prompt on the slide in the skeleton: 'Curious what data have/are being collected on the CalCOFI platform?'")

# ── 11-17 · part 6: explore, click through ─────────────────────────────────────────────────────
shot_slide <- function(eyebrow, h, img, lines, url, side_note = NULL, box = c(8.4, 4.98)) {
  new_slide()
  headline(eyebrow, h)
  g <- fit_img(assets[img], M, 1.8, box[1], box[2], align = "left")
  x <- g[["left"]] + g[["w"]] + 0.35; w <- W - M - x
  txt(lines, x, 1.85, w, 3.9, fp_t = fp(17, NAVY), pad_b = 12, ls = 1.1)
  rect(x, 5.75, w, 0.85, SAND, geom = "roundRect")
  txt(list(rich(list(ftext("TRY IT", fp_eye)), pad_b = 1), rich(list(ftext(url, fp(12.5, BLUE, bold = TRUE))))),
      x + 0.15, 5.82, w - 0.3, 0.75, ls = 1)
  footer(url)
  invisible(g)
}
EX <- "https://calcofi.io/explore/"
shot_slide("Part 6 · explore · 1 of 7", "Pick what you care about, see every place it was found", "stations",
           c("Choose an organism or a measurement. Each dot is a station where CalCOFI has looked, shaded by how much was there.",
             "Here: Pacific sardine larvae, over all years. The bars along the bottom show when."),
           "calcofi.io/explore")
notes("This is the front page of the Explorer: one map, no software to install. On the left you choose what you care about, an organism or a measurement. Each dot is a station, a place the ship has stopped, and its colour is how much was found there.",
      "The bars along the bottom are time: how many observations were made each year. You can drag to look at just a few years.",
      RESHOOT(paste0(EX, "?tour=off&theme=light"), "the header still reads release v2026.09.06 and this shot predates the 9/16 colour-ramp and 10/1 changes; retake on v2026.10.01, 1600 x 1000 CSS px at 2x"),
      "Shot source: explore/shots/tour/stations_light.png (also in the 9/8 deck, slide 6).")
log_reshoot(paste0(EX, "?tour=off&theme=light"), "stamp reads release v2026.09.06; retake on v2026.10.01")

new_slide()
headline("Part 6 · explore · 2 of 7", "One sentence says what you are looking at")
g <- fit_img(assets["lenses"], M, 1.85, W - 2 * M, 3.7, align = "left")
txt(c("Every word in the sentence is a control: change the organism, the years or the depth and the map follows.",
      "The last chip changes the way of looking. There are six lenses, and your selection stays put when you switch."),
    M, 5.6, W - 2 * M, 1.2, fp_t = fp(17, NAVY), pad_b = 6, ls = 1.1)
footer("calcofi.io/explore")
notes("Here is the idea that makes the Explorer easy for a first-time visitor. The sentence at the top of the screen says, in words, exactly what you are looking at: the animal, its life stage, the statistic, the years, the seasons, the depth. Each part of the sentence is a drop-down.",
      "The menu that is open is the lens picker: stations, hexagons, contours, cruises, regions, sections. Pick a lens and the same question is drawn a different way. The next five slides go through them.",
      RESHOOT(paste0(EX, "?tour=off&theme=light"), "open the sentence, then open the 'View as' chip; the old shot is cropped from the v2026.09.06 build (recipe: explore/shots/tour/README.md, sentence_dropdown.png)"),
      "Shot source: explore/shots/tour/sentence_dropdown.png (9/8 deck, slide 7).")
log_reshoot(paste0(EX, "?tour=off&theme=light + open the sentence, then the View-as chip"), "cropped from the v2026.09.06 build")

shot_slide("Part 6 · explore · 3 of 7", "Hexagons: the pattern, not the points", "hexagons",
           c("The same sardine larvae, pooled into honeycomb cells about 8.5 km across.",
             "Good for seeing where a species lives, without being distracted by single stations."),
           "calcofi.io/explore/?lens=hex")
notes("Same data, different lens. Instead of one dot per station, we pool everything into small hexagons. A hexagon is a fair way to tile a map because every neighbour is the same distance away. You can slide the size up and down to see the pattern at different scales.",
      "Plain version: where do sardine larvae live? Look for the yellow band close to the coast.",
      RESHOOT(paste0(EX, "?lens=hex&res=5&tour=off&theme=light"), "stamp reads release v2026.09.06"),
      "Shot source: explore/shots/tour/hexagons.png (9/8 deck, slide 9).")
log_reshoot(paste0(EX, "?lens=hex&res=5&tour=off&theme=light"), "stamp reads release v2026.09.06")

shot_slide("Part 6 · explore · 4 of 7", "Contours: filling in the water between the stations", "contours",
           c("Temperature, estimated between the stations that measured it, and drawn as a surface.",
             "It is computed in your browser, and the app can show how uncertain the estimate is."),
           "calcofi.io/explore/?lens=contour&var=temperature")
notes("Ships only measure where they stop, so between stations there is a gap. The contour lens fills the gap with a statistical estimate, kriging, which is a standard method in the earth sciences. The white dots are the real measurements; the colours between them are the estimate.",
      "Everything is computed in your own browser, with no server. There is also a view of how uncertain the estimate is, which is the honest part: where the stations are far apart, the picture says so.",
      RESHOOT(paste0(EX, "?lens=contour&var=temperature&grain=station&labels=on&tour=off&theme=light"), "stamp reads release v2026.09.06; the 10/1 release also changed the climatology and the colour ramps"),
      "Shot source: explore/shots/tour/contours_temperature_grid_labels.png (9/8 deck used the 9/7 contour shot).")
log_reshoot(paste0(EX, "?lens=contour&var=temperature&grain=station&labels=on&tour=off&theme=light"), "stamp reads release v2026.09.06")

shot_slide("Part 6 · explore · 5 of 7", "Cruises: follow one voyage", "cruises",
           c("One ship's track, with its stations coloured by temperature.",
             "Underneath, every cruise since the record began is a dot: this voyage in context."),
           "calcofi.io/explore/?lens=cruise&var=temperature")
notes("Here we follow a single voyage, the July 2026 cruise. The track runs across the map and the stations are coloured by temperature.",
      "The big panel underneath is the whole record: each dot is one cruise's average temperature, back to the beginning. The highlighted dot on the right is this cruise, so you can see at a glance whether it was warm or cold for its time. That is the question people will ask about the El Niño cruise.",
      RESHOOT(paste0(EX, "?lens=cruise&var=temperature&tour=off&theme=light"), "stamp reads release v2026.09.06, newest cruise then was 2026-07-3322; retake with the newest cruise on v2026.10.01"),
      "Shot source: explore/shots/tour/cruises.png.")
log_reshoot(paste0(EX, "?lens=cruise&var=temperature&tour=off&theme=light"), "stamp reads release v2026.09.06")

shot_slide("Part 6 · explore · 6 of 7", "Regions: the numbers inside a sanctuary", "regions",
           c("Average sardine larvae inside each National Marine Sanctuary, ranked.",
             "Swap the sanctuaries for another boundary layer and the same data is summarised there."),
           "calcofi.io/explore/?lens=region")
notes("Managers ask about places with names: a sanctuary, a county, a protected area. The regions lens averages inside each boundary and ranks them, so you can read the answer straight off the list on the left.",
      "Several boundary layers are built in, so the same question can be asked of different management areas.",
      RESHOOT(paste0(EX, "?lens=region&tour=off&theme=light"), "stamp reads release v2026.09.06"),
      "Shot source: explore/shots/tour/regions.png (9/8 deck, slide 9).")
log_reshoot(paste0(EX, "?lens=region&tour=off&theme=light"), "stamp reads release v2026.09.06")

shot_slide("Part 6 · explore · 7 of 7", "Sections: the ocean in slices", "section",
           c("A slice down through the water along one line of stations: offshore on the left, depth going down.",
             "Warm water floats on top and cools quickly with depth."),
           "calcofi.io/explore/?lens=section&line=90")
notes("This is the view oceanographers love: a vertical slice. Imagine cutting the sea along line 90, a row of stations running offshore from Southern California. Offshore is on the left, the surface is at the top, and depth runs down. The yellow band at the top is warm surface water, and the water cools quickly with depth.",
      "Bridge to the next section: this is as measured. Next, the question that matters for El Niño: how does this slice compare with normal?",
      RESHOOT(paste0(EX, "?lens=section&var=temperature&line=90&tour=off&theme=light"), "stamp reads release v2026.09.06 and shows cruise 2026-07-3322; retake on the newest cruise in v2026.10.01"),
      "Shot source: explore/shots/tour/sections_env.png.")
log_reshoot(paste0(EX, "?lens=section&var=temperature&line=90&tour=off&theme=light"), "stamp reads release v2026.09.06")

# ── 18-19 · part 7: ctd-transects ──────────────────────────────────────────────────────────────
CT <- "https://calcofi.io/ctd-transects/"
shot_slide("Part 7 · the CTD visualizer · 1 of 2", "The same slice, against normal: warmer or colder?", "transect",
           c("The CTD Transects plotter draws a slice for every line and every cruise.",
             "Red is warmer than the 1993 to 2013 normal, blue is colder. Line 90, August 2024: a cold coastal edge and a warm offshore layer.",
             "Every cruise since 1993 is a click away."),
           "calcofi.io/ctd-transects", box = c(8.4, 4.98))
notes("CTD is the instrument lowered from the ship that records temperature, salinity and oxygen all the way down. This plotter turns every cruise's casts into a slice like the last one, but coloured as a difference from the long-term normal.",
      "Red means warmer than normal for that place, depth and month; blue means colder. That is how an El Niño shows up: a warm anomaly spreading through the upper layers. Here the line 90 slice for August 2024 shows cold water against the coast and a warm layer offshore.",
      "The normal is the average of the cruises from 1993 to 2013, with at least five cruises behind each cell; the page says how many.",
      RESHOOT(paste0(CT, "?line=90&cruise=2024-08-33P4&var=temperature_ave&mode=anomaly"), "stamp reads release v2026.09.11; 10/1 plotter changes (variables shown only where enough stations carry them) are not in this shot; also shoot the 'as measured' version of the same section and a current cruise"),
      "Shot source: 9/23 deck, slide 20 (ctd-transects PR #4 build).")
log_reshoot(paste0(CT, "?line=90&cruise=2024-08-33P4&var=temperature_ave&mode=anomaly"), "stamp reads release v2026.09.11; app changed 10/1 (ctd-transects#12); also shoot the as-measured view")

new_slide()
headline("Part 7 · the CTD visualizer · 2 of 2", "More stations, a sharper coast")
wpan <- (W - 2 * M - 0.3) / 2
fit_img(assets["before"], M, 2.45, wpan, 3.0, align = "left")
fit_img(assets["after"],  M + wpan + 0.3, 2.45, wpan, 3.0, align = "left")
txt("BEFORE · ONE STATION PER GRID CELL", M, 2.1, wpan, 0.3, fp_t = fp_eye, pad_b = 0)
txt("AFTER · EVERY STATION ITS OWN COLUMN", M + wpan + 0.3, 2.1, wpan, 0.3, fp_t = fp_eye, pad_b = 0)
txt(c("Line 90, August 2024. Once each station is drawn as itself, two inshore stations appear, and with them a cold nearshore core that the old picture hid.",
      "Red is warmer and blue colder than normal."),
    M, 5.65, W - 2 * M, 1.15, fp_t = fp(17, NAVY), pad_b = 6, ls = 1.1)
footer(CT)
notes("The same section, before and after one change: we stopped lumping several nearby stations into one box and drew each station as itself. Two inshore stations that were invisible now show up, and with them a band of cold water right at the coast, the signature of coastal upwelling, which the old picture averaged away.",
      "The message for a non-technical audience: more of the real data reaches the screen, and the picture sharpens. This is also why we do the work in the database and not in each app.",
      "Two things changed at once, the station key and the baseline, so say 'comes into focus' and do not credit one cause.",
      RESHOOT(paste0(CT, "?line=90&cruise=2024-08-33P4&var=temperature_ave&mode=anomaly"), "optional: the 'after' picture is from the release v2026.09.11 build; only needed if this slide is kept and the plotter's ramps or baseline changed again"),
      "Shot source: 9/23 deck, slide 19 (before = build of 2026-09-07 on v2026.09.06; after = the bot refresh of 2026-09-12 on v2026.09.11).")
log_reshoot(paste0(CT, "?line=90&cruise=2024-08-33P4&var=temperature_ave&mode=anomaly"), "optional: before/after pair is v2026.09.06 / v2026.09.11; 'before' cannot be re-shot from a current build")

# ── 20 · part 8: the upcoming El Niño (offered) ────────────────────────────────────────────────
new_slide()
headline("Part 8 · offered by Ben", "Watching the next El Niño as it happens")
frame <- function(x, ttl, sub) {
  rect(x, 1.85, wpan, 3.3, SAND, ln_col = STONE)
  txt("PLACEHOLDER SHOT", x + 0.25, 2.0, wpan - 0.5, 0.3, fp_t = fp_eye, pad_b = 0)
  txt(ttl, x + 0.25, 2.8, wpan - 0.5, 1.0, fp_t = fp(24, NAVY, DISPLAY), pad_b = 0, align = "center", ls = 0.95)
  txt(sub, x + 0.25, 4.0, wpan - 0.5, 0.9, fp_t = fp(14, GRAY), pad_b = 0, align = "center")
}
frame(M, "TEMPERATURE ANOMALY, ONE LINE", "The CTD Transects slice for a current cruise, against normal.")
frame(M + wpan + 0.3, "MIXED-LAYER DEPTH, A MAP", "How deep the warm surface layer reaches, station by station.")
txt(list(rich(list(ftext(sprintf("The El Niño cruise leaves %s.", CRUISE$leaves), fp(20, BLUE, bold = TRUE))), pad_b = 6),
         rich(list(ftext("Our aim: as each line is sampled, show how the water compares with normal, and how deep the warm layer reaches, in the tools you have just seen.", fp(17, NAVY))))),
    M, 5.35, W - 2 * M, 1.4, ls = 1.1)
footer("calcofi.io/ctd-transects · calcofi.io/explore")
notes(sprintf("The El Niño cruise leaves %s and runs to about %s. If one more slide is wanted, this is the closing beat: the same tools we just walked through, aimed at the thing everyone will be asking about.", CRUISE$leaves, CRUISE$returns),
      "Two views are planned. First, the temperature anomaly along a line, from CTD Transects: red upper layers spreading offshore are the El Niño signature. Second, a map of mixed-layer depth, the depth to which the surface water is well mixed. These are the first derived products we publish, computed per cast from the CTD profiles and released in v2026.10.01.",
      "Be careful with 'as it happens': the preliminary cruise files reach us after the stations are processed, not live from the ship. Confirm with Rasmus what the realistic delay is before the talk, and soften the aim sentence if it is days, not hours.",
      "RESHOOT 10/5-10/6 (placeholders, both frames): (1) a CTD Transects anomaly section for the newest cruise: calcofi.io/ctd-transects/?line=90&var=temperature_ave&mode=anomaly. (2) a mixed-layer-depth map from the Explorer, once the surface maps for MLD land (explore#13, not yet built). Until then, delete the frame or keep the placeholder.",
      sprintf("The cruise dates are not in any release record. Source: %s.", CRUISE$source))
log_reshoot(paste0(CT, "?line=90&var=temperature_ave&mode=anomaly"), "placeholder frame 1: anomaly section for the newest cruise")
log_reshoot("calcofi.io/explore (mixed-layer depth surface map; waits on explore#13)", "placeholder frame 2: MLD map does not exist yet")

# ── 21 · close ─────────────────────────────────────────────────────────────────────────────────
new_slide()
rect(0, 0, W, H, DARK)
fit_img(assets["logo"], M, 0.6, 3.2, 0.8, align = "left", frame = FALSE)
txt("ONE RECORD · A DOOR FOR EVERYONE", M, 2.2, 11, 0.4, fp_t = fp(13, YELLOW, bold = TRUE), pad_b = 0)
txt("Explore it, cite it, build on it", M, 2.6, 11.8, 1.2, fp_t = fp(54, WHITE, DISPLAY), pad_b = 0, ls = 0.9)
txt(c("calcofi.io/explore · see the data", "calcofi.io/ctd-transects · slices and anomalies", "calcofi.io/docs · which door is yours",
      sprintf("Release %s · doi.org/%s", N$version, N$doi), "data@calcofi.io"),
    M, 4.1, 11, 2.4, fp_t = fp(18, STONE), pad_b = 6)
notes("Close on the door idea: whoever you are, there is a door; behind it is one record; and the portals, CalOOS among them, point back to it rather than copying it.",
      "Leave this slide up for questions. data@calcofi.io is the address in the 9/8 deck.")

out <- "presentations/2026-10-13 CalOOS keynote - CalCOFI.io slides.pptx"
print(doc, target = out)

# officer writes every manual shape as a placeholder (<p:ph>); drop the tag so empty shapes don't show
# "Click to edit Master text styles" (see build_update_2026-09-08.R)
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
cat("wrote", out, "| slides:", length(doc), "| release:", VERSION, "\n")
cat("numbers:", paste(names(N), unlist(N), sep = "=", collapse = " | "), "\n")
cat("reshoot list:\n"); for (r in RESHOOT_LOG) cat(sprintf("  slide %2d  %s  -- %s\n", r$slide, r$url, r$why))

# one PNG per slide for Google Slides (fonts do not survive the import) ----
# soffice -> pdf -> pdftoppm at 144 dpi (1920 x 1080). The renderer uses the fonts installed on THIS machine: with no
# Source Sans 3 / Teko installed the PNGs are in fallback faces (wider than the brand's); install the two fonts first
# (brand/v2/fonts ships woff2 only; Google Fonts has the TTFs) and re-run for brand-true PNGs.
png_dir <- "presentations/caloos_2026-10-13"
if (nzchar(Sys.which("soffice")) && nzchar(Sys.which("pdftoppm"))) {
  tmp <- file.path(tempdir(), "caloos_pdf"); dir.create(tmp, showWarnings = FALSE)
  system2("soffice", c("--headless", "--convert-to", "pdf", "--outdir", shQuote(tmp), shQuote(normalizePath(out))), stdout = FALSE, stderr = FALSE)
  pdf <- list.files(tmp, pattern = "\\.pdf$", full.names = TRUE)
  stopifnot(length(pdf) == 1)
  unlink(png_dir, recursive = TRUE); dir.create(png_dir, recursive = TRUE)
  system2("pdftoppm", c("-r", "144", "-png", shQuote(pdf), shQuote(file.path(png_dir, "slide"))))
  fonts <- suppressWarnings(system2("fc-list", stdout = TRUE, stderr = FALSE))
  cat("PNGs:", length(list.files(png_dir)), "in", png_dir, "| Source Sans 3 installed:", any(grepl("Source Sans 3", fonts)),
      "| Teko installed:", any(grepl("Teko", fonts)), "\n")
} else cat("soffice or pdftoppm not found: no PNGs rendered\n")
