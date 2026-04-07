# common settings for all ingest workflows
# source(here::here("libs/ingest.R")) in each QMD setup chunk

# set TRUE to force full rebuild (delete wrangling DB + parquet);
# FALSE for incremental runs (skip already-ingested data)
overwrite <- TRUE

# shared Google Drive data root
dir_data <- "~/My Drive/projects/calcofi/data-public"
