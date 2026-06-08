# Build the CalCOFI progress PowerPoint (Dec 2025 - Jun 2026) with officer.
suppressMessages({library(officer); library(dplyr)})
have_ft <- requireNamespace("flextable", quietly = TRUE)
if (have_ft) suppressMessages(library(flextable))

# palette
cc_blue <- "#0A3D62"; cc_teal <- "#1B7B7B"; cc_accent <- "#F58518"; gray <- "#5A5A5A"
logo <- "presentations/assets/logo_calcofi.png"
erd  <- "presentations/assets/calcofi_erd.png"

doc <- read_pptx()
LT  <- "Title and Content"; MST <- "Office Theme"

# helpers ----
title_fp <- fp_text(font.size = 30, bold = TRUE, color = cc_blue)
h_fp     <- fp_text(font.size = 26, bold = TRUE, color = cc_blue)
sub_fp   <- fp_text(font.size = 16, color = gray, italic = TRUE)
bul_fp   <- fp_text(font.size = 16, color = "#222222")
lab_fp   <- fp_text(font.size = 13, color = gray)

bullets <- function(items, fp = bul_fp) {
  blocks <- lapply(items, function(t)
    fpar(ftext(t, fp), fp_p = fp_par(padding.bottom = 6)))
  do.call(block_list, blocks)
}
content_slide <- function(title, items) {
  doc <<- add_slide(doc, LT, MST)
  doc <<- ph_with(doc, fpar(ftext(title, h_fp)), location = ph_location_type("title"))
  doc <<- ph_with(doc, bullets(items), location = ph_location_type("body"))
}
section_slide <- function(kicker, title) {
  doc <<- add_slide(doc, "Section Header", MST)
  doc <<- ph_with(doc, fpar(ftext(title, fp_text(font.size = 40, bold = TRUE, color = cc_blue))),
                  location = ph_location_type("title"))
  doc <<- ph_with(doc, fpar(ftext(kicker, fp_text(font.size = 18, bold = TRUE, color = cc_accent))),
                  location = ph_location_type("body"))
}
ft_tbl <- function(df, hbg = cc_blue) {
  if (!have_ft) return(df)
  flextable(df) |> theme_box() |>
    bg(part = "header", bg = hbg) |> color(part = "header", color = "white") |>
    bold(part = "header") |> fontsize(size = 11, part = "all") |>
    fontsize(size = 12, part = "header") |> padding(padding = 4, part = "all") |>
    autofit()
}

# 1. TITLE ----
doc <- add_slide(doc, "Title Slide", MST)
doc <- ph_with(doc, fpar(ftext("CalCOFI Automation — Ocean Metrics", fp_text(font.size = 34, bold = TRUE, color = cc_blue))),
               location = ph_location_type("ctrTitle"))
doc <- ph_with(doc, fpar(
  ftext("Progress Report: December 2025 – June 2026\n", fp_text(font.size = 20, color = cc_teal)),
  ftext("Integrating, serving & visualizing America's oldest ocean-ecosystem time series", sub_fp)),
  location = ph_location_type("subTitle"))
if (file.exists(logo))
  doc <- ph_with(doc, external_img(logo, width = 1.6, height = 1.6),
                 location = ph_location(left = 8.0, top = 0.3))

# 2. VISION ----
content_slide("The Vision", c(
  "Maximize the value of CalCOFI data within the SCCOOS / IOOS ocean-observing ecosystem.",
  "1)  Increase accessibility & transparency across CalCOFI data constituents.",
  "2)  Accelerate adoption across California ocean-management entities.",
  "3)  Strengthen integration with the network of CA ocean-observation programs.",
  "Three components of work:  ① INGEST  →  ② VISUALIZE  →  ③ SHARE.",
  "Built on open standards: Parquet + DuckDB + reproducible notebooks — the same stack as GBIF & OBIS."))

