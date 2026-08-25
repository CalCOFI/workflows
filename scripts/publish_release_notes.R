#!/usr/bin/env Rscript
# (Re)publish RELEASE_NOTES.md for one or more versions from RELEASES.md.
#
#   Rscript scripts/publish_release_notes.R                 # the promoted version
#   Rscript scripts/publish_release_notes.R v2026.08.14     # one version
#   Rscript scripts/publish_release_notes.R --all           # every version with local sidecars
#   ... --dry-run                                           # render locally, no upload
#
# Notes are not data: this touches RELEASE_NOTES.md and RELEASES.md on GCS and
# nothing else, so it is safe to run for a promoted version (an edit to
# RELEASES.md after test_release approved it) or for the whole history (backfill).
suppressMessages({library(calcofi4db); library(here); library(glue)})
args    <- commandArgs(trailingOnly = TRUE)
dry     <- "--dry-run" %in% args
all_v   <- "--all" %in% args
vers    <- setdiff(args, c("--dry-run", "--all"))
dir_rel <- here("data/releases")
vers_local <- character()   # versions rendered locally but not uploaded

if (all_v) {
  vers <- sort(basename(list.dirs(dir_rel, recursive = FALSE)))
  vers <- vers[grepl("^v20", vers)]
  if (!dry) {
    # only versions that exist on GCS: three early versions are local-only and
    # publishing notes for them would mint stray prefixes with no data behind them
    on_gcs <- system2(find_gcloud(), c("storage", "ls", "gs://calcofi-db/ducklake/releases/"),
                      stdout = TRUE)
    on_gcs <- basename(sub("/$", "", on_gcs[grepl("/v20", on_gcs)]))
    vers_local <- setdiff(vers, on_gcs)
    vers <- intersect(vers, on_gcs)
    if (length(vers_local))
      cat("not on GCS, local render only:", paste(vers_local, collapse = ", "), "\n")
  }
} else if (!length(vers)) {
  vers <- read_promoted_release(bucket = "calcofi-db")
}

pkg <- c(calcofi4db = as.character(packageVersion("calcofi4db")),
         calcofi4r  = tryCatch(as.character(packageVersion("calcofi4r")), error = function(e) NA))
pkg <- pkg[!is.na(pkg)]

ok <- character(); bad <- character()
run <- function(v, bucket, pkg_versions) {
  tryCatch({
    publish_release_notes(v, here("RELEASES.md"), dir_rel, bucket = bucket, pkg_versions = pkg_versions)
    ok <<- c(ok, v)
  }, error = function(e) bad <<- c(bad, glue("{v}: {conditionMessage(e)}")))
}
for (v in vers)
  run(v, bucket = if (dry) NULL else "calcofi-db",
      # package versions describe the build being cut now, not the history
      pkg_versions = if (!all_v) pkg else NULL)
for (v in vers_local) run(v, bucket = NULL, pkg_versions = NULL)

cat(glue("published {length(ok)} version(s){if (dry) ' (dry run, local only)' else ''}\n"))
if (length(bad)) { cat("skipped:\n"); cat(paste(" -", bad), sep = "\n") }
