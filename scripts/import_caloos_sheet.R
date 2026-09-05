# import_caloos_sheet.R -------------------------------------------------------
#
# WS-R1 (plan "CalCOFI.io as a dataset catalog", 2026-09-05, § Context › "The
# CalOOS working sheet", D-1, D-9, D-11, Decision 16). Imports the CalOOS
# working sheet (CalOOS's Data Ingest Request Form, filled in for CalCOFI by
# Erin/Betty) into the git-tracked registries, ONCE, without re-typing anything
# a person already typed there:
#
#   - a sheet row whose *Data Access URL* matches an already-integrated
#     dataset (distribution.csv, a dataset's link_data_source/link_calcofi_org,
#     or a CalOOS module id) becomes a PROPOSAL written into that dataset's
#     `metadata/{provider}/{dataset}/dataset_meta.proposed.yml` (never into the
#     notebook YAML, never into a sidecar directly -- R2 owns dataset_meta.yml
#     for the 16 datasets that have an ingest notebook) plus, where the sheet
#     adds an endpoint the release does not already carry (a CalOOS module id,
#     a predecessor DataZoo access route), a new `metadata/distribution.csv`
#     row;
#   - an unmatched row becomes a HOLDING: a new `dataset_key`, a new
#     `metadata/{provider}/{dataset}/dataset_meta.yml` sidecar (status:
#     planned | external | archived), a new provider.csv row if needed.
#
# Every written value carries a `# source: caloos-sheet row N, 2026-09-05`
# comment (or, for GCMD keywords, `# source: <GCMD KMS URL>, checked
# 2026-09-05`) so a reviewer can trace it back to the cell that produced it.
# Matching a sheet row to a dataset_key/holding-key needs judgement no CSV
# join can supply (multi-URL cells, "TBD (coming)" placeholders, EDI
# accessions whose cite-service title disagrees with the sheet's own
# description) -- that judgement is recorded in DISPOSITION below, each row
# with the evidence that decided it, rather than silently guessed at runtime.
#
# Idempotent: every write is guarded by "does this row/file/value already
# exist" -- a second run reports the same match table and writes nothing.
#
# Run: Rscript scripts/import_caloos_sheet.R
# Do not: edit the Google Sheet; edit any ingest_*.qmd; touch calcofi4db.

librarian::shelf(readr, dplyr, purrr, yaml, stringr, tibble, quiet = TRUE)

SHEET_URL     <- "https://docs.google.com/spreadsheets/d/1eyvhdzA5YwuDxH8tBld2-h_odKA1KYt_RXI3loI0OaU/export?format=csv&gid=0"
METADATA_DIR  <- "metadata"
TODAY         <- "2026-09-05"
GCMD_VIEWER   <- "https://gcmd.earthdata.nasa.gov/KeywordViewer/"
DRY           <- FALSE  # TRUE = report only, write nothing

message("== import_caloos_sheet.R ", TODAY, " ==")

# 1. read the sheet, aliased to short snake_case names --------------------------

sheet_raw <- readr::read_csv(SHEET_URL, show_col_types = FALSE, na = c("", "NA"))
stopifnot("expected 41 CalOOS rows (measured 2026-09-05)" = nrow(sheet_raw) == 41)

names(sheet_raw) <- c(
  "caloos_link", "programs", "ongoing_archived", "priority_caloos", "dataset_name",
  "lead_name", "lead_email", "lead_affiliation", "module", "title_portal", "abstract",
  "access_url", "doi", "metadata_standard", "update_frequency",
  "contrib_collection", "contrib_qaqc", "contrib_curation", "contrib_other",
  "funders", "other_institutions", "usage_restrictions", "license_usage",
  "citation_preferred", "tags", "qc_flags", "qc_protocol", "viz_requirements",
  "additional_info", "blank1", "blank2", "continuous", "start_date", "most_recent",
  "processing_required")
sheet <- sheet_raw |> mutate(row = row_number()) |> select(row, everything())
g <- function(r, col) { v <- sheet[[col]][sheet$row == r]; if (length(v) == 0 || is.na(v)) NULL else trimws(v) }
src <- function(r) sprintf("caloos-sheet row %d, %s", r, TODAY)
src_rows <- function(rs) sprintf("caloos-sheet row%s %s, %s", if (length(rs) > 1) "s" else "",
                                 paste(rs, collapse = ","), TODAY)

# 2. the disposition table -------------------------------------------------------
# one row per sheet row: how it maps onto the registries, and why (the "why" is
# the evidence a generic URL-join cannot reconstruct -- see header comment).