# 3. ARCHITECTURE ----
content_slide("Pipeline & Architecture", c(
  "Source files (CSV/XLSX) curated in Google Drive  →  long-term archive in Google Cloud Storage (rclone).",
  "calcofi4db ingest notebooks (Quarto) normalize each dataset to a shared schema with referential integrity.",
  "Versioned, frozen DuckLake: Parquet on GCS + reproducible recreation from source + a changelog.",
  "One release fans out to portals — ERDDAP, OBIS, EDI — and to apps + an interactive schema site.",
  "Self-tracking, AI-assisted loop: explore → generate-metadata → ingest → validate → publish (Claude Code skills)."))

# 4. BY THE NUMBERS ----
doc <- add_slide(doc, LT, MST)
doc <- ph_with(doc, fpar(ftext("Release v2026.06.08 — by the numbers", h_fp)), location = ph_location_type("title"))
nums <- data.frame(
  Metric = c("Datasets integrated", "Tables", "Records", "Frozen size (Parquet/GCS)",
             "ERDDAP datasets served", "Apps", "Workflow commits since Dec 2025"),
  Value  = c("10", "44", "133,807,311", "3.7 GB", "6 (5 live, CTD syncing)",
             "schema site · ctd-viz · datacheck", "81"),
  check.names = FALSE)
doc <- ph_with(doc, ft_tbl(nums), location = ph_location_type("body"))

# 5. INGEST SECTION ----
section_slide("Component 1 of 3", "① INGEST")

# 6. INGEST scorecard ----
doc <- add_slide(doc, LT, MST)
doc <- ph_with(doc, fpar(ftext("Datasets ingested into the integrated database", h_fp)), location = ph_location_type("title"))
score <- data.frame(
  Dataset = c("Ichthyoplankton (eggs & larvae)", "Bottle (hydro chemistry)", "CTD casts",
              "DIC / carbonate chemistry", "Krill / euphausiids", "Zooplankton tows",
              "Underway CUFES", "Lobster phyllosoma", "Seabird & mammal census",
              "Phytoplankton (Venrick)"),
  `Headline` = c("830K+ records", "11M+ measurements", "ctd_thin 5.5M (234M source)",
              "8.3K measurements", "10K tows", "99.5K tows", "49.5K samples",
              "1.9K tows", "60.7K observations", "159.8K measurements"),
  SOW = c("must ✓","must ✓","must ✓","must ✓","must ✓","◑ biovol pending","✓","must ✓","✓","must ✓"),
  check.names = FALSE)
doc <- ph_with(doc, ft_tbl(score), location = ph_location_type("body"))

# 7. INGEST highlights ----
content_slide("Ingest — engineering highlights", c(
  "Prescriptive schema: a canonical field dictionary + schema-lint enforce names/types/units across datasets.",
  "UUID-first primary keys minted at sea (stable through QA/QC); natural keys (cruise_key) where appropriate.",
  "Cross-dataset relationships registry — every dataset links to the shared cruise / ship / grid tables.",
  "CTD adaptive thinning (Douglas–Peucker): 15+ GB → 258 MB while preserving every profile inflection.",
  "Hardest ingest — phytoplankton: region-pooled grain (no per-station position), cross-tab Excel, WoRMS taxonomy.",
  "Reusable spatial/temporal match helpers resolve cross-dataset joins (site+datetime, nearest-depth)."))

# 8. PROCESS HARDENING ----
content_slide("A repeatable, self-tracking ingest loop", c(
  "Claude Code skills pipeline: explore-dataset → generate-metadata → ingest-new → validate-ingest → publish.",
  "Every workflow records ranked follow-up questions for data providers (per-dataset questions.csv).",
  "A dataset_status tracker + cross-dataset relationship registry make the pipeline auditable.",
  "Each new dataset auto-discovers into the release — no manual wiring.",
  "Result: 81 commits since December turning 11 raw sources into one coherent, documented database."))

# 9. VISUALIZE SECTION ----
section_slide("Component 2 of 3", "② VISUALIZE")
content_slide("Visualize — interactive products", c(
  "Schema site (calcofi.io/schema): interactive ERD, table & column browser, cross-dataset filter — data-driven from GCS sidecars.",
  "ctd-viz app: ODV-style interpolated CTD transects with bathymetry, linked map/table/plot.",
  "datacheck app (NEW): cross-dataset observations for any cruise on a map/table/plot, with deep-linkable URLs for provider questions.",
  "Integrated app (app.calcofi.io/int): H3 hexagon summaries; new cached endpoint serves hexes on-the-fly by map extent & zoom.",
  "Management areas of interest (sanctuaries, MPAs, BOEM wind) — in progress."))

