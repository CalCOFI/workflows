# libs/download_hplc_pigments_calcofi.R
# -----------------------------------------------------------------------------
# Reproducible acquisition of the CCE-LTER/CalCOFI HPLC pigment export used by
# ingest_cce-lter_hplc-pigments-calcofi.qmd.
#
# Source: EDI package knb-lter-cce.316.1, "High Performance Liquid
# Chromatography (HPLC) pigment analysis from rosette bottle samples at various
# depths from CalCOFI-CCE Augmented cruises in the California Current System,
# 2002 to 2023 (ongoing)". Single entity, "ChromatographyPigmentsCalCOFI"
# (table_324.csv; DataZoo dataset 316, datatable 324): 9,153 rows, 60 columns,
# 81 CalCOFI cruises 2002-03 to 2023-04, checked 2026-10-06 against the package
# zip and its EML.
#
# The revision is pinned (1) and the entity's md5 is asserted, so a
# republished package fails loudly rather than silently re-shaping the
# ingest. md5 95e1ef23ebfbf096d1aab29422aab8fd is the EML's own
# <authentication method="MD5"> for table_324.csv and matches the file in the
# package zip (checked 2026-10-06). download_edi_entity() skips the md5 check
# when the cached file exists, so confirm from a clean cache after a revision
# bump.
#
# Sourced + invoked from ingest_cce-lter_hplc-pigments-calcofi.qmd (guarded so
# it only hits EDI when the CSV is missing or overwrite = TRUE).

#' Download the CalCOFI-cruise HPLC pigment CSV from EDI
#'
#' @param out_dir   directory to write data.csv into
#' @param overwrite if FALSE (default) and data.csv exists, use the cached copy
#' @param verbose   print progress
#' @return path to data.csv
download_hplc_pigments_calcofi <- function(out_dir, overwrite = FALSE, verbose = TRUE) {

  if (!exists("download_edi_entity"))
    source(here::here("libs/download_edi.R"))

  download_edi_entity(
    scope       = "knb-lter-cce",
    id          = 316,
    rev         = 1,
    entity_name = "ChromatographyPigmentsCalCOFI",
    dest        = file.path(out_dir, "data.csv"),
    md5         = "95e1ef23ebfbf096d1aab29422aab8fd",
    overwrite   = overwrite,
    verbose     = verbose)

  file.path(out_dir, "data.csv")
}
