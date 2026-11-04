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
# Sourced by libs/download_euphausiids.R, libs/download_iron.R,
# libs/download_picoplankton_bacteria.R, libs/download_poc_pon.R and
# libs/download_toc.R; not called directly from a notebook.

#' Resolve the latest revision of an EDI package
#'
#' @param scope EDI scope, e.g. "knb-lter-cce"
#' @param id    package id, e.g. 313
#' @return integer revision (the highest published)
edi_latest_rev <- function(scope, id) {
  revs <- tryCatch(
    suppressWarnings(readLines(
      glue::glue("https://pasta.lternet.edu/package/eml/{scope}/{id}"),
      warn = FALSE)),
    error = function(e) NULL)
  if (is.null(revs)) {
    # PASTA refused (see download_edi_entity()): the revisions the DataONE
    # coordinating node has indexed for this package (checked 2026-11-04:
    # knb-lter-cce.253 -> 3)
    stopifnot(requireNamespace("jsonlite", quietly = TRUE))
    q <- utils::URLencode(glue::glue(
      "formatType:METADATA AND id:*package/metadata/eml/{scope}/{id}/*"), reserved = TRUE)
    docs <- jsonlite::fromJSON(glue::glue(
      "https://cn.dataone.org/cn/v2/query/solr/?q={q}&fl=id&rows=1000&wt=json"))$response$docs
    revs <- sub(".*/", "", docs$id[grepl(glue::glue("/eml/{scope}/{id}/[0-9]+$"), docs$id)])
    if (!length(revs)) stop(glue::glue("no revision of {scope}.{id} on PASTA or DataONE"))
  }
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
  dir.create(dirname(dest), showWarnings = FALSE, recursive = TRUE)

  # PASTA refuses every anonymous call now and then (2026-11-04: HTTP 403
  # "Public Access is not authorized" on every endpoint, from two networks),
  # so the entity listing is tried and, if it fails, the same bytes are read
  # from EDI's DataONE member node, where the package is replicated under the
  # PASTA identifiers (see edi_dataone_entity()).
  ents <- tryCatch(
    suppressWarnings(readLines(
      glue::glue("https://pasta.lternet.edu/package/data/eml/{scope}/{id}/{rev}"),
      warn = FALSE)),
    error = function(e) NULL)

  if (is.null(ents)) {
    if (verbose) cat(glue::glue(
      "EDI: PASTA refused the entity listing for {pkg}; ",
      "reading it from the DataONE replica (gmn.lternet.edu)\n\n"))
    edi_dataone_entity(scope, id, rev, entity_name, dest, verbose = verbose)
  } else {
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

    if (verbose) cat(glue::glue("EDI: downloading {pkg} '{entity_name}'\n\n"))
    utils::download.file(url, dest, mode = "wb", quiet = !verbose)
  }

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

#' Download one EDI data entity through DataONE
#'
#' EDI replicates every package to its DataONE member node
#' (`urn:node:LTER`, https://gmn.lternet.edu/mn) under the PASTA identifiers,
#' and the coordinating node serves the package's EML. The entity is found by
#' `entity_name` in that EML (`entityName` + its `url function="download"`),
#' then read from the member node. Used by [download_edi_entity()] when PASTA
#' refuses anonymous access; `rev` must be known (pin it).
#'
#' @inheritParams download_edi_entity
#' @return `dest`, invisibly
edi_dataone_entity <- function(scope, id, rev, entity_name, dest, verbose = TRUE) {
  stopifnot(requireNamespace("xml2", quietly = TRUE), !is.null(rev))
  pkg      <- glue::glue("{scope}.{id}.{rev}")
  meta_pid <- glue::glue("https://pasta.lternet.edu/package/metadata/eml/{scope}/{id}/{rev}")
  eml      <- xml2::read_xml(paste0(
    "https://cn.dataone.org/cn/v2/object/", utils::URLencode(meta_pid, reserved = TRUE)))
  names_x  <- xml2::xml_find_all(eml, "//*[local-name()='entityName']")
  ents     <- vapply(names_x, function(n) {
    ent <- xml2::xml_parent(n)
    xml2::xml_text(xml2::xml_find_first(ent, ".//*[local-name()='url']"))
  }, character(1))
  names(ents) <- xml2::xml_text(names_x)
  if (!entity_name %in% names(ents))
    stop(glue::glue(
      "EDI package {pkg} (DataONE EML) has no entity named '{entity_name}'. Available: ",
      "{paste(names(ents), collapse = '; ')}"))
  data_pid <- unname(ents[[entity_name]])
  url <- paste0("https://gmn.lternet.edu/mn/v2/object/", utils::URLencode(data_pid, reserved = TRUE))
  if (verbose) cat(glue::glue("EDI: downloading {pkg} '{entity_name}' via DataONE\n\n"))
  utils::download.file(url, dest, mode = "wb", quiet = !verbose)
  invisible(dest)
}
