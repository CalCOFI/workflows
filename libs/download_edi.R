# libs/download_edi.R
# -----------------------------------------------------------------------------
# Reproducible acquisition of data entities from the EDI (Environmental Data
# Initiative) PASTA repository, https://pasta.lternet.edu.
#
# PASTA is a plain REST API over stable, versioned package identifiers
# ({scope}.{id}.{rev}), so unlike the Datazoo / ZooDB portals there is no form,
# no session, and no data agreement to accept — a package coordinate plus an
# entity name fully determines the bytes. That makes it the preferred route for
# any CCE-LTER dataset that is mirrored on EDI.
#
# Sourced by libs/download_euphausiids.R and
# libs/download_picoplankton_bacteria.R; not called directly from a notebook.

#' Resolve the latest revision of an EDI package
#'
#' @param scope EDI scope, e.g. "knb-lter-cce"
#' @param id    package id, e.g. 313
#' @return integer revision (the highest published)
edi_latest_rev <- function(scope, id) {
  revs <- readLines(
    glue::glue("https://pasta.lternet.edu/package/eml/{scope}/{id}"),
    warn = FALSE)
  max(as.integer(revs[nzchar(revs)]))
}

#' Download one named data entity from an EDI package
#'
#' Resolves the entity id by matching `entity_name` against the package's
#' entity-name listing, so the caller pins the human-readable name (stable
#' across revisions) rather than an opaque hash that changes when the package
#' is republished.
#'
#' @param scope       EDI scope, e.g. "knb-lter-cce"
#' @param id          package id, e.g. 313
#' @param entity_name exact entity name, e.g. "Brinton and Townsend Euphausiid Abundance Data"
#' @param dest        destination file path
#' @param rev         package revision; NULL (default) resolves the latest
#' @param md5         optional expected md5 of the downloaded file; mismatch is
#'   an error, so a silent upstream change fails loudly instead of quietly
#'   re-shaping the ingest
#' @param overwrite   if FALSE (default) and `dest` exists, skip the download
#' @param verbose     print progress
#' @return `dest`, invisibly
download_edi_entity <- function(
    scope,
    id,
    entity_name,
    dest,
    rev       = NULL,
    md5       = NULL,
    overwrite = FALSE,
    verbose   = TRUE) {

  stopifnot(requireNamespace("glue", quietly = TRUE))

  if (!overwrite && file.exists(dest)) {
    if (verbose) cat("EDI: using cached", basename(dest), "\n")
    return(invisible(dest))
  }

  if (is.null(rev))
    rev <- edi_latest_rev(scope, id)

  pkg  <- glue::glue("{scope}.{id}.{rev}")
  ents <- readLines(
    glue::glue("https://pasta.lternet.edu/package/data/eml/{scope}/{id}/{rev}"),
    warn = FALSE)
  ents <- ents[nzchar(ents)]

  names(ents) <- vapply(ents, function(e) {
    paste(readLines(
      glue::glue("https://pasta.lternet.edu/package/name/eml/{scope}/{id}/{rev}/{e}"),
      warn = FALSE), collapse = "")
  }, character(1))

  if (!entity_name %in% names(ents))
    stop(glue::glue(
      "EDI package {pkg} has no entity named '{entity_name}'. Available: ",
      "{paste(names(ents), collapse = '; ')}"))

  entity_id <- ents[[entity_name]]
  url <- glue::glue(
    "https://pasta.lternet.edu/package/data/eml/{scope}/{id}/{rev}/{entity_id}")

  dir.create(dirname(dest), showWarnings = FALSE, recursive = TRUE)
  if (verbose) cat(glue::glue("EDI: downloading {pkg} '{entity_name}'\n\n"))
  utils::download.file(url, dest, mode = "wb", quiet = !verbose)

  if (!is.null(md5)) {
    got <- tools::md5sum(dest)[[1]]
    if (!identical(unname(got), md5))
      stop(glue::glue(
        "EDI {pkg} '{entity_name}' md5 mismatch: expected {md5}, got {got}. ",
        "The upstream package changed — re-verify the ingest against the new ",
        "file before updating the expected md5."))
    if (verbose) cat("EDI: md5 verified", md5, "\n")
  }

  invisible(dest)
}
