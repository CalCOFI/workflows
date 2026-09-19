# libs/download_iron.R
# -----------------------------------------------------------------------------
# Reproducible acquisition of the CCE-LTER/Barbeau dissolved iron export used
# by ingest_cce-lter_iron.qmd.
#
# Source: EDI package knb-lter-cce.21.3, "Measurements of dissolved inorganic
# concentrations of nutrient iron and of iron limitation at selected stations
# and depths from CalCOFI cruises in the California Current System, Nov. 2002
# - July 2004 (completed)". Single entity, "DissolvedIron": 171 rows, 13
# columns (studyName, Event Number, Index Number, Latitude, Longitude, Line,
# Station, Datetime PST, Depth, Iron Sampling Equipment, Dissolved Fe, Total
# Fe, Chla response to Fe+) per the package's EML. Unlike the picoplankton/
# bacteria table, this entity is NOT gated behind a Datazoo login/data-
# agreement form, so it is pulled directly from EDI like euphausiids.
#
# The revision is pinned (3, the newest per DataONE's index as of 2026-09-19)
# and the entity's md5 is asserted as the download's expected md5, so a
# republished package fails loudly rather than silently re-shaping the
# ingest.
#
# NOTE (updated 2026-09-19): this URL still could not be exercised from the
# environment that wrote this file — EDI's PASTA API (pasta.lternet.edu) and
# portal (portal.edirepository.org) are both unreachable from here
# (robots.txt on the portal, an org egress policy rejecting the PASTA host).
# The md5 below was corrected against Betty's own EDI portal download of the
# real package zip (knb-lter-cce.21.3_1.zip): table_21.csv inside it hashes
# to ced2a3df91259c11e650d9b5a01629f3, which does NOT match the value this
# notebook originally pinned (4c538532e291f12e3118457354433a1f, sourced from
# a DataONE system-metadata lookup while EDI itself was unreachable and never
# cross-checked against real bytes). The value below is now the one observed
# directly. It is still possible EDI's zip export re-packages the CSV
# slightly differently than the bytes `download_edi_entity()` fetches from
# PASTA's own data-entity URL (e.g. if PASTA regenerates the file on each
# request) — if the first real run of this notebook hits a fresh md5
# mismatch, trust the pipeline's own fetch over this pin and update it, don't
# assume the file changed.
#
# Sourced + invoked from ingest_cce-lter_iron.qmd (guarded so it only hits EDI
# when the CSV is missing or overwrite = TRUE).

#' Download the Barbeau dissolved iron CSV from EDI
#'
#' @param out_dir   directory to write data.csv into
#' @param overwrite if FALSE (default) and data.csv exists, use the cached copy
#' @param verbose   print progress
#' @return path to data.csv
download_iron <- function(out_dir, overwrite = FALSE, verbose = TRUE) {

  if (!exists("download_edi_entity"))
    source(here::here("libs/download_edi.R"))

  download_edi_entity(
    scope       = "knb-lter-cce",
    id          = 21,
    rev         = 3,
    entity_name = "DissolvedIron",
    dest        = file.path(out_dir, "data.csv"),
    md5         = "ced2a3df91259c11e650d9b5a01629f3",
    overwrite   = overwrite,
    verbose     = verbose)

  file.path(out_dir, "data.csv")
}
