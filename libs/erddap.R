# erddap.R — helpers to publish CalCOFI parquet tables to ERDDAP as
# EDDTableFromParquetFiles datasets (server is erddap/erddap:latest = v2.30,
# which supports Parquet natively since v2.27).
#
# Two steps per table:
#   1. stage_table_for_erddap(): write an ERDDAP-friendly parquet (drop geom;
#      expose latitude/longitude/depth doubles; time as epoch-seconds double).
#   2. erddap_dataset_xml(): emit the <dataset type="EDDTableFromParquetFiles">
#      block with dataVariables (dataType + units + ioos_category + standard_name).
#
# usage:
#   librarian::shelf(DBI, duckdb, glue, jsonlite, readr, dplyr, here, quiet=T)
#   source(here("libs/erddap.R"))

# canonical CF/ioos attributes for the well-known coordinate columns
.erddap_coord_attrs <- list(
  time      = list(dataType="double", units="seconds since 1970-01-01T00:00:00Z",
                   ioos_category="Time", standard_name="time", long_name="Time"),
  latitude  = list(dataType="double", units="degrees_north",
                   ioos_category="Location", standard_name="latitude", long_name="Latitude"),
  longitude = list(dataType="double", units="degrees_east",
                   ioos_category="Location", standard_name="longitude", long_name="Longitude"),
  depth     = list(dataType="double", units="m", positive="down",
                   ioos_category="Location", standard_name="depth", long_name="Depth"))

# map a DuckDB type to an ERDDAP <dataType>
.duckdb_to_erddap_type <- function(t) {
  t <- toupper(t)
  if (grepl("BIGINT|HUGEINT|INT64", t))        return("long")
  if (grepl("INTEGER|INT32|INT4", t))          return("int")
  if (grepl("SMALLINT|INT2", t))               return("short")
  if (grepl("TINYINT", t))                     return("byte")
  if (grepl("DOUBLE|FLOAT8", t))               return("double")
  if (grepl("REAL|FLOAT4", t))                 return("float")
  if (grepl("BOOLEAN", t))                     return("boolean")
  "String"  # VARCHAR, UUID, etc.
}

# guess an ioos_category from a column name (fallback when not a coord/measurement)
.erddap_ioos_category <- function(col) {
  if (grepl("(_key|_id|_uuid|_code)$", col)) return("Identifier")
  if (grepl("temp", col, ignore.case=TRUE))  return("Temperature")
  if (grepl("sal",  col, ignore.case=TRUE))  return("Salinity")
  if (grepl("oxy|o2", col, ignore.case=TRUE))return("Dissolved O2")
  if (grepl("depth|lat|lon|grid|line|station|geo", col, ignore.case=TRUE)) return("Location")
  if (grepl("date|time|year|month|season|julian", col, ignore.case=TRUE)) return("Time")
  if (grepl("count|tally|abundance|biovol|measurement_value|avg", col, ignore.case=TRUE)) return("Other")
  "Other"
}

#' Stage a parquet table for ERDDAP.
#' @return data.frame(column, duckdb_type) of the staged columns (for XML gen).
stage_table_for_erddap <- function(
    con, src_parquet, table, out_dir,
    time_col = "datetime_start_utc", lat_col = "latitude",
    lon_col = "longitude", depth_col = "depth_m") {

  DBI::dbExecute(con, glue::glue(
    "CREATE OR REPLACE VIEW _src AS SELECT * FROM read_parquet('{src_parquet}')"))
  cols <- DBI::dbGetQuery(con,
    "SELECT column_name, data_type FROM information_schema.columns WHERE table_name='_src'")

  # build SELECT: drop geom/blob; coord columns -> canonical ERDDAP names
  drop <- cols$column_name[grepl("GEOMETRY|BLOB", toupper(cols$data_type)) |
                           grepl("^_", cols$column_name) | cols$column_name == "geom"]
  sel <- c()
  for (i in seq_len(nrow(cols))) {
    cn <- cols$column_name[i]; if (cn %in% drop) next
    if (cn == time_col)       sel <- c(sel, glue::glue('EXTRACT(epoch FROM "{cn}")::DOUBLE AS "time"'))
    else if (cn == lat_col)   sel <- c(sel, glue::glue('"{cn}"::DOUBLE AS "latitude"'))
    else if (cn == lon_col)   sel <- c(sel, glue::glue('"{cn}"::DOUBLE AS "longitude"'))
    else if (cn == depth_col) sel <- c(sel, glue::glue('"{cn}"::DOUBLE AS "depth"'))
    else                      sel <- c(sel, glue::glue('"{cn}"'))
  }
  fs::dir_create(file.path(out_dir, table))
  out_pq <- file.path(out_dir, table, glue::glue("{table}.parquet"))
  DBI::dbExecute(con, glue::glue(
    "COPY (SELECT {paste(sel, collapse=', ')} FROM _src) TO '{out_pq}' (FORMAT parquet)"))

  st <- DBI::dbGetQuery(con, glue::glue(
    "DESCRIBE SELECT * FROM read_parquet('{out_pq}')"))
  data.frame(column = st$column_name, duckdb_type = st$column_type, stringsAsFactors = FALSE)
}

