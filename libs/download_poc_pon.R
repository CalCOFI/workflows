# libs/download_poc_pon.R
# -----------------------------------------------------------------------------
# Reproducible acquisition of the CCE-LTER/Goericke particulate organic carbon
# and nitrogen export used by ingest_cce-lter_poc-pon.qmd.
#
# Source: EDI package knb-lter-cce.54.10, "Particulate organic carbon and
# nitrogen measurements at selected depths in the water column from
# CalCOFI-CCE Augmented cruises in the California Current System, 2004 -
# November 2022". Single entity, "ParticulateOrganicCarbonandNitrogen"
# (table_54.csv): 17,413 rows, 18 columns, checked 2026-10-06 against the
# package zip and its EML (18 attributes). The DataZoo summary page's figures
# (17,289 rows, 17 columns) describe a different snapshot and are not asserted.
# Real headers carry unit suffixes the EML's attributeName omits
# (`Latitude (º)`, `Depth (m)`, `umol/L_C (µmol/L)`, ...), see flds_redefine.csv.
#
# The revision is pinned (10) and the entity's md5 is asserted, so a
# republished package fails loudly rather than silently re-shaping the
# ingest. md5 ff3bf2769247d0d5cd9d05845145ddf9 is the EML's own
# <authentication method="MD5"> for table_54.csv and matches the file in the
# package zip (checked 2026-10-06). download_edi_entity() skips the md5 check
# when the cached file exists, so confirm from a clean cache after a revision
# bump.
#
# Sourced + invoked from ingest_cce-lter_poc-pon.qmd (guarded so it only hits
# EDI when the CSV is missing or overwrite = TRUE).

#' Download the Goericke POC/PON CSV from EDI
#'
#' @param out_dir   directory to write data.csv into
#' @param overwrite if FALSE (default) and data.csv exists, use the cached copy
#' @param verbose   print progress
#' @return path to data.csv
download_poc_pon <- function(out_dir, overwrite = FALSE, verbose = TRUE) {

  if (!exists("download_edi_entity"))
    source(here::here("libs/download_edi.R"))

  download_edi_entity(
    scope       = "knb-lter-cce",
    id          = 54,
    rev         = 10,
    entity_name = "ParticulateOrganicCarbonandNitrogen",
    dest        = file.path(out_dir, "data.csv"),
    md5         = "ff3bf2769247d0d5cd9d05845145ddf9",
    overwrite   = overwrite,
    verbose     = verbose)

  file.path(out_dir, "data.csv")
}