DISPOSITION <- tribble(
  ~row, ~kind,      ~key,                              ~note,
  1,  "matched",  "swfsc_ichthyo",                    "erdCalCOFIeggcnt, already in distribution.csv",
  2,  "matched",  "swfsc_cufes",                       "erdCalCOFIcufes, already in distribution.csv",
  3,  "matched",  "swfsc_ichthyo",                     "erdCalCOFIeggstg, already in distribution.csv",
  4,  "matched",  "swfsc_ichthyo",                     "erdCalCOFIlrvcnt, already in distribution.csv",
  5,  "matched",  "swfsc_ichthyo",                     "erdCalCOFIlrvsiz, already in distribution.csv",
  6,  "matched",  "swfsc_ichthyo",                     "erdCalCOFIlrvstg, already in distribution.csv",
  7,  "matched",  "swfsc_ichthyo",                     "erdCalCOFIinvcnt, already in distribution.csv (swfsc/invert folded in)",
  8,  "matched",  "swfsc_ichthyo",                     "erdCalCOFIinvsiz, already in distribution.csv",
  9,  "matched",  "sio_pic-zooplankton",               "erdCalCOFIzoovol, already in distribution.csv (biovolume, pending Q01)",
  10, "holding",  "swfsc_ctd-noaa",                    "erdCalCOFINOAAhydros is NOT a mirror of calcofi_ctd-cast (uncalibrated, per its own abstract) -- a holding candidate",
  11, "matched",  "calcofi_bottle",                    "siocalcofiHydroCast, already in distribution.csv",
  12, "matched",  "calcofi_ctd-cast",                  "exact match to link_data_source (calcofi.org/data/oceanographic-data/ctd-cast-files/)",
  13, "matched",  "calcofi_bottle",                    "exact match to link_calcofi_org (calcofi.org/data/oceanographic-data/bottle-database/)",
  14, "matched",  "farallon_bird-mammal",               "CAC_FI_SBAS_obs matches link_data_source; CAC_FI_SBAS_tr (transect effort) is a new distribution row",
  15, "matched",  "calcofi_mets",                      "exact match to link_data_source/link_calcofi_org (calcofi.org/data/oceanographic-data/underway/)",
  16, "matched",  "cce-lter_picoplankton-bacteria",     "exact match to link_data_source (datazoo/159)",
  17, "matched",  "calcofi_phytoplankton",              "datazoo/254 is the DataZoo predecessor route; ingest's link_data_source is EDI 254.4 -- new mirror distribution row",
  18, "holding",  "cce-lter_hplc-pigments",             "EDI 72 (HPLC pigments) is a DIFFERENT variable than calcofi_phytoplankton's visual counts -- not matched",
  19, "matched",  "cce-lter_zooscan",                   "zooscandb/secure/login.php normalizes to link_data_source's zooscandb/ (same portal)",
  20, "matched",  "cce-lter_zoodb",                     "zoodb/ (http) normalizes to link_data_source's zoodb/ (https)",
  21, "matched",  "cce-lter_euphausiids",                "exact match to link_data_source (EDI 313)",
  22, "matched",  "calcofi_phyllosoma",                 "exact match to link_data_source (EDI 188.4)",
  23, "holding",  "sio_cetacean-sightings",              "EDI 262 (Hildebrand cetacean visual monitoring) is NOT farallon_bird-mammal's EDI 255 (Sydeman bird/mammal census) -- a different package/PI",
  24, "holding",  "cce-lter_poc-pon",                    "EDI 54 (POC/PON, CalCOFI-CCE Augmented cruises) -- no ingest",
  25, "holding",  "cce-lter_toc",                        "EDI 253 (TOC) -- no ingest",
  26, "holding",  "cce-lter_poc-pon-cce-region",         "CONFLICT: sheet row 26 header/abstract describe nitrate stable isotopes (N15/O18), but EDI knb-lter-cce.104 (the URL given, rev 13 checked 2026-09-05) is titled 'Particulate organic carbon and nitrogen measurements ... in the CCE region since 2006' -- likely a wrong EDI accession in the sheet. Recorded under the verified EDI title; the isotope dataset's real accession is unconfirmed.",
  27, "holding",  "cce-lter_primary-production-c14",    "EDI 71 (primary production, C14 uptake) -- overlaps dataset_status.csv calcofi/prodo #34",
  28, "holding",  "calcofi_prodo",                       "EDI 78 (PRODO product; abstract says 'drawn from the CalCOFI hydrographic bottle database') -- overlaps calcofi_bottle's chlorophyll/productivity fields; recorded as holding per plan guidance, not a mirror; also #34",
  29, "matched",  "calcofi_dic",                         "exact match to link_data_source (NCEI 0301029)",
  30, "holding",  "jcvi_ncog-metabarcoding",             "NCBI BioProjects 555783/665326 -- new provider jcvi",
  31, "holding",  "sccoos_ifcb-ctd",                     "ifcb.caloos.org CTD timeline -- provider sccoos (CalOOS/SCCOOS-hosted IFCB)",
  32, "holding",  "sccoos_ifcb-underway",                "ifcb.caloos.org underway timeline",
  33, "holding",  "stanford_hopkins-zooplankton",        "Stanford Digital Repository DOI 10.25740/nt620vn7810 -- new provider stanford",
  34, "holding",  "stanford_hopkins-supplemental",       "abstract describes real content (hydrographic/met/bio field-notebook scans) distinct from 33/35, not a duplicate; access URL is a generic SearchWorks query pending a specific record",
  35, "holding",  "stanford_hopkins-phytoplankton",      "searchworks.stanford.edu/view/pz376rp0413 -- a specific catalog record",
  36, "matched",  "sio_mesopelagic-fish",                "exact match to link_data_source (UCSD Library bb9217084g)",
  37, "matched",  "cdfw_dungeness-crab",                 "Access URL is 'TBD (coming)'; matched by dataset name/module to the already-ingested cdfw_dungeness-crab (megalopae time series source file)",
  38, "matched",  "cdfw_dungeness-crab",                 "Access URL is 'TBD (coming)'; matched by dataset name/module (sorting-log source file)",
  39, "holding",  "cce-lter_iron",                       "EDI 21 (dissolved/total iron) -- new holding; sheet's own DOI matches the newest revision (21.3)",
  40, "holding",  "cce-lter_chl-size-fractionated",     "EDI 249 (size-fractionated Chl a) -- new holding; sheet's own DOI matches the newest revision (249.3)",
  41, "holding",  "calpoly_whale-edna",                  "Zenodo DOI (baleen whale eDNA) -- new provider calpoly"
)
stopifnot(nrow(DISPOSITION) == 41, setequal(DISPOSITION$row, 1:41))

