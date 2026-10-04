#!/usr/bin/env Rscript
# Dry run of `hex7` on `sample` and `sample_root` (calcofi4db::add_sample_hex7(), 2026-10-02) against a
# PUBLISHED release, without cutting one: builds both tables from the release's own `sample` object in a
# scratch DuckDB, runs the release gate (check_sample_hex7()) against the release's obs_bio / obs_env,
# exports both through the release writer and reports rows, cells per dataset x sample_type, parity
# with the observations' hex7 per dataset, and the size change of each parquet object.
#
#   CALCOFI_STAGE_DIR=/some/private/dir Rscript scripts/dryrun_sample_hex7.R [version]
#
# - every object is resolved through the catalog (cc_catalog() / cc_release_sources()), never a path;
# - CALCOFI_STAGE_DIR must be set to a PRIVATE directory: a release counts every shard it finds under
#   the shared stage (~/_big/calcofi), so a dry run never writes there;
# - CALCOFI4DB_DIR, when set, is a calcofi4db checkout to devtools::load_all() (a branch that is not
#   installed yet); otherwise the installed package is used.
suppressMessages({library(DBI); library(duckdb); library(glue); library(dplyr)})
options(width = 220, scipen = 30)

version <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(version)) version <- "latest"
stage <- Sys.getenv("CALCOFI_STAGE_DIR", "")
stopifnot(
  "set CALCOFI_STAGE_DIR to a private directory for a dry run" = nzchar(stage),
  "CALCOFI_STAGE_DIR must not be the shared stage" =
    normalizePath(stage, mustWork = FALSE) != normalizePath("~/_big/calcofi", mustWork = FALSE))
pkg_dir <- Sys.getenv("CALCOFI4DB_DIR", "")
if (nzchar(pkg_dir)) suppressMessages(devtools::load_all(pkg_dir, quiet = TRUE)) else library(calcofi4db)
stopifnot(exists("add_sample_hex7"), exists("check_sample_hex7"))

catalog <- calcofi4r::cc_catalog(version)
version <- catalog$version
dir_out <- cc_stage_path("hex7_dryrun", version, create = TRUE)
cat(glue("release {version} - scratch {dir_out}\n\n"))

drv <- duckdb::duckdb(file.path(dir_out, "dryrun.duckdb"))
con <- dbConnect(drv)
on.exit({ dbDisconnect(con); duckdb::duckdb_shutdown(drv) }, add = TRUE)
dbExecute(con, "INSTALL httpfs; LOAD httpfs; INSTALL spatial; LOAD spatial;")
q <- function(...) dbGetQuery(con, glue(..., .envir = parent.frame()))   # the CALLER's variables, not q's

