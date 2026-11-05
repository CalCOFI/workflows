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
# Since 2026-07-30 PASTA requires authentication for every REST call
# (anonymous calls answer HTTP 403 "Public Access is not authorized"). An EDI
# access key (https://auth.edirepository.org → Profile → Access Keys; the
# project's lives at ~/.config/calcofi/edi_access_key.txt, or EDI_ACCESS_KEY)
# is exchanged once per session for a short-lived token that travels in a
# Cookie header, so the key never appears in a URL, a log or a cached file
# (edi_token()). Without a key the helpers fall back to the DataONE replica,
# which refused anonymous reads too on 2026-11-05 (HTTP 403), so the key is the
# only working route for now.
#
# Sourced by libs/download_euphausiids.R, libs/download_iron.R,
# libs/download_picoplankton_bacteria.R, libs/download_poc_pon.R,
# libs/download_toc.R and libs/download_chl_size_fractionated.R; not called
# directly from a notebook.

.edi <- new.env(parent = emptyenv())

#' The EDI access key, or "" when none is configured
#'
#' `EDI_ACCESS_KEY` wins; else the first line of the file named by
#' `EDI_ACCESS_KEY_FILE` (default `~/.config/calcofi/edi_access_key.txt`).
#' The value is never printed.
edi_access_key <- function() {
  key <- Sys.getenv("EDI_ACCESS_KEY", "")
  if (!nzchar(key)) {
    f <- Sys.getenv("EDI_ACCESS_KEY_FILE", "~/.config/calcofi/edi_access_key.txt")
    if (file.exists(f))
      key <- readLines(f, n = 1, warn = FALSE)
  }
  trimws(key)
}

#' An EDI authentication token for this session, or "" when there is no key
#'
#' Exchanges the access key for a token (`POST /auth/v1/key`,
#' https://auth.edirepository.org/auth/ui/api-docs/token) once per R session.
#' An invalid key is an error naming the file, never the key itself.
edi_token <- function() {
  if (!is.null(.edi$token)) return(.edi$token)
  key <- edi_access_key()
  if (!nzchar(key)) return(.edi$token <- "")
  stopifnot(requireNamespace("curl", quietly = TRUE), requireNamespace("jsonlite", quietly = TRUE))
  h <- curl::new_handle(
    postfields    = jsonlite::toJSON(list(key = key), auto_unbox = TRUE),
    customrequest = "POST")
  curl::handle_setheaders(h, "Content-Type" = "application/json")
  r <- curl::curl_fetch_memory("https://auth.edirepository.org/auth/v1/key", handle = h)
  if (r$status_code != 200L)
    stop(glue::glue(
      "EDI refused the access key (HTTP {r$status_code}: ",
      "{jsonlite::fromJSON(rawToChar(r$content))$msg %||% 'no message'}). ",
      "Create one at https://auth.edirepository.org (Profile > Access Keys) and ",
      "put it in ~/.config/calcofi/edi_access_key.txt or EDI_ACCESS_KEY."))
  .edi$token <- jsonlite::fromJSON(rawToChar(r$content))[["edi-token"]]
}

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

#' A curl handle carrying the EDI token cookie (anonymous when there is no key)
edi_handle <- function() {
  h <- curl::new_handle(useragent = "calcofi-workflows (libs/download_edi.R)")
  tok <- edi_token()
  if (nzchar(tok)) curl::handle_setheaders(h, Cookie = paste0("edi-token=", tok))
  h
}

#' GET a PASTA URL as lines; NULL on any non-200 answer (the callers fall back)
edi_read_lines <- function(url) {
  r <- tryCatch(curl::curl_fetch_memory(url, handle = edi_handle()), error = function(e) NULL)
  if (is.null(r) || r$status_code != 200L) return(NULL)
  strsplit(rawToChar(r$content), "\n", fixed = TRUE)[[1]]
}

#' GET a PASTA URL to a file; an error on any non-200 answer
edi_download <- function(url, dest) {
  r <- curl::curl_fetch_disk(url, dest, handle = edi_handle())
  if (r$status_code != 200L)
    stop(glue::glue("EDI answered HTTP {r$status_code} for {url}"))
  invisible(dest)
}

#' Resolve the latest revision of an EDI package
#'
#' @param scope EDI scope, e.g. "knb-lter-cce"
#' @param id    package id, e.g. 313
#' @return integer revision (the highest published)
edi_latest_rev <- function(scope, id) {
  revs <- edi_read_lines(glue::glue("https://pasta.lternet.edu/package/eml/{scope}/{id}"))
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

  # PASTA refuses every anonymous call (HTTP 403 "Public Access is not
  # authorized" since 2026-07-30; seen 2026-11-04 from two networks). With an
  # access key the call is authenticated (edi_handle()); without one, or if
  # PASTA still refuses, the same bytes are read from EDI's DataONE member
  # node, where the package is replicated under the PASTA identifiers (see
  # edi_dataone_entity()).
  ents <- edi_read_lines(
    glue::glue("https://pasta.lternet.edu/package/data/eml/{scope}/{id}/{rev}"))

  if (is.null(ents)) {
    if (verbose) cat(glue::glue(
      "EDI: PASTA refused the entity listing for {pkg}",
      "{if (nzchar(edi_access_key())) '' else ' (no access key configured)'}; ",
      "reading it from the DataONE replica (gmn.lternet.edu)\n\n"))
    edi_dataone_entity(scope, id, rev, entity_name, dest, verbose = verbose)
  } else {
    ents <- ents[nzchar(ents)]
    names(ents) <- vapply(ents, function(e) {
      paste(edi_read_lines(
        glue::glue("https://pasta.lternet.edu/package/name/eml/{scope}/{id}/{rev}/{e}")),
        collapse = "")
    }, character(1))

    if (!entity_name %in% names(ents))
      stop(glue::glue(
        "EDI package {pkg} has no entity named '{entity_name}'. Available: ",
        "{paste(names(ents), collapse = '; ')}"))

    entity_id <- ents[[entity_name]]
    url <- glue::glue(
      "https://pasta.lternet.edu/package/data/eml/{scope}/{id}/{rev}/{entity_id}")

    if (verbose) cat(glue::glue("EDI: downloading {pkg} '{entity_name}'\n\n"))
    edi_download(url, dest)
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
