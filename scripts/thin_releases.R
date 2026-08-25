#!/usr/bin/env Rscript
# Thin the release archive: remove the parquet/ of every version that is neither
# consolidated (metadata/release_policy.yml) nor the promoted version or its
# predecessor. Sidecars, RELEASE_NOTES.md and index.html stay, so the record is
# complete; a retired.json {retired_utc, to, reason} says where the data went.
#
#   Rscript scripts/thin_releases.R                 # dry run: table of what would go
#   Rscript scripts/thin_releases.R --execute       # delete, write retired.json, rebuild versions.json + index
#   Rscript scripts/thin_releases.R --prefix ducklake-staging/releases   # staging
#
# Refuses (even with --execute) to touch a version that is pinned as a literal
# in docs/, db-query/_config.yml or server/postgis/init/50_release_views.sql —
# those readers do not resolve latest.txt, so deleting under them breaks a page.
suppressMessages({library(calcofi4db); library(glue); library(jsonlite); library(here)})
args    <- commandArgs(trailingOnly = TRUE)
opt     <- function(flag, default) { i <- match(flag, args); if (is.na(i)) default else args[i + 1] }
execute <- "--execute" %in% args
prefix  <- opt("--prefix", "ducklake/releases")
bucket  <- "calcofi-db"
gcloud  <- calcofi4db:::find_gcloud()
https   <- function(p) glue("https://storage.googleapis.com/{bucket}/{p}")
policy  <- yaml::read_yaml(here("metadata/release_policy.yml"))

latest   <- trimws(readLines(https(glue("{prefix}/latest.txt")), warn = FALSE)[1])
versions <- build_versions_json(bucket, prefix, consolidated = policy$consolidated)
plan     <- thin_plan(versions, latest, policy$consolidated, policy$keep_latest %||% 2)
cand     <- plan[!plan$keep, ]

# pinned-version guard --------------------------------------------------------
pin_files <- c(
  list.files(here("../docs"), pattern = "[.](qmd|md|R|py|yml)$", recursive = TRUE, full.names = TRUE),
  here("../db-query/_config.yml"), here("../server/postgis/init/50_release_views.sql"))
pin_files <- pin_files[file.exists(pin_files) & !grepl("/_site/|/_freeze/|/node_modules/", pin_files)]
pinned <- lapply(cand$version, function(v) {
  hit <- vapply(pin_files, function(f) any(grepl(v, readLines(f, warn = FALSE), fixed = TRUE)), TRUE)
  names(hit)[hit]
})
names(pinned) <- cand$version

# size ------------------------------------------------------------------------
bytes <- vapply(cand$version, function(v) {
  out <- system2(gcloud, c("storage", "du", "-s", glue("gs://{bucket}/{prefix}/{v}/parquet/")),
                 stdout = TRUE, stderr = FALSE)
  if (!length(out)) return(0)
  as.numeric(strsplit(trimws(out[1]), "\\s+")[[1]][1])
}, 0)
cand$gb     <- round(bytes / 1e9, 2)
cand$pinned <- vapply(pinned, function(p) paste(basename(p), collapse = ";"), "")

# reachability sweep over the content-addressed store -------------------------
# tables/ objects are shared by every version whose catalog points at them; one
# nobody kept references any more is garbage. Kept = every version that keeps
# its parquet after this run (plan$keep), read from their catalogs.
tables_prefix <- sub("/releases$", "/tables", prefix)
referenced <- unique(unlist(lapply(plan$version[plan$keep], function(v) {
  cat_ <- tryCatch(fromJSON(https(glue("{prefix}/{v}/catalog.json")), simplifyVector = FALSE),
                   error = function(e) NULL)
  unlist(lapply(cat_$tables, function(t) vapply(t$objects, function(o) o$path, "")))
})))
store <- system2(gcloud, c("storage", "ls", "-l", "-r", glue("gs://{bucket}/{tables_prefix}/**")),
                 stdout = TRUE, stderr = FALSE)
