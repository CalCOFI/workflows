# libs/download_cufes.R
# -----------------------------------------------------------------------------
# Reproducible acquisition of the SWFSC CUFES export used by
# ingest_swfsc_cufes.qmd.
#
# Source: `Cufes.csv` in SWFSC's CSV export of its CalCOFI database, the
# provider folder `{dir_data}/swfsc/ichthyo/` on the shared Drive (mirrored to
# gs://calcofi-files-public/_sync/ and archived with the rest of that folder by
# ingest_swfsc_ichthyo.qmd's read_csv_files()). Ed Weber (SWFSC) added it on
# 2026-09-26: "I also added it to the csv repo. Cufes is also now linked with
# CruiseId". 27 columns, one row per CUFES sample, CufesId unique.
#
# Nothing is written in the Drive folder (never unzip or write in Drive: it
# evicts files to empty placeholders and mints conflict copies). The file is
# copied, byte for byte, to a staging directory under cc_stage_dir(), and the
# notebook archives that copy to gs://calcofi-files-public/archive/swfsc/cufes/.
# The header is asserted so a re-shaped export fails here, not three chunks on.

CUFES_COLUMNS <- c(
  "CufesId", "CruiseId", "Cruise", "Ship", "SampleNumber",
  "Start", "StartLatitude", "StartLongitude", "StartTemperature", "StartSalinity",
  "StartWindSpeed", "StartWindDirection", "StartPumpSpeed",
  "Stop", "StopLatitude", "StopLongitude", "StopTemperature", "StopSalinity",
  "StopWindSpeed", "StopWindDirection", "StopPumpSpeed",
  "SardineEggs", "AnchovyEggs", "JackMackerelEggs", "HakeEggs", "SquidEggs", "OtherFishEggs")

#' Stage SWFSC's Cufes.csv from the provider folder
#'
#' @param dir_src   the provider folder holding Cufes.csv (`{dir_data}/swfsc/ichthyo`)
#' @param out_dir   staging directory to copy it into (under cc_stage_dir())
#' @param overwrite copy even when the staged copy already has the same md5
#' @param verbose   print what happened
#' @return a list: `csv` (the staged path), `md5`, `bytes`, `modified` (the
#'   source file's modification time), `copied` (TRUE when bytes moved)
stage_cufes_source <- function(dir_src, out_dir, overwrite = FALSE, verbose = TRUE) {
  src  <- file.path(path.expand(dir_src), "Cufes.csv")
  dest <- file.path(out_dir, "Cufes.csv")
  stopifnot(
    "Cufes.csv not found in the provider folder" = file.exists(src),
    "Cufes.csv in the provider folder is empty (a Drive placeholder?)" = file.size(src) > 0)
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

  md5_src <- unname(tools::md5sum(src))
  copied  <- FALSE
  if (overwrite || !file.exists(dest) || unname(tools::md5sum(dest)) != md5_src) {
    stopifnot("copying Cufes.csv to the stage failed" =
                file.copy(src, dest, overwrite = TRUE, copy.date = TRUE))
    copied <- TRUE
  }
  stopifnot("staged Cufes.csv differs from the source" =
              unname(tools::md5sum(dest)) == md5_src)

  hdr <- names(readr::read_csv(dest, n_max = 0, show_col_types = FALSE))
  if (!identical(hdr, CUFES_COLUMNS))
    stop("Cufes.csv header changed: missing [",
         paste(setdiff(CUFES_COLUMNS, hdr), collapse = ", "), "], new [",
         paste(setdiff(hdr, CUFES_COLUMNS), collapse = ", "),
         "]. Update metadata/swfsc/cufes/flds_redefine.csv (libs/build_cufes_metadata.R) first.",
         call. = FALSE)

  out <- list(csv = dest, md5 = md5_src, bytes = file.size(dest),
              modified = file.mtime(src), copied = copied)
  if (verbose)
    message(sprintf("Cufes.csv: %s bytes, md5 %s, modified %s (%s)",
                    format(out$bytes, big.mark = ","), out$md5,
                    format(out$modified, "%Y-%m-%d %H:%M"),
                    if (copied) "copied to the stage" else "stage already current"))
  out
}
