# publish_netcdf.R — shared helpers for the publish_{dataset}_to-netcdf.qmd notebooks.
#
# These notebooks are a DEPLOY step: they run after release_database.qmd, read the
# FROZEN release (never the ERDDAP serving tree — reading that is how the first
# NetCDF shipped from a month-old snapshot), and publish one self-documenting CF
# file per dataset.
#
# Two transformations, and only the second is dataset-specific:
#
#   1. WIDEN for CF. The database is normalized: one row per observation with
#      `measurement_type` naming the quantity and `measurement_value` holding the
#      number. A single value column therefore mixes quantities with DIFFERENT
#      units, which CF forbids — a variable has one unit and one standard_name. So
#      each measurement_type becomes its own variable, carrying units/long_name
#      from metadata/measurement_type.csv. This part is mechanical.
#
#   2. RECONSTRUCT the one-to-many. CalCOFI datasets nest: cruise -> tow -> net ->
#      taxon occurrence -> length-frequency bin, plus event-level effort. Flatten
#      that and every tow's effort repeats onto every length bin, inviting
#      double-counting. netCDF-4 groups + ragged-array indices store each level
#      once. The nesting differs per dataset, which is why these are notebooks
#      rather than one generic script.
#
# CF SCOPE, stated honestly in every file: CF covers profile/trajectory cleanly,
# but there is NO CF standard for a tow -> net -> taxon -> size-bin hierarchy.
# Files are CF where CF applies and netCDF-4 convention elsewhere; the global
# attribute `cf_scope` says which.
librarian::shelf(dplyr, glue, jsonlite, ncdf4, readr, digest, quiet = TRUE)
# page() / esc() / fmt_* : one skin across every generated page. Located by
# search rather than sys.frame() introspection, which breaks depending on how the
# file is sourced (knitr, Rscript, interactive).
.cc_lib_dir <- local({
  cands <- c("libs", file.path(getwd(), "libs"),
             tryCatch(here::here("libs"), error = function(e) NULL))
  hit <- Filter(function(p) !is.null(p) && file.exists(file.path(p, "gcs_index.R")), cands)
  if (!length(hit)) stop("cannot locate libs/gcs_index.R")
  hit[[1]]
})
source(file.path(.cc_lib_dir, "gcs_index.R"))

GCS_BUCKET_DB  <- "calcofi-db"
GCS_BUCKET_PUB <- "calcofi-files-public"
RELEASES_URL   <- glue("https://storage.googleapis.com/{GCS_BUCKET_DB}/ducklake/releases")
NETCDF_SITE    <- glue("https://storage.calcofi.io/{GCS_BUCKET_PUB}/netcdf")

#' Resolve the release to publish from. Defaults to the PROMOTED release
#' (latest.txt), never to whatever a local tree happens to hold.
cc_release_version <- function(version = NULL) {
  if (!is.null(version)) return(version)
  trimws(readLines(glue("{RELEASES_URL}/latest.txt"), warn = FALSE)[1])
}

#' Base URL of a release's parquet. Tables are read straight over HTTPS so the
#' notebook cannot silently diverge from what was published.
cc_release_parquet <- function(version = NULL) {
  glue("{RELEASES_URL}/{cc_release_version(version)}/parquet")
}

#' measurement_type -> CF-ish variable metadata, from the canonical registry.
#' @return named list keyed by measurement_type: units, long_name, standard_name
cc_measurement_meta <- function(wf = getwd()) {
  mt <- read_csv(file.path(wf, "metadata/measurement_type.csv"), show_col_types = FALSE)
  setNames(lapply(seq_len(nrow(mt)), function(i) list(
    units         = mt$units[i]         %||% "",
    long_name     = mt$description[i]   %||% mt$measurement_type[i],
    standard_name = if ("standard_name" %in% names(mt)) mt$standard_name[i] else NA_character_,
    canonical     = isTRUE(mt$is_canonical[i]) || identical(mt$is_canonical[i], "TRUE")
  )), mt$measurement_type)
}

