# Build the 2026-10-01 CalCOFI DMP meeting deck (16:9, brand v2) with officer + flextable.
#
# Plan: .claude/plans/2026-10-01 four hours to the DMP meeting — ….md; its sources are the subagent reports in
# .claude/plans/2026-10-01 review/ (gmail, tactiq, repos, pr_*). Every number on a slide is read from those
# reports, the PR bodies, or the files named in the speaker notes. The live status of the morning's work sits in
# STATUS below: edit it at T-30 min and re-run, nothing else needs to change.
#
# Run from the workflows/ root:  Rscript presentations/build_update_2026-10-01.R
# Helpers are lifted from build_update_2026-09-08.R (same template, logo, palette).
suppressMessages({
  library(officer); library(flextable); library(png)
})
stopifnot("run from the workflows/ root" = dir.exists("presentations/assets"))

# live status (edit before the meeting) ----
STATUS <- list(
  release      = "v2026.10.01: LIVE. latest.txt promoted 16:22 CEST; test_release 87 pass / 0 fail / 4 skip; both READMEs pass",
  release_done = TRUE,                       # TRUE once latest.txt is promoted
  prs_merged   = c("workflows#116", "#117", "#118", "#119", "db-viz-station#16", "calcofi4db#16", "ctd-transects#12"),
  replies_sent = character(0))   # drafts ready: Rasmus, Ed Weber, Ho Jung; Kelsey (2 edits)                # e.g. c("Rasmus", "Ed Weber", "Kelsey", "UCSD Library")

# brand v2 (calcofi.io/brand/v2/theme.css, light) ----
NAVY   <- "#182b49"; BLUE  <- "#00629b"; YELLOW <- "#ffcd00"; SAND <- "#f5f0e6"
GOLD   <- "#c69214"; GRAY  <- "#66686a"; STONE  <- "#b6b1a9"; WHITE <- "#ffffff"
RULE   <- "#dddddd"
SANS   <- "Source Sans 3"; DISPLAY <- "Teko"; MONO <- "Source Code Pro"

# slide geometry (in) ----
W <- 13.333; H <- 7.5; M <- 0.6
TOP_BODY <- 1.85; BOT_BODY <- 6.45

A <- function(f) file.path("presentations/assets", f)
assets <- c(
  template = A("template_16x9.pptx"),
  logo     = A("logo_calcofi_h.png"),
  logo_lt  = A("logo_calcofi_h_light.png"),
  do_shot  = A("rasmus_2504_93.3_do_sta_corr.png"),
  no3_shot = A("rasmus_2504_93.3_no3_cruise_corr.png"),
  do_fix   = A("rasmus_fix_do.png"),
  no3_fix  = A("rasmus_fix_no3.png"))
stopifnot(all(file.exists(assets)))

# officer helpers (from build_update_2026-09-08.R) ----
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
  invisible(c(left = unname(left + dx), top = unname(top), w = unname(iw), h = unname(ih)))
}
caption <- function(s, left, top, width, color = GRAY, align = "left")
  txt(s, left, top, width, 0.42, fp_t = fp(10.5, color), align = align, pad_b = 0)
notes <- function(...) doc <<- set_notes(doc, value = paste(c(...), collapse = "\n"), location = notes_location_type("body"))