# newest-revision EDI citations for the holdings above (measured 2026-09-05 via
# cite.edirepository.org/cite/knb-lter-cce.<id>.<rev>?style=ESIP; the newest
# revision that answers 200 is used, and the sheet's own accession/revision
# is superseded when a newer one exists)
EDI_CITE <- list(
  "cce-lter_hplc-pigments" = list(pkg = "knb-lter-cce.72.4", doi = "10.6073/pasta/831e099fb086954d3d73638d33d3dd05",
    title = "High Performance Liquid Chromatography (HPLC) pigment analysis from rosette bottle samples at various depths from CCE LTER process cruises in the California Current System, 2006 to 2017"),
  "sio_cetacean-sightings" = list(pkg = "knb-lter-cce.262.2", doi = "10.6073/pasta/9ee6ca9b4a316708ca3d17ddc92debfb",
    title = "Index of visual monitoring, location, species behavior, and identification of cetaceans from CalCOFI cruises in the California Current System, 2005-2015 (ongoing)"),
  "cce-lter_poc-pon" = list(pkg = "knb-lter-cce.54.10", doi = "10.6073/pasta/830ff22e75a9de5b493af48330e5fc4c",
    title = "Particulate organic carbon and nitrogen measurements at selected depths in the water column from CalCOFI-CCE Augmented cruises in the California Current System, 2004 - November 2022"),
  "cce-lter_toc" = list(pkg = "knb-lter-cce.253.3", doi = "10.6073/pasta/ba2ce7e921448a75372109d9f2f5cab2",
    title = "Total dissolved organic carbon measurements at standard depths in the water column from nine CalCOFI cruises, 2008-2017"),
  "cce-lter_poc-pon-cce-region" = list(pkg = "knb-lter-cce.104.13", doi = "10.6073/pasta/9feb1de01eb3795e7ea39a8b7ba325e6",
    title = "Particulate organic carbon and nitrogen measurements at selected depths in the water column in the CCE region since 2006 - 2024 (ongoing)"),
  "cce-lter_primary-production-c14" = list(pkg = "knb-lter-cce.71.6", doi = "10.6073/pasta/0b954fc2d13835a58bdbf17aa5119d34",
    title = "Primary production estimates from 14C uptake (in situ), determined by the incorporation of inorganic carbon into particulate organic carbon (POC) due to photosynthesis at selected light levels from CCE LTER process cruises in the California Current System, 2006 - 2021 (ongoing)"),
  "calcofi_prodo" = list(pkg = "knb-lter-cce.78.5", doi = "10.6073/pasta/7f8e5d24e9b27ae695295a8ddc0809d1",
    title = "Measurements from CalCOFI cruises in the California Current System, including log of station information, weather, sea conditions as well as physical, chemical and biological measurements including temperature, salinity, oxygen, density, sigma theta, phosphate, silicate, nitrite, nitrate, ammonia, chlorophyll a, integrated chlorophyll a, primary productivity, and integrated primary production. 1949 - January 2020"),
  "cce-lter_iron" = list(pkg = "knb-lter-cce.21.3", doi = "10.6073/pasta/63c4e57f87861db3acaf80d1dec103e1",
    title = "Measurements of dissolved inorganic concentrations of nutrient iron and of iron limitation at selected stations and depths from CalCOFI cruises in the California Current System, Nov. 2002 - July 2004 (completed)"),
  "cce-lter_chl-size-fractionated" = list(pkg = "knb-lter-cce.249.3", doi = "10.6073/pasta/02183db3ad041992304d26757f1b25f9",
    title = "Size fractionation of total Chl a larger and smaller than 8 μm data generated by Mike Mullin of the Marine Life Research Group, aboard CalCOFI (California Cooperative Oceanic Fisheries Investigations) cruises of the coast of California, January 1994 - October 1996")
)

