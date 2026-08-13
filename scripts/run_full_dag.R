#!/usr/bin/env Rscript
# run_full_dag.R — force a complete rebuild of every target, beginning to end.
#
#   Rscript scripts/run_full_dag.R            # invalidate everything, then build
#   Rscript scripts/run_full_dag.R --no-reset # build without invalidating first
#
# Why this exists rather than a one-liner: editing a .qmd does NOT make its
# target outdated (build_targets_list() puts the filename in the command as a
# literal, so the notebook's contents are not a tracked dependency), and the
# documented `tar_make(names = tidyselect::all_of(tgt))` workaround does not work
# from inside an Rscript — targets evaluates `names` in its own environment, so a
# loop over a variable fails with "object 'tgt' not found", instantly, for every
# target. Ten "runs" once completed in 11 seconds having rewritten nothing.
#
# `everything()` sidesteps the whole family: it is a tidyselect helper resolved
# in targets' own environment, so there is no caller-environment variable to lose
# and no loop variable to collide with base::t.
#
# The failure mode this guards against is that a no-op looks exactly like a pass.
# Never trust the exit code — the caller compares _output/*.html mtimes.

suppressPackageStartupMessages(library(targets))

args <- commandArgs(trailingOnly = TRUE)
reset <- !("--no-reset" %in% args)

t0 <- Sys.time()
cat("=== full DAG run started", format(t0, "%Y-%m-%d %H:%M:%S"), "===\n")

n_defined <- nrow(tar_manifest(fields = "name"))
cat("targets defined:", n_defined, "\n")

if (reset) {
  # tar_invalidate() operates on recorded metadata and ERRORS on a target that
  # has never run — which is exactly the state a recovery re-run is in. Scope it
  # to what tar_meta() knows; tar_make() below still builds everything.
  known <- tryCatch(tar_meta()$name, error = function(e) character())
  cat("targets with recorded metadata:", length(known), "\n")
  if (length(known)) {
    tar_invalidate(names = tidyselect::everything())
    cat("invalidated all recorded targets\n")
  } else {
    cat("no metadata to invalidate (clean slate)\n")
  }
}

cat("--- building ---\n")
status <- tryCatch({
  tar_make(reporter = "verbose")
  "ok"
}, error = function(e) paste("ERROR:", conditionMessage(e)))

t1 <- Sys.time()
cat("=== finished", format(t1, "%Y-%m-%d %H:%M:%S"),
    sprintf("(%.1f min) status: %s ===\n", as.numeric(difftime(t1, t0, units = "mins")), status))

# report per-target errors explicitly: tar_make() can return without erroring
# while individual targets failed
m <- tryCatch(tar_meta(fields = "error"), error = function(e) NULL)
if (!is.null(m)) {
  e <- m[!is.na(m$error), c("name", "error")]
  cat("targets with errors:", nrow(e), "\n")
  if (nrow(e)) for (i in seq_len(nrow(e)))
    cat("  !", e$name[i], "::", substr(e$error[i], 1, 300), "\n")
}