store <- store[grepl("\\.parquet$", store)]
store_df <- data.frame(
  bytes = as.numeric(sub("^\\s*(\\d+)\\s.*$", "\\1", store)),
  path  = sub(glue("^.*gs://{bucket}/"), "", store), stringsAsFactors = FALSE)
orphans <- store_df[!store_df$path %in% referenced, ]

cat(glue("archive {prefix}: {nrow(plan)} versions, promoted {latest}\n\n"))
print(as.data.frame(plan[plan$keep, c("version", "reason")]), row.names = FALSE)
cat("\nto thin:\n")
print(as.data.frame(cand[, c("version", "to", "gb", "pinned")]), row.names = FALSE)
cat(glue("\ntotal {round(sum(cand$gb), 1)} GB across {nrow(cand)} version(s)\n"))
cat(glue("content store {tables_prefix}: {nrow(store_df)} objects, {length(referenced)} referenced by kept ",
         "catalogs, {nrow(orphans)} unreferenced ({round(sum(orphans$bytes) / 1e9, 2)} GB) to sweep\n"))
blocked <- cand[nzchar(cand$pinned), ]
if (nrow(blocked)) {
  cat(glue("\nBLOCKED: {nrow(blocked)} version(s) are pinned as literals (see column pinned); ",
           "repoint those files first\n"))
}
if (!execute) { cat("\ndry run — pass --execute to delete\n"); quit(status = if (nrow(blocked)) 1 else 0) }
if (nrow(blocked)) stop("refusing to execute with pinned versions in the candidate list")
if (!nrow(cand))  { cat("nothing to thin\n"); quit(status = 0) }

# execute ---------------------------------------------------------------------
for (i in seq_len(nrow(cand))) {
  v <- cand$version[i]
  ret <- list(retired_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
              to = cand$to[i],
              reason = glue("archive thinning (metadata/release_policy.yml): parquet removed, ",
                            "sidecars and RELEASE_NOTES.md kept; read {cand$to[i]} instead"))
  f <- tempfile(fileext = ".json"); write_json(ret, f, auto_unbox = TRUE, pretty = TRUE)
  put_gcs_file(f, glue("gs://{bucket}/{prefix}/{v}/retired.json"))
  rc <- system2(gcloud, c("storage", "rm", "-r", glue("gs://{bucket}/{prefix}/{v}/parquet/")),
                stdout = FALSE, stderr = FALSE)
  if (!identical(rc, 0L)) stop(glue("gcloud storage rm failed for {v} (rc={rc})"))
  cat(glue("retired {v} -> {cand$to[i]} ({cand$gb[i]} GB)\n"))
}
if (nrow(orphans)) {
  lst <- tempfile(); writeLines(glue("gs://{bucket}/{orphans$path}"), lst)
  rc <- system2(gcloud, c("storage", "rm", "-I"), stdin = lst, stdout = FALSE, stderr = FALSE)
  if (!identical(rc, 0L)) stop(glue("sweep of {nrow(orphans)} unreferenced objects failed (rc={rc})"))
  cat(glue("swept {nrow(orphans)} unreferenced objects ({round(sum(orphans$bytes) / 1e9, 2)} GB) from {tables_prefix}\n"))
}
versions <- build_versions_json(bucket, prefix, consolidated = policy$consolidated)
f <- tempfile(fileext = ".json"); write_json(list(versions = versions), f, auto_unbox = TRUE, pretty = TRUE)
put_gcs_file(f, glue("gs://{bucket}/{prefix}/versions.json"))
system2(gcloud, c("storage", "objects", "update", "--cache-control=no-cache",
                  glue("gs://{bucket}/{prefix}/versions.json")), stdout = FALSE, stderr = FALSE)
cat("versions.json rebuilt; regenerating index pages\n")
if (prefix == "ducklake/releases")
  system2("Rscript", here("scripts/build_release_index.R"))
