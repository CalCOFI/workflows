# libs/edi_entities.R — shared helpers for publish_to-edi.qmd.
#
# The generic pattern from publish_to-netcdf.qmd / publish_to-erddap.qmd: read
# the FROZEN release (never a local wrangling tree), export what a publisher
# needs per dataset_key, gate the network-touching step behind an explicit
# flag. Here the network-touching step is EDI's PASTA API (EDIutils):
# `evaluate_data_package()` runs on every render *when credentials are set*
# (there is nothing production-destructive about evaluating against EDI's
# staging environment), while `create_data_package()` / `update_data_package()`
# — which mint or revise a real package id — run only under
# `CALCOFI_PUBLISH_EDI=true`.
#
# Every function below is a pure transform of an already-parsed list/tibble —
# no network, no file I/O beyond a plain local read — so `scripts/test_publish_edi.R`
# can exercise the shape logic with small fixtures. The notebook does the
# network/file parts (HTTP GETs of the release JSON, DuckDB reads, CSV/EML
# writes) and calls these to decide *what* to do.

librarian::shelf(dplyr, tibble, glue, jsonlite, digest, readr, quiet = TRUE)

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a)) || identical(a, "")) b else a

CC_STORAGE_HTTPS <- "https://storage.googleapis.com/calcofi-db"

# EDI package hosts — a dataset already served from one of these should never be
# re-published under a CalCOFI-owned package (plan § D-6's non-interference rule,
# the same one OBIS follows: "a provider's own record is never republished").
EDI_HOST_PATTERN <- "edirepository\\.org|pasta\\.lternet\\.edu"

# ---- release JSON -----------------------------------------------------------

#' Read a release JSON file, whether `path_or_url` is a local path or an https URL
edi_read_json <- function(path_or_url) {
  jsonlite::fromJSON(path_or_url, simplifyVector = FALSE)
}

#' Resolve the release version to publish from under a given prefix.
#'
#' Mirrors `cc_release_version()` in `libs/publish_netcdf.R`, generalised to any
#' prefix (staging by default here — plan § D-6 evaluates against staging, and
#' `release_database.qmd` has not yet shipped `datasets.json`/`eml/` in a
#' promoted release at the time this notebook was written).
#'
#' @param prefix the releases prefix, e.g. `"ducklake-staging/releases"`
#' @param version an explicit version, or NULL to read `{prefix}/latest.txt`
#' @param base_https bucket https root
#' @return character version string
edi_resolve_version <- function(prefix, version = NULL, base_https = CC_STORAGE_HTTPS) {
  if (!is.null(version) && nzchar(version)) return(version)
  trimws(readLines(glue("{base_https}/{prefix}/latest.txt"), warn = FALSE)[1])
}

#' One dataset's record out of a parsed `datasets.json`
#'
#' @param datasets_json the parsed (`simplifyVector = FALSE`) `datasets.json`
#' @param dataset_key the dataset to extract
#' @return the record (a list), or NULL if not present
edi_dataset_record <- function(datasets_json, dataset_key) {
  recs <- datasets_json[["datasets"]] %||% list()
  hit <- Filter(function(r) identical(r[["dataset_key"]], dataset_key), recs)
  if (!length(hit)) NULL else hit[[1]]
}

# ---- non-interference: refuse a dataset that is already an EDI package -----

#' Is this dataset already published as an EDI (or CCE-LTER `knb-lter-cce`)
#' package by its own provider?
#'
#' Plan § D-6 / WS-E3 brief: "the notebook refuses a dataset whose source is
#' already an EDI package ... per the non-interference rule". Two independent
#' signals, either one blocks:
#'  1. the sidecar's (or record's) own `link_data_source` names an EDI/PASTA host
#'     — the SOURCE itself is an EDI package (e.g. `cce-lter_euphausiids`).
#'  2. the record's `distributions[]` already carries a `kind = "archive"` row
#'     on `portal %in% c("edi", "knb-lter-cce")` — a package already exists for
#'     this dataset_key, curated or observed, whoever created it.
#'
#' @param record one dataset record from `datasets.json` (or NULL)
#' @param sidecar the dataset's `dataset_meta.yml` as a list (or NULL)
#' @return list(blocked = logical, reasons = character())
edi_non_interference_check <- function(record = NULL, sidecar = NULL) {
  reasons <- character()
  link <- (sidecar %||% list())[["link_data_source"]] %||%
    (record %||% list())[["links"]]$data_source %||% ""
  if (nzchar(link) && grepl(EDI_HOST_PATTERN, link, ignore.case = TRUE))
    reasons <- c(reasons, glue("link_data_source is itself an EDI/PASTA package: {link}"))

  dists <- (record %||% list())[["distributions"]] %||% list()
  arch <- Filter(function(d) identical(d[["kind"]], "archive") &&
                    isTRUE(tolower(.chr0(d[["portal"]])) %in% c("edi", "knb-lter-cce")), dists)
  if (length(arch)) {
    who <- vapply(arch, function(d) glue("{d[['portal']]}:{.chr0(d[['id']]) %||% .chr0(d[['url']])}"), "")
    reasons <- c(reasons, glue("already registered as an EDI/knb-lter-cce archive: {paste(who, collapse = '; ')}"))
  }
  list(blocked = length(reasons) > 0, reasons = reasons)
}
.chr0 <- function(x) if (is.null(x)) "" else as.character(x)[1]

