# erddap_netcdf.R — publish CalCOFI long CTD tables to ERDDAP as the NATIVE
# ERDDAP path: per-cruise CF "profile" NetCDF files served by EDDTableFromNcCFFiles
# (Discrete Sampling Geometry, contiguous ragged array). This is the "NetCDF per
# cast à la Trinidad Head" option Lynn DeWitt raised — except CalCOFI has ~5.55M
# casts, so one file PER CAST is infeasible; we bundle casts BY CRUISE (96 files).
#
# The long tables (one row per cast x depth x measurement_type) are pivoted to
# WIDE (one column per canonical measurement_type) per cruise, joined to ctd_cast
# for time/lat/lon, and written as CF profiles: profile = cast, obs = depth level.
# ERDDAP reads each file's per-file index and only opens matching files, so memory
# stays low (contrast EDDTableFromParquetFiles, which loads whole files on-heap).
#
# Reuses erddap.R helpers (.erddap_datavar_xml, .xml_escape, %||%).
# Requires: DBI, duckdb, glue, ncdf4. Generate in the rstudio container, reading
# Parquet from and writing NetCDF to the shared /share/data tree (so the paths
# resolve identically when ERDDAP later reads them). See bench_erddap_ctd.qmd.

# CF/NetCDF default double fill (recognized by ERDDAP as the missing value).
.NC_FILL_DOUBLE <- 9.969209968386869e36