# 16 ingested datasets: GCMD Science Keywords (verified 2026-09-05 against the
# live GCMD KMS export -- gcmd.earthdata.nasa.gov/kms/concepts/concept_scheme/
# sciencekeywords?format=csv, Keyword Version 24.7 -- every string below is an
# exact "Category > Topic > Term > ..." path in that export), justified from
# the dataset's category.csv row + the measurement_type.csv categories/
# variables its own rows carry (never invented past what those show).
GCMD_KEYWORDS <- list(
  "calcofi_bottle" = c(
    "EARTH SCIENCE > OCEANS > OCEAN TEMPERATURE > WATER TEMPERATURE",
    "EARTH SCIENCE > OCEANS > SALINITY/DENSITY > OCEAN SALINITY",
    "EARTH SCIENCE > OCEANS > OCEAN CHEMISTRY > OXYGEN",
    "EARTH SCIENCE > OCEANS > OCEAN CHEMISTRY > NUTRIENTS",
    "EARTH SCIENCE > OCEANS > OCEAN CHEMISTRY > CHLOROPHYLL"),
  "calcofi_ctd-cast" = c(
    "EARTH SCIENCE > OCEANS > OCEAN TEMPERATURE > WATER TEMPERATURE",
    "EARTH SCIENCE > OCEANS > SALINITY/DENSITY > OCEAN SALINITY",
    "EARTH SCIENCE > OCEANS > OCEAN CHEMISTRY > OXYGEN",
    "EARTH SCIENCE > OCEANS > OCEAN PRESSURE > WATER PRESSURE"),
  "calcofi_dic" = c(
    "EARTH SCIENCE > OCEANS > OCEAN CHEMISTRY > INORGANIC CARBON",
    "EARTH SCIENCE > OCEANS > OCEAN CHEMISTRY > ALKALINITY",
    "EARTH SCIENCE > OCEANS > OCEAN CHEMISTRY > PH",
    "EARTH SCIENCE > OCEANS > OCEAN TEMPERATURE > WATER TEMPERATURE",
    "EARTH SCIENCE > OCEANS > SALINITY/DENSITY > OCEAN SALINITY"),
  "calcofi_mets" = c(
    "EARTH SCIENCE > ATMOSPHERE > ATMOSPHERIC WINDS",
    "EARTH SCIENCE > ATMOSPHERE > ATMOSPHERIC TEMPERATURE > SURFACE TEMPERATURE > AIR TEMPERATURE",
    "EARTH SCIENCE > ATMOSPHERE > ATMOSPHERIC PRESSURE > SURFACE PRESSURE",
    "EARTH SCIENCE > OCEANS > OCEAN OPTICS > OCEAN COLOR",
    "EARTH SCIENCE > OCEANS > OCEAN TEMPERATURE > WATER TEMPERATURE"),
  "calcofi_phyllosoma" = c(
    "EARTH SCIENCE > BIOSPHERE > ECOSYSTEMS > AQUATIC ECOSYSTEMS > PLANKTON > ZOOPLANKTON",
    "EARTH SCIENCE > BIOLOGICAL CLASSIFICATION > ANIMALS/INVERTEBRATES > ARTHROPODS > CRUSTACEANS > DECAPODS"),
  "calcofi_phytoplankton" = c(
    "EARTH SCIENCE > BIOSPHERE > ECOSYSTEMS > AQUATIC ECOSYSTEMS > PLANKTON > PHYTOPLANKTON",
    "EARTH SCIENCE > BIOLOGICAL CLASSIFICATION > PROTISTS > PLANKTON > PHYTOPLANKTON"),
  "cce-lter_euphausiids" = c(
    "EARTH SCIENCE > BIOSPHERE > ECOSYSTEMS > AQUATIC ECOSYSTEMS > PLANKTON > ZOOPLANKTON",
    "EARTH SCIENCE > BIOLOGICAL CLASSIFICATION > ANIMALS/INVERTEBRATES > ARTHROPODS > CRUSTACEANS > EUPHAUSIIDS (KRILL)"),
  "cce-lter_picoplankton-bacteria" = c(
    "EARTH SCIENCE > BIOLOGICAL CLASSIFICATION > BACTERIA/ARCHAEA",
    "EARTH SCIENCE > BIOLOGICAL CLASSIFICATION > PROTISTS > PLANKTON > PHYTOPLANKTON"),
  "cce-lter_zoodb" = c(
    "EARTH SCIENCE > BIOSPHERE > ECOSYSTEMS > AQUATIC ECOSYSTEMS > PLANKTON > ZOOPLANKTON",
    "EARTH SCIENCE > BIOLOGICAL CLASSIFICATION > ANIMALS/INVERTEBRATES > ARTHROPODS > CRUSTACEANS",
    "EARTH SCIENCE > BIOLOGICAL CLASSIFICATION > ANIMALS/INVERTEBRATES > ARTHROPODS > CRUSTACEANS > COPEPODS"),
  "cce-lter_zooscan" = c(
    "EARTH SCIENCE > BIOSPHERE > ECOSYSTEMS > AQUATIC ECOSYSTEMS > PLANKTON > ZOOPLANKTON",
    "EARTH SCIENCE > BIOLOGICAL CLASSIFICATION > ANIMALS/INVERTEBRATES > ARTHROPODS > CRUSTACEANS"),
  "cdfw_dungeness-crab" = c(
    "EARTH SCIENCE > BIOSPHERE > ECOSYSTEMS > AQUATIC ECOSYSTEMS > PLANKTON > ZOOPLANKTON",
    "EARTH SCIENCE > BIOLOGICAL CLASSIFICATION > ANIMALS/INVERTEBRATES > ARTHROPODS > CRUSTACEANS > DECAPODS"),
  "farallon_bird-mammal" = c(
    "EARTH SCIENCE > BIOLOGICAL CLASSIFICATION > ANIMALS/VERTEBRATES > BIRDS",
    "EARTH SCIENCE > BIOLOGICAL CLASSIFICATION > ANIMALS/VERTEBRATES > MAMMALS"),
  "sio_mesopelagic-fish" = c(
    "EARTH SCIENCE > BIOLOGICAL CLASSIFICATION > ANIMALS/VERTEBRATES > FISH",
    "EARTH SCIENCE > BIOLOGICAL CLASSIFICATION > ANIMALS/VERTEBRATES > FISH > RAY-FINNED FISHES"),
  "sio_pic-zooplankton" = c(
    "EARTH SCIENCE > BIOSPHERE > ECOSYSTEMS > AQUATIC ECOSYSTEMS > PLANKTON",
    "EARTH SCIENCE > BIOSPHERE > ECOSYSTEMS > AQUATIC ECOSYSTEMS > PLANKTON > ZOOPLANKTON"),
  "swfsc_cufes" = c(
    "EARTH SCIENCE > BIOLOGICAL CLASSIFICATION > ANIMALS/VERTEBRATES > FISH",
    "EARTH SCIENCE > BIOLOGICAL CLASSIFICATION > ANIMALS/VERTEBRATES > FISH > RAY-FINNED FISHES > ANCHOVIES/HERRINGS"),
  "swfsc_ichthyo" = c(
    "EARTH SCIENCE > BIOLOGICAL CLASSIFICATION > ANIMALS/VERTEBRATES > FISH",
    "EARTH SCIENCE > BIOLOGICAL CLASSIFICATION > ANIMALS/VERTEBRATES > FISH > RAY-FINNED FISHES")
)

