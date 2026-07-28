# libs/download_picoplankton_bacteria.R
# -----------------------------------------------------------------------------
# Reproducible acquisition of the CCE-LTER picoplankton + heterotrophic bacteria
# flow-cytometry table used by ingest_cce-lter_picoplankton-bacteria.qmd.
#
# Source: EDI package knb-lter-cce.159, entity "PicoplanktonandBacteriaAbundance"
# (Landry, M., "Picoplankton and Bacteria Abundance (CalCOFI Cruise)").
#
# The dataset is ALSO served from the Datazoo portal
# (oceaninformatics.ucsd.edu/datazoo/.../datasets/159/datatables/159/download),
# which is what the dataset page links to — but that URL 302s to a
# "Login / Accept Data Agreement" form, so it cannot be fetched unattended
# without a human accepting terms. EDI carries the same table (the Datazoo page's
# own DOI, 10.6073/pasta/bc2915c8448214d2841b064a7414064b, resolves to
# knb-lter-cce.159), so we pull from EDI instead.
#
# Revision deliberately NOT pinned: this series is ongoing (2004-2023 and
# growing), so we take the latest published revision and record which one was
# used in the notebook output.
#
# Sourced + invoked from ingest_cce-lter_picoplankton-bacteria.qmd (guarded so
# it only hits EDI when the CSV is missing or overwrite = TRUE).

#' Download the picoplankton + bacteria abundance CSV from EDI
#'
#' @param out_dir   directory to write PicoplanktonandBacteriaAbundance.csv into
#' @param overwrite if FALSE (default) and the CSV exists, use the cached copy
#' @param verbose   print progress
#' @return path to PicoplanktonandBacteriaAbundance.csv
download_picoplankton_bacteria <- function(
    out_dir, overwrite = FALSE, verbose = TRUE) {

  if (!exists("download_edi_entity"))
    source(here::here("libs/download_edi.R"))

  csv <- file.path(out_dir, "PicoplanktonandBacteriaAbundance.csv")

  download_edi_entity(
    scope       = "knb-lter-cce",
    id          = 159,
    entity_name = "PicoplanktonandBacteriaAbundance",
    dest        = csv,
    overwrite   = overwrite,
    verbose     = verbose)

  csv
}
