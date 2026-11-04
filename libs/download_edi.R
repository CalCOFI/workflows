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
# libs/download_picoplankton_bacteria.R and libs/download_toc.R; not called
# directly from a notebook.
#
# DataONE mirror (2026-11-04): PASTA began refusing every anonymous call
# (`User 'EDI-... (Public Access)' is not authorized to execute service method
# listDataEntities / readMetadata / readDataEntity`; the portal shows a "Human
# Verification Check"). EDI is a DataONE member node (urn:node:LTER,
# https://gmn.lternet.edu/mn/v2), and the coordinating node indexes every
# revision's EML, so the same bytes stay reachable: the entity id is read from
# the mirrored EML by entity name and the file comes from the member node. The
# md5 pin is checked the same way on both routes (checked 2026-11-04 on
# knb-lter-cce.253.3: md5 17b393b6f06441c8f682907b58a87403 on both). PASTA is
# still tried first and the route used is printed.

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
    # PASTA refused (anonymous access closed, see header): list the revisions
    # the DataONE coordinating node has indexed for this package
    stopifnot(requireNamespace("jsonlite", quietly = TRUE))
    q <- utils::URLencode(glue::glue(
      "formatType:METADATA AND id:*package/metadata/eml/{scope}/{id}/*"), reserved = TRUE)
    docs <- jsonlite::fromJSON(glue::glue(
      "{EDI_DATAONE_CN}/query/solr/?q={q}&fl=id&rows=1000&wt=json"))$response$docs
    revs <- sub(".*/", "", docs$id[grepl(glue::glue("/eml/{scope}/{id}/[0-9]+$"), docs$id)])
    if (!length(revs)) stop(glue::glue("no revision of {scope}.{id} on PASTA or DataONE"))
  }
  max(as.integer(revs[nzchar(revs)]))
}

# DataONE coordinating node and EDI's member node (urn:node:LTER)
EDI_DATAONE_CN <- "https://cn.dataone.org/cn/v2"
EDI_DATAONE_MN <- "https://gmn.lternet.edu/mn/v2"

#' A PASTA resource path as a DataONE object identifier (URL-encoded PASTA URL)
#' @param path path under https://pasta.lternet.edu/package/, e.g. "metadata/eml/knb-lter-cce/253/3"
#' @return the encoded identifier, ready to append to `{node}/object/`
edi_dataone_id <- function(path)
  utils::URLencode(paste0("https://pasta.lternet.edu/package/", path), reserved = TRUE)

#' The entity ids of an EDI package, by entity name, from its PASTA listing
#' @return named character vector (names = entity names, values = entity ids),
#'   or NULL when PASTA refuses
edi_entities_pasta <- function(scope, id, rev) {
  ents <- tryCatch(
    suppressWarnings(readLines(
      glue::glue("https://pasta.lternet.edu/package/data/eml/{scope}/{id}/{rev}"),
      warn = FALSE)),
    error = function(e) NULL)
  if (is.null(ents)) return(NULL)
  ents <- ents[nzchar(ents)]
  names(ents) <- vapply(ents, function(e) {
    paste(readLines(
      glue::glue("https://pasta.lternet.edu/package/name/eml/{scope}/{id}/{rev}/{e}"),
      warn = FALSE), collapse = "")
  }, character(1))
  ents
}

#' The entity ids of an EDI package, by entity name, from the EML the DataONE
#' coordinating node mirrors (every dataTable / otherEntity / spatial* entity's
#' `distribution/online/url` ends in the PASTA entity id)
#' @return named character vector (names = entity names, values = entity ids)
edi_entities_dataone <- function(scope, id, rev) {
  stopifnot(requireNamespace("xml2", quietly = TRUE))
  eml <- xml2::read_xml(paste0(
    EDI_DATAONE_CN, "/object/", edi_dataone_id(glue::glue("metadata/eml/{scope}/{id}/{rev}"))))
  xml2::xml_ns_strip(eml)
  nodes <- xml2::xml_find_all(
    eml, ".//dataTable | .//otherEntity | .//spatialRaster | .//spatialVector | .//view")
  nm  <- xml2::xml_text(xml2::xml_find_first(nodes, "./entityName"))
  url <- xml2::xml_text(xml2::xml_find_first(nodes, ".//distribution/online/url"))
  keep <- !is.na(url) & grepl(glue::glue("/data/eml/{scope}/{id}/{rev}/"), url)
  stats::setNames(sub(".*/", "", url[keep]), nm[keep])
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

  pkg   <- glue::glue("{scope}.{id}.{rev}")
  route <- "PASTA"
  ents  <- edi_entities_pasta(scope, id, rev)
  if (is.null(ents)) {
    # PASTA refused (anonymous access closed, see header): same package, same
    # bytes, from EDI's DataONE member node
    route <- "DataONE mirror (PASTA refused anonymous access)"
    ents  <- edi_entities_dataone(scope, id, rev)
  }

  if (!entity_name %in% names(ents))
    stop(glue::glue(
      "EDI package {pkg} has no entity named '{entity_name}'. Available: ",
      "{paste(names(ents), collapse = '; ')}"))

  entity_id <- ents[[entity_name]]
  url <- if (route == "PASTA") {
    glue::glue("https://pasta.lternet.edu/package/data/eml/{scope}/{id}/{rev}/{entity_id}")
  } else {
    paste0(EDI_DATAONE_MN, "/object/",
           edi_dataone_id(glue::glue("data/eml/{scope}/{id}/{rev}/{entity_id}")))
  }

  dir.create(dirname(dest), showWarnings = FALSE, recursive = TRUE)
  if (verbose) cat(glue::glue("EDI: downloading {pkg} '{entity_name}' via {route}\n\n"))
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
