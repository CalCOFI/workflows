# pg_ctd.R — load the CTD cast archive (calcofi.org db-CSV products) into the
# CTD team's PostgreSQL database, schema `ctd` (server/postgis/init/40_ctd.sql).
#
# Three steps, each a function so the notebook (load_pg_ctd.qmd) and a server-side
# Rscript can share them:
#   pg_ctd_discover_files(dir_ext)          which files, which stage, sha256  (laptop)
#   pg_ctd_build_parquet(files, dir_out)    typed parquet, one per file        (laptop)
#   pg_ctd_load(parquet, pg_dsn)            parquet -> ctd.file + ctd.scan     (server or laptop via tunnel)
#   pg_ctd_finish(pg_dsn, ...)              refresh_derived(), data dictionary
#
# Originals stay verbatim: every one of the 82 columns is kept, blanks become NULL, the
# -99 sentinels and NaN strings are kept as values (the QC layer flags them), and each
# row carries (archive, path, row_num) so a value can be traced to a line in a file.
#
# File-discovery rules duplicate the ingest's `d_csv` chunk in ingest_calcofi_ctd-cast.qmd
# (data_stage from directory + filename tokens; cast_dir = last char of the stem). Keep
# them in step; the ingest is the reference.

CTD_DATA_STAGES <- c("final", "preliminary_with_bottle", "preliminary_without_bottle")

# date-time formats seen in the db-CSV files (DuckDB strptime list; first match wins):
#   20-Sep-1997 10:43:30   most files
#   01/29/2015 05:55       1501NH, 1810SR, 1904RL(U), 2204SH, 2601RL and parts of 1911OC/2504SH
#   9/9/2026 9:05          same, without zero padding
PG_CTD_TS_FORMATS <- "['%d-%b-%Y %H:%M:%S', '%m/%d/%Y %H:%M:%S', '%m/%d/%Y %H:%M', '%Y-%m-%d %H:%M:%S']"

# the 82 db-CSV columns in source order -> (column_name, type, source_header)
pg_ctd_columns <- function() {
  hdr <- c("Project","Study","Ord_Occ","Event_Num","Cast_ID","Date_Time_UTC","Date_Time_PST",
    "Lat_Dec","Lon_Dec","Sta_ID","Line","Sta","Depth","Pressure","PrQ","Temp1","Temp1Q","Temp2",
    "Temp2Q","TempAve","Salt1","Salt1Q","Salt1_Corr","Salt2","Salt2Q","Salt2_Corr","SaltAve_Corr",
    "Ox1","Ox1Q","Ox1_CruiseCorr","Ox1_StaCorr","Ox2","Ox2Q","Ox2_CruiseCorr","Ox2_StaCorr",
    "OxAve_StaCorr","Ox1uM","Ox1uM_CruiseCorr","Ox1uM_StaCorr","Ox2uM","Ox2uM_CruiseCorr",
    "Ox2uM_StaCorr","OxAveuM_StaCorr","FluorV","FluorQ","EstChl_CruiseCorr","EstChl_StaCorr",
    "ISUSV","ISUSQ","EstNO3_CruiseCorr","EstNO3_StaCorr","SigThetaTS1","SigThetaTS1Q",
    "SigThetaTS2","SigThetaTS2Q","BAT","XMiss","TransQ","pH","pHQ","SPAR","SPARQ","PAR","PARQ",
    "PoT1","PoT2","DynHt","SVA","OxSat1","OxSat2","BTL_Depth","BTL_Temp","SaltB","OxB","OxBuM",
    "Chl-a","Phaeo","NO3","NO2","NH4","PO4","SIL")
  col <- tolower(gsub("-", "_", hdr))
  type <- dplyr::case_when(
    col %in% c("project","study","ord_occ","event_num","cast_id","sta_id") ~ "text",
    col %in% c("date_time_utc","date_time_pst")                              ~ "timestamp",
    grepl("q$", col) & !col %in% c("sigthetats1","sigthetats2")              ~ "smallint",  # *Q flag columns
    TRUE                                                                     ~ "double")
  tibble::tibble(column_name = col, source_header = hdr, type = type)
}

