# release_content_gaps.R -- a REPORT (never a gate) of what a release's public pages will publish empty.
#
# The landing site (CalCOFI.github.io) draws /measurements/ and /datasets/ from the promoted release's
# measurements.json and datasets.json, and nothing else; a key with no `face` or no `why` renders a
# page with the section missing, and a dataset with no citation, licence or DOI renders an empty
# "How to cite". Nothing in the release run says so: check_dataset_citation() reports the attribution
# half at ingest time (and fails the index build on a hard gap), but no step lists, for the RELEASED
# record, which measurement keys have no face or no why. This is that list.
#
# It reports and returns; it does NOT stop (a gap is exempt only while an open question names it, which
# check_dataset_citation() already decides; this just lists what the release actually carries).
#
#   source("libs/release_content_gaps.R")
#   gaps <- release_content_gaps()                 # the promoted release (latest.txt), over https
#   gaps <- release_content_gaps("v2026.10.01")    # a named release
#   gaps <- release_content_gaps(measurements = "data/releases/v2026.10.07/measurements.json",
#                                datasets     = "data/releases/v2026.10.07/datasets.json")
#   gaps <- release_content_gaps(registry_dir = "metadata")   # also: every canonical measurement_type
#                                                             # with no row in the face / why registry,
#                                                             # BEFORE a release carries its record
#
# A staging record: pass `base = "https://storage.googleapis.com/calcofi-db/ducklake-staging/releases"`.
#
# Returns a tibble (kind, key, gap, detail): kind in measurement | dataset | registry; gap in
# no_face | no_why | no_method | no_citation | no_license | no_doi | no_page; empty when clean.

#' @param release version ("v2026.10.01"); NULL reads `{base}/latest.txt`
#' @param measurements,datasets a path or URL of `measurements.json` / `datasets.json`, or an
#'   already parsed list; NULL builds `{base}/{release}/{file}`
#' @param registry_dir optional `metadata/` directory: adds the `registry` rows (see above)
#' @param base the releases prefix
#' @param quiet suppress the printed report
release_content_gaps <- function(release = NULL, measurements = NULL, datasets = NULL,
                                 registry_dir = NULL,
                                 base = Sys.getenv("CALCOFI_RELEASE_BASE",
                                                   "https://storage.googleapis.com/calcofi-db/ducklake/releases"),
                                 quiet = FALSE) {
  stopifnot(is.character(base), length(base) == 1L)
  read_json <- function(x, file) {
    if (is.list(x)) return(x)
    if (is.null(x)) {
      if (is.null(release)) release <<- trimws(readLines(file.path(base, "latest.txt"), warn = FALSE)[1])
      x <- file.path(base, release, file)
    }
    jsonlite::fromJSON(x, simplifyVector = FALSE)
  }
  blank <- function(x) is.null(x) || length(x) == 0L || is.na(x[[1]]) || !nzchar(trimws(as.character(x[[1]])))
  row <- function(kind, key, gap, detail = "")
    data.frame(kind = kind, key = key, gap = gap, detail = detail, stringsAsFactors = FALSE)
  out <- list()

  # measurement keys the release carries -------------------------------------------------------
  m <- read_json(measurements, "measurements.json")
  # a per-cast key (grain "sample", read from sample_measurement by the ws-1004d catalog) has a page
  # like any other key, so a missing face / why / method is the same gap; the detail says which grain
  # it is, so a reader knows the registry rows to write are for a per-cast type.
  for (k in m$measurements) {
    key <- k$key
    per_cast <- identical(k$grain, "sample")
    tag <- if (per_cast) " (per-cast key, grain sample)" else ""
    if (is.null(k$face))
      out[[length(out) + 1]] <- row("measurement", key, "no_face",
                                    paste0("no row in metadata/measurement_face.csv: the What section is empty", tag))
    if (is.null(k$why) || !length(k$why))
      out[[length(out) + 1]] <- row("measurement", key, "no_why",
                                    paste0("no row in metadata/measurement_why.csv: the Why section is empty", tag))
    if (is.null(k$method) || !length(k$method))
      out[[length(out) + 1]] <- row("measurement", key, "no_method",
                                    paste0("no row in metadata/measurement_method.csv for any of its series: the How section is empty", tag))
  }

  # datasets the release carries ---------------------------------------------------------------
  d <- read_json(datasets, "datasets.json")
  for (x in d$datasets) {
    a <- x$attribution
    key <- x$dataset_key
    if (blank(a$citation_main)) out[[length(out) + 1]] <- row("dataset", key, "no_citation")
    if (blank(a$license))       out[[length(out) + 1]] <- row("dataset", key, "no_license")
    if (blank(a$doi))           out[[length(out) + 1]] <- row("dataset", key, "no_doi")
  }

  # before a release carries its record: the registries against measurement_type.csv ------------
  # canonical keys only (a non-canonical per-sensor twin has no page of its own; a RETIRED key such as
  # mld_sigma_theta_003 is is_canonical FALSE, so it needs no face). A `registry` row also names whether
  # the key can have a page at all: the catalog reads obs_env and, for the datasets it is told
  # (calcofi_ctd-derived), the per-cast types of sample_measurement (grain "sample"); an obs_bio or
  # attribute key is described here and drawn nowhere.
  if (!is.null(registry_dir)) {
    rd <- function(f) {
      p <- file.path(registry_dir, f)
      utils::read.csv(text = grep("^#", readLines(p, warn = FALSE), value = TRUE, invert = TRUE),
                      stringsAsFactors = FALSE, na.strings = "")
    }
    mt <- rd("measurement_type.csv")
    mt <- mt[toupper(as.character(mt$is_canonical)) %in% "TRUE", , drop = FALSE]
    face <- rd("measurement_face.csv")$key
    why  <- rd("measurement_why.csv")$key
    for (i in seq_len(nrow(mt))) {
      key <- mt$measurement_type[i]
      pageless <- if (!is.na(mt$grain[i]) && !mt$grain[i] %in% c("obs", "sample"))
        paste0("grain ", mt$grain[i], ": no /measurements/ page") else ""
      if (!key %in% face) out[[length(out) + 1]] <- row("registry", key, "no_face", pageless)
      if (!key %in% why)  out[[length(out) + 1]] <- row("registry", key, "no_why",  pageless)
    }
  }

  res <- if (length(out)) do.call(rbind, out) else
    data.frame(kind = character(), key = character(), gap = character(), detail = character(),
               stringsAsFactors = FALSE)
  res <- tibble::as_tibble(res)

  if (!quiet) {
    cat("release content gaps (report only)", if (!is.null(release)) paste0(" -- ", release), "\n", sep = "")
    if (!nrow(res)) cat("  none\n") else {
      by <- split(res, paste(res$kind, res$gap))
      for (nm in names(by)) {
        b <- by[[nm]]
        cat(sprintf("  %-26s %3d  %s\n", nm, nrow(b), paste(utils::head(b$key, 12), collapse = ", ")))
      }
    }
  }
  invisible(res)
}