# ---- table classification: csv entity | shared-vocabulary reference | excluded --

#' Classify one of a dataset's core tables for EDI publication
#'
#' Three outcomes:
#' * `"csv"` — the table carries a `dataset_key` column and is not
#'   `supplemental`: exported as a filtered/partitioned CSV `dataTable` entity.
#' * `"other_ref"` — no `dataset_key` column (a shared vocabulary/reference
#'   table like `measurement_type`, `taxon`): too small to duplicate honestly
#'   per dataset, so the whole already-published parquet object is named as an
#'   `otherEntity` instead of a filtered copy.
#' * `"excluded_supplemental"` — the catalog marks the table `supplemental`
#'   (the full-resolution `obs_ctd_full` / `obs_mets_full` scan tables: hundreds
#'   of millions of rows, gigabytes, partitioned by `cruise_key` not
#'   `dataset_key`): excluded from the package entirely rather than emitted as
#'   an unwieldy CSV or a hundred-plus `otherEntity` rows, and reported so the
#'   gap is visible, not silent.
#'
#' @param table table name
#' @param catalog_entry this table's entry from `catalog.json$tables[[]]` (a list)
#' @param has_dataset_key whether `metadata.json` documents a `{table}.dataset_key` column
#' @return list(class = one of the three strings above, reason = character(1))
edi_classify_table <- function(table, catalog_entry, has_dataset_key) {
  if (isTRUE((catalog_entry %||% list())[["supplemental"]]))
    return(list(class = "excluded_supplemental",
               reason = glue("{table} is a supplemental full-resolution table ",
                             "({fmt_n0(catalog_entry[['rows']])} rows, {fmt_mb0(catalog_entry[['bytes']])}); ",
                             "not partitioned by dataset_key, too large for one EDI entity")))
  if (isTRUE(has_dataset_key))
    return(list(class = "csv", reason = glue("{table} carries dataset_key: filtered to this dataset's rows")))
  list(class = "other_ref",
      reason = glue("{table} is a shared vocabulary/reference table (no dataset_key column); ",
                    "named as otherEntity rather than duplicated per dataset"))
}
fmt_n0  <- function(n) if (is.null(n)) "?" else formatC(as.numeric(n), format = "d", big.mark = ",")
fmt_mb0 <- function(b) { if (is.null(b)) return("? MB"); b <- as.numeric(b)
  if (b >= 1073741824) sprintf("%.2f GB", b / 1073741824) else sprintf("%.1f MB", b / 1048576) }

# ---- resolving a table's source parquet, per dataset --------------------------

#' Every https URL a release table's objects resolve to, via
#' `calcofi4r::cc_release_sources()` (the one resolver — never hand-build a path).
#'
#' @param catalog the parsed `catalog.json` (must carry `$version`)
#' @param table table name
#' @return the list `cc_release_sources()` returns: `urls`, `hive`, `single_file`, ...
edi_table_urls <- function(catalog, table) {
  calcofi4r::cc_release_sources(catalog, table)
}

#' Pick the URL of a hive-partitioned table's `dataset_key=<key>` partition
#'
#' @param urls character vector of partition URLs (as `edi_table_urls()$urls`)
#' @param dataset_key the dataset to find
#' @param partition_col the partition column name (default `"dataset_key"`)
#' @return the matching URL, or NA_character_ if none matches
edi_partition_url_for <- function(urls, dataset_key, partition_col = "dataset_key") {
  pat <- paste0("(?<=", partition_col, "=)[^/]+")
  has <- grepl(pat, urls, perl = TRUE)
  vals <- rep(NA_character_, length(urls))
  vals[has] <- vapply(urls[has], function(u) regmatches(u, regexpr(pat, u, perl = TRUE)), "")
  hit <- urls[!is.na(vals) & vals == dataset_key]
  if (length(hit)) hit[1] else NA_character_
}

