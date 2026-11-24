# libs/download_sio_cetacean_sightings.R
# -----------------------------------------------------------------------------
# Reproducible acquisition of the Scripps Whale Acoustics Lab's final QA/QC'd
# CalCOFI cetacean visual-survey product read by ingest_sio_cetacean-sightings.qmd.
#
# Source: the lab's PRIVATE GitHub repository
# MarineBioAcousticsRC/CalCOFI_visual_survey_data_2004_2025 (Michaela Alksne,
# 2026-11-13; Ben has read access), at a pinned commit so a re-render reads the
# same bytes. Six files: the on-effort sightings and effort segments (CSV), the
# lab's code list (`codes.csv`: species, behaviour, cue, sighting conditions),
# its data dictionary, the CountCOFI field manual and the visual observation
# protocol (PDF, added 2026-11-18).
#
# The repository is private, so the files are fetched with the GitHub CLI (`gh`)
# under the caller's own login, never an anonymous URL, and land in the CalCOFI
# Data Folder's data-private/ (never data-public/, whose sync to GCS publishes
# whatever it holds). `_source.json` beside them records the repository, the
# commit and each file's sha256.
#
# Sourced + invoked from ingest_sio_cetacean-sightings.qmd (it only fetches when
# a file is missing, the recorded commit differs, or overwrite = TRUE).

SIO_SIGHTINGS_REPO  <- "MarineBioAcousticsRC/CalCOFI_visual_survey_data_2004_2025"
SIO_SIGHTINGS_FILES <- c(
  sightings  = "CalCOFI_cetacean_sightings_on_effort_2004-2025.csv",
  segments   = "CalCOFI_cetacean_effort_segments_2004-2025.csv",
  codes      = "codes.csv",
  dictionary = "data_dictionary.csv",
  manual     = "CountCOFI_Manual.docx",
  protocol   = "CalCOFI_Visual_Observation_Protocol.pdf")

#' Download the lab's cetacean visual-survey files from its private GitHub repo
#'
#' @param out_dir   directory to write the files into (data-private/sio/cetacean-sightings)
#' @param ref       full commit sha to read (pinned by the notebook)
#' @param overwrite fetch again even if the files and `_source.json` match `ref`
#' @param verbose   print progress
#' @return named character vector of the file paths (names as SIO_SIGHTINGS_FILES)
download_sio_cetacean_sightings <- function(
    out_dir, ref, repo = SIO_SIGHTINGS_REPO, overwrite = FALSE, verbose = TRUE) {

  stopifnot("ref must be a full 40-hex commit sha" = grepl("^[0-9a-f]{40}$", ref))
  paths    <- setNames(file.path(out_dir, SIO_SIGHTINGS_FILES), names(SIO_SIGHTINGS_FILES))
  src_json <- file.path(out_dir, "_source.json")

  have_ref <- if (file.exists(src_json)) jsonlite::read_json(src_json)$ref else NA_character_
  if (!overwrite && all(file.exists(paths)) && identical(have_ref, ref)) {
    if (verbose) cat("GitHub", repo, "@", substr(ref, 1, 7), ": using cached files\n")
    return(paths)
  }

  gh <- Sys.which("gh")
  stopifnot("the GitHub CLI (gh) is needed: the lab's repository is private" = nzchar(gh))
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  for (f in SIO_SIGHTINGS_FILES) {
    if (verbose) cat("GitHub", repo, "@", substr(ref, 1, 7), ": downloading", f, "\n")
    rc <- system2(gh, c("api", "-H", shQuote("Accept: application/vnd.github.raw"),
                        shQuote(sprintf("repos/%s/contents/%s?ref=%s", repo, utils::URLencode(f), ref))),
                  stdout = file.path(out_dir, f), stderr = FALSE)
    stopifnot("gh api failed: is this login a collaborator on the lab's repository?" = rc == 0)
  }

  # gh writes the API's JSON error body on a failure that still exits 0 for some
  # proxies: assert we got the CSV header / a docx (zip) / a PDF rather than JSON
  hdr <- readLines(paths[["sightings"]], n = 1, warn = FALSE)
  stopifnot(
    "sightings CSV header not found (got an error page?)" = grepl("^\"?Cruise\"?,", hdr),
    "the manual is a docx (zip)" =
      identical(readBin(paths[["manual"]], "raw", 2), as.raw(c(0x50, 0x4b))),
    "the protocol is a PDF" =
      identical(rawToChar(readBin(paths[["protocol"]], "raw", 4)), "%PDF"))

  commit <- jsonlite::fromJSON(system2(
    gh, c("api", shQuote(sprintf("repos/%s/commits/%s", repo, ref))), stdout = TRUE))
  jsonlite::write_json(list(
    repo         = repo,
    ref          = ref,
    commit_date  = commit$commit$committer$date,
    commit_msg   = commit$commit$message,
    retrieved    = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    files        = lapply(paths, \(p) list(
      file   = basename(p),
      bytes  = file.size(p),
      sha256 = digest::digest(file = p, algo = "sha256")))),
    src_json, auto_unbox = TRUE, pretty = TRUE)
  paths
}
