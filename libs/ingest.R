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

# source files: data-public in the CalCOFI Data Folder, the UCSD-controlled
# Shared Drive folder (1KYo8-WiWpdYcvHU8CBPvPhJdJdOym0oW) that providers drop
# files into, reached through its shortcut in My Drive/projects/calcofi. on the
# Mac mini the same path is a plain folder mirrored from GCS. the personal
# My Drive/projects/calcofi/data-public is retired (2026-10-06) and holds only
# pointers. override with CALCOFI_DATA_DIR
dir_data <- Sys.getenv(
  "CALCOFI_DATA_DIR",
  "~/My Drive/projects/calcofi/CalCOFI Data Folder/data-public")
