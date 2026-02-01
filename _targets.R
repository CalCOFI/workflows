# calcofi data workflow pipeline
# run with: targets::tar_make()
# visualize: targets::tar_visnetwork()

library(targets)
library(tarchetypes)

# set options ----
tar_option_set(
  packages = c(
    "calcofi4db", "arrow", "dplyr", "duckdb", "DBI",
    "glue", "readr", "tibble", "tidyr"),
  format   = "qs",          # fast serialization
  storage  = "worker",      # parallel execution ready
  retrieval = "worker")

# configuration ----
GCS_BUCKET_FILES <- "calcofi-files"
GCS_BUCKET_DB    <- "calcofi-db"
DIR_DATA         <- "~/My Drive/projects/calcofi/data"
DIR_PARQUET      <- "parquet"
DIR_DUCKDB       <- "duckdb"

# helper functions ----

#' Get local CSV path or download from GCS
get_csv_path <- function(provider, dataset, filename, dir_data = DIR_DATA) {
  local_path <- file.path(dir_data, provider, dataset, filename)

  if (file.exists(local_path)) {
    return(local_path)
  }

  # fallback to GCS
  gcs_path <- glue::glue(
    "gs://{GCS_BUCKET_FILES}/current/{provider}/{dataset}/{filename}")
  calcofi4db::get_gcs_file(gcs_path)
}

#' Read and clean CSV file
read_source_csv <- function(csv_path) {
  readr::read_csv(csv_path, show_col_types = FALSE) |>
    janitor::clean_names()
}

#' Convert to parquet and return path
csv_to_parquet_target <- function(data, name, dir = DIR_PARQUET) {
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE)
  }

  output_path <- file.path(dir, paste0(name, ".parquet"))
  arrow::write_parquet(data, output_path, compression = "snappy")

  message(glue::glue("Created: {output_path} ({nrow(data)} rows)"))
  output_path
}

#' Create DuckDB from parquet files
create_calcofi_duckdb <- function(
    parquet_paths,
    db_path = file.path(DIR_DUCKDB, "calcofi.duckdb")) {

  if (!dir.exists(dirname(db_path))) {
    dir.create(dirname(db_path), recursive = TRUE)
  }

  # remove existing database to recreate
  if (file.exists(db_path)) {
    file.remove(db_path)
  }

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  # load each parquet file as a table
  for (pqt_path in parquet_paths) {
    tbl_name <- tools::file_path_sans_ext(basename(pqt_path))

    DBI::dbExecute(con, glue::glue(
      "CREATE TABLE {tbl_name} AS SELECT * FROM read_parquet('{pqt_path}')"))

    n_rows <- DBI::dbGetQuery(con, glue::glue(
      "SELECT COUNT(*) as n FROM {tbl_name}"))$n

    message(glue::glue("Loaded table: {tbl_name} ({n_rows} rows)"))
  }

  # add h3 extension for spatial indexing
  DBI::dbExecute(con, "INSTALL h3 FROM community; LOAD h3;")

  message(glue::glue("Created DuckDB: {db_path}"))
  db_path
}

