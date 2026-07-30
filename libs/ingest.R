# common settings for all ingest workflows
# source(here::here("libs/ingest.R")) in each QMD setup chunk

# set TRUE to force rebuild of wrangling DB and parquet outputs;
# FALSE for incremental runs (skip already-ingested data)
#
# DO NOT set this FALSE globally to let one dataset resume. Tried 2026-07-30 (to
# let ctd-cast skip to upload after it failed in a cosmetic appendix with its
# parquet already correct) and it broke a DIFFERENT ingest:
# ingest_cce-lter_euphausiids.qmd dies in [emit_core] because its resume path
# sets eval = FALSE on the chunks that build the tables emit_core then reads.
# This file is sourced by EVERY ingest, so the flag is all-or-nothing, and the
# skip path is not uniformly safe across notebooks. Per-notebook resume needs a
# per-notebook mechanism (ctd-cast's own check_resume chunk is the model).
overwrite <- TRUE

# set TRUE to also redo intermediate checkpoints (RDS files, etc.);
# downloads are always skipped if files exist regardless of this flag
overwrite_all <- FALSE

# shared Google Drive data root
dir_data <- "~/My Drive/projects/calcofi/data-public"
