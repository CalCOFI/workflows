#!/usr/bin/env Rscript
# run_pipeline.R
# runs the calcofi targets pipeline
#
# usage:
#   Rscript run_pipeline.R              # run full pipeline
#   Rscript run_pipeline.R --outdated   # show outdated targets
#   Rscript run_pipeline.R --network    # show dependency network

librarian::shelf(
  targets, tarchetypes, here, glue,
  quiet = TRUE)

# parse arguments
args <- commandArgs(trailingOnly = TRUE)

# set working directory to workflows/
setwd(here::here("workflows"))

# check for _targets.R
if (!file.exists("_targets.R")) {
  stop("_targets.R not found. Run from the CalCOFI repo root.")
}

# handle commands
if ("--outdated" %in% args) {
  # show outdated targets
  cat("Checking for outdated targets...\n\n")
  outdated <- tar_outdated()
  if (length(outdated) == 0) {
    cat("All targets are up to date!\n")
  } else {
    cat("Outdated targets:\n")
    cat(paste("-", outdated), sep = "\n")
  }

} else if ("--network" %in% args) {
  # show dependency network
  cat("Generating dependency network...\n")
  tar_visnetwork()

} else if ("--manifest" %in% args) {
  # show manifest
  cat("Pipeline manifest:\n\n")
  m <- tar_manifest()
  print(m, n = 100)

} else {
  # run the pipeline
  cat("═══════════════════════════════════════════════════════════════════════════\n")
  cat("CalCOFI Data Pipeline\n")
  cat("═══════════════════════════════════════════════════════════════════════════\n")
  cat(glue("Start time: {Sys.time()}\n\n"))

  # run targets
  tar_make()

  cat("\n═══════════════════════════════════════════════════════════════════════════\n")
  cat(glue("End time: {Sys.time()}\n"))
  cat("Pipeline complete!\n")
  cat("═══════════════════════════════════════════════════════════════════════════\n")
}