# the published objects, as published --------------------------------------------------------------
published <- list()
for (tb in c("sample", "sample_root")) {
  src <- calcofi4r::cc_release_sources(catalog, tb)
  stopifnot(length(src$urls) == 1)
  f <- file.path(dir_out, glue("{tb}_published.parquet"))
  if (!file.exists(f)) utils::download.file(src$urls, f, mode = "wb", quiet = TRUE)
  published[[tb]] <- f
  dbExecute(con, glue("CREATE OR REPLACE TABLE {tb}_published AS SELECT * FROM read_parquet('{f}')"))
}
dbExecute(con, "CREATE OR REPLACE TABLE sample AS SELECT * FROM sample_published")
# the observations' own cells: obs_id, sample, position, hex7 - all a parity check reads
for (tb in c("obs_bio", "obs_env")) {
  if (tb %in% dbListTables(con)) next
  src <- calcofi4r::cc_release_sources(catalog, tb)
  dbExecute(con, glue("CREATE TABLE {tb} AS
    SELECT obs_id, dataset_key, sample_key, root_id, latitude, longitude, hex_id, hex7
    FROM {calcofi4r::cc_read_parquet_sql(src)}"))
}

# the change: stamp sample, carry onto sample_root -------------------------------------------------
add_sample_hex7(con)
build_sample_root(con)

cat("\n== columns: nothing renamed or reordered, hex7 appended\n")
for (tb in c("sample", "sample_root")) {
  a <- dbListFields(con, glue("{tb}_published")); b <- dbListFields(con, tb)
  stopifnot(identical(b, c(a, "hex7")))
  cat(glue("{tb}: {length(a)} published columns + hex7\n\n"))
}
# every published value is unchanged, row for row (EXCEPT both ways, geometry compared as WKB)
for (tb in c("sample", "sample_root")) {
  cols <- paste(ifelse(dbListFields(con, glue("{tb}_published")) == "geom", "ST_AsWKB(geom) AS geom",
                       dbListFields(con, glue("{tb}_published"))), collapse = ", ")
  n_diff <- q("SELECT (SELECT count(*) FROM (SELECT {cols} FROM {tb} EXCEPT ALL SELECT {cols} FROM {tb}_published))
                    + (SELECT count(*) FROM (SELECT {cols} FROM {tb}_published EXCEPT ALL SELECT {cols} FROM {tb})) AS n")$n
  cat(glue("{tb}: {n_diff} row(s) differ from the published table in its own columns\n\n"))
  stopifnot(n_diff == 0)
}

cat("\n== the gate: check_sample_hex7()\n")
ck <- check_sample_hex7(con)
print(as.data.frame(ck))
stopifnot(all(ck$status != "fail"))

cat("\n== hex7 per dataset and sample_type\n")
print(q("
  SELECT s.dataset_key, s.sample_type, count(*) AS n_sample, count(s.hex7) AS n_hex7,
         count(*) FILTER (WHERE s.latitude IS NULL AND s.longitude IS NULL) AS n_no_position,
         count(*) FILTER (WHERE (s.latitude IS NULL) <> (s.longitude IS NULL)) AS n_half_position,
         count(*) FILTER (WHERE s.parent_sample_key IS NULL) AS n_root, count(r.hex7) AS n_root_hex7
  FROM sample s LEFT JOIN sample_root r ON r.root_sample_key = s.sample_key
  GROUP BY ROLLUP (s.dataset_key, s.sample_type) HAVING s.sample_type IS NOT NULL OR s.dataset_key IS NULL
  ORDER BY 1 NULLS LAST, 2"))

cat("\n== parity with the observations' hex7, per dataset (obs_bio + obs_env rows joined to their own sample)\n")
print(q("
  WITH o AS (SELECT * FROM obs_bio UNION ALL SELECT * FROM obs_env)
  SELECT o.dataset_key, count(*) AS n_obs, count(DISTINCT o.sample_key) AS n_sample,
         count(*) FILTER (WHERE o.hex7 IS NOT DISTINCT FROM s.hex7) AS n_same,
         count(*) FILTER (WHERE o.hex7 IS NULL AND s.hex7 IS NULL)  AS n_both_null,
         count(*) FILTER (WHERE o.hex7 IS DISTINCT FROM s.hex7)     AS n_differ,
         count(*) FILTER (WHERE o.latitude = s.latitude AND o.longitude = s.longitude) AS n_same_position,
         count(*) FILTER (WHERE o.latitude = s.latitude AND o.longitude = s.longitude
                            AND o.hex7 IS DISTINCT FROM s.hex7)     AS n_same_position_differ,
         count(DISTINCT o.sample_key) FILTER (WHERE o.hex7 IS DISTINCT FROM s.hex7) AS n_sample_differ
  FROM o JOIN sample s USING (sample_key)
  GROUP BY ROLLUP (o.dataset_key) ORDER BY 1 NULLS LAST"))

# the export: the release writer, the release sort keys ---------------------------------------------
cat("\n== parquet size, written by export_release_parquet() with release_sort_keys()\n")
sk <- release_sort_keys()
size <- bind_rows(lapply(c("sample", "sample_root"), function(tb) {
  # control: the published table re-exported here must reproduce the published object's size, or the
  # delta below would measure this machine's writer rather than the column
  f0 <- file.path(dir_out, glue("{tb}_control.parquet")); f1 <- file.path(dir_out, glue("{tb}.parquet"))
  export_release_parquet(con, glue("{tb}_published"), f0, sk[[tb]]$order_by)
  export_release_parquet(con, tb, f1, sk[[tb]]$order_by)
  tibble(table = tb, rows = q("SELECT count(*) AS n FROM {tb}")$n,
         bytes_published = file.size(published[[tb]]), bytes_control = file.size(f0), bytes_hex7 = file.size(f1))
})) |>
  mutate(delta_bytes = bytes_hex7 - bytes_control, delta_pct = round(100 * delta_bytes / bytes_control, 1),
         control_ok = bytes_control == bytes_published)
print(as.data.frame(size))
