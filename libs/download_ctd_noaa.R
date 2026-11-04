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
# repeated requests (HTTP 429 "Too Many Requests"), so the download retries
# minutes apart, honouring Retry-After, and a cached copy under cc_stage_dir()
# is used when present.
#
# Sourced + invoked from ingest_swfsc_ctd-noaa.qmd.

CTD_NOAA_URL <- "https://coastwatch.pfeg.noaa.gov/erddap/tabledap/erdCalCOFINOAAhydros.csv"

#' Download the NOAA additional-CTD table from ERDDAP
#'
#' ERDDAP answers a burst of requests with HTTP 429 (Too Many Requests) and no
#' body, which `utils::download.file()` reports only as a generic failure; the
#' download therefore goes through curl, prints the status of each failed
#' attempt and waits `Retry-After` (else a growing pause, minutes not seconds:
#' 2026-11-04 three attempts 30-90 s apart all got 429) before trying again.
#'
#' @param out_dir   directory to write data.csv into
#' @param overwrite if FALSE (default) and data.csv exists, use the cached copy
#' @param tries     download attempts before giving up
#' @param pause_s   seconds to wait after attempt i is `pause_s * i` unless the
#'   server's Retry-After is longer
#' @param verbose   print progress
#' @return path to data.csv
download_ctd_noaa <- function(out_dir, overwrite = FALSE, tries = 5, pause_s = 120,
                              verbose = TRUE) {
  dest <- file.path(out_dir, "data.csv")
  if (!overwrite && file.exists(dest) && file.size(dest) > 0) {
    if (verbose) cat("ERDDAP: using cached", dest, "\n")
    return(dest)
  }
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)
  tmp <- paste0(dest, ".part")
  for (i in seq_len(tries)) {
    res <- tryCatch(
      curl::curl_fetch_disk(CTD_NOAA_URL, tmp, handle = curl::new_handle(timeout = 600)),
      error = function(e) list(status_code = NA_integer_, headers = raw(0), error = conditionMessage(e)))
    status <- res$status_code
    ok <- isTRUE(status == 200L) && file.exists(tmp) && file.size(tmp) > 0 &&
      startsWith(readLines(tmp, n = 1, warn = FALSE), "cruise,ship,ship_code")
    if (ok) {
      file.rename(tmp, dest)
      if (verbose) cat("ERDDAP: downloaded", dest, "on attempt", i, "\n")
      return(dest)
    }
    if (file.exists(tmp)) file.remove(tmp)
    hdr <- if (length(res$headers)) curl::parse_headers_list(res$headers) else list()
    retry_after <- suppressWarnings(as.numeric(hdr[["retry-after"]]))
    wait <- max(pause_s * i, if (length(retry_after) && !is.na(retry_after)) retry_after else 0)
    if (verbose) cat("ERDDAP: attempt", i, "failed:",
                     if (is.na(status)) res$error else paste("HTTP", status),
                     if (i < tries) paste0("-- waiting ", wait, " s") else "", "\n")
    if (i < tries) Sys.sleep(wait)
  }
  stop("Could not download ", CTD_NOAA_URL, " after ", tries, " attempts. ",
       "Save it from a browser as ", dest, " and re-run.", call. = FALSE)
}
