#!/usr/bin/env Rscript
# Ask every portal what it says NOW about our external copies, and write
# metadata/distribution_observed.json (plan 2026-09-05 § D-10/D-11; calcofi4db >= 4.3.0).
#
#   Rscript scripts/observe_distributions.R              # registry + the holdings' links
#   Rscript scripts/observe_distributions.R --registry   # the curated registry only
#   Rscript scripts/observe_distributions.R --quiet
#
# NOTHING IS DELETED. `distribution.csv` stays the curated record; this writes a
# parallel observation beside it, and a portal that stops answering becomes an
# observed `retired` row, never a missing one. An unanswered request is
# `unreachable` — EDI's portal refuses ranged GETs after ~150 requests in a day and
# NOAA's ERDDAPs 503 under load, and neither is a retirement.
#
# Run weekly by .github/workflows/observe.yml, which commits the JSON.
suppressMessages({library(calcofi4db); library(here); library(glue); library(dplyr)})
args     <- commandArgs(trailingOnly = TRUE)
quiet    <- "--quiet" %in% args
reg_only <- "--registry" %in% args
dir_meta <- here("metadata")
path_obs <- file.path(dir_meta, "distribution_observed.json")

registry <- read_distribution_registry(file.path(dir_meta, "distribution.csv"))
portals  <- read_portal_registry(file.path(dir_meta, "portal.csv"))
targets  <- if (reg_only) registry else
  distribution_targets(registry, read_dataset_sidecars(dir_meta))

cat(glue("observing {nrow(targets)} distribution(s) ",
         "({nrow(registry)} registry + {nrow(targets) - nrow(registry)} holdings)\n\n"))
previous <- read_distribution_observed(path_obs)
observed <- observe_distributions(targets, portals, quiet = quiet)
changes  <- distribution_changes(observed, previous)
write_distribution_observed(observed, path_obs, changes)

cat("\n")
print(as.data.frame(count(observed, status)))
if (nrow(changes)) {
  cat(glue("\n{nrow(changes)} change(s) since the last observation — a change is a PROPOSAL:\n",
           "file each as a `proposed` questions.csv row (`observed_change`) for the dataset's provider\n\n"))
  print(as.data.frame(changes))
} else {
  cat("\nno change since the last observation\n")
}
cat(glue("\nwrote {path_obs}\n"))