# Treats NULL / empty / NA / "" as absent. The NA and "" tests apply ONLY to a
# length-1 atomic: calling is.na() on a list (var_meta[[col]] is a 4-element list)
# returns a vector, and `||` rejects that in R >= 4.3 with
# "'length = 4' in coercion to 'logical(1)'".
`%||%` <- function(a, b) {
  if (is.null(a) || length(a) == 0) return(b)
  if (length(a) == 1 && is.atomic(a) && (is.na(a) || identical(as.character(a), ""))) return(b)
  a
}

# ---- netCDF-4 group writing --------------------------------------------------

# GROUPS IN ncdf4 — verified 2026-07-28, ncdf4 1.24.
# ncdf4 exposes NO group API (there is no ncgrp_def, no group arguments), which
# reads as "R cannot write netCDF-4 groups". It can: a SLASH-SEPARATED variable
# name creates a real group. Confirmed independently, not just by round-tripping
# through ncdf4 itself —
#   ncvar_def("tow/volume_sampled", ...)
#   ncdump -h ->  group: tow { double volume_sampled(tow_n) ; }
#   h5dump -n ->  group /tow ; dataset /tow/volume_sampled
# so it is a true HDF5/netCDF-4 group, not a variable with a slash in its name.
# Dimensions are defined at the root and referenced from any group, which is what
# lets a child level index into its parent.

#' Build the variable definitions for one level of a nested dataset.
#'
#' Each level becomes a netCDF-4 group. The link to the parent is an explicit
#' index variable, NOT repetition of the parent's columns — that is the whole
#' reason for using netCDF-4 here rather than a flat table: tow effort is stored
#' once, and a length-frequency bin points at the tow it came from.
#'
#' @param group  group name, e.g. "tow", "occurrence", "length_bin"
#' @param df     data.frame for this level, ordered so children are contiguous
#' @param dim    the ncdim for this level (from nc_level_dim())
#' @param parent_dim  parent level's ncdim, or NULL at the top
#' @param parent_index 1-based index into the parent level, one per row of `df`
#' @param var_meta named list: column -> list(units, long_name, standard_name)
#' @return list of ncvar objects to pass to nc_create()
nc_level_vars <- function(group, df, dim, parent_dim = NULL, parent_index = NULL,
                          var_meta = list(), strlen = 64L) {
  stopifnot(is.data.frame(df))
  d_str <- ncdf4::ncdim_def(glue("{group}_strlen"), "", seq_len(strlen),
                            create_dimvar = FALSE)
  vars <- list()
  for (nm in names(df)) {
    x  <- df[[nm]]
    md <- var_meta[[nm]] %||% list()
    vars[[nm]] <- if (is.character(x) || is.factor(x)) {
      ncdf4::ncvar_def(glue("{group}/{nm}"), "", list(d_str, dim), prec = "char")
    } else if (is.integer(x)) {
      ncdf4::ncvar_def(glue("{group}/{nm}"), as.character(md$units %||% ""), dim,
                       prec = "integer", missval = -2147483647L)
    } else {
      ncdf4::ncvar_def(glue("{group}/{nm}"), as.character(md$units %||% ""), dim,
                       prec = "double", missval = 9.969209968386869e36)
    }
  }
  if (!is.null(parent_index) && !is.null(parent_dim))
    vars[["__parent_index"]] <- ncdf4::ncvar_def(
      glue("{group}/parent_index"), "", dim, prec = "integer")
  vars
}

#' Write the data + attributes for one level previously defined by nc_level_vars().
nc_level_put <- function(nc, group, df, vars, parent_index = NULL,
                         var_meta = list(), parent_group = NA_character_) {
  for (nm in names(df)) {
    x <- df[[nm]]
    ncdf4::ncvar_put(nc, vars[[nm]], if (is.factor(x)) as.character(x) else x)
    md <- var_meta[[nm]] %||% list()
    vn <- glue("{group}/{nm}")
    ln <- as.character(md$long_name %||% gsub("_", " ", nm))
    ncdf4::ncatt_put(nc, vn, "long_name", ln)
    sn <- md$standard_name %||% NA_character_
    if (!is.na(sn) && nzchar(sn)) ncdf4::ncatt_put(nc, vn, "standard_name", sn)
  }
  if (!is.null(parent_index) && !is.null(vars[["__parent_index"]])) {
    ncdf4::ncvar_put(nc, vars[["__parent_index"]], as.integer(parent_index))
    vn <- glue("{group}/parent_index")
    ncdf4::ncatt_put(nc, vn, "long_name",
      glue("1-based index into the {parent_group} group"))
    ncdf4::ncatt_put(nc, vn, "comment", paste(
      "Explicit parent link. Each row belongs to the", parent_group,
      "record at this index; parent values are stored ONCE there rather than",
      "repeated here, so summing a parent-level quantity over this group would",
      "double-count."))
    ncdf4::ncatt_put(nc, vn, "instance_dimension", parent_group)
  }
  invisible(TRUE)
}

