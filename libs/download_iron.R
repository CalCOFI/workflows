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
# md5 pin (checked 2026-10-01): ced2a3df91259c11e650d9b5a01629f3 is the md5 of
# table_21.csv as shipped in the package zip (knb-lter-cce.21.3.zip; presumably the same
# bytes PASTA serves at the entity download URL). The value this file first
# pinned (4c538532e291f12e3118457354433a1f) is NOT an md5: it is the entity id,
# the last path segment of that download URL in the EML
# (.../package/data/eml/knb-lter-cce/21/3/4c538532...). PASTA's own endpoints were
# returning "not authorized" from the macOS box on 2026-10-01 (the whole API, not
# just this package), so the pin could not be re-checked against a live PASTA
# fetch; it matches the zip. Note download_edi_entity() skips the md5 check when
# the cached file exists, so confirm from a clean cache the next time PASTA is up.
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
