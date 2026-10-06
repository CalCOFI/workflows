# libs/download_toc.R
# -----------------------------------------------------------------------------
# Reproducible acquisition of the CCE-LTER/Aluwihare total organic carbon
# export used by ingest_cce-lter_toc.qmd.
#
# Source: EDI package knb-lter-cce.253.3, "Total dissolved organic carbon
# measurements at standard depths in the water column from nine CalCOFI
# cruises, 2008-2017". Single entity, "TOC" (table_253.csv): 10,150 rows, 13
# columns, 22 cruises 2008-03 to 2017-08, checked 2026-10-06 against the
# package zip and its EML (13 attributes). Real headers carry unit suffixes the
# EML's attributeName omits (`Latitude (º)`, `Total Organic Carbon (µmol/L)`,
# `TOC CV (%)`), see flds_redefine.csv.
#
# The revision is pinned (3) and the entity's md5 is asserted, so a republished
# package fails loudly rather than silently re-shaping the ingest. md5
# 17b393b6f06441c8f682907b58a87403 is the EML's own <authentication
# method="MD5"> for table_253.csv and matches the file in the package zip
# (checked 2026-10-06). download_edi_entity() skips the md5 check when the
# cached file exists, so confirm from a clean cache after a revision bump.
#
# Sourced + invoked from ingest_cce-lter_toc.qmd (guarded so it only hits EDI
# when the CSV is missing or overwrite = TRUE).

#' Download the Aluwihare TOC CSV from EDI
#'
#' @param out_dir   directory to write data.csv into
#' @param overwrite if FALSE (default) and data.csv exists, use the cached copy
#' @param verbose   print progress
#' @return path to data.csv
download_toc <- function(out_dir, overwrite = FALSE, verbose = TRUE) {

  if (!exists("download_edi_entity"))
    source(here::here("libs/download_edi.R"))

  download_edi_entity(
    scope       = "knb-lter-cce",
    id          = 253,
    rev         = 3,
    entity_name = "TOC",
    dest        = file.path(out_dir, "data.csv"),
    md5         = "17b393b6f06441c8f682907b58a87403",
    overwrite   = overwrite,
    verbose     = verbose)

  file.path(out_dir, "data.csv")
}