# 3. helpers to pull sheet fields into sidecar shapes ----------------------------

lead_creator <- function(r) {
  nm <- g(r, "lead_name"); if (is.null(nm)) return(NULL)
  list(list(name = nm, organization = g(r, "lead_affiliation"), email = g(r, "lead_email"), role = "lead"))
}
role_parties <- function(r, col, role) {
  v <- g(r, col); if (is.null(v)) return(NULL)
  list(list(name = v, role = role))
}
associated_parties_for <- function(r) {
  c(role_parties(r, "contrib_collection", "data collection"),
    role_parties(r, "contrib_qaqc", "processing/QA-QC"),
    role_parties(r, "contrib_curation", "curation/management"),
    role_parties(r, "contrib_other", "other"))
}
qc_md_for <- function(r) {
  flag <- g(r, "qc_flags"); proto <- g(r, "qc_protocol")
  if (is.null(flag) && is.null(proto)) return(NULL)
  paste(c(if (!is.null(flag)) sprintf("QC flags present: %s.", flag), proto), collapse = " ")
}
maintenance_for <- function(r) {
  bits <- c(g(r, "update_frequency"), g(r, "ongoing_archived"),
            if (!is.null(g(r, "continuous"))) sprintf("continuous: %s", g(r, "continuous")))
  if (!length(bits)) return(NULL)
  paste(bits, collapse = "; ")
}
tags_for <- function(r) { t <- g(r, "tags"); if (is.null(t)) return(NULL); as.list(trimws(strsplit(t, ",")[[1]])) }

# 4. YAML emission with a `# source:` comment per top-level key -----------------

yaml_field <- function(key, value, source) {
  if (is.null(value)) return(NULL)
  y <- yaml::as.yaml(stats::setNames(list(value), key))
  paste0("# source: ", source, "\n", sub("\n$", "", y))
}
write_sidecar <- function(path, blocks) {
  blocks <- Filter(Negate(is.null), blocks)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(paste(blocks, collapse = "\n\n"), path)
  message("  wrote ", path)
}

pd_of <- function(key) { m <- regmatches(key, regexec("^([^_]+)_(.+)$", key))[[1]]; list(provider = m[2], dataset = m[3]) }

# 5. matched datasets -> dataset_meta.proposed.yml ------------------------------

matched <- DISPOSITION |> filter(kind == "matched")
report_matched <- tibble()