# define pipeline ----
list(
  # ═══════════════════════════════════════════════════════════════════════════
  # RAW DATA: NOAA CalCOFI Database (ichthyoplankton)
  # ═══════════════════════════════════════════════════════════════════════════

  tar_target(
    csv_path_cruise,
    get_csv_path("swfsc.noaa.gov", "calcofi-db", "cruise.csv"),
    format = "file"),

  tar_target(
    csv_path_ship,
    get_csv_path("swfsc.noaa.gov", "calcofi-db", "ship.csv"),
    format = "file"),

  tar_target(
    csv_path_site,
    get_csv_path("swfsc.noaa.gov", "calcofi-db", "site.csv"),
    format = "file"),

  tar_target(
    csv_path_tow,
    get_csv_path("swfsc.noaa.gov", "calcofi-db", "tow.csv"),
    format = "file"),

  tar_target(
    csv_path_net,
    get_csv_path("swfsc.noaa.gov", "calcofi-db", "net.csv"),
    format = "file"),

  tar_target(
    csv_path_species,
    get_csv_path("swfsc.noaa.gov", "calcofi-db", "species.csv"),
    format = "file"),

  tar_target(
    csv_path_larva,
    get_csv_path("swfsc.noaa.gov", "calcofi-db", "larva.csv"),
    format = "file"),

  tar_target(
    csv_path_egg,
    get_csv_path("swfsc.noaa.gov", "calcofi-db", "egg.csv"),
    format = "file"),

  # ─── read source CSVs ───────────────────────────────────────────────────────

  tar_target(raw_cruise,  read_source_csv(csv_path_cruise)),
  tar_target(raw_ship,    read_source_csv(csv_path_ship)),
  tar_target(raw_site,    read_source_csv(csv_path_site)),
  tar_target(raw_tow,     read_source_csv(csv_path_tow)),
  tar_target(raw_net,     read_source_csv(csv_path_net)),
  tar_target(raw_species, read_source_csv(csv_path_species)),
  tar_target(raw_larva,   read_source_csv(csv_path_larva)),
  tar_target(raw_egg,     read_source_csv(csv_path_egg)),

  # ═══════════════════════════════════════════════════════════════════════════
  # TRANSFORM: Clean and standardize data
  # ═══════════════════════════════════════════════════════════════════════════

  # cruises table
  tar_target(
    tbl_cruise,
    raw_cruise |>
      dplyr::rename(
        cruise_uuid = cruiseuuid,
        ship_key    = shipkey) |>
      dplyr::select(-recordversion)),

  # ships table
  tar_target(
    tbl_ship,
    raw_ship |>
      dplyr::rename(
        ship_key  = shipkey,
        ship_nodc = shipnodc)),

  # sites table (sampling locations)
  tar_target(
    tbl_site,
    raw_site |>
      dplyr::rename(
        site_uuid   = siteuuid,
        cruise_uuid = cruiseuuid) |>
      dplyr::select(-recordversion)),

  # tows table
  tar_target(
    tbl_tow,
    raw_tow |>
      dplyr::rename(
        tow_uuid     = towuuid,
        site_uuid    = siteuuid,
        tow_type_key = towtypekey,
        time_start   = timestart,
        time_end     = timeend) |>
      dplyr::select(-recordversion, -starts_with("stationid"))),

  # nets table
  tar_target(
    tbl_net,
    raw_net |>
      dplyr::rename(
        net_uuid = netuuid,
        tow_uuid = towuuid) |>
      dplyr::select(-recordversion)),

  # species reference table
  tar_target(
    tbl_species,
    raw_species |>
      dplyr::rename(
        species_id = speciesid)),

  # larvae observations
  tar_target(
    tbl_larva,
    raw_larva |>
      dplyr::rename(
        net_uuid   = netuuid,
        species_id = speciesid)),

  # egg observations
  tar_target(
    tbl_egg,
    raw_egg |>
      dplyr::rename(
        net_uuid   = netuuid,
        species_id = speciesid)),

  # ═══════════════════════════════════════════════════════════════════════════
  # PARQUET: Convert transformed tables to Parquet format
  # ═══════════════════════════════════════════════════════════════════════════

  tar_target(
    pqt_cruise,
    csv_to_parquet_target(tbl_cruise, "cruise"),
    format = "file"),

  tar_target(
    pqt_ship,
    csv_to_parquet_target(tbl_ship, "ship"),
    format = "file"),

  tar_target(
    pqt_site,
    csv_to_parquet_target(tbl_site, "site"),
    format = "file"),

  tar_target(
    pqt_tow,
    csv_to_parquet_target(tbl_tow, "tow"),
    format = "file"),

  tar_target(
    pqt_net,
    csv_to_parquet_target(tbl_net, "net"),
    format = "file"),

  tar_target(
    pqt_species,
    csv_to_parquet_target(tbl_species, "species"),
    format = "file"),

  tar_target(
    pqt_larva,
    csv_to_parquet_target(tbl_larva, "larva"),
    format = "file"),

  tar_target(
    pqt_egg,
    csv_to_parquet_target(tbl_egg, "egg"),
    format = "file"),

  # ═══════════════════════════════════════════════════════════════════════════
  # DUCKDB: Create integrated database from Parquet files
  # ═══════════════════════════════════════════════════════════════════════════

  tar_target(
    all_parquet_files,
    c(pqt_cruise, pqt_ship, pqt_site, pqt_tow,
      pqt_net, pqt_species, pqt_larva, pqt_egg)),

  tar_target(
    duckdb_path,
    create_calcofi_duckdb(all_parquet_files),
    format = "file")

  # ═══════════════════════════════════════════════════════════════════════════
  # TODO: Add OBIS publishing targets in Phase 2
  # ═══════════════════════════════════════════════════════════════════════════
  # tar_target(
  #   obis_archive,
  #   create_obis_archive(duckdb_path))
)
