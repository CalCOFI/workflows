# calcofi data workflow pipeline
# run with: targets::tar_make() [Rscript -e 'targets::tar_make()']
# visualize: targets::tar_visnetwork()

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
      ingest_swfsc_ichthyo  # needs ship, cruise, grid from ichthyo
      quarto::quarto_render("ingest_calcofi_ctd-cast.qmd")
      "data/parquet/calcofi_ctd-cast/manifest.json"
    },
    format = "file"
  ),

  tar_target(
    release_database,
    {
      ingest_swfsc_ichthyo
      ingest_calcofi_bottle
      ingest_calcofi_ctd_cast
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