for (key in unique(matched$key)) {
  rows <- matched$row[matched$key == key]
  pd <- pd_of(key)
  out_path <- file.path(METADATA_DIR, pd$provider, pd$dataset, "dataset_meta.proposed.yml")
  report_matched <- bind_rows(report_matched, tibble(dataset_key = key, rows = paste(rows, collapse = ",")))

  if (file.exists(out_path)) { message("skip (exists): ", out_path); next }
  if (DRY) { message("[dry] would write: ", out_path); next }

  # aggregate creators across the group's rows, deduped by (name, email)
  creators <- unique(unlist(lapply(rows, lead_creator), recursive = FALSE))
  parties  <- unique(unlist(lapply(rows, associated_parties_for), recursive = FALSE))
  keywords <- as.list(unique(unlist(lapply(rows, tags_for))))
  funders  <- unique(unlist(lapply(rows, function(r) g(r, "funders"))))
  qc_mds   <- unique(unlist(lapply(rows, qc_md_for)))
  maint    <- unique(unlist(lapply(rows, maintenance_for)))
  citation <- unique(unlist(lapply(rows, function(r) g(r, "citation_preferred"))))
  # abstract: only propose one when the group is a single sheet row -- a
  # multi-row group (e.g. swfsc_ichthyo's 7 rows) each describes one MEASURED
  # SLICE, not the dataset as a whole, and picking one would misrepresent the
  # others (never invent a synthesis nobody wrote)
  abstract <- if (length(rows) == 1) g(rows[1], "abstract") else NULL

  blocks <- list(
    if (length(creators)) yaml_field("creators", creators, src_rows(rows)),
    if (length(rows) == 1 && !is.null(g(rows[1], "lead_email")))
      yaml_field("contact", g(rows[1], "lead_email"), src(rows[1])),
    if (length(keywords)) yaml_field("keywords", keywords, src_rows(rows)),
    if (!is.null(GCMD_KEYWORDS[[key]]))
      yaml_field("keywords_gcmd", GCMD_KEYWORDS[[key]],
                 paste0(GCMD_VIEWER, ", checked ", TODAY, " (GCMD KMS export, Earth Science, verified 2026-09-05)")),
    if (length(funders)) yaml_field("funding", paste(funders, collapse = "; "), src_rows(rows)),
    if (length(parties)) yaml_field("associated_parties", parties, src_rows(rows)),
    if (length(qc_mds)) yaml_field("quality_control_md", paste(qc_mds, collapse = " / "), src_rows(rows)),
    if (length(maint)) yaml_field("maintenance", paste(maint, collapse = " / "), src_rows(rows)),
    if (length(citation)) yaml_field("citation_main", citation[1], src_rows(rows)),
    if (!is.null(abstract)) yaml_field("abstract", abstract, src(rows[1]))
  )
  write_sidecar(out_path, blocks)
}

# 6. holdings -> dataset_meta.yml -------------------------------------------------

holdings <- DISPOSITION |> filter(kind == "holding")
report_holdings <- tibble()

holding_category <- c(
  "swfsc_ctd-noaa" = "Physical Oceanography",
  "cce-lter_hplc-pigments" = "Productivity & Pigments",
  "sio_cetacean-sightings" = "Seabirds & Marine Mammals",
  "cce-lter_poc-pon" = "Nutrients & Chemistry",
  "cce-lter_toc" = "Nutrients & Chemistry",
  "cce-lter_poc-pon-cce-region" = "Nutrients & Chemistry",
  "cce-lter_primary-production-c14" = "Productivity & Pigments",
  "calcofi_prodo" = "Productivity & Pigments",
  "jcvi_ncog-metabarcoding" = "Genomics & eDNA",
  "sccoos_ifcb-ctd" = "Phytoplankton",
  "sccoos_ifcb-underway" = "Phytoplankton",
  "stanford_hopkins-zooplankton" = "Zooplankton",
  "stanford_hopkins-supplemental" = "Physical Oceanography",
  "stanford_hopkins-phytoplankton" = "Phytoplankton",
  "cce-lter_iron" = "Nutrients & Chemistry",
  "cce-lter_chl-size-fractionated" = "Productivity & Pigments",
  "calpoly_whale-edna" = "Genomics & eDNA")

holding_gh_issue <- c("cce-lter_primary-production-c14" = "#34", "calcofi_prodo" = "#34")