#' Build one <dataVariable> block.
.erddap_datavar_xml <- function(col, dtype, units = "", long_name = "", standard_name = "") {
  a <- if (col %in% names(.erddap_coord_attrs)) .erddap_coord_attrs[[col]] else
    list(dataType = .duckdb_to_erddap_type(dtype),
         ioos_category = .erddap_ioos_category(col),
         long_name = if (nzchar(long_name)) long_name else gsub("_", " ", tools::toTitleCase(col)))
  if (nzchar(units) && is.null(a$units)) a$units <- units
  if (nzchar(standard_name) && is.null(a$standard_name)) a$standard_name <- standard_name
  atts <- a[setdiff(names(a), "dataType")]
  att_xml <- paste0('      <att name="', names(atts), '">', unlist(atts), "</att>", collapse = "\n")
  glue::glue(
    '  <dataVariable>\n',
    '    <sourceName>{col}</sourceName>\n',
    '    <destinationName>{col}</destinationName>\n',
    '    <dataType>{a$dataType}</dataType>\n',
    '    <addAttributes>\n{att_xml}\n    </addAttributes>\n',
    '  </dataVariable>')
}

#' Build a full EDDTableFromParquetFiles <dataset> block for a staged table.
#' @param staged data.frame(column, duckdb_type) from stage_table_for_erddap().
#' @param units_lookup named list/char vector column -> units (e.g. from metadata.json).
erddap_dataset_xml <- function(
    staged, dataset_id, title, summary, file_dir,
    units_lookup = list(), longname_lookup = list(),
    subset_vars = NULL, cdm_data_type = "Point", institution = "CalCOFI") {

  has <- function(c) c %in% staged$column
  if (is.null(subset_vars))
    subset_vars <- intersect(c("cruise_key","line","station","site_key"), staged$column)

  dvars <- vapply(seq_len(nrow(staged)), function(i) {
    col <- staged$column[i]
    .erddap_datavar_xml(
      col, staged$duckdb_type[i],
      units = as.character(units_lookup[[col]] %||% ""),
      long_name = as.character(longname_lookup[[col]] %||% ""))
  }, character(1))

  glob <- c(
    cdm_data_type = cdm_data_type,
    Conventions = "COARDS, CF-1.10, ACDD-1.3",
    institution = institution, infoUrl = "https://calcofi.org",
    sourceUrl = "(local files)", license = "CC-BY 4.0",
    creator_name = "CalCOFI", creator_url = "https://calcofi.org",
    title = title, summary = summary,
    standard_name_vocabulary = "CF Standard Name Table v79")
  if (length(subset_vars)) glob["subsetVariables"] <- paste(subset_vars, collapse = ", ")
  glob_xml <- paste0('    <att name="', names(glob), '">', glob, "</att>", collapse = "\n")

  glue::glue(
    '<dataset type="EDDTableFromParquetFiles" datasetID="{dataset_id}" active="true">\n',
    '  <reloadEveryNMinutes>10080</reloadEveryNMinutes>\n',
    '  <updateEveryNMillis>0</updateEveryNMillis>\n',
    '  <fileDir>{file_dir}</fileDir>\n',
    '  <fileNameRegex>.*\\.parquet</fileNameRegex>\n',
    '  <recursive>false</recursive>\n',
    '  <pathRegex>.*</pathRegex>\n',
    '  <metadataFrom>last</metadataFrom>\n',
    '  <standardizeWhat>0</standardizeWhat>\n',
    '  <accessibleViaFiles>true</accessibleViaFiles>\n',
    '  <addAttributes>\n{glob_xml}\n  </addAttributes>\n',
    '{paste(dvars, collapse = "\\n")}\n',
    '</dataset>')
}

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
