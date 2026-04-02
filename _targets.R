# calcofi data workflow pipeline
# targets::tar_invalidate(everything()) # start fresh
# targets::tar_make()                   # run make; Rscript -e 'targets::tar_make()'
# targets::tar_visnetwork()             # visualize the dependency graph
# targets::tar_outdated()               # see which targets would run
# targets::tar_manifest()               # inspect all targets as a data frame

library(targets)

list(
  tar_target(
    ingest_swfsc_ichthyo,
    {
      quarto::quarto_render("ingest_swfsc_ichthyo.qmd")
      "data/parquet/swfsc_ichthyo/manifest.json"
    },
    format = "file"
  ),

  tar_target(
    ingest_calcofi_bottle,
    {
      ingest_swfsc_ichthyo # depends on ingest_swfsc_ichthyo (load_prior_tables)
      quarto::quarto_render("ingest_calcofi_bottle.qmd")
      "data/parquet/calcofi_bottle/manifest.json"
    },
    format = "file"
  ),

  tar_target(
    ingest_calcofi_ctd_cast,
    {
      ingest_swfsc_ichthyo # needs ship, cruise, grid from ichthyo
      quarto::quarto_render("ingest_calcofi_ctd-cast.qmd")
      "data/parquet/calcofi_ctd-cast/manifest.json"
    },
    format = "file"
  ),

  tar_target(
    ingest_calcofi_dic,
    {
      ingest_calcofi_bottle # needs casts + bottle for FK matching
      quarto::quarto_render("ingest_calcofi_dic.qmd")
      "data/parquet/calcofi_dic/manifest.json"
    },
    format = "file"
  ),

  tar_target(
    ingest_swfsc_inverts,
    {
      ingest_swfsc_ichthyo # needs ship, cruise, tow, net from ichthyo
      quarto::quarto_render("ingest_swfsc_inverts.qmd")
      "data/parquet/swfsc_inverts/manifest.json"
    },
    format = "file"
  ),

  tar_target(
    ingest_spatial,
    {
      quarto::quarto_render("ingest_spatial.qmd")
      "data/parquet/spatial"
    },
    format = "file"
  ),

  tar_target(
    release_database,
    {
      ingest_swfsc_ichthyo
      ingest_swfsc_inverts
      ingest_calcofi_bottle
      ingest_calcofi_ctd_cast
      ingest_calcofi_dic
      ingest_spatial
      quarto::quarto_render("release_database.qmd")
      here::here("data/releases")
    },
    format = "file"
  ),

  tar_target(
    publish_ichthyo_to_obis,
    {
      release_database
      quarto::quarto_render("publish_ichthyo_to_obis.qmd")
      Sys.glob("data/darwincore/ichthyo_*.zip")
    },
    format = "file"
  )
)