#' discover the db-CSV cast files under the extraction dir (same rules as the ingest)
pg_ctd_discover_files <- function(dir_ext, compute_sha = TRUE) {
  stopifnot(dir.exists(dir_ext))
  paths <- fs::dir_ls(dir_ext, recurse = TRUE, glob = "*.csv", type = "file")
  d <- tibble::tibble(path_abs = as.character(paths)) |>
    dplyr::mutate(
      rel        = fs::path_rel(path_abs, dir_ext),
      dir_unzip  = stringr::str_extract(rel, "^[^/]+"),
      file_csv   = basename(rel),
      archive    = paste0(dir_unzip, ".zip"),
      study      = stringr::str_extract(dir_unzip, "(?<=^\\d{2}-)\\d{4}[A-Z]{2}"),
      data_stage = dplyr::case_when(
        stringr::str_detect(rel, "Final.*db[_|-]csv")                                   ~ "final",
        stringr::str_detect(dir_unzip, "CTDFinalDB$") & rel == file.path(dir_unzip, file_csv) ~ "final",
        stringr::str_detect(dir_unzip, "Prelim") & stringr::str_detect(file_csv, "_CTDBTL_") ~ "preliminary_with_bottle",
        stringr::str_detect(dir_unzip, "Prelim") & stringr::str_detect(file_csv, "_CTD_")    ~ "preliminary_without_bottle",
        TRUE ~ NA_character_),
      file_stem = file_csv |> stringr::str_remove("\\.csv$") |>
        stringr::str_remove("\\s*\\(\\d+\\)$") |> stringr::str_remove("\\s+\\d+$"),
      cast_dir  = dplyr::case_when(
        stringr::str_detect(file_stem, stringr::regex("U$", ignore_case = TRUE)) ~ "U",
        stringr::str_detect(file_stem, stringr::regex("D$", ignore_case = TRUE)) ~ "D",
        TRUE ~ NA_character_),
      n_bytes   = fs::file_size(path_abs) |> as.numeric()) |>
    dplyr::filter(data_stage %in% CTD_DATA_STAGES, !is.na(cast_dir))
  # the file's own Study column is the authority (two-ship cruises like 0404NHJD and odd ship
  # codes like 0907M2 do not match the directory pattern); directory-derived value is the fallback
  d$study_file <- vapply(d$path_abs, function(p) {
    l <- tryCatch(readLines(p, n = 2, warn = FALSE), error = function(e) character())
    if (length(l) < 2) return(NA_character_)
    h <- strsplit(l[1], ",")[[1]]; v <- strsplit(l[2], ",")[[1]]
    i <- match("Study", h); if (is.na(i) || i > length(v)) NA_character_ else trimws(v[i])
  }, "")
  d <- d |>
    dplyr::mutate(study = dplyr::coalesce(dplyr::na_if(study_file, ""), study)) |>
    dplyr::filter(!is.na(study)) |>
    dplyr::select(archive, path = rel, study, data_stage, cast_dir, n_bytes, path_abs) |>
    dplyr::arrange(study, data_stage, path)
  if (compute_sha)
    d$sha256 <- vapply(d$path_abs, function(p) digest::digest(p, algo = "sha256", file = TRUE), "")
  d
}

#' study (9709NH) -> release cruise_key (1997-09-32NM) via the release cruise table
pg_ctd_cruise_keys <- function(studies, release = "latest") {
  # resolved through the release catalog (content-addressed since v2026.09):
  # never concatenate releases/{v}/parquet/… by hand
  cat_ <- calcofi4r::cc_catalog(release)
  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  DBI::dbExecute(con, "INSTALL httpfs; LOAD httpfs;")
  cr <- DBI::dbGetQuery(con, glue::glue(
    "SELECT cruise_key, date_ym, ship_key FROM ",
    calcofi4r::cc_read_parquet_sql(calcofi4r::cc_release_sources(cat_, "cruise"))))
  sh <- DBI::dbGetQuery(con, glue::glue(
    "SELECT ship_key, ship_nodc FROM ",
    calcofi4r::cc_read_parquet_sql(calcofi4r::cc_release_sources(cat_, "ship"))))
  yy <- as.integer(substr(studies, 1, 2)); mm <- as.integer(substr(studies, 3, 4))
  yr <- ifelse(yy >= 49, 1900L + yy, 2000L + yy)
  key <- tibble::tibble(study = studies,
    date_ym  = as.Date(sprintf("%04d-%02d-01", yr, mm)),
    # a 6-character study is YYMM + 2-letter ship; anything else (0404NHJD, 0907M2) gets no key
    ship_key = ifelse(nchar(studies) == 6, substr(studies, 5, 6), NA_character_)) |>
    dplyr::left_join(cr, by = c("date_ym", "ship_key")) |>
    dplyr::left_join(sh, by = "ship_key") |>
    # not in the release cruise table (CTD-only cruises): construct YYYY-MM-NODC from the ship table
    dplyr::mutate(cruise_key = dplyr::coalesce(cruise_key,
      ifelse(!is.na(ship_nodc), sprintf("%s-%s", format(date_ym, "%Y-%m"), ship_nodc), NA_character_)))
  stats::setNames(key$cruise_key, key$study)
}