#' The (first / whole-table) object of a catalog table entry — bytes + SHA-256 +
#' url, for the `otherEntity` reference tables (`measurement_type`, `taxon`, …)
#' that are named whole rather than filtered per dataset.
#'
#' @param catalog parsed `catalog.json`
#' @param table table name
#' @param base_https bucket https root
#' @return list(url, bytes, sha256, path), or NULL if the table has no objects
edi_first_object <- function(catalog, table, base_https = CC_STORAGE_HTTPS) {
  entry <- Find(function(t) identical(t[["name"]], table), catalog[["tables"]] %||% list())
  if (is.null(entry) || !length(entry[["objects"]])) return(NULL)
  o <- entry[["objects"]][[1]]
  list(url = paste0(base_https, "/", o[["path"]]), bytes = o[["bytes"]], sha256 = o[["sha256"]], path = o[["path"]])
}

#' Decide how to read one table's rows for one dataset: a ready-made per-dataset
#' partition file (no filter needed) or the whole table filtered by dataset_key.
#'
#' @param catalog parsed `catalog.json`
#' @param table table name
#' @param dataset_key the dataset to read
#' @return list(mode = "partition" | "filter", url = character(1) [partition] or
#'   urls = character() [filter, may be >1 for a table hive-partitioned on a
#'   different column], filter_sql = character(1) or NULL)
edi_table_read_plan <- function(catalog, table, dataset_key) {
  src <- edi_table_urls(catalog, table)
  if (isTRUE(src$hive)) {
    u <- edi_partition_url_for(src$urls, dataset_key)
    if (!is.na(u)) return(list(mode = "partition", url = u, filter_sql = NULL))
  }
  # not partitioned by dataset_key (whole file, or partitioned by something
  # else e.g. obs_ctd_full's cruise_key — callers exclude those via
  # edi_classify_table() before reaching here): read everything, filter by column
  list(mode = "filter", urls = src$urls,
      filter_sql = glue("WHERE dataset_key = '{dataset_key}'"))
}

# ---- EML document surgery: rewrite dataTable physical, add otherEntity --------

#' Point one dataTable entity's `physical` at an exported CSV instead of the
#' release parquet object `build_eml()` originally filled in.
#'
#' Pure list surgery — never edits `calcofi4db`; this is the notebook-side
#' rewrite the WS-E3 brief calls for ("entity `physical` rewritten to the
#' exported files").
#'
#' @param doc an EML document list (from `calcofi4db::build_eml()`)
#' @param table the `dataTable` entityName to rewrite
#' @param object_name the CSV's file name (`objectName`)
#' @param bytes file size in bytes
#' @param sha256 the CSV's own SHA-256 (not the parquet's)
#' @param url a web-accessible URL for the CSV, or NULL while it is local-only
#'   (EDI's `evaluate_data_package()` / `create_data_package()` fetch entities
#'   from `physical/distribution/online/url`, so this must be filled in before
#'   either is called for real)
#' @param delimiter field delimiter (default `,`)
#' @return `doc`, with the matching `dataTable[[i]]$physical` replaced
edi_rewrite_datatable_physical <- function(doc, table, object_name, bytes, sha256,
                                           url = NULL, delimiter = ",") {
  dts <- doc$dataset$dataTable
  if (!length(dts)) return(doc)
  i <- which(vapply(dts, function(d) identical(d[["entityName"]], table), logical(1)))
  if (!length(i)) return(doc)
  phys <- list(
    objectName = object_name,
    size = list(unit = "bytes", size = as.character(as.integer(bytes))),
    authentication = list(method = "SHA-256", authentication = sha256),
    dataFormat = list(textFormat = list(
      numHeaderLines = "1",
      recordDelimiter = "\\n",
      attributeOrientation = "column",
      simpleDelimited = list(fieldDelimiter = delimiter))))
  if (!is.null(url)) phys$distribution <- list(online = list(`function` = "download", url = url))
  doc$dataset$dataTable[[i[1]]]$physical <- phys
  doc
}

#' Append one `otherEntity` referencing an already-published parquet object —
#' a shared vocabulary table (`measurement_type`, `taxon`) named whole rather
#' than duplicated per dataset.
#'
#' @param doc an EML document list
#' @param entity_name the table/entity name
#' @param description free text explaining what it is and why it is referenced
#'   rather than exported
#' @param object_name file name
#' @param bytes,sha256,url the parquet object's own measured values
#' @param format_name EML `externallyDefinedFormat/formatName` (default Parquet)
#' @return `doc`, with one item appended to `doc$dataset$otherEntity`
edi_add_other_entity <- function(doc, entity_name, description, object_name, bytes, sha256, url,
                                 format_name = "Apache Parquet") {
  e <- list(
    entityName = entity_name,
    entityDescription = description,
    physical = list(
      objectName = object_name,
      size = list(unit = "bytes", size = as.character(as.integer(bytes))),
      authentication = list(method = "SHA-256", authentication = sha256),
      dataFormat = list(externallyDefinedFormat = list(formatName = format_name)),
      distribution = list(online = list(`function` = "download", url = url))),
    entityType = "table")
  doc$dataset$otherEntity <- c(doc$dataset$otherEntity, list(e))
  doc
}

