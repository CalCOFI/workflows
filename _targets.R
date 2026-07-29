# calcofi data workflow pipeline
# dependencies auto-discovered from calcofi: YAML frontmatter in each .qmd
#
# targets::tar_invalidate(everything())    # start fresh
# targets::tar_invalidate("ingest_swfsc_ichthyo")    # invalidate node
# targets::tar_make()                      # run pipeline: Rscript -e 'targets::tar_make()'
# targets::tar_make("ingest_calcofi_dic")  # run specific workflow in pipeline: Rscript -e 'targets::tar_make("ingest_calcofi_dic")'
# targets::tar_visnetwork()                # visualize the dependency graph
# targets::tar_outdated()                  # see which targets would run
# targets::tar_manifest()                  # inspect all targets as a data frame
# targets::tar_unblock_process()           # unblock processes, eg locked db connections
# targets::tar_meta(fields = error)        # inspect error metadata for all targets

library(targets)
#devtools::load_all(here::here("../calcofi4db"))
library(calcofi4db) # remotes::install_github("calcofi/calcofi4db"); remotes::install_github("calcofi/calcofi4r")

# Chrome >= 132 removed the legacy --headless mode that Quarto uses to
# screenshot mermaid diagrams (mermaid-format: png), causing renders to hang.
# Force the modern headless API so PNG mermaid (zoomable via lightbox) works.
# Inherited by the quarto/Chrome subprocesses spawned via quarto_render().
Sys.setenv(QUARTO_CHROMIUM_HEADLESS_MODE = "new")

build_targets_list(
  exclude = c(
    "publish_ichthyo_to-obis",
    # ctd-cast is ALREADY BUILT AND SYNCED for this run: sample (14,336),
    # obs (5,551,551) and obs_ctd_full (216,427,608 rows / 4.9 GB / 96
    # partitions) are on disk and mirrored to GCS. Its target record was lost
    # when the previous run was killed mid-upload, so targets would otherwise
    # redo ~2 h of work to reach the same bytes. release_database reads the
    # shards straight off the filesystem (assemble_core() globs
    # data/parquet/*/), so excluding the target does NOT drop CTD from the
    # release. REMOVE THIS once the CTD source data changes.
    "ingest_calcofi_ctd-cast",
    # netCDF publishing is on hold — these already ran, and the whole-dataset
    # recreation likely belongs at the ingest step rather than after the release.
    "publish_ctd-cast_to-netcdf",
    "publish_ichthyo_to-netcdf")
)