for (i in seq_len(nrow(holdings))) {
  key <- holdings$key[i]; r <- holdings$row[i]
  pd <- pd_of(key)
  out_path <- file.path(METADATA_DIR, pd$provider, pd$dataset, "dataset_meta.yml")
  report_holdings <- bind_rows(report_holdings, tibble(key = key, row = r, note = holdings$note[i]))

  if (file.exists(out_path)) { message("skip (exists): ", out_path); next }
  if (DRY) { message("[dry] would write: ", out_path); next }

  status <- if (identical(g(r, "ongoing_archived"), "archived") ||
                grepl("^archived", g(r, "ongoing_archived") %||% "")) "archived" else "external"
  edi <- EDI_CITE[[key]]
  dataset_name <- if (!is.null(edi)) edi$title else g(r, "title_portal") %||% g(r, "dataset_name")
  doi   <- if (!is.null(edi)) edi$doi else if (!is.null(g(r, "doi")) && grepl("doi\\.org", g(r, "doi")))
             sub("^https?://doi\\.org/", "", g(r, "doi")) else NULL
  link  <- g(r, "access_url")
  creators <- lead_creator(r)
  parties  <- associated_parties_for(r)
  keywords <- tags_for(r)

  blocks <- list(
    yaml_field("provider", pd$provider, "WS-R1 2026-09-05: dataset_key minted from the CalOOS row's access URL/provider"),
    yaml_field("dataset", pd$dataset, "WS-R1 2026-09-05"),
    yaml_field("dataset_name", dataset_name,
               if (!is.null(edi)) paste0("https://cite.edirepository.org/cite/", edi$pkg, "?style=ESIP, checked ", TODAY,
                                          " (newest EDI revision; overrides the sheet's title where they disagree, see note)")
               else src(r)),
    yaml_field("category", holding_category[[key]], "WS-R1 2026-09-05: category.csv (widened for this holding, see hand-back)"),
    yaml_field("status", status, src(r)),
    yaml_field("visibility", "public", "WS-R1 2026-09-05 default"),
    yaml_field("priority_caloos", g(r, "priority_caloos"), src(r)),
    if (key %in% names(holding_gh_issue))
      yaml_field("gh_issue", unname(holding_gh_issue[[key]]), "dataset_status.csv calcofi/prodo row (#34)"),
    yaml_field("module", g(r, "module"), src(r)),
    yaml_field("abstract", g(r, "abstract"), src(r)),
    if (length(creators)) yaml_field("creators", creators, src(r)),
    if (!is.null(g(r, "lead_email"))) yaml_field("contact", g(r, "lead_email"), src(r)),
    if (length(keywords)) yaml_field("keywords", keywords, src(r)),
    if (length(parties)) yaml_field("associated_parties", parties, src(r)),
    yaml_field("funding", g(r, "funders"), src(r)),
    yaml_field("quality_control_md", qc_md_for(r), src(r)),
    yaml_field("maintenance", maintenance_for(r), src(r)),
    yaml_field("doi", doi, if (!is.null(edi)) paste0("https://cite.edirepository.org/cite/", edi$pkg, "?style=ESIP, checked ", TODAY) else src(r)),
    yaml_field("link_data_source", link, src(r)),
    # next_step is what holdings_from_sidecars() surfaces as holdings.csv's `notes`
    # column (plan D-11) -- the match/conflict evidence goes here, not in a key the
    # generated index would never show
    yaml_field("next_step",
               paste0("confirm dataset scope, license and DOI with the provider; no ingest planned yet. ",
                      holdings$note[i]),
               "WS-R1 2026-09-05 triage note + match/conflict evidence (see hand-back)")
  )
  write_sidecar(out_path, blocks)
}

# 7. provider.csv: JCVI, Cal Poly, Stanford Hopkins Marine Station --------------

provider_path <- file.path(METADATA_DIR, "provider.csv")
provider <- readr::read_csv(provider_path, show_col_types = FALSE, na = character())
new_providers <- tribble(
  ~provider,  ~provider_short,        ~provider_name,                                     ~url,                                        ~status,  ~notes,
  "jcvi",     "JCVI",                 "J. Craig Venter Institute",                         "https://www.jcvi.org",                      "active", "Andy Allen's group; NCOG metabarcoding + IFCB holdings. Added 2026-09-05 from the CalOOS working sheet (WS-R1); url checked 2026-09-05 (200).",
  "calpoly",  "Cal Poly",             "California Polytechnic State University",           "https://www.calpoly.edu",                    "active", "Trevor Ruiz; baleen-whale eDNA density-prediction holding. Added 2026-09-05 from the CalOOS working sheet (WS-R1); url checked 2026-09-05 (200).",
  "stanford", "Stanford Hopkins MS",  "Hopkins Marine Station, Stanford University",       "https://hopkinsmarinestation.stanford.edu",  "active", "Amanda Whitmire; historical (1955-1974) Monterey Bay CalCOFI zooplankton/phytoplankton/supplemental holdings. Added 2026-09-05 from the CalOOS working sheet (WS-R1); url checked 2026-09-05 (200, note the site is 'hopkinsmarinestation', no dot)."
)
missing_providers <- anti_join(new_providers, provider, by = "provider")
if (nrow(missing_providers) && !DRY) {
  readr::write_csv(bind_rows(provider, missing_providers), provider_path, na = "")
  message("appended ", nrow(missing_providers), " provider(s) to ", provider_path)
} else message(nrow(missing_providers), " provider(s) to add (", if (DRY) "dry run" else "none new", ")")

# 8. category.csv: Genomics & eDNA + widen Nutrients & Chemistry / Phytoplankton -

category_path <- file.path(METADATA_DIR, "category.csv")
category <- readr::read_csv(category_path, show_col_types = FALSE, na = character(),
                            col_types = readr::cols(.default = readr::col_character()))
changed <- FALSE
if (!"Genomics & eDNA" %in% category$category) {
  category <- bind_rows(category, tibble(
    category = "Genomics & eDNA", order = "13", realm = "bio", icon = "cat-genomics",
    description = "Metabarcoding and environmental DNA — ASV tables, eDNA-derived abundance and density"))
  changed <- TRUE
  message("added category: Genomics & eDNA")
}
widen <- function(cat, new_desc) {
  i <- which(category$category == cat)
  if (length(i) && !identical(category$description[i], new_desc)) {
    category$description[i] <<- new_desc; changed <<- TRUE
    message("widened category: ", cat)
  }
}
widen("Nutrients & Chemistry",
      "Nitrate, nitrite, phosphate, silicate and ammonium from bottle samples; particulate and total organic carbon and nitrogen, nitrate isotopes, and trace metals (iron)")
