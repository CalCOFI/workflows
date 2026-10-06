# libs/download_chl_size_fractionated.R
# -----------------------------------------------------------------------------
# Reproducible acquisition of the MLRG/Mullin size-fractionated chlorophyll a
# table used by ingest_cce-lter_chl-size-fractionated.qmd.
#
# Source: EDI package knb-lter-cce.249.3, "Size fractionation of total Chl a
# larger and smaller than 8 um ... January 1994 - October 1996". Single entity,
# "SizeFractionatedChl" (table_249.csv): 422 rows, 8 columns, 12 CalCOFI
# cruises, checked 2026-10-06 against the package zip.
#
# Revision pinned (3) and md5 asserted. md5 f5447bfb82d92ec4f1317ae668f9962d is
# the md5 of table_249.csv as shipped in the package zip (checked 2026-10-06).
# download_edi_entity() skips the md5 check when the cached file exists.

#' Download the size-fractionated chlorophyll CSV from EDI
#'
#' @param out_dir   directory to write data.csv into
#' @param overwrite if FALSE (default) and data.csv exists, use the cached copy
#' @param verbose   print progress
#' @return path to data.csv
download_chl_size_fractionated <- function(out_dir, overwrite = FALSE, verbose = TRUE) {

  if (!exists("download_edi_entity"))
    source(here::here("libs/download_edi.R"))

  download_edi_entity(
    scope       = "knb-lter-cce",
    id          = 249,
    rev         = 3,
    entity_name = "SizeFractionatedChl",
    dest        = file.path(out_dir, "data.csv"),
    md5         = "f5447bfb82d92ec4f1317ae668f9962d",
    overwrite   = overwrite,
    verbose     = verbose)

  file.path(out_dir, "data.csv")
}
