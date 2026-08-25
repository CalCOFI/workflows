#!/usr/bin/env Rscript
# T3: verify a release's catalog.json against the bucket — every object exists,
# its size matches, and (for objects under --max-mb, default 50) the bytes hash
# to the recorded sha256. For the canonical layout also checks every compat_path.
#
#   Rscript scripts/verify_release_objects.R v2026.08.25
#   Rscript scripts/verify_release_objects.R v2026.08.25 --prefix ducklake-staging/releases --max-mb 200
suppressMessages({library(jsonlite); library(glue); library(digest)})
args <- commandArgs(trailingOnly = TRUE)
opt <- function(flag, default) { i <- match(flag, args); if (is.na(i)) default else args[i + 1] }
version <- args[!grepl("^--", args) & !args %in% c(opt("--prefix", ""), opt("--max-mb", ""))][1]
prefix  <- opt("--prefix", "ducklake/releases")
max_mb  <- as.numeric(opt("--max-mb", "50"))
bucket  <- "calcofi-db"
https   <- function(p) glue("https://storage.googleapis.com/{bucket}/{p}")
cat <- jsonlite::fromJSON(https(glue("{prefix}/{version}/catalog.json")), simplifyVector = FALSE)
stopifnot(identical(cat$version, version))
layout <- cat$layout %||% "legacy"
cat0 <- base::cat
cat0(glue("release {version} · layout {layout} · {length(cat$tables)} tables\n"))
if (is.null(cat$tables[[1]]$objects)) stop("catalog has no objects[] — not a content-addressed release")
# GCS occasionally resets an HTTP/2 stream mid-transfer (INTERNAL_ERROR in the
# framing layer); force HTTP/1.1 and retry a few times so a flake is not a failure
.h <- function(...) curl::new_handle(http_version = 2L, ...)   # 2L = CURL_HTTP_VERSION_1_1
.retry <- function(f, tries = 4) {
  for (i in seq_len(tries)) {
    r <- tryCatch(f(), error = function(e) e)
    if (!inherits(r, "error")) return(r)
    if (i == tries) stop(r)
    Sys.sleep(2 * i)
  }
}
head_ok <- function(url) .retry(function() {
  h <- curl::curl_fetch_memory(url, handle = .h(nobody = TRUE, customrequest = "HEAD"))
  list(code = h$status_code, bytes = as.numeric(curl::parse_headers_list(h$headers)[["content-length"]] %||% NA))
})
n_obj <- 0; bad <- character(); n_hashed <- 0
for (t in cat$tables) for (o in t$objects) {
  n_obj <- n_obj + 1
  h <- head_ok(https(o$path))
  if (h$code != 200) { bad <- c(bad, glue("{o$path}: HTTP {h$code}")); next }
  if (!is.na(h$bytes) && h$bytes != o$bytes) bad <- c(bad, glue("{o$path}: size {h$bytes} != catalog {o$bytes}"))
  if (o$bytes <= max_mb * 1e6) {
    f <- tempfile(fileext = ".parquet")
    .retry(function() curl::curl_download(https(o$path), f, quiet = TRUE, handle = .h()))
    sha <- digest::digest(f, algo = "sha256", file = TRUE); unlink(f); n_hashed <- n_hashed + 1
    if (!identical(sha, o$sha256)) bad <- c(bad, glue("{o$path}: sha256 mismatch"))
  }
  if (layout == "canonical" && !is.null(o$compat_path %||% t$compat_path)) {
    # each object records its own legacy path (calcofi4db >= 3.23.2); older
    # canonical catalogs are reconstructed from the table's compat directory
    cp <- o$compat_path %||% (if (is.null(o$partition_by)) t$compat_path else
      glue("{t$compat_path}{o$partition_by}={o$partition_value}/data_0.parquet"))
    hc <- head_ok(https(cp))
    if (hc$code != 200) bad <- c(bad, glue("compat {cp}: HTTP {hc$code}"))
  }
}
cat0(glue("{n_obj} objects checked, {n_hashed} hashed, {length(bad)} problem(s)\n"))
if (length(bad)) { cat0(paste(" -", bad), sep = "\n"); quit(status = 1) }
cat0("OK\n")