widen("Phytoplankton",
      "Phytoplankton counts by taxon or functional group, and imaging flow cytometry (IFCB)")
if (changed && !DRY) {
  category <- category |> arrange(as.integer(order))
  readr::write_csv(category, category_path, na = "")
  message("wrote ", category_path)
} else message("category.csv: ", if (changed) "changes pending (dry run)" else "already up to date")

# 9. distribution.csv: caloos module rows + the two new mirror rows -------------

dist_path <- file.path(METADATA_DIR, "distribution.csv")
dist <- readr::read_csv(dist_path, show_col_types = FALSE, na = character(),
                        col_types = readr::cols(.default = readr::col_character()))
new_dist <- tribble(
  ~dataset_key, ~kind,     ~portal,  ~id,                                     ~url,                                                                                                            ~title,                                                                          ~status,    ~superseded_by, ~observed_utc,           ~notes,
  "swfsc_ichthyo",         "service", "caloos", "1a1a7812-48f9-4325-8ad0-e51e67e366ba",
    "https://data.caloos.org/#module-metadata/1a1a7812-48f9-4325-8ad0-e51e67e366ba",
    "CalCOFI Fish Eggs & Larvae Counts/Stages from net tows and CUFES (CalOOS module)", "external", "", "2026-09-05T00:00:00Z",
    "CalOOS catalog module id for the CoastWatch mirror rows; # source: caloos-sheet rows 1,4, 2026-09-05",
  "sio_pic-zooplankton",   "service", "caloos", "81f12914-825b-499c-8aad-33b34ec29c93",
    "https://data.caloos.org/#module-metadata/81f12914-825b-499c-8aad-33b34ec29c93/2301d387-2347-4632-aa3d-afc45a39bec3",
    "CalCOFI Zooplankton Biovolumes from net tows (CalOOS module)", "external", "", "2026-09-05T00:00:00Z",
    "# source: caloos-sheet row 9, 2026-09-05",
  "farallon_bird-mammal",  "service", "caloos", "2458d7c2-af69-4a76-abfb-195fb5aa8f14",
    "https://data.caloos.org/#module-metadata/2458d7c2-af69-4a76-abfb-195fb5aa8f14",
    "CalCOFI & CCE-LTER Seabird Visual Observations (CalOOS module)", "external", "", "2026-09-05T00:00:00Z",
    "# source: caloos-sheet row 14, 2026-09-05",
  "calcofi_phytoplankton", "mirror",  "datazoo", "254",
    "https://oceaninformatics.ucsd.edu/datazoo/catalogs/ccelter/datasets/254",
    "CalCOFI Phytoplankton Community Composition (DataZoo 254)", "external", "", "2026-09-05T00:00:00Z",
    "the DataZoo predecessor access route for EDI knb-lter-cce.254 (the ingest's own source); # source: caloos-sheet row 17, 2026-09-05",
  "farallon_bird-mammal",  "source",  "erddap-noaa", "CAC_FI_SBAS_tr",
    "https://oceanview.pfeg.noaa.gov/erddap/tabledap/CAC_FI_SBAS_tr.html",
    "CalCOFI Seabird/Mammal Transect Effort (NOAA ERDDAP)", "external", "", "2026-09-05T00:00:00Z",
    "the transect-effort table alongside link_data_source's CAC_FI_SBAS_obs; # source: caloos-sheet row 14, 2026-09-05"
)
new_dist <- new_dist |> mutate(across(everything(), as.character))
already <- new_dist$url %in% dist$url
if (any(!already) && !DRY) {
  readr::write_csv(bind_rows(dist, new_dist[!already, ]), dist_path, na = "")
  message("appended ", sum(!already), " distribution.csv row(s)")
} else message(sum(!already), " distribution.csv row(s) to add (", if (DRY) "dry run" else "none new", ")")

# 10. report ----------------------------------------------------------------------

message("\n== match table (41 rows) ==")
print(DISPOSITION |> select(row, kind, key, note), n = 41, width = Inf)

message("\n== conflicts (sheet value disagrees with the record) ==")
conflicts <- DISPOSITION |> filter(grepl("CONFLICT|overlaps|NOT a mirror|NOT ", note))
print(conflicts |> select(row, key, note), n = Inf, width = Inf)

message("\n== license claims NOT propagated (evidence insufficient) ==")
message(" rows 1-9 (swfsc_ichthyo/swfsc_cufes/sio_pic-zooplankton): sheet says 'Public domain (CC0) -",
       " Free use and reuse'; the source ERDDAP .das `license` global on erdCalCOFIeggcnt/siocalcofiHydroCast",
       " is the generic ERDDAP disclaimer, NOT a CC0 statement (checked 2026-09-05) -- does not confirm CC0.",
       " swfsc_ichthyo already has an open proposal for US-PD (Q11); swfsc_cufes's license is already 'custom';",
       " sio_pic-zooplankton's license is open via Q08. No license value written; flagged here for a provider decision.")

message("\n== GCMD keywords written ==")
for (k in names(GCMD_KEYWORDS)) message(" ", k, ": ", paste(GCMD_KEYWORDS[[k]], collapse = " | "))

message("\nDone.")