headline <- function(eyebrow, h) {
  txt(toupper(eyebrow), M, 0.32, W - 2 * M - 1.7, 0.3, fp_t = fp_eye, pad_b = 0)
  txt(h, M, 0.56, W - 2 * M - 1.7, 1.25, fp_t = fp_h, pad_b = 0, ls = 0.9)
  fit_img(assets["logo_lt"], W - M - 1.55, 0.36, 1.55, 0.37, align = "right", frame = FALSE)
}
footer <- function(url = "calcofi.io") {
  rect(M, 6.93, W - 2 * M, 0.02, NAVY)
  txt(url, M, 7.0, 8.5, 0.32, fp_t = fp_link, pad_b = 0)
  txt(sprintf("CalCOFI DMP · 2026-10-01 · %d", n_slide), W - M - 4.5, 7.0, 4.5, 0.32,
      fp_t = fp_sm, align = "right", pad_b = 0)
}
stat_tile <- function(big, small, left, top, w = 2.8, h = 1.3, bg = SAND, big_col = BLUE, small_col = NAVY) {
  rect(left, top, w, h, bg, geom = "roundRect")
  txt(big,   left + 0.15, top + 0.05, w - 0.3, 0.7, fp_t = fp(34, big_col, DISPLAY), pad_b = 0)
  txt(small, left + 0.15, top + 0.75, w - 0.3, 0.5, fp_t = fp(11.5, small_col), pad_b = 0)
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
tbl <- function(ft, left = M, top = TOP_BODY)
  doc <<- ph_with(doc, ft, location = loc(left, top, W - 2 * M, BOT_BODY - top))

# ── 1 · title ──────────────────────────────────────────────────────────────────────────────────
new_slide()
rect(0, 0, W, H, "#0f1a2e")
fit_img(assets["logo"], M, 0.6, 3.2, 0.8, align = "left", frame = FALSE)
txt("CALCOFI.IO · DATA MANAGEMENT PLAN", M, 2.3, 10, 0.4, fp_t = fp(13, YELLOW, bold = TRUE), pad_b = 0)
txt("More datasets, faster — and the first derived products",
    M, 2.7, 11.5, 1.8, fp_t = fp(54, WHITE, DISPLAY), pad_b = 0, ls = 0.9)
txt("Ben, Betty, Mark, Erin · 1 October 2026", M, 4.75, 10, 0.4, fp_t = fp(18, STONE), pad_b = 0)
notes("Agenda: where the release is; five datasets in review; derived products and Rasmus's screenshots;",
      "what we owe providers; the decisions only this group can make; the next two weeks.",
      "Source: plan .claude/plans/2026-10-01 four hours to the DMP meeting — ….md")

# ── 2 · at a glance ────────────────────────────────────────────────────────────────────────────
new_slide()
headline("Since 23 September", "At a glance")
stat_tile("5",      "new datasets ingested and merged (iron, 3 × cetacean, 2022 eDNA)", M,        TOP_BODY + 0.1)
stat_tile("53",     "named phytoplankton taxa recovered from \"not identified further\"", M + 3.05, TOP_BODY + 0.1)
stat_tile("1",      "release ready to cut today (staged + tested 9/24)", M + 6.10, TOP_BODY + 0.1)
stat_tile("Oct 31", "El Niño cruise departs: the derived products' deadline", M + 9.15, TOP_BODY + 0.1, big_col = GOLD)
bullets(c(
  "Last round (9/23): every open PR in the org merged or closed with a review: 12 PRs, 9 repos.",
  "This round: 5 PRs, all Betty's. Three are new ingests, two answer Pooh's phytoplankton review.",
  "Review caught a release-breaker in 3 of the 5 PRs before release; all 5 plus 3 follow-on PRs are merged today.",
  "Derived products are new territory: sigma-theta, spice, MLD, chlorophyll max and integrated chl are released; Rasmus has sent 7 more."),
  M, TOP_BODY + 1.75, W - 2 * M, 2.6)
footer("github.com/CalCOFI · gh search prs --owner CalCOFI")
notes("12 PRs / 9 repos: 9/23 triage Outcome section. 5 datasets: PR bodies of workflows#116, #117 (3 notebooks), #118.",
      "53 named taxa: workflows#119 body. 3 of 5 with a release-breaker: #117 (taxon override orphans), #118 (assay unregistered), #119 (ingest never re-run).",
      "Oct 31 – Nov 10 El Niño cruise: Tactiq 9/23 DMP.")

# ── 3 · the release ────────────────────────────────────────────────────────────────────────────
new_slide()
headline("Database release", if (STATUS$release_done) "v2026.10.01 is live" else "v2026.10.01 goes out today")
bullets(c(
  "CTD: Kelsey's corrected 2607 file, plus four more cruises whose stations ≥ 100 were truncated (2507SR, 2511SR, 2601RL, 2604SH): offshore stations are back.",
  "CTD: the provider's quality flags on every series; Rasmus's sensor-pair rule; the 2607 secondary sensor flagged bad; cruise-corrected oxygen (new).",
  "New dataset calcofi_ctd-derived: sigma-theta and spiciness profiles; per-cast mixed-layer depth, chlorophyll max and integrated chlorophyll.",
  "Crab: 97 samples without a cruise reduced to 1. Picoplankton moves to Biology with a taxon on every row.",
  "The climatology now reaches the bottom (it stopped at 500 m): deep anomalies become possible.",
  "Measurements catalog 1.1: an anomaly per depth band, flagged values kept out of the advertised range."),
  M, TOP_BODY, 8.3, 4.6, fp_t = fp(14.5))
rect(M + 8.6, TOP_BODY, W - 2 * M - 8.6, 4.4, SAND, geom = "roundRect")
txt(c("STATUS", STATUS$release, "",
      "Previous public release: v2026.09.11 (three weeks old).",
      "Gates: test_release consumer contract + the calcofi4r and calcofi4py READMEs run against the candidate.",
      "Then: ctd-transects, db-viz-station and the docs book refresh automatically."),
    M + 8.8, TOP_BODY + 0.15, W - 2 * M - 9.0, 4.1, fp_t = fp(13), pad_b = 6)
footer("storage.calcofi.io · RELEASES.md")
notes("Content: RELEASES.md '# v2026.09.24' section in ~/Github/CalCOFI/workflows-release (renamed to v2026.10.01 at cut).",
      "Staging 9/24: test_release 87 pass / 0 fail / 4 skip; both READMEs pass. The version string is the cut date (release_database.qmd:141).")

# ── 3b · release ledger ─────────────────────────────────────────────────────────────────────────
new_slide()
headline("What ships when", "Released, next release, held, and still open")
col <- function(i, title, colr, items) {
  w <- (W - 2 * M - 0.45) / 4; x <- M + (i - 1) * (w + 0.15)
  rect(x, TOP_BODY, w, 4.55, SAND, geom = "roundRect")
  rect(x, TOP_BODY, w, 0.08, colr)
  txt(title, x + 0.15, TOP_BODY + 0.15, w - 0.3, 0.6, fp_t = fp(15, colr, bold = TRUE), pad_b = 0)
  bullets(items, x + 0.15, TOP_BODY + 0.8, w - 0.3, 3.7, fp_t = fp(12), pad_b = 5)
}
col(1, "RELEASED · v2026.10.01 (live)", BLUE, c(
  "CTD: corrected 2607 + 4 truncated cruises; provider flags; cruise-corrected DO",
  "calcofi_ctd-derived: MLD, spice, sigma-theta",
  "16 metadata proposals; crab cruise keys",
  "measurements 1.1; climatology to the bottom; picoplankton → Biology",
  "Plotter, station viewer, query app rebuilt"))
col(2, "MERGED · ships next release", NAVY, c(
  "cce-lter_iron: dissolved iron, 170 samples (#116)",
  "Phytoplankton names: 118 codes re-keyed (#119)",
  "41 provider answers in the question registries (#128)",
  "Registry rows for the held eDNA / cetacean types"))
col(3, "MERGED · held for providers", GOLD, c(
  "Cetacean sightings, sonobuoy, eDNA (#117): licence, citation, behaviour codes",
  "2022 vertebrate eDNA (#118): 8 provider questions",
  "Iron bioassay + total iron: units (Q01)",
  "Released when answered: flag off, re-render"))
col(4, "OPEN · not merged", GRAY, c(
  "CTD depth-constant guard + Q40 (calcofi4db#18, workflows#127): needs a 1 h CTD re-render",
  "docs#18 with the 2022 eDNA",
  "Not started: derived products round 2, SWFSC ichthyo re-ingest, ICES ship codes"))
footer("RELEASES.md · # v2026.10.01 / # Unreleased · in_release: false")
notes("Ledger as of 17:10 CEST 2026-10-01; full version in the plan's 'Release ledger' section. Held datasets set calcofi.in_release: false in their notebooks; # Unreleased lists them as staged, not released.")

# ── 4 · datasets in review ─────────────────────────────────────────────────────────────────────
new_slide()
headline("Ingest pipeline", "Five datasets and a taxonomy fix, reviewed and merged today")
tbl(ft_tbl(data.frame(
  PR       = c("workflows#116", "workflows#118", "workflows#117", "workflows#119", "db-viz-station#16"),
  Dataset  = c("CCE-LTER iron (Barbeau; EDI)", "CalCOFI Oct 2022 vertebrate eDNA (GBIF)",
               "Cetacean sightings · sonobuoy calls · eDNA (marmam-app)", "Phytoplankton (Venrick): taxon names",
               "Phytoplankton pages + map (Pooh's review)"),
  Size     = c("170 samples · 170 obs", "47 filters · 148 obs", "6,107 sightings · 3,244 call-hours · 133 eDNA samples",
               "75 → 24 codes without a WoRMS id; obs unchanged (159,804)", "8 files"),
  Review   = c("merged today, after fixes", "merged today: reworked to filter × taxon × assay",
               "merged today: release blocker fixed (calcofi4db 4.17.2)",
               "merged today: re-run, 118 codes re-keyed", "merged today"),
  Release  = c("next release", "held out until provider answers", "held out (licence, citation)", "next release", "with #119"),
  check.names = FALSE), size = 12.5, widths = c(1.8, 3.2, 3.3, 2.1, 1.7)))
footer("github.com/CalCOFI/workflows/pulls")
notes("Counts are the PR bodies'. Reviews: .claude/plans/2026-10-01 review/pr_workflows_116.md, _117, _118, pr_phyto.md.",
      "Merge order (append-both conflicts in dataset_status.csv, RELEASES.md, taxon_lineage.csv): #116 → #118 → #117 → #119 → db-viz-station#16.")

# ── 5 · what review catches ────────────────────────────────────────────────────────────────────
new_slide()
headline("QA/QC", "Review caught the release-breakers before the release; all fixed today")
tbl(ft_tbl(data.frame(
  PR      = c("#117 cetaceans", "#118 eDNA", "#118 eDNA", "#119 phytoplankton", "#116 iron", "#116 iron"),
  Finding = c("13 taxon overrides for held-out datasets read as orphans by the release check",
              "the assay attribute is not a registered measurement type",
              "one row per ASV, not per detection: 2–17 rows for one taxon in one filter",
              "the corrected names never re-ran through the ingest, so the taxon tables are stale",
              "8 malformed rows in the field-redefinition CSV shift a column's units",
              "parquet rendered without the cloud upload"),
  Effect  = c("next release stops", "next release stops", "counts read as abundance",
              "the fix would not ship", "wrong units in metadata", "dataset missing from the release"),
  check.names = FALSE), size = 13, widths = c(2.2, 6.6, 3.3)))
footer("calcofi.io/docs · validation gates")
notes("Sources: the four review reports. Each finding cites file:line there (e.g. release_database.qmd:802-804 for #117,",
      "release_database.qmd:709-720 for #118).")

# ── 6 · derived products ───────────────────────────────────────────────────────────────────────
new_slide()
headline("New territory", "Derived products: the first set is released; Rasmus's definitions are next")
txt("RELEASED · calcofi_ctd-derived in v2026.10.01", M, TOP_BODY, 5.8, 0.3, fp_t = fp_eye, pad_b = 0)
bullets(c("Profiles: sigma-theta (sensor pair) and spiciness, ~663,000 values each",
          "Per cast (~9,000 casts): mixed-layer depth by 3 criteria (σθ +0.03, +0.125 kg/m³; −0.2 °C)",
          "Per cast: chlorophyll max + its depth (5 m running median); chlorophyll integrated 0–200 m",
          "Built, not released: relative geostrophic flow (speeds under review)"),
        M, TOP_BODY + 0.35, 5.8, 2.9, fp_t = fp(13.5))
txt("NEXT · Rasmus's definitions (9/24)", M + 6.3, TOP_BODY, 5.8, 0.3, fp_t = fp_eye, pad_b = 0)
bullets(c("MLD headline at the CalCOFI legacy +0.02 kg/m³ below 10 m",
          "Chlorophyll max from a 3 m running mean (now 5 m median)",
          "Nitracline (1 µM); hypoxic boundaries at 2.4 / 1.4 / 0.5 mL/L",
          "Pycnocline (TEOS-10); buoyancy frequency; geostrophic flow fixed",
          "Bottle climatologies 1949–2013 and 1993–2013"),
        M + 6.3, TOP_BODY + 0.35, W - 2 * M - 6.3, 2.9, fp_t = fp(13.5))
rect(M, 5.25, W - 2 * M, 1.2, SAND, geom = "roundRect")
txt(c("Not yet visible: the dataset page lists only the two profile variables (per-cast values are in sample_measurement); Explorer surface maps for MLD, DCM, nitracline and hypoxia are explore#13.",
      "Target: Rasmus's definitions in the release before the El Niño cruise leaves on 31 October."),
    M + 0.2, 5.38, W - 2 * M - 0.4, 1.0, fp_t = fp(14), pad_b = 4)
footer("calcofi.io/ctd-transects · workflows#98–#103 · explore#13")
notes("Rasmus, thread 'Next Two Weeks Tasks': 9/22 (spice, geostrophic), 9/24 00:24Z (five answers), 9/24 21:41Z (nitracline, hypoxia, pycnocline, N², isopycnals parked).",
      "Built: calcofi4db#11 + workflows#107/#110, dataset calcofi_ctd-derived.")

# ── 7 · Rasmus's screenshots ───────────────────────────────────────────────────────────────────
new_slide()
headline("Rasmus, 29 Sep", "\"Not showing the data correctly\": the plotter draws what the files say")
g1 <- fit_img(assets["do_shot"],  M, TOP_BODY, 6.0, 1.95, align = "left")
g2 <- fit_img(assets["no3_shot"], M, TOP_BODY + 2.15, 6.0, 1.95, align = "left")
x <- M + 6.3; w <- W - M - x
txt("DO, STATION-CORRECTED", x, TOP_BODY, w, 0.3, fp_t = fp_eye, pad_b = 0)
txt("The 2504SH file has station-corrected oxygen at 3 of 14 casts on line 93.3 (stations 45, 50, 55): the bottle merge covered only those. The plotter fills between them as if the whole section were sampled.",
    x, TOP_BODY + 0.3, w, 1.6, fp_t = fp(13))
txt("NITRATE, CRUISE-CORRECTED", x, TOP_BODY + 2.15, w, 0.3, fp_t = fp_eye, pad_b = 0)
txt("In the source file the column does not vary with depth: on 2504SH one value per cast (65 casts > 0, 42 at 0); on 2307SR exact 0 throughout (unfilled). Census: 441 of 5,066 casts on 20 of 76 cruises. Is it an offset?",
    x, TOP_BODY + 2.45, w, 1.5, fp_t = fp(13))
rect(M, 6.1, W - 2 * M, 0.65, SAND, geom = "roundRect")
txt("Fixed today (ctd-transects#12): a variable shows only where ≥ 3 stations and ≥ half the section carry it; depth-constant series are withheld with a note; cruise-corrected DO is offered first.",
    M + 0.2, 6.18, W - 2 * M - 0.4, 0.55, fp_t = fp(13, NAVY, bold = TRUE), pad_b = 0)
footer("calcofi.io/ctd-transects")
notes("Verified 2026-10-01 against ~/_big/calcofi/ctd-cast/unzip/20-2504SH_CTDPrelim/db-csvs/20-2504SH_CTDBTL_001-116D.csv",
      "and the shard public/data/sections/93.3__2025-04-3322.json. Station correction needs a ~500 m cast with ~10+ bottles (ctd-cast Q17).",
      "Depth-constant EstNO3_CruiseCorr census (libs/census_depth_constant_ctd.R, workflows#127): 441 / 5,066 judged casts, 20 of 76 cruises; every judged cast on 2304SH, 2504SH, 2301RL, 2307SR, 2105SH, 2411SR, 0810NH. Mostly exact 0 (unfilled); ~99 casts carry a non-zero per-cast value (2504SH 0.007-24.5 uM). 9809NH and 2204SH are -99/blank (missing), not constant.")

# ── 7b · the same section, live today ──────────────────────────────────────────────────────────
new_slide()
headline("Live on v2026.10.01", "The same section today: what the plotter shows, and what it withholds")
fit_img(assets["do_fix"],  M, TOP_BODY, 6.0, 2.05, align = "left")
fit_img(assets["no3_fix"], M, TOP_BODY + 2.25, 6.0, 2.05, align = "left")
x <- M + 6.3; w <- W - M - x
txt("DO, CRUISE-CORRECTED (NEW)", x, TOP_BODY, w, 0.3, fp_t = fp_eye, pad_b = 0)
txt("Offered in place of the station-corrected series, which is withheld: data at 3 of 15 stations.",
    x, TOP_BODY + 0.3, w, 1.2, fp_t = fp(13))
txt("NITRATE, STATION-CORRECTED", x, TOP_BODY + 2.25, w, 0.3, fp_t = fp_eye, pad_b = 0)
txt("The real profile, ~5 → 40 µmol/L with depth. The cruise-corrected column is withheld (constant with depth) until the CTD team answers Q40.",
    x, TOP_BODY + 2.55, w, 1.4, fp_t = fp(13))
footer("calcofi.io/ctd-transects/?line=93.3&cruise=2025-04-3322")
notes("Screenshots of the live site taken 2026-10-01 ~16:40 CEST after the v2026.10.01 refresh (ctd-transects#12 rules).",
      "Shard: public/data/sections/93.3__2025-04-3322.json withheld = {est_nitrate_cruise_corr: constant with depth, oxygen_ml_l_ave_sta_corr: data at 3 of 15 stations}.")

# ── 8 · providers ──────────────────────────────────────────────────────────────────────────────
new_slide()
headline("Conversations", "What we owe our data providers")
tbl(ft_tbl(data.frame(
  Who    = c("Rasmus Swalethorp", "Ed Weber (SWFSC)", "Kelsey Vogel", "UCSD Library (Ho Jung Yoo)",
             "Christy Juhasz (CDFW)", "CCE-LTER, marmam, eDNA providers"),
  Topic  = c("Thursday update promised; screenshots; derived-product definitions; ammonium zeros",
             "New ichthyo tables (a breaking change to measured larvae); ICES vs NODC ship codes",
             "Four more corrected preliminary files; confirm the 2607 sensor-2 flag",
             "Cruise naming for the deposit", "Portal link to the Library DOI",
             "Licence, citation, units and definitions (questions in each PR)"),
  Status = c("reply today", "reply today; re-ingest next week", "draft ready (since 9/24)",
             "answer never reached them", "waits on the Library URL", "questions filed; Betty sends after Erin's review"),
  check.names = FALSE), size = 12.5, widths = c(2.6, 6.3, 3.2)))
if (length(STATUS$replies_sent))
  caption(paste("Sent today:", paste(STATUS$replies_sent, collapse = ", ")), M, 6.5, W - 2 * M)
footer("questions.csv per dataset · provider Google Sheets")
notes("Source: .claude/plans/2026-10-01 review/gmail.md (thread ids there). Ed Weber thread 1a035889e1db4873; Rasmus 1a081fa6c2393fa1; Kelsey draft r-5609354737494233360.")

# ── 8b · questions sheets ──────────────────────────────────────────────────────────────────────
new_slide()
headline("Provider question sheets", "Providers are answering faster than we record")
stat_tile("~33", "answers in the sheets and comments not yet in our registries", M, TOP_BODY + 0.1)
stat_tile("9",   "comment threads assigned to Ben, the oldest from 17 Sep", M + 3.05, TOP_BODY + 0.1, big_col = GOLD)
stat_tile("4",   "places a provider disagrees with our proposal (we adopt theirs)", M + 6.10, TOP_BODY + 0.1)
stat_tile("3",   "sheets with new input: CalCOFI, SWFSC, CDFW", M + 9.15, TOP_BODY + 0.1)
bullets(c(
  "Ammonium: Rasmus (9/28): don't flag early zeros as below detection; a zero is valid. We concur; Annie asked to confirm.",
  "CTD: three data stages confirmed; DBcoeff is stable and publishable; exclude bad pH; serve bottle and sensor values side by side.",
  "SWFSC (Ed Weber): tows with no catch row are true zeros (except 198202JD, 198212JD); NetDepth is the true depth; aggregate by AphiaID.",
  "CDFW (Christy): crab times are Pacific local; list the CNRA portal copy as a distribution.",
  "Sync order matters: record the answers in the registries first (PR open), then push to the sheets, or typed answers are erased."),
  M, TOP_BODY + 1.75, W - 2 * M, 2.8, fp_t = fp(14))
footer("docs.google.com · questions for CalCOFI / SWFSC / CDFW")
notes("Source: .claude/plans/2026-10-01 review/questions_sheets.md (8 CalCOFI tabs, SWFSC, CDFW; 9 Gmail comment threads). Counts are rows/threads as classified there.",
      "Open to Ben: bottle Q01/Q02 (flag codes), ctd-cast Q10, Q12, Q14, Q15, Q20 (Jim Wilkinson), Q24; Kelsey asks about 'Ben's Kraken program' for removing the failed 2607 sensor.")

# ── 9 · decisions ──────────────────────────────────────────────────────────────────────────────
new_slide()
headline("For this group", "Decisions we need")
tbl(ft_tbl(data.frame(
  Decision = c("Ship codes", "eDNA sample hierarchy", "Cetacean counts", "Shared bounds and units",
               "Phytoplankton duplicates", "Kuali vendor review", "SCCOOS quote"),
  Question = c("SWFSC asks for ICES codes; our cruise_key uses NODC",
               "2022 filters are replicates of 37 water samples; cetacean eDNA matched to bottles: add a parent?",
               "Two observer teams on the same cruises: split species counts per dataset?",
               "chl_fluor valid_min = 0 is shared with METS; eDNA oxygen arrives in mg/L",
               "12 samples (cruises 0704, 1202, 1203) carry two rows per code (workflows#124)",
               "Reply to Pilar drafted 9/30: sent?",
               "Trim Quote 1 by $433.25 to hold $65,625?"),
  Proposal = c("keep NODC in the key; add ICES as a column (reply drafted)",
               "yes: parent_sample_key to the water sample / matched bottle",
               "yes: per-dataset counts in taxa.json",
               "keep the floor; convert mg/L to the shared ml/L type",
               "ask Venrick which row is right; until then keep the first",
               "confirm", "Erin"),
  check.names = FALSE), size = 12.5, widths = c(2.1, 4.7, 5.3)))
footer("plan § Decisions only Ben can make (B1–B11)")
notes("Settled today by Ben (applied in the merged PRs): eDNA grain filter × taxon × assay with edna_presence as headline; PCR negatives held; effort status to obs_attribute; iron bioassay held out; phytoplankton keys the accepted genus (Tripos) and the LCA for two-genus codes.", "New from the PR work: workflows#121 (cetacean parent key, taxa.json split), #124 (doubled phytoplankton samples), db-viz-station #17/#19 (design). Ammonium: concur with Rasmus (no qual=4 backfill; zero is valid).")

# ── 10 · next two weeks ────────────────────────────────────────────────────────────────────────
new_slide()
headline("Calendar", "The next two weeks, and the cruise")
tbl(ft_tbl(data.frame(
  When = c("today", "this week", "mid next week", "Thu 8 Oct", "by 8 Oct", "Oct", "31 Oct – 10 Nov"),
  What = c("release v2026.10.01 · plotter refresh · replies to Rasmus, Ed, Kelsey, Library",
           "merge the five PRs; held-out datasets stay staged until providers answer",
           "State of the California Current tutorials (Rasmus, Andrew Thompson, Nastassia Patin): Betty scheduling",
           "next DMP call",
           "next release: iron, phytoplankton names, derived products round 2, the ingest guard on depth-constant series",
           "ichthyo re-ingest from SWFSC's new tables; cruise_key_alt; Explorer cmocean ramps",
           "El Niño cruise: derived products and transects live before it leaves"),
  check.names = FALSE), size = 13, widths = c(2.0, 10.1)))
footer("calcofi.io")
notes("Dates: Tactiq 9/23 DMP (10/8, El Niño cruise), Gmail (SOCCR meeting mid next week).")

out <- "presentations/2026-10-01 CalCOFI.io DMP update.pptx"
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
cat("wrote", out, "| slides:", length(doc), "\n")
