# common settings for all ingest workflows
# source(here::here("libs/ingest.R")) in each QMD setup chunk

# set TRUE to force rebuild of wrangling DB and parquet outputs;
# FALSE for incremental runs (skip already-ingested data)
overwrite <- TRUE

# set TRUE to also redo intermediate checkpoints (RDS files, etc.);
# downloads are always skipped if files exist regardless of this flag
overwrite_all <- FALSE

# shared Google Drive data root
dir_data <- "~/My Drive/projects/calcofi/data-public"