# 10. SCHEMA IMAGE ----
doc <- add_slide(doc, LT, MST)
doc <- ph_with(doc, fpar(ftext("One integrated, referentially-intact schema", h_fp)), location = ph_location_type("title"))
if (file.exists(erd))
  doc <- ph_with(doc, external_img(erd, width = 9.0, height = 5.0),
                 location = ph_location(left = 0.5, top = 1.5))
doc <- ph_with(doc, fpar(ftext("Entity–relationship diagram of release v2026.06.08 (44 tables across 10 datasets)", lab_fp)),
               location = ph_location(left = 0.5, top = 6.7))

# 11. SHARE SECTION ----
section_slide("Component 3 of 3", "③ SHARE")
doc <- add_slide(doc, LT, MST)
doc <- ph_with(doc, fpar(ftext("Share — publishing to standards portals", h_fp)), location = ph_location_type("title"))
share <- data.frame(
  Portal = c("ERDDAP", "OBIS (Darwin Core)", "EDI", "EDI", "OBIS"),
  Dataset = c("CTD · Bottle · DIC · Krill · Zooplankton · Phytoplankton",
              "Ichthyoplankton (eggs/larvae)", "Zooplankton", "Phytoplankton",
              "Seabirds & Marine mammals"),
  Status = c("5 live, CTD syncing", "done", "planned (#42)", "planned (#62)", "planned (#43/#44)"),
  check.names = FALSE)
doc <- ph_with(doc, ft_tbl(share, hbg = cc_teal), location = ph_location_type("body"))

# 12. STATUS vs SOW ----
content_slide("Status vs. Statement of Work", c(
  "✓ ALL must-complete INGESTS delivered: Bottle, Fish eggs & larvae, Krill, CTD, Cephalopods, Phytoplankton, DIC, Phyllosoma.",
  "✓ Must-complete SHARE delivered: CTD & Bottle → ERDDAP, Fish eggs & larvae → OBIS, DIC → ERDDAP.",
  "✓ Integrated database versioned & reproducible (frozen DuckLake, v2026.06.08).",
  "◑ Remaining ingest: ZooDb & ZooScan (blocked on Ohman/DataZoo portal export), PRODO, acoustic mammals.",
  "◑ Remaining share: seabirds/mammals → OBIS, zooplankton/phytoplankton → EDI, underway MET → ERDDAP."))

# 13. WHAT'S NEXT ----
content_slide("What's next", c(
  "Unblock ZooDb / ZooScan via an Ohman-lab / DataZoo data export (the one external dependency).",
  "Finish the publish side: seabird & mammal → OBIS, zooplankton & phytoplankton → EDI, underway MET → ERDDAP.",
  "Bring calcofi_ctd fully live on ERDDAP (944 MB ctd_wide).",
  "Expand H3 hexagon summaries across the newly ingested datasets in the integrated app.",
  "Deliver the live, recorded webinar series — a CalCOFI.io product showcase (this deck is the starting point)."))

# 14. CLOSING ----
doc <- add_slide(doc, "Section Header", MST)
doc <- ph_with(doc, fpar(ftext("From 11 raw sources to one living, versioned, served database.",
                               fp_text(font.size = 28, bold = TRUE, color = cc_blue))),
               location = ph_location_type("title"))
doc <- ph_with(doc, fpar(ftext("Ben Best · Ocean Metrics LLC · ben@oceanmetrics.io · calcofi.io", fp_text(font.size = 15, color = cc_teal))),
               location = ph_location_type("body"))

out <- "presentations/CalCOFI_progress_Dec2025-Jun2026.pptx"
dir.create(dirname(out), showWarnings = FALSE, recursive = TRUE)
print(doc, target = out)
cat("wrote", out, "\n")
cat("slides:", length(doc), "| flextable:", have_ft, "\n")