#' Pivot one cruise of a long CTD table to a wide (cast x depth) data.frame.
#' @return data.frame ordered by (profile_id, depth): columns profile_id, time
#'   (epoch s), latitude, longitude, line, sta, depth, then one per `vars`.
.ctd_cruise_wide <- function(con, data_dir, table, cruise_key, vars) {
  val <- vapply(vars, function(v) glue::glue(
    "MAX(t.measurement_value) FILTER (WHERE t.measurement_type='{v}')::DOUBLE AS \"{v}\""),
    character(1))
  sql <- glue::glue(
    "SELECT
       t.ctd_cast_uuid                                  AS profile_id,
       epoch(any_value(c.datetime_start_utc))::DOUBLE   AS time,
       any_value(c.latitude)::DOUBLE                    AS latitude,
       any_value(c.longitude)::DOUBLE                   AS longitude,
       any_value(c.line)                                AS line,
       any_value(c.sta)                                 AS sta,
       t.depth_m::DOUBLE                                AS depth,
       {paste(val, collapse=',\n       ')}
     FROM read_parquet('{data_dir}/{table}/**/*.parquet', hive_partitioning=true) t
     JOIN read_parquet('{data_dir}/ctd_cast.parquet') c USING (ctd_cast_uuid)
     WHERE t.cruise_key = '{cruise_key}'
     GROUP BY t.ctd_cast_uuid, t.depth_m
     ORDER BY t.ctd_cast_uuid, t.depth_m")
  DBI::dbGetQuery(con, sql)
}

#' Write one cruise's wide data.frame to a CF contiguous-ragged Profile NetCDF.
.write_cruise_nc <- function(df, cruise_key, out_file, vars, title, summary,
                             units_lookup = list(), longname_lookup = list(),
                             institution = "CalCOFI") {
  prof_ids  <- unique(df$profile_id)          # df is ordered by profile_id, so contiguous
  nprof     <- length(prof_ids)
  nobs      <- nrow(df)
  rowSize   <- as.integer(table(factor(df$profile_id, levels = prof_ids)))
  first_idx <- match(prof_ids, df$profile_id) # first obs row of each profile
  STRLEN    <- 64L
  FILL      <- .NC_FILL_DOUBLE

  d_obs  <- ncdf4::ncdim_def("obs",     "", seq_len(nobs),  create_dimvar = FALSE)
  d_prof <- ncdf4::ncdim_def("profile", "", seq_len(nprof), create_dimvar = FALSE)
  d_str  <- ncdf4::ncdim_def("name_strlen", "", seq_len(STRLEN), create_dimvar = FALSE)

  # profile-level (indexed by profile)
  v_pid   <- ncdf4::ncvar_def("profile_id", "", list(d_str, d_prof), prec = "char")
  v_cru   <- ncdf4::ncvar_def("cruise_key", "", list(d_str, d_prof), prec = "char")
  v_line  <- ncdf4::ncvar_def("line",       "", list(d_str, d_prof), prec = "char")
  v_sta   <- ncdf4::ncvar_def("sta",        "", list(d_str, d_prof), prec = "char")
  v_time  <- ncdf4::ncvar_def("time", "seconds since 1970-01-01T00:00:00Z", d_prof, prec = "double")
  v_lat   <- ncdf4::ncvar_def("latitude",  "degrees_north", d_prof, prec = "double")
  v_lon   <- ncdf4::ncvar_def("longitude", "degrees_east",  d_prof, prec = "double")
  v_rs    <- ncdf4::ncvar_def("rowSize",   "",              d_prof, prec = "integer")
  # obs-level (indexed by obs)
  v_depth <- ncdf4::ncvar_def("depth", "m", d_obs, prec = "double", missval = FILL)
  v_data  <- lapply(vars, function(v) ncdf4::ncvar_def(
    v, as.character(units_lookup[[v]] %||% ""), d_obs, prec = "double", missval = FILL))

  nc <- ncdf4::nc_create(out_file, c(list(v_pid, v_cru, v_line, v_sta, v_time,
                                          v_lat, v_lon, v_rs, v_depth), v_data),
                         force_v4 = FALSE)
  on.exit(ncdf4::nc_close(nc), add = TRUE)

  ncdf4::ncvar_put(nc, v_pid,  prof_ids)
  ncdf4::ncvar_put(nc, v_cru,  rep(cruise_key, nprof))
  ncdf4::ncvar_put(nc, v_line, df$line[first_idx])
  ncdf4::ncvar_put(nc, v_sta,  df$sta[first_idx])
  ncdf4::ncvar_put(nc, v_time, df$time[first_idx])
  ncdf4::ncvar_put(nc, v_lat,  df$latitude[first_idx])
  ncdf4::ncvar_put(nc, v_lon,  df$longitude[first_idx])
  ncdf4::ncvar_put(nc, v_rs,   rowSize)
  ncdf4::ncvar_put(nc, v_depth, df$depth)
  for (i in seq_along(vars)) ncdf4::ncvar_put(nc, v_data[[i]], df[[vars[i]]])

  # CF DSG attributes
  ncdf4::ncatt_put(nc, "profile_id", "cf_role",   "profile_id")
  ncdf4::ncatt_put(nc, "profile_id", "long_name", "CTD cast UUID")
  ncdf4::ncatt_put(nc, "cruise_key", "long_name", "CalCOFI cruise key")
  ncdf4::ncatt_put(nc, "line",       "long_name", "CalCOFI line")
  ncdf4::ncatt_put(nc, "sta",        "long_name", "CalCOFI station")
  ncdf4::ncatt_put(nc, "time", "standard_name", "time")
  ncdf4::ncatt_put(nc, "time", "long_name", "Time")
  ncdf4::ncatt_put(nc, "time", "axis", "T")
  ncdf4::ncatt_put(nc, "latitude",  "standard_name", "latitude")
  ncdf4::ncatt_put(nc, "latitude",  "long_name", "Latitude");  ncdf4::ncatt_put(nc, "latitude", "axis", "Y")
  ncdf4::ncatt_put(nc, "longitude", "standard_name", "longitude")
  ncdf4::ncatt_put(nc, "longitude", "long_name", "Longitude"); ncdf4::ncatt_put(nc, "longitude", "axis", "X")
  ncdf4::ncatt_put(nc, "depth", "standard_name", "depth")
  ncdf4::ncatt_put(nc, "depth", "long_name", "Depth")
  ncdf4::ncatt_put(nc, "depth", "positive", "down"); ncdf4::ncatt_put(nc, "depth", "axis", "Z")
  ncdf4::ncatt_put(nc, "rowSize", "long_name", "Number of observations for this profile")
  ncdf4::ncatt_put(nc, "rowSize", "sample_dimension", "obs")   # -> contiguous ragged array
  for (v in vars) {
    ln <- as.character(longname_lookup[[v]] %||% gsub("_", " ", tools::toTitleCase(v)))
    ncdf4::ncatt_put(nc, v, "long_name", ln)
    ncdf4::ncatt_put(nc, v, "coordinates", "time latitude longitude depth")
  }
  # globals
  g <- list(
    featureType = "profile", cdm_data_type = "Profile",
    cdm_profile_variables = "profile_id, time, latitude, longitude, cruise_key, line, sta",
    Conventions = "CF-1.6, COARDS, ACDD-1.3", institution = institution,
    infoUrl = "https://calcofi.org", license = "CC-BY 4.0",
    title = title, summary = summary, cruise_key = cruise_key,
    source = "CalCOFI CTD cast files (https://calcofi.org)",
    creator_name = "CalCOFI", creator_url = "https://calcofi.org")
  for (nm in names(g)) ncdf4::ncatt_put(nc, 0, nm, g[[nm]])
  invisible(c(nprof = nprof, nobs = nobs))
}

#' Build per-cruise CF Profile NetCDF for a long CTD table.
#' @param data_dir base dir with {table}/ (hive by cruise_key) + ctd_cast.parquet.
#' @param out_dir  destination for <cruise_key>.nc (created if absent).
#' @param vars     canonical measurement_type names -> wide NetCDF variables.
#' @param cruises  optional subset of cruise_keys (default: all partitions).
#' @param con      a live DuckDB DBI connection (caller-managed; reused so the
#'   :memory: instance lifecycle stays in one place).
#' @param overwrite re-write existing .nc (default FALSE -> resumable).
#' @return data.frame(cruise_key, nprof, nobs, file, mb) for files written/seen.
build_ctd_netcdf <- function(con, data_dir, out_dir, table, vars, title, summary,
                             units_lookup = list(), longname_lookup = list(),
                             cruises = NULL, mem_limit = "2GB", threads = 2,
                             tmp_dir = "/share/data/erddap-duckdb/tmp",
                             overwrite = FALSE, verbose = TRUE) {
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)
  if (is.null(cruises)) {
    parts <- list.files(file.path(data_dir, table), pattern = "^cruise_key=")
    cruises <- sort(sub("^cruise_key=", "", parts))
  }
  cruises <- setdiff(cruises, "__HIVE_DEFAULT_PARTITION__")  # NULL-cruise hive bucket
  for (s in c(glue::glue("SET memory_limit='{mem_limit}'"),
              glue::glue("SET threads={threads}"),
              glue::glue("SET temp_directory='{tmp_dir}'"),
              "SET preserve_insertion_order=false"))
    try(DBI::dbExecute(con, s), silent = TRUE)
  rows <- vector("list", length(cruises))
  for (i in seq_along(cruises)) {
    ck   <- cruises[i]
    f    <- file.path(out_dir, paste0(ck, ".nc"))
    if (file.exists(f) && !overwrite) {
      rows[[i]] <- data.frame(cruise_key = ck, nprof = NA, nobs = NA,
                              file = f, mb = round(file.size(f) / 1048576, 2))
      if (verbose) cat(sprintf("[%d/%d] %s  (exists, skip)\n", i, length(cruises), ck))
      next
    }
    df  <- .ctd_cruise_wide(con, data_dir, table, ck, vars)
    if (nrow(df) == 0L) {                       # no casts join to ctd_cast — skip
      if (verbose) cat(sprintf("[%d/%d] %s  (0 rows, skip)\n", i, length(cruises), ck))
      next
    }
    dims <- .write_cruise_nc(df, ck, f, vars, title, summary, units_lookup, longname_lookup)
    rows[[i]] <- data.frame(cruise_key = ck, nprof = dims["nprof"], nobs = dims["nobs"],
                            file = f, mb = round(file.size(f) / 1048576, 2))
    if (verbose) cat(sprintf("[%d/%d] %s  profiles=%d obs=%d  %.1f MB\n",
                             i, length(cruises), ck, dims["nprof"], dims["nobs"],
                             file.size(f) / 1048576))
    rm(df); gc(FALSE)
  }
  do.call(rbind, rows)
}

