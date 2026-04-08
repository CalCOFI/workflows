# calcofi data workflow pipeline
# dependencies auto-discovered from calcofi: YAML frontmatter in each .qmd
#
# targets::tar_invalidate(everything())    # start fresh
# targets::tar_invalidate("ingest_swfsc_ichthyo")    # invalidate node
# targets::tar_invalidate(everything())    # start fresh
# targets::tar_make()                      # run pipeline: Rscript -e 'targets::tar_make()'
# targets::tar_make("ingest_calcofi_dic")  # run specific workflow in pipeline: Rscript -e 'targets::tar_make("ingest_calcofi_dic")'
# targets::tar_visnetwork()                # visualize the dependency graph
# targets::tar_outdated()                  # see which targets would run
# targets::tar_manifest()                  # inspect all targets as a data frame
# targets::tar_unblock_process()           # unblock processes, eg locked db connections
# targets::tar_meta(fields = error)        # inspect error metadata for all targets

library(targets)
devtools::load_all(here::here("../calcofi4db"))
build_targets_list(
  exclude = c("ingest_calcofi_ctd-cast", "publish_ichthyo_to_obis")
)