#' typed parquet, one file per source file, under dir_out/study=<study>/<archive>__<stem>.parquet, plus
#' dir_out/_issues/study=<study>/<stem>.parquet holding every non-blank source cell that could not be typed (verbatim).
#' returns files with n_rows, n_issues and a per-column issue summary as attr "cast_failures"
pg_ctd_build_parquet <- function(files, dir_out, overwrite = FALSE, progress = TRUE) {
  cols <- pg_ctd_columns()
  con  <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  DBI::dbExecute(con, "SET preserve_insertion_order = true;")   # parallel CSV read keeps file order (verified)
  q <- function(h) sprintf('"%s"', h)
  typed <- function(c, h, t) switch(t,
    text      = sprintf("nullif(trim(%s), '')", q(h)),
    timestamp = sprintf("try_strptime(nullif(trim(%s), ''), %s)", q(h), PG_CTD_TS_FORMATS),
    smallint  = sprintf("TRY_CAST(nullif(trim(%s), '') AS SMALLINT)", q(h)),
    double    = sprintf("TRY_CAST(nullif(trim(%s), '') AS DOUBLE)", q(h)))
  sel <- paste(mapply(function(c, h, t) sprintf("%s AS %s", typed(c, h, t), c),
                      cols$column_name, cols$source_header, cols$type), collapse = ",\n      ")
  # issues: one cheap filtered scan per non-text column (UNION ALL beats UNPIVOT+CASE ~10x here):
  # every non-blank source cell whose typed value is NULL, kept verbatim with its column name
  nontext <- cols[cols$type != "text", ]
  issues_sql <- paste(mapply(function(c, h, t) sprintf(
      "SELECT row_num, '%s' AS column_name, %s AS raw_value FROM t_raw WHERE nullif(trim(%s), '') IS NOT NULL AND %s IS NULL",
      c, q(h), q(h), typed(c, h, t)),
    nontext$column_name, nontext$source_header, nontext$type), collapse = "
          UNION ALL ")
  files$n_rows <- NA_integer_; files$n_issues <- NA_integer_; files$parquet <- NA_character_
  issue_counts <- list()
  for (i in seq_len(nrow(files))) {
    f    <- files[i, ]
    # archive in the name: JRW's *_CTDFinalDB.zip and calcofi.org's *_CTDFinalQC.zip hold files
    # with IDENTICAL inner names (20-0001NH_CTDBTL_001-066D.csv), which once silently overwrote
    # each other here and left 37 files with no scans (caught by the completeness check)
    # …and the SAME archive can hold the same filename in two subdirectories (2204SH: csvs-plots/
    # and db-csvs/), so the parquet name is the whole member path
    stem <- gsub("/", "__", tools::file_path_sans_ext(f$path))
    out  <- file.path(dir_out, paste0("study=", f$study), paste0(stem, ".parquet"))
    outi <- file.path(dir_out, "_issues", paste0("study=", f$study), paste0(stem, ".parquet"))   # sibling tree: scan globs never see it
    dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE); dir.create(dirname(outi), recursive = TRUE, showWarnings = FALSE)
    if (!(file.exists(out) && file.exists(outi) && !overwrite)) {
      DBI::dbExecute(con, sprintf("CREATE OR REPLACE TABLE t_raw AS SELECT row_number() OVER () AS row_num, * FROM read_csv('%s', all_varchar = true, header = true)", f$path_abs))
      DBI::dbExecute(con, sprintf("COPY (SELECT '%s' AS archive, '%s' AS path, row_num, %s FROM t_raw ORDER BY row_num) TO '%s' (FORMAT parquet, COMPRESSION zstd)",
                                  f$archive, f$path, sel, out))
      DBI::dbExecute(con, sprintf("
        COPY (
          SELECT '%s' AS archive, '%s' AS path, row_num, column_name, raw_value
          FROM (%s)
          ORDER BY row_num, column_name
        ) TO '%s' (FORMAT parquet, COMPRESSION zstd)", f$archive, f$path, issues_sql, outi))
    }
    files$n_rows[i]   <- DBI::dbGetQuery(con, sprintf("SELECT count(*) FROM read_parquet('%s')", out))[[1]]
    files$n_issues[i] <- DBI::dbGetQuery(con, sprintf("SELECT count(*) FROM read_parquet('%s')", outi))[[1]]
    files$parquet[i]  <- out
    if (files$n_issues[i] > 0)
      issue_counts[[f$path]] <- DBI::dbGetQuery(con, sprintf("SELECT column_name, count(*) AS n_failed FROM read_parquet('%s') GROUP BY 1", outi))
    if (progress && (i %% 50 == 0 || i == nrow(files)))
      cat(sprintf("  %d/%d files, %s rows, %s issue cells so far\n", i, nrow(files),
        format(sum(files$n_rows, na.rm = TRUE), big.mark = ","), format(sum(files$n_issues, na.rm = TRUE), big.mark = ",")))
  }
  attr(files, "cast_failures") <- if (length(issue_counts)) dplyr::bind_rows(issue_counts, .id = "path") else NULL
  files
}

#' DuckDB connection with the PostgreSQL db ATTACHed as `pg` (read-write)
pg_ctd_duck <- function(pg_dsn, remote = FALSE) {
  con <- DBI::dbConnect(duckdb::duckdb())
  DBI::dbExecute(con, "INSTALL postgres; LOAD postgres; INSTALL httpfs; LOAD httpfs;")
  if (remote) DBI::dbExecute(con, "
    SET s3_region='auto'; SET s3_endpoint='storage.googleapis.com'; SET s3_url_style='path';
    SET s3_access_key_id=''; SET s3_secret_access_key='';")
  DBI::dbExecute(con, sprintf("ATTACH '%s' AS pg (TYPE postgres)", pg_dsn))
  con
}

#' load parquet (local dir or s3://calcofi-db/... prefix) into ctd.file + ctd.scan.
#' Idempotent on (archive, path): files already in ctd.file are skipped.
pg_ctd_load <- function(files, parquet_root, pg_dsn, gcs_uri_root = NULL, cruise_keys = NULL, batch_studies = 10) {
  remote <- grepl("^s3://", parquet_root)
  con <- pg_ctd_duck(pg_dsn, remote = remote)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  cols <- pg_ctd_columns()
  # identity is (archive, path): the same bytes can sit in two archives (JRW + calcofi.org)
  existing <- DBI::dbGetQuery(con, "SELECT archive || '|' || path AS k FROM pg.ctd.file")$k
  new <- files[!paste0(files$archive, "|", files$path) %in% existing, ]
  cat(sprintf("ctd.file: %d already registered, %d new\n", nrow(files) - nrow(new), nrow(new)))
  if (nrow(new) > 0) {
    new$cruise_key <- if (is.null(cruise_keys)) NA_character_ else unname(cruise_keys[new$study])
    new$gcs_uri    <- if (is.null(gcs_uri_root)) NA_character_ else file.path(gcs_uri_root, new$archive)
    DBI::dbWriteTable(con, "new_files", as.data.frame(new[, c("archive","path","study","cruise_key","data_stage","cast_dir","sha256","n_bytes","n_rows","gcs_uri")]), overwrite = TRUE)
    DBI::dbExecute(con, "
      INSERT INTO pg.ctd.file (archive, path, study, cruise_key, data_stage, cast_dir, sha256, n_bytes, n_rows, gcs_uri)
      SELECT archive, path, study, cruise_key, data_stage, cast_dir, sha256, n_bytes::BIGINT, n_rows::INTEGER, gcs_uri FROM new_files")
  }
  # scans: every registered file that has no scans yet (resumable after an interrupted run)
  DBI::dbExecute(con, "CREATE OR REPLACE TABLE file_ids AS SELECT file_id, archive, path, study FROM pg.ctd.file")
  DBI::dbExecute(con, "CREATE OR REPLACE TABLE pending AS
    SELECT f.file_id, f.archive, f.path, f.study FROM pg.ctd.file f
    WHERE NOT EXISTS (SELECT 1 FROM pg.ctd.scan s WHERE s.file_id = f.file_id)")
  pend <- DBI::dbGetQuery(con, "SELECT study, count(*) AS n FROM pending GROUP BY 1 ORDER BY 1")
  cat(sprintf("ctd.scan: %d files pending in %d studies\n", sum(pend$n), nrow(pend)))
  if (nrow(pend) == 0) return(invisible(0))
  col_list   <- paste(cols$column_name, collapse = ", ")
  col_list_p <- paste0("p.", cols$column_name, collapse = ", ")
  studies  <- pend$study
  t0 <- Sys.time(); n_total <- 0
  for (chunk in split(studies, ceiling(seq_along(studies) / batch_studies))) {
    globs <- sprintf("'%s/study=%s/*.parquet'", sub("/$", "", parquet_root), chunk)
    n <- DBI::dbExecute(con, sprintf("
      INSERT INTO pg.ctd.scan (file_id, row_num, %s)
      SELECT pf.file_id, p.row_num::INTEGER, %s
      FROM read_parquet([%s]) p
      JOIN pending pf ON pf.archive = p.archive AND pf.path = p.path
      ORDER BY pf.file_id, p.row_num", col_list, col_list_p, paste(globs, collapse = ", ")))
    n_total <- n_total + n
    cat(sprintf("  %s: +%s rows (%s total, %.0f s)\n", paste(range(chunk), collapse = ".."),
      format(n, big.mark = ","), format(n_total, big.mark = ","),
      as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  }
  # the untypable cells, verbatim
  for (chunk in split(studies, ceiling(seq_along(studies) / batch_studies))) {
    globs <- sprintf("'%s/_issues/study=%s/*.parquet'", sub("/$", "", parquet_root), chunk)
    DBI::dbExecute(con, sprintf("
      INSERT INTO pg.ctd.scan_issue (file_id, row_num, column_name, raw_value)
      SELECT pf.file_id, p.row_num::INTEGER, p.column_name, p.raw_value
      FROM read_parquet([%s]) p JOIN pending pf ON pf.archive = p.archive AND pf.path = p.path
      ORDER BY pf.file_id, p.row_num, p.column_name", paste(globs, collapse = ", ")))
  }
  # per-file completeness: rows in scan == n_rows recorded from the parquet
  chk <- DBI::dbGetQuery(con, "
    SELECT f.file_id, f.path, f.n_rows, count(s.scan_id) AS n_loaded
    FROM pg.ctd.file f LEFT JOIN pg.ctd.scan s USING (file_id)
    GROUP BY 1,2,3 HAVING f.n_rows IS DISTINCT FROM count(s.scan_id)")
  if (nrow(chk) > 0) { print(chk); stop("row-count mismatch between ctd.file.n_rows and ctd.scan for ", nrow(chk), " file(s)") }
  cat("all files complete: ctd.scan rows match ctd.file.n_rows\n")
  invisible(n_total)
}

#' after a load: derived products + data dictionary from the measurement-type registry
pg_ctd_finish <- function(pg_dsn, measurement_type_csv = NULL) {
  con <- DBI::dbConnect(RPostgres::Postgres(), dbname = sub(".*dbname=([^ ]+).*", "\\1", pg_dsn),
    host = sub(".*host=([^ ]+).*", "\\1", pg_dsn), port = as.integer(sub(".*port=([^ ]+).*", "\\1", pg_dsn)),
    user = sub(".*user=([^ ]+).*", "\\1", pg_dsn))
  on.exit(DBI::dbDisconnect(con))
  if (!is.null(measurement_type_csv) && file.exists(measurement_type_csv)) {
    # the registry's _source_column is janitor-snake-cased (Ox1_CruiseCorr -> ox1_cruise_corr),
    # so match through the same transformation of the raw headers
    cols <- pg_ctd_columns() |>
      dplyr::mutate(source_clean = janitor::make_clean_names(source_header))
    mt <- calcofi4db::read_measurement_type(measurement_type_csv) |>
      dplyr::filter(!is.na(`_source_column`), `_source_column` != "") |>
      dplyr::distinct(`_source_column`, .keep_all = TRUE) |>
      dplyr::inner_join(cols, by = c("_source_column" = "source_clean")) |>
      dplyr::transmute(source_header, measurement_type, description, units)
    DBI::dbWriteTable(con, DBI::Id(schema = "work", table = "_scan_column_meta"), as.data.frame(mt), overwrite = TRUE, temporary = FALSE)
    DBI::dbExecute(con, "
      UPDATE ctd.scan_column c SET measurement_type = m.measurement_type, description = coalesce(c.description, m.description), units = coalesce(c.units, m.units)
      FROM work._scan_column_meta m WHERE m.source_header = c.source_header")
    DBI::dbExecute(con, "DROP TABLE work._scan_column_meta")
  }
  DBI::dbExecute(con, "SELECT ctd.refresh_derived()")
  for (q in c("ANALYZE ctd.scan", "ANALYZE ctd.file", "ANALYZE ctd.scan_issue", "ANALYZE ctd.flag")) DBI::dbExecute(con, q)
  DBI::dbGetQuery(con, "
    SELECT (SELECT count(*) FROM ctd.file) AS files, (SELECT count(*) FROM ctd.scan) AS scans, (SELECT count(*) FROM ctd.scan_issue) AS issue_cells,
           (SELECT count(*) FROM ctd.cast) AS casts, (SELECT count(*) FROM ctd.file WHERE is_best_stage) AS best_files,
           pg_size_pretty(pg_total_relation_size('ctd.scan')) AS scan_size")
}
