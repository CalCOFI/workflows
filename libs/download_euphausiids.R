# libs/download_euphausiids.R
# -----------------------------------------------------------------------------
# Reproducible acquisition of the CCE-LTER euphausiid (BTEDB) abundance export
# used by ingest_cce-lter_euphausiids.qmd.
#
# Source: EDI package knb-lter-cce.313.1, "California Current Ecosystem
# Euphausiid data, Brinton and Townsend Euphausiid Database (BTEDB)".
# The abundance entity is the species- and life-stage-resolved table: 7,482
# tows x 237 columns, of which 225 are {Genus}_{species}_{life_stage}_Abundance.
#
# This SUPERSEDES the earlier hand-staged `{dir_data}/euphausiids/data.csv`,
# which was a 12-column extract carrying a single undifferentiated `Abundance`
# column (the entire content of question Q02). The revision is pinned and the
# md5 asserted so a republished package fails loudly rather than silently
# re-shaping the ingest.
#
# Sourced + invoked from ingest_cce-lter_euphausiids.qmd (guarded so it only
# hits EDI when the CSV is missing or overwrite = TRUE).

#' Download the BTEDB euphausiid abundance CSV from EDI
#'
#' @param out_dir   directory to write data.csv into
#' @param overwrite if FALSE (default) and data.csv exists, use the cached copy
#' @param verbose   print progress
#' @return path to data.csv
download_euphausiids <- function(out_dir, overwrite = FALSE, verbose = TRUE) {

  if (!exists("download_edi_entity"))
    source(here::here("libs/download_edi.R"))

  download_edi_entity(
    scope       = "knb-lter-cce",
    id          = 313,
    rev         = 1,
    entity_name = "Brinton and Townsend Euphausiid Abundance Data",
    dest        = file.path(out_dir, "data.csv"),
    md5         = "3e7b7cf338c4c9cb5a5e8d4196a979e8",
    overwrite   = overwrite,
    verbose     = verbose)

  file.path(out_dir, "data.csv")
}
