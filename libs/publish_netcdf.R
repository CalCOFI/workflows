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

#' Explicit URLs for every partition of a hive-partitioned release table.
#'
#' `read_parquet('.../obs_ctd_full/**/*.parquet')` FAILS over plain HTTPS with a
#' 404: expanding a glob requires a directory listing, and object storage has
#' none. (Same constraint that forces a single-file obs.parquet for browser
#' DuckDB-WASM.) So enumerate objects via the XML listing API and hand DuckDB an
#' explicit vector of URLs, which it accepts wherever a glob would go.
#'
#' @return character vector of https URLs, one per partition file
cc_release_partitions <- function(table, version = NULL) {
  v   <- cc_release_version(version)
  pre <- glue("ducklake/releases/{v}/parquet/{table}/")
  u   <- glue("https://storage.googleapis.com/{GCS_BUCKET_DB}?prefix={pre}&max-keys=1000")
  x   <- paste(readLines(url(u), warn = FALSE), collapse = "")
  keys <- grep("\\.parquet$",
               regmatches(x, gregexpr("(?<=<Key>)[^<]+", x, perl = TRUE))[[1]],
               value = TRUE)
  if (!length(keys)) stop(glue("no partitions found under {pre}"))
  # a truncated listing would silently publish a PARTIAL dataset that still looks
  # complete — refuse rather than warn
  if (grepl("<IsTruncated>true", x, fixed = TRUE))
    stop(glue("{table}: partition listing truncated at 1000 — would publish incomplete data"))
  as.character(glue("https://storage.googleapis.com/{GCS_BUCKET_DB}/{keys}"))
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

# ---- netCDF-4 group + CF profile writing: MOVED to calcofi4db ---------------
#
# `nc_level_vars()` / `nc_level_put()` used to live here, alongside a hand-rolled
# CF profile writer in each publish notebook. They are now
# `calcofi4db::nc_level_vars()` / `nc_level_put()` / `nc_profile_def()` /
# `nc_profile_write()` / `nc_profile_atts()`, with a testthat fixture per branch.
#
# They had to leave this file, not merely be duplicated: every publish notebook
# does `devtools::load_all("../calcofi4db")` and THEN sources this file, so a
# definition here silently shadows the package's. That is not hypothetical — the
# first run of the generic notebook failed inside the old copy
# (`ncvar_def("/sample_key")`), because this file's version predated the root-group
# support that `group = ""` needs.
#
# `cc_measurement_meta()` is likewise superseded by
# `calcofi4db::measurement_var_meta()`, which reads the registry through
# `read_measurement_type()` and so cannot be handed a corrupted "NA" unit.
#
# What remains below is genuine deploy plumbing — GCS paths, upload, manifests and
# the browse-page skin — which belongs to this repo, not to the package.

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
