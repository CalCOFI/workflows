# libs/download_ctd_noaa.R
# -----------------------------------------------------------------------------
# Reproducible acquisition of the NOAA SWFSC "CalCOFI NOAA Additional CTD"
# table used by ingest_swfsc_ctd-noaa.qmd.
#
# Source: NOAA CoastWatch ERDDAP tabledap `erdCalCOFINOAAhydros`, the whole table
# as CSV (all 14 variables, no constraint). Checked 2026-10-06: 15,151 rows,
# 1,235 casts on 28 cruise x ship combinations, 2002-02-08 to 2014-08-23; about
# 1.6 MB. ERDDAP's .csv has two header lines: variable names, then units.
#
# ERDDAP generates the file on request, so there is no md5 to pin; the notebook
# asserts the header, the units line and the row count instead. ERDDAP throttles
# repeated requests ("Too Many Requests"), so the download retries with a pause,
# and a cached copy under cc_stage_dir() is used when present.
#
# Sourced + invoked from ingest_swfsc_ctd-noaa.qmd.

CTD_NOAA_URL <- "https://coastwatch.pfeg.noaa.gov/erddap/tabledap/erdCalCOFINOAAhydros.csv"

#' Download the NOAA additional-CTD table from ERDDAP
#'
#' @param out_dir   directory to write data.csv into
#' @param overwrite if FALSE (default) and data.csv exists, use the cached copy
#' @param tries     download attempts before giving up
#' @param verbose   print progress
#' @return path to data.csv
download_ctd_noaa <- function(out_dir, overwrite = FALSE, tries = 3, verbose = TRUE) {
  dest <- file.path(out_dir, "data.csv")
  if (!overwrite && file.exists(dest) && file.size(dest) > 0) {
    if (verbose) cat("ERDDAP: using cached", dest, "\n")
    return(dest)
  }
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)
  tmp <- paste0(dest, ".part")
  for (i in seq_len(tries)) {
    ok <- tryCatch({
      utils::download.file(CTD_NOAA_URL, tmp, mode = "wb", quiet = !verbose)
      TRUE
    }, error = function(e) {
      if (verbose) cat("ERDDAP: attempt", i, "failed:", conditionMessage(e), "\n")
      FALSE
    })
    if (ok && file.size(tmp) > 0) {
      file.rename(tmp, dest)
      return(dest)
    }
    Sys.sleep(30 * i)
  }
  stop("Could not download ", CTD_NOAA_URL, " after ", tries, " attempts. ",
       "Save it from a browser as ", dest, " and re-run.", call. = FALSE)
}
