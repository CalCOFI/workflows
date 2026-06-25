# erddap_duckdb.R — publish CalCOFI long CTD tables to ERDDAP via
# EDDTableFromDatabase over DuckDB *views* (CREATE VIEW ... read_parquet) that
# join to ctd_cast for time/lat/lon. ERDDAP streams filtered results from DuckDB
# (predicate pushdown + partition pruning + disk spill) instead of loading whole
# Parquet files into the JVM heap, as EDDTableFromParquetFiles does — the OOM
# that disabled ctd_wide. See CalCOFI/workflows/bench_erddap_ctd.qmd.
#
# Reuses erddap.R helpers (.erddap_datavar_xml, .duckdb_to_erddap_type,
# .erddap_coord_attrs, %||%). source(here("libs/erddap.R")) first.
#
# Requires the DuckDB JDBC driver in ERDDAP's WEB-INF/lib (custom image:
# CalCOFI/server/erddap/Dockerfile). The duckdb_jdbc engine version must be >=
# the DuckDB engine that built the .db (we build with 1.5.2 → pin 1.5.2.x).

#' Build the DuckDB .db of denormalizing views (for the publish/promote path).
#' Mirrors libs/ctd views: joins ctd_thin / ctd_measurement to ctd_cast and
#' exposes ERDDAP-canonical columns (epoch-seconds time, double lat/lon/depth).
#' @param db_path   output .db file (overwritten).
#' @param data_dir  base dir holding ctd_thin/, ctd_cast.parquet,
#'                  ctd_measurement/ — must be the SAME absolute path ERDDAP
#'                  will see (identity-mount), since views bind paths literally.
build_ctd_duckdb <- function(db_path, data_dir,
                             tables = c("ctd_thin", "ctd_measurement")) {
  if (file.exists(db_path)) file.remove(db_path)
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  uuid_col <- c(ctd_thin = "ctd_thin_uuid", ctd_measurement = "ctd_measurement_uuid")
  extra    <- c(ctd_thin = ", t.cast_dir, t.retained_reason", ctd_measurement = "")
  for (tb in tables) {
    DBI::dbExecute(con, glue::glue("
      CREATE OR REPLACE VIEW {tb}_erddap AS
      SELECT
        t.ctd_cast_uuid,
        c.datetime_start_utc AS time,   -- real TIMESTAMP: ERDDAP EDVTimeStamp uses rs.getTimestamp()
        c.latitude::DOUBLE  AS latitude,
        c.longitude::DOUBLE AS longitude,
        t.depth_m::DOUBLE   AS depth,
        c.cruise_key, c.site_key, c.line, c.sta,
        t.measurement_type,
        t.measurement_value::DOUBLE AS measurement_value,
        t.measurement_qual{extra[[tb]]},
        t.{uuid_col[[tb]]}
      FROM read_parquet('{data_dir}/{tb}/**/*.parquet', hive_partitioning = true) t
      JOIN read_parquet('{data_dir}/ctd_cast.parquet') c USING (ctd_cast_uuid)"))
  }
  writeLines(as.character(DBI::dbGetQuery(con, "SELECT version()")[[1]]),
             file.path(dirname(db_path), "BUILD_VERSION.txt"))
  DBI::dbGetQuery(con, "SELECT view_name FROM duckdb_views() WHERE NOT internal")$view_name
}

#' EDDTableFromDatabase <dataset> block for a DuckDB view.
#' @param staged data.frame(column, duckdb_type) — the view's columns.
#' @param conn_props named character of JDBC connection properties (DuckDB config).
erddap_duckdb_dataset_xml <- function(
    staged, dataset_id, title, summary, source_url, table_name,
    conn_props = c(`duckdb.read_only` = "true", memory_limit = "1500MB",
                   threads = "2", temp_directory = "/share/data/erddap-duckdb/tmp"),
    subset_vars = NULL, cdm_data_type = "Point", institution = "CalCOFI",
    units_lookup = list(), longname_lookup = list(), comment_lookup = list(),
    range_lookup = list(), global_atts = list(), reload_minutes = 10080, order_by = NULL) {

  if (is.null(subset_vars))
    subset_vars <- intersect(c("cruise_key", "site_key", "measurement_type", "cast_dir"),
                             staged$column)

  dvars <- vapply(seq_len(nrow(staged)), function(i) {
    col <- staged$column[i]
    .erddap_datavar_xml(col, staged$duckdb_type[i],
      units     = as.character(units_lookup[[col]]    %||% ""),
      long_name = as.character(longname_lookup[[col]] %||% ""),
      comment   = as.character(comment_lookup[[col]]  %||% ""),
      actual_range = range_lookup[[col]])
  }, character(1))

  glob <- c(
    cdm_data_type = cdm_data_type,
    Conventions = "COARDS, CF-1.10, ACDD-1.3",
    institution = institution, infoUrl = "https://calcofi.org",
    sourceUrl = "(local DuckDB)", license = "CC-BY 4.0",
    creator_name = "CalCOFI", creator_url = "https://calcofi.org",
    title = title, summary = summary,
    standard_name_vocabulary = "CF Standard Name Table v79")
  for (nm in names(global_atts)) glob[nm] <- as.character(global_atts[[nm]])
  if (length(subset_vars)) glob["subsetVariables"] <- paste(subset_vars, collapse = ", ")
  glob_xml <- paste0('    <att name="', names(glob), '">', .xml_escape(glob), "</att>", collapse = "\n")

  cprop_xml <- paste0('  <connectionProperty name="', names(conn_props), '">',
                      conn_props, "</connectionProperty>", collapse = "\n")
  order_xml <- if (!is.null(order_by)) glue::glue("  <orderBy>{order_by}</orderBy>\n") else ""

  glue::glue(
    '<dataset type="EDDTableFromDatabase" datasetID="{dataset_id}" active="true">\n',
    '  <reloadEveryNMinutes>{reload_minutes}</reloadEveryNMinutes>\n',
    '  <sourceUrl>{source_url}</sourceUrl>\n',
    '  <driverName>org.duckdb.DuckDBDriver</driverName>\n',
    '{cprop_xml}\n',
    '  <catalogName></catalogName>\n',
    '  <schemaName></schemaName>\n',
    '  <tableName>{table_name}</tableName>\n',
    '  <columnNameQuotes>"</columnNameQuotes>\n',
    # let DuckDB (not ERDDAP heap) handle ORDER BY / DISTINCT when a query asks
    '  <sourceCanOrderBy>yes</sourceCanOrderBy>\n',
    '  <sourceCanDoDistinct>yes</sourceCanDoDistinct>\n',
    '{order_xml}',
    '  <addAttributes>\n{glob_xml}\n  </addAttributes>\n',
    '{paste(dvars, collapse = "\\n")}\n',
    '</dataset>')
}

#' EDDTableFromAsciiFiles (CSV) <dataset> block — the uncompressed baseline.
erddap_csv_dataset_xml <- function(
    staged, dataset_id, title, summary, file_dir,
    subset_vars = NULL, cdm_data_type = "Point", institution = "CalCOFI",
    units_lookup = list(), longname_lookup = list(), reload_minutes = 10080) {

  if (is.null(subset_vars))
    subset_vars <- intersect(c("cruise_key", "site_key", "measurement_type", "cast_dir"),
                             staged$column)
  dvars <- vapply(seq_len(nrow(staged)), function(i) {
    col <- staged$column[i]
    .erddap_datavar_xml(col, staged$duckdb_type[i],
      units = as.character(units_lookup[[col]] %||% ""),
      long_name = as.character(longname_lookup[[col]] %||% ""))
  }, character(1))

  glob <- c(
    cdm_data_type = cdm_data_type, Conventions = "COARDS, CF-1.10, ACDD-1.3",
    institution = institution, infoUrl = "https://calcofi.org",
    sourceUrl = "(local files)", license = "CC-BY 4.0",
    title = title, summary = summary,
    standard_name_vocabulary = "CF Standard Name Table v79")
  if (length(subset_vars)) glob["subsetVariables"] <- paste(subset_vars, collapse = ", ")
  glob_xml <- paste0('    <att name="', names(glob), '">', glob, "</att>", collapse = "\n")

  glue::glue(
    '<dataset type="EDDTableFromAsciiFiles" datasetID="{dataset_id}" active="true">\n',
    '  <reloadEveryNMinutes>{reload_minutes}</reloadEveryNMinutes>\n',
    '  <updateEveryNMillis>0</updateEveryNMillis>\n',
    '  <fileDir>{file_dir}</fileDir>\n',
    '  <fileNameRegex>.*\\.csv</fileNameRegex>\n',
    '  <recursive>true</recursive>\n',
    '  <pathRegex>.*</pathRegex>\n',
    '  <columnNamesRow>1</columnNamesRow>\n',
    '  <firstDataRow>2</firstDataRow>\n',
    '  <standardizeWhat>0</standardizeWhat>\n',
    '  <addAttributes>\n{glob_xml}\n  </addAttributes>\n',
    '{paste(dvars, collapse = "\\n")}\n',
    '</dataset>')
}