#' EDDTableFromNcCFFiles <dataset> block for the per-cruise Profile NetCDF.
#' Reuses .erddap_datavar_xml() for the per-variable blocks (source erddap.R first).
erddap_nccf_dataset_xml <- function(
    dataset_id, title, summary, file_dir, vars,
    units_lookup = list(), longname_lookup = list(), range_lookup = list(),
    institution = "CalCOFI", reload_minutes = 10080, global_atts = list()) {

  # column -> (duckdb-ish) type for .erddap_datavar_xml()'s dataType mapping
  prof_cols <- c(profile_id = "VARCHAR", time = "TIMESTAMP", latitude = "DOUBLE",
                 longitude = "DOUBLE", cruise_key = "VARCHAR", line = "VARCHAR",
                 sta = "VARCHAR")
  obs_cols  <- c(depth = "DOUBLE", setNames(rep("DOUBLE", length(vars)), vars))
  cols <- c(prof_cols, obs_cols)

  blocks <- vapply(names(cols), function(col) {
    b <- .erddap_datavar_xml(
      col, cols[[col]],
      units     = as.character(units_lookup[[col]]    %||% ""),
      long_name = as.character(longname_lookup[[col]] %||% ""),
      actual_range = range_lookup[[col]])
    if (col == "profile_id")            # CF discrete-geometry instance variable
      b <- sub("    <addAttributes>\n",
               "    <addAttributes>\n      <att name=\"cf_role\">profile_id</att>\n",
               b, fixed = TRUE)
    b
  }, character(1))

  glob <- c(
    cdm_data_type = "Profile", featureType = "Profile",
    cdm_profile_variables = "profile_id, time, latitude, longitude, cruise_key, line, sta",
    subsetVariables = "cruise_key, line, sta",
    Conventions = "CF-1.6, COARDS, ACDD-1.3", institution = institution,
    infoUrl = "https://calcofi.org", sourceUrl = "(local files)", license = "CC-BY 4.0",
    creator_name = "CalCOFI", creator_url = "https://calcofi.org",
    title = title, summary = summary,
    standard_name_vocabulary = "CF Standard Name Table v79")
  for (nm in names(global_atts)) glob[nm] <- as.character(global_atts[[nm]])
  glob_xml <- paste0('    <att name="', names(glob), '">', .xml_escape(glob), "</att>", collapse = "\n")

  glue::glue(
    '<dataset type="EDDTableFromNcCFFiles" datasetID="{dataset_id}" active="true">\n',
    '  <reloadEveryNMinutes>{reload_minutes}</reloadEveryNMinutes>\n',
    '  <updateEveryNMillis>0</updateEveryNMillis>\n',
    '  <fileDir>{file_dir}</fileDir>\n',
    '  <fileNameRegex>.*\\.nc</fileNameRegex>\n',
    '  <recursive>true</recursive>\n',
    '  <pathRegex>.*</pathRegex>\n',
    '  <metadataFrom>last</metadataFrom>\n',
    '  <standardizeWhat>0</standardizeWhat>\n',
    '  <accessibleViaFiles>true</accessibleViaFiles>\n',
    '  <addAttributes>\n{glob_xml}\n  </addAttributes>\n',
    '{paste(blocks, collapse = "\\n")}\n',
    '</dataset>')
}
