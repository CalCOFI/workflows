# libs/download_poc_pon_cce_region.R
# -----------------------------------------------------------------------------
# Reproducible acquisition of the CCE-LTER/Aluwihare particulate organic carbon
# and nitrogen export used by ingest_cce-lter_poc-pon-cce-region.qmd.
#
# Source: EDI package knb-lter-cce.104.13, "Particulate organic carbon and
# nitrogen measurements at selected depths in the water column in the CCE
# region since 2006 - 2024 (ongoing)". Single entity,
# "ParticulateOrganicCarbonandNitrogen" (table_104.csv): 3,295 rows,
# 20 columns, 11 CCE Process cruises (P0605KN to P2402), checked 2026-10-06
# against the package zip and its EML (20 attributes).
#
# The revision is pinned (13) and the entity's md5 is asserted, so a
# republished package fails loudly rather than silently re-shaping the
# ingest. md5 f188ed88229ad6f661ad704581ad716b is the EML's own
# <authentication method="MD5"> for table_104.csv and matches the file in the
# package zip (checked 2026-10-06). download_edi_entity() skips the md5 check
# when the cached file exists, so confirm from a clean cache after a revision
# bump.
#
# Sourced + invoked from ingest_cce-lter_poc-pon-cce-region.qmd (guarded so it
# only hits EDI when the CSV is missing or overwrite = TRUE).

#' Download the Aluwihare CCE-region POC/PON CSV from EDI
#'
#' @param out_dir   directory to write data.csv into
#' @param overwrite if FALSE (default) and data.csv exists, use the cached copy
#' @param verbose   print progress
#' @return path to data.csv
download_poc_pon_cce_region <- function(out_dir, overwrite = FALSE, verbose = TRUE) {

  if (!exists("download_edi_entity"))
    source(here::here("libs/download_edi.R"))

  download_edi_entity(
    scope       = "knb-lter-cce",
    id          = 104,
    rev         = 13,
    entity_name = "ParticulateOrganicCarbonandNitrogen",
    dest        = file.path(out_dir, "data.csv"),
    md5         = "f188ed88229ad6f661ad704581ad716b",
    overwrite   = overwrite,
    verbose     = verbose)

  file.path(out_dir, "data.csv")
}