# ---- versioning: release-named paths, bytes written once ---------------------

#' Decide whether a freshly built file needs uploading, or is byte-identical to
#' an earlier release and should be POINTED at instead.
#'
#' Release-named paths (so a URL always answers "which release is this?") without
#' re-uploading unchanged bytes. Object storage has no symlinks, so the pointer is
#' a manifest + index page, and Caddy 302s the .nc path to the canonical object.
#'
#' @return list(sha256, identical_to = <version or NA>, canonical_url)
cc_netcdf_plan <- function(local_file, dataset, version) {
  sha <- digest::digest(local_file, algo = "sha256", file = TRUE)
  prior <- tryCatch(
    fromJSON(glue("{NETCDF_SITE}/{dataset}/manifests.json"), simplifyDataFrame = FALSE),
    error = function(e) list(releases = list()))
  hit <- NULL
  for (r in prior$releases %||% list())
    if (identical(r$sha256, sha)) { hit <- r; break }
  if (!is.null(hit)) {
    list(sha256 = sha, identical_to = hit$version,
         canonical_url = hit$canonical_url, upload = FALSE)
  } else {
    list(sha256 = sha, identical_to = NA_character_,
         canonical_url = glue("{NETCDF_SITE}/{dataset}/{version}/{dataset}.nc"),
         upload = TRUE)
  }
}

# ---- upload -----------------------------------------------------------------

#' `gcloud storage` is not in the default release track everywhere (the CalCOFI
#' server only has it under `alpha`), so probe once rather than assume.
.gcloud_sub <- function() {
  g <- Sys.which("gcloud")
  if (!nzchar(g)) stop("gcloud not found — publishing needs write credentials")
  if (system2(g, c("storage", "--help"), stdout = FALSE, stderr = FALSE) == 0)
    "storage" else c("alpha", "storage")
}

cc_gcs_cp <- function(local, gcs, content_type, cache_control = NULL) {
  g <- Sys.which("gcloud"); sub <- .gcloud_sub()
  args <- c(sub, "cp", glue("--content-type={content_type}"))
  if (!is.null(cache_control)) args <- c(args, glue("--cache-control={cache_control}"))
  res <- system2(g, c(args, shQuote(local), shQuote(gcs)), stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(res, "status"))) stop(glue("upload failed: {gcs}\n{paste(res, collapse='\n')}"))
  invisible(TRUE)
}