#' Note an excluded supplemental table in `additionalMetadata`, so the package
#' says honestly why one of the dataset's release tables carries no entity here.
#'
#' @param doc an EML document list
#' @param table table name
#' @param reason the human-readable reason (from [edi_classify_table()])
#' @return `doc`
edi_note_excluded_table <- function(doc, table, reason) {
  am <- doc$additionalMetadata$metadata$calcofi %||% list()
  am$excludedTables <- c(am$excludedTables, stats::setNames(list(reason), table))
  doc$additionalMetadata$metadata$calcofi <- am
  doc
}

# ---- manifest + content hash --------------------------------------------------

#' A stable content hash over a set of entity SHA-256s (order-independent), so
#' the manifest's `content_hash` changes if and only if an entity's bytes did.
#'
#' @param hashes character vector of per-entity SHA-256 hashes
#' @return a SHA-256 hex digest, or NA_character_ if `hashes` is empty
edi_content_hash <- function(hashes) {
  hashes <- hashes[!is.na(hashes) & nzchar(hashes)]
  if (!length(hashes)) return(NA_character_)
  digest::digest(paste(sort(unique(hashes)), collapse = "|"), algo = "sha256", serialize = FALSE)
}

#' Build one manifest row (the shape `publish_to-edi.qmd` writes to
#' `data/edi/manifest.csv`, "like E2's": `package_id, revision, content_hash,
#' uploaded_utc`, plus the fields this notebook's own gates need).
edi_manifest_row <- function(dataset_key, version, content_hash, n_csv = NA_integer_,
                             n_other_ref = NA_integer_, n_excluded = NA_integer_,
                             bytes_total = NA_real_, package_id = NA_character_,
                             revision = NA_integer_, evaluated_utc = NA_character_,
                             uploaded_utc = NA_character_) {
  tibble::tibble(
    dataset_key = dataset_key, version = version, content_hash = content_hash,
    n_csv = as.integer(n_csv), n_other_ref = as.integer(n_other_ref),
    n_excluded = as.integer(n_excluded), bytes_total = as.numeric(bytes_total),
    package_id = package_id, revision = as.integer(revision),
    evaluated_utc = evaluated_utc, uploaded_utc = uploaded_utc)
}

# ---- EDI credentials + the package-id registry --------------------------------

#' Are EDI credentials available in the environment?
#'
#' `EDIutils::login()` accepts `userId`/`userPass`, a `key` (modern API key), or
#' a `config` file; here we look for the environment-variable forms so an
#' unattended `targets` run can evaluate without a console prompt. Absence is
#' not an error — the notebook must "say so and skip cleanly" (WS-E3 brief).
#'
#' @return list(available = logical, method = "key" | "userpass" | NA)
edi_has_credentials <- function() {
  key <- Sys.getenv("EDI_KEY", "")
  usr <- Sys.getenv("EDI_USER", ""); pwd <- Sys.getenv("EDI_PASS", "")
  if (nzchar(key)) return(list(available = TRUE, method = "key"))
  if (nzchar(usr) && nzchar(pwd)) return(list(available = TRUE, method = "userpass"))
  list(available = FALSE, method = NA_character_)
}

EDI_PACKAGES_COLS <- c("dataset_key", "scope", "identifier", "revision", "env",
                      "package_id", "created_utc", "updated_utc")

#' Read `metadata/edi_packages.csv` (dataset_key -> the EDI package id that owns
#' it), or an empty typed tibble if the file does not exist yet.
edi_read_package_registry <- function(path) {
  if (!file.exists(path))
    return(tibble::as_tibble(stats::setNames(replicate(length(EDI_PACKAGES_COLS), character(), simplify = FALSE),
                                             EDI_PACKAGES_COLS)))
  readr::read_csv(path, col_types = readr::cols(.default = "c"), na = "")
}

#' The registered EDI package id for a dataset, or NA if none exists yet
#' (`create_data_package()` has never run for it under `CALCOFI_PUBLISH_EDI=true`).
edi_package_id_for <- function(registry, dataset_key) {
  hit <- registry[registry$dataset_key == dataset_key, , drop = FALSE]
  if (!nrow(hit)) NA_character_ else hit$package_id[1]
}
