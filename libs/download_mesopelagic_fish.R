# libs/download_mesopelagic_fish.R
# -----------------------------------------------------------------------------
# Reproducible acquisition of the SIO mesopelagic-fish (MOHT micronekton trawl)
# workbook used by ingest_ucsd_sio_mesopelagic-fish.qmd.
#
# Source: UC San Diego Library Digital Collections object bb9217084g,
# "CalCOFI Trawl Data" (Koslow, J. Anthony, 2016), https://doi.org/10.6075/J0BZ64DH.
# The object exposes a single xlsx whose download URL is derived from the object
# id, so no scraping of the landing page is needed.
#
# The workbook carries BOTH sheets the ingest depends on: `Sheet1` (the curated
# "Final Data") and the `Original` raw field log that supplies the per-tow date,
# integer start hour/minute, and explicit PST/PDT time zone.
#
# Sourced + invoked from ingest_ucsd_sio_mesopelagic-fish.qmd (guarded so it
# only hits the library when the xlsx is missing or overwrite = TRUE).

#' Download the CalCOFI trawl (mesopelagic fish) workbook from UCSD Library DC
#'
#' @param out_dir   directory to write bb9217084g_1_1.xlsx into
#' @param overwrite if FALSE (default) and the xlsx exists, use the cached copy
#' @param verbose   print progress
#' @return path to bb9217084g_1_1.xlsx
download_mesopelagic_fish <- function(
    out_dir, overwrite = FALSE, verbose = TRUE) {

  xlsx <- file.path(out_dir, "bb9217084g_1_1.xlsx")

  if (!overwrite && file.exists(xlsx)) {
    if (verbose) cat("UCSD DC: using cached", basename(xlsx), "\n")
    return(xlsx)
  }

  url <- "https://library.ucsd.edu/dc/object/bb9217084g/_1_1.xlsx/download"
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  if (verbose) cat("UCSD DC: downloading bb9217084g_1_1.xlsx\n")
  utils::download.file(url, xlsx, mode = "wb", quiet = !verbose)

  # the endpoint returns an HTML error page rather than a 404 when the object
  # id changes, so assert we actually got a workbook
  sig <- readBin(xlsx, "raw", 2)
  if (!identical(sig, as.raw(c(0x50, 0x4b))))
    stop("UCSD DC download is not an xlsx (no PK zip signature) — ",
         "the object id or download path likely changed: ", url)

  xlsx
}