#' Publish one dataset's NetCDF for one release.
#'
#' Release-named paths so a URL always answers "which release is this?", with the
#' BYTES written once: when the build is byte-identical to an earlier release the
#' folder still gets a manifest and index, but the multi-hundred-MB file is not
#' re-uploaded. Object storage has no symlinks, so storage.calcofi.io 302s the
#' release-scoped .nc path to the canonical object.
#'
#' Always writes, even when nothing changed:
#'   {ds}/{release}/manifest.json   what this release is, and what it points at
#'   {ds}/{release}/index.html      human page naming the canonical download
#'   {ds}/manifests.json            accumulated history (drives identity matching)
#'   {ds}/latest.txt                the newest release for this dataset
cc_netcdf_publish <- function(local_nc, dataset, release, plan, manifest,
                              dry_run = FALSE) {
  base_gs  <- glue("gs://{GCS_BUCKET_PUB}/netcdf/{dataset}")
  base_web <- glue("{NETCDF_SITE}/{dataset}")
  tmp <- tempdir()

  # accumulate history BEFORE writing, so a re-run is idempotent
  hist <- tryCatch(fromJSON(glue("{base_web}/manifests.json"), simplifyDataFrame = FALSE),
                   error = function(e) list(releases = list()))
  rel <- Filter(function(r) !identical(r$version, release), hist$releases %||% list())
  rel <- c(rel, list(manifest))
  ord <- order(vapply(rel, function(r) r$version, character(1)), decreasing = TRUE)
  hist <- list(dataset = dataset, releases = rel[ord])

  size_mb <- round(manifest$bytes / 1048576, 1)
  ident   <- manifest$identical_to
  body <- glue(
    '<div class="scroll"><table><thead><tr><th>file</th>',
    '<th style="text-align:right">size</th></tr></thead><tbody>',
    '<tr><td><a href="{manifest$canonical_url}">{dataset}.nc</a></td>',
    '<td class="num">{size_mb} MB</td></tr></tbody></table></div>',
    if (!is.na(ident)) glue(
      '<div class="note"><b>Identical to {ident}.</b> This release produced a ',
      'byte-identical file, so the bytes are not duplicated — the download above ',
      'points at the object published for <code>{ident}</code>. The ',
      '<code>sha256</code> in <a href="{base_web}/{release}/manifest.json">',
      'manifest.json</a> confirms they match.</div>') else "",
    '<div class="note"><b>Provenance.</b> Built from CalCOFI integrated database ',
    'release <b>{manifest$db_release}</b> on {substr(manifest$generated_utc,1,10)} ',
    'from <code>{paste(manifest$source_tables, collapse="</code>, <code>")}</code>.',
    '<br><br><b>CF scope.</b> {manifest$cf_scope}</div>')

  page_html <- page(glue("{dataset} — {release}"),
    glue("CF NetCDF · {size_mb} MB · database release {manifest$db_release}"),
    body, crumb = glue('<p class="crumb"><a href="{NETCDF_SITE}/">netcdf</a> / ',
                       '<a href="{base_web}/">{dataset}</a></p>'))

  f_man  <- file.path(tmp, "manifest.json");  write_json(manifest, f_man, auto_unbox = TRUE, pretty = TRUE)
  f_hist <- file.path(tmp, "manifests.json"); write_json(hist, f_hist, auto_unbox = TRUE, pretty = TRUE)
  f_idx  <- file.path(tmp, "release.html");   writeLines(page_html, f_idx)
  f_lat  <- file.path(tmp, "latest.txt");     writeLines(release, f_lat)

  if (dry_run) {
    message(glue("DRY RUN: would upload={plan$upload} to {base_gs}/{release}/"))
    return(invisible(list(uploaded = FALSE, base = base_web)))
  }

  if (plan$upload) {
    message(glue("  uploading {basename(local_nc)} ({size_mb} MB) ..."))
    cc_gcs_cp(local_nc, glue("{base_gs}/{release}/{dataset}.nc"), "application/x-netcdf")
  } else {
    message(glue("  byte-identical to {ident} — not re-uploading {size_mb} MB"))
  }
  cc_gcs_cp(f_man,  glue("{base_gs}/{release}/manifest.json"), "application/json", "no-cache")
  cc_gcs_cp(f_idx,  glue("{base_gs}/{release}/index.html"),    "text/html",        "no-cache")
  cc_gcs_cp(f_hist, glue("{base_gs}/manifests.json"),          "application/json", "no-cache")
  cc_gcs_cp(f_lat,  glue("{base_gs}/latest.txt"),              "text/plain",       "no-cache")

  invisible(list(uploaded = plan$upload, base = base_web,
                 url = manifest$canonical_url))
}

#' Per-release manifest written alongside every published file — including the
#' releases where nothing changed, so the release folder always exists and always
#' explains itself.
cc_netcdf_manifest <- function(plan, dataset, version, release, n_bytes,
                               source_tables, cf_scope) {
  list(
    dataset       = dataset,
    version       = version,
    db_release    = release,
    generated_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    sha256        = plan$sha256,
    bytes         = n_bytes,
    identical_to  = plan$identical_to,
    canonical_url = plan$canonical_url,
    source_tables = source_tables,
    cf_scope      = cf_scope)
}
