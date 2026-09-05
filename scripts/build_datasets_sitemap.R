#!/usr/bin/env Rscript
# Regenerate datasets/sitemap.xml from the release record (plan 2026-09-05 § D-10;
# calcofi4db >= 4.3.0) — the file ODISCat record 3318 points at.
#
#   Rscript scripts/build_datasets_sitemap.R                       # the promoted release
#   Rscript scripts/build_datasets_sitemap.R v2026.09.05           # one version
#   CALCOFI_SKIP_LINK_CHECK=1 Rscript scripts/build_datasets_sitemap.R   # structure only
#
# The calcofi.io dataset pages come first — they are canonical and their JSON-LD
# carries the external records as `sameAs` — then every `current` / `external`
# record at another portal. A `superseded` or `retired` distribution stays in
# metadata/distribution.csv and never reaches the sitemap.
suppressMessages({library(calcofi4db); library(here); library(glue); library(dplyr)})
args     <- commandArgs(trailingOnly = TRUE)
version  <- setdiff(args, grep("^--", args, value = TRUE))
prefix   <- Sys.getenv("CALCOFI_RELEASE_PREFIX", "ducklake/releases")
base     <- glue("https://storage.googleapis.com/calcofi-db/{prefix}")
if (!length(version))
  version <- trimws(readLines(glue("{base}/latest.txt"), warn = FALSE))[1]
dir_meta <- here("metadata")
path_map <- here("datasets/sitemap.xml")

record   <- jsonlite::fromJSON(glue("{base}/{version}/datasets.json"), simplifyVector = FALSE)
observed <- read_distribution_observed(file.path(dir_meta, "distribution_observed.json"))

# a sidecar's own last edit: the `edited` stamp the metadata Sheet writes back, else
# the file's last commit — a provider's correction is a change to the page
sidecars <- read_dataset_sidecars(dir_meta)
edited <- vapply(names(sidecars), function(k) {
  y <- sidecars[[k]]
  e <- as.character(y[["edited"]] %||% "")[1]
  if (!is.na(e) && nzchar(e)) return(substr(e, 1, 10))
  g <- suppressWarnings(system2("git", c("-C", here(), "log", "-1", "--format=%cs", "--", y[["path"]]),
                                stdout = TRUE, stderr = FALSE))
  if (length(g) && nzchar(g[1])) g[1] else ""
}, "")

d <- build_datasets_sitemap(record, observed = observed, edited = edited)
write_sitemap_xml(d, path_map)

chk <- check_sitemap(d)
# TEMPORARY, and it comes out with WS-P1: calcofi.io/datasets/{key}/ 404s until the
# landing repo generates the pages (33 of them, measured 2026-09-05). Set
# CALCOFI_PAGES_PENDING=1 to let those — and only those — through; a dead EXTERNAL
# record still fails, which is what this check is for.
allow <- if (nzchar(Sys.getenv("CALCOFI_PAGES_PENDING"))) "^https://calcofi[.]io/datasets/" else character()
assert_sitemap(chk, allow_dead = allow)
if (any(chk$finding != "ok")) print(as.data.frame(count(chk[chk$finding != "ok", ], finding, detail)))
n_pages <- sum(d$kind == "page" & d$portal == "calcofi.io")
cat(glue("{path_map}: {nrow(d)} URLs — {n_pages} calcofi.io dataset pages + ",
         "{nrow(d) - n_pages} external records (release {version})\n"))
print(as.data.frame(count(d, kind, portal)))
