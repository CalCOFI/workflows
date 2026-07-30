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
    # RE-ENABLED 2026-07-30. The exclusion below was correct while the CTD
    # outputs were byte-identical to what was already on disk, but the ingest
    # LOGIC has now changed in three ways that require a real rebuild:
    #   1. `-99` (the source's documented missing sentinel, previously stripped
    #      only from longitude/latitude) is now removed from measurements — it
    #      had been reaching obs as a real reading, 84,302 rows in v2026.07.17
    #      including canonical oxygen.
    #   2. btl_ammonium is now is_canonical = TRUE, so it enters ctd_thin/obs.
    #   3. ctd_thin retains bottle-trip depths ('bottle' retained_reason);
    #      without it only ~27% of bottle ammonium survived depth thinning.
    # The checkpoint DB (data/wrangling/calcofi_ctd-cast_checkpoint.duckdb) is
    # kept, so this restores ctd_raw and re-runs from the pivot rather than
    # re-downloading 62 GB.
    # "ingest_calcofi_ctd-cast",
    # netCDF publishing is on hold — these already ran, and the whole-dataset
    # recreation likely belongs at the ingest step rather than after the release.
    "publish_ctd-cast_to-netcdf",
    "publish_ichthyo_to-netcdf")
)
