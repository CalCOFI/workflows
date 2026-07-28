# libs/download_mets.R
# -----------------------------------------------------------------------------
# Reproducible acquisition of the CalCOFI METS (underway TSG + meteorology)
# archive used by ingest_calcofi_mets.qmd.
#
# Source: https://calcofi.org/data/oceanographic-data/underway/ — the same
# shape as the CTD-cast ingest: scrape every data-file link off the page, cache
# the URL list to CSV so a site outage falls back to the last known inventory,
# then download anything not already local.
#
# The page serves files under two URL shapes, and BOTH encode the cruise
# unambiguously — which is what makes scraping strictly better than the
# hand-staged Drive archive this ingest used to read:
#
#   .../downloads/underway/{YYYY}/{CRUISE}/{file}      <- cruise is the folder
#   .../downloads/underway/{YYYY}/{CRUISE}_Underway*   <- cruise is the filename
#
# There is no case where a folder and a filename disagree (questions.csv
# mets_21): the apparent conflicts were an artifact of how files had been
# copied into Drive folders by hand.
#
# Sourced + invoked from ingest_calcofi_mets.qmd (guarded so it only hits the
# website when files are missing or overwrite = TRUE).

METS_URL <- "https://calcofi.org/data/oceanographic-data/underway/"

# plots (png/pdf) are the bulk of the page and carry no data; *_Notes.txt /
# NewHorizon_notes.txt are per-cruise READMEs — kept as documentation but
# excluded from the ingest's file table by is_data
METS_DATA_EXT  <- c("csv", "txt", "xlsx", "xls", "zip")
METS_NOTES_RGX <- regex("_notes\\.txt$|notes\\.txt$", ignore_case = TRUE)

#' Scrape the underway page for every data-file URL
#'
#' @param cache_csv path to cache the scraped inventory; used as the fallback
#'   when the site is unreachable
#' @param url page to scrape
#' @return tibble of url, file_name, year, cruise_key, is_data
scrape_mets_urls <- function(cache_csv, url = METS_URL) {

  parse_links <- function(page) {
    hrefs <- page |>
      rvest::html_nodes("a[href]") |>
      rvest::html_attr("href")
    hrefs <- unique(hrefs[grepl("/downloads/underway/", hrefs, fixed = TRUE)])
    hrefs <- ifelse(startsWith(hrefs, "http"), hrefs,
                    paste0("https://calcofi.org", hrefs))

    tibble::tibble(url = hrefs) |>
      dplyr::mutate(
        file_name = basename(url),
        ext       = tolower(tools::file_ext(file_name)),
        rel       = sub("^.*/downloads/underway/", "", url),
        year      = as.integer(stringr::str_extract(rel, "^\\d{4}")),
        # shape 1: {year}/{CRUISE}/{file} -> cruise is the middle path segment.
        # shape 2: {year}/{CRUISE}_Underway*.csv -> cruise is the filename stem.
        # The last two fallbacks cover codes with no ship suffix at all
        # (1411_UnderwayFinaldt.csv) and the CC{YYMM}UW_1MinData.xlsx naming;
        # the ingest resolves those to a ship via the cruise reference table.
        cruise_code = dplyr::coalesce(
          stringr::str_extract(rel, "^\\d{4}/(\\d{4}[A-Za-z][A-Za-z0-9])/", group = 1),
          stringr::str_extract(file_name, "^(\\d{4}[A-Za-z][A-Za-z0-9])[_.]", group = 1),
          stringr::str_extract(rel, "^\\d{4}/(\\d{4})/", group = 1),
          stringr::str_extract(file_name, "^(\\d{4})_", group = 1),
          stringr::str_extract(file_name, "^CC(\\d{4})UW", group = 1)) |>
          toupper(),
        cruise_key = cruise_code,
        is_data = ext %in% METS_DATA_EXT &
          !stringr::str_detect(file_name, METS_NOTES_RGX)) |>
      dplyr::filter(ext %in% c(METS_DATA_EXT, "pdf", "png")) |>
      dplyr::select(-rel) |>
      dplyr::arrange(dplyr::desc(year), cruise_key, file_name)
  }

  out <- tryCatch({
    d <- parse_links(rvest::read_html(url))
    dir.create(dirname(cache_csv), showWarnings = FALSE, recursive = TRUE)
    readr::write_csv(d, cache_csv)
    cat(glue::glue(
      "Scraped {nrow(d)} underway links ",
      "({sum(d$is_data)} data files) from {url}"), "\n")
    d
  }, error = function(e) {
    if (file.exists(cache_csv)) {
      cat(glue::glue(
        "Underway page unavailable ({conditionMessage(e)}) — ",
        "using cached inventory {basename(cache_csv)}"), "\n")
      readr::read_csv(cache_csv, show_col_types = FALSE)
    } else {
      stop(e)
    }
  })

  out
}

