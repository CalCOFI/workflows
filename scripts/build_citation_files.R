#!/usr/bin/env Rscript
# Regenerate .zenodo.json and CITATION.cff at the repo root from the ingest YAML.
#
#   Rscript scripts/build_citation_files.R                       # concept form (committed)
#   Rscript scripts/build_citation_files.R v2026.09.03 2026-09-03 # before WS-F tags a release
#
# Zenodo's GitHub integration reads .zenodo.json at each release tag; without it
# the alpha record came out as "CalCOFI/workflows: initial Zenodo release", MIT,
# creators = the GitHub contributors (measured 2026-09-03). The generated record is
# a DATASET: the three partners as creators, every dataset's PIs (pi_names) as
# DataCollector contributors, the curators, cc-by-4.0, the GCS release as
# isSupplementTo and db-schema as isDocumentedBy. `version` is left to the tag
# unless one is given. CITATION.cff carries the concept DOI (all versions).
# calcofi4db::write_citation_files() does the work; re-run whenever pi_names change,
# and with the version + date immediately before tagging, then commit both files.
suppressPackageStartupMessages(
  if (nzchar(Sys.getenv("CALCOFI4DB_DIR"))) {
    devtools::load_all(Sys.getenv("CALCOFI4DB_DIR"), quiet = TRUE)
  } else library(calcofi4db))
args    <- commandArgs(trailingOnly = TRUE)
version <- if (length(args) >= 1) args[1] else "v2026.09.03-alpha"   # the only Zenodo record so far
date    <- if (length(args) >= 2) args[2] else "2026-09-03"
root    <- here::here()
ds      <- calcofi4db::ingest_yaml_to_dataset_df(calcofi4db::read_ingest_yaml(root))
paths   <- calcofi4db::write_citation_files(
  root, ds, version = version, date_released = date,
  zenodo_version = if (length(args) >= 1) version else NULL)
cat("wrote", paste(basename(paths), collapse = " + "), "for", version, "(", date, ")\n")