#' Download the METS archive from calcofi.org
#'
#' Files land as `{out_dir}/{cruise_key}/{file_name}` so the on-disk layout
#' carries the cruise even for the flat `{year}/{CRUISE}_Underway*.csv` shape,
#' and zips are expanded in place.
#'
#' @param out_dir   download directory (`{dir_data}/calcofi/mets/download`)
#' @param cache_csv path for the scraped URL inventory
#' @param overwrite re-download files that already exist
#' @param data_only download only data files, skipping plots (default TRUE)
#' @param verbose   print per-file progress
#' @return the inventory tibble, with `path` and `downloaded` columns
download_mets <- function(
    out_dir,
    cache_csv  = NULL,
    overwrite  = FALSE,
    data_only  = TRUE,
    verbose    = TRUE) {

  stopifnot(requireNamespace("rvest", quietly = TRUE))
  if (is.null(cache_csv))
    cache_csv <- file.path(out_dir, "_mets_urls.csv")

  d <- scrape_mets_urls(cache_csv)
  if (data_only) d <- dplyr::filter(d, is_data)

  # a file with no resolvable cruise anywhere in its URL would be silently
  # mis-filed, so fail rather than guess
  bad <- d[is.na(d$cruise_key), ]
  if (nrow(bad))
    stop("cruise_key unresolved for: ", paste(bad$file_name, collapse = ", "))

  d$path       <- file.path(out_dir, d$cruise_key, d$file_name)
  d$downloaded <- FALSE
  d$available  <- NA
  d$error      <- NA_character_

  # some of the 2004-2010 era files (notably the *_SCIMS.txt / *_SCS.txt pairs)
  # are linked on the page but return 403 Forbidden — see questions.csv
  # mets_11/12/13. Record that per file rather than letting it pass as a
  # warning, so the notebook can report exactly which cruises are unreachable.
  for (i in seq_len(nrow(d))) {
    dest <- d$path[i]
    if (!overwrite && file.exists(dest) && file.size(dest) > 0) {
      d$available[i] <- TRUE
      next
    }
    dir.create(dirname(dest), showWarnings = FALSE, recursive = TRUE)
    res <- tryCatch({
      utils::download.file(d$url[i], dest, mode = "wb", quiet = TRUE)
      list(ok = TRUE, err = NA_character_)
    }, error = function(e) list(ok = FALSE, err = conditionMessage(e)),
       warning = function(w) list(ok = FALSE, err = conditionMessage(w)))

    # a server that answers 200 with an HTML error body would otherwise be
    # stored as if it were data
    if (isTRUE(res$ok) && file.exists(dest)) {
      head_bytes <- readBin(dest, "raw", n = 300)
      if (grepl("<!doctype html|<html", rawToChar(head_bytes), ignore.case = TRUE)) {
        res <- list(ok = FALSE, err = "server returned an HTML page, not data")
        unlink(dest)
      }
    }

    d$downloaded[i] <- isTRUE(res$ok)
    d$available[i]  <- isTRUE(res$ok)
    d$error[i]      <- res$err
    if (isTRUE(res$ok) && verbose)
      cat(glue::glue("  downloaded {d$cruise_key[i]}/{d$file_name[i]}"), "\n")
  }

  # expand any zips in place; the ingest's file scan then sees their contents
  for (z in d$path[tolower(tools::file_ext(d$path)) == "zip"]) {
    if (!file.exists(z)) next
    ex <- file.path(dirname(z), tools::file_path_sans_ext(basename(z)))
    if (!dir.exists(ex) || isTRUE(overwrite)) {
      dir.create(ex, showWarnings = FALSE, recursive = TRUE)
      tryCatch(utils::unzip(z, exdir = ex),
               error = function(e) warning(glue::glue(
                 "Failed to unzip {basename(z)}: {conditionMessage(e)}")))
    }
  }

  n_avail <- sum(d$available, na.rm = TRUE)
  cat(glue::glue(
    "METS archive: {n_avail}/{nrow(d)} data files available across ",
    "{dplyr::n_distinct(d$cruise_key[d$available])} cruises ",
    "({sum(d$downloaded)} newly downloaded)"), "\n")

  if (any(!d$available))
    cat(glue::glue(
      "{sum(!d$available)} file(s) linked on the page but not retrievable ",
      "(403/blocked — see questions.csv mets_11/12/13): ",
      "{paste(unique(d$file_name[!d$available]), collapse = ', ')}"), "\n")

  d
}
