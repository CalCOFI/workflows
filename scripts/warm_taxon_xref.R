#!/usr/bin/env Rscript
# Warm metadata/taxon_xref.csv from the ids the release and the local shards
# already carry, so the ingests run offline.
#
# The cache is a reviewable, committed registry exactly like taxon_lineage.csv:
# `calcofi4db::fetch_taxon_xref()` skips anything already in it, so this script
# is a one-time cost and every later ingest re-run is free. Safe to delete (it
# refetches, slowly) and safe to re-run (it only fetches what is missing).
#
#   Rscript scripts/warm_taxon_xref.R [sleep_seconds]

librarian::shelf(dplyr, glue, here, readr, calcofi/calcofi4db, quiet = T)

# NB: `args[1] %||% 0.15` would NOT work — subsetting an empty character vector
# yields NA, not NULL, and `%||%` only catches NULL
args      <- commandArgs(trailingOnly = TRUE)
sleep     <- if (length(args)) as.numeric(args[1]) else 0.15
cache_csv <- here("metadata/taxon_xref.csv")

# every authority id reachable from the current release + every local shard, so
# a dataset held out of the release (cdfw_dungeness-crab) is warmed too
con <- calcofi4db::get_duckdb_con(":memory:")
on.exit(calcofi4db::close_duckdb(con))

ids <- DBI::dbGetQuery(con, glue("
  WITH t AS (
    SELECT * FROM '{here('data/releases/v2026.08.04/parquet/taxon.parquet')}'
    UNION ALL BY NAME
    SELECT * FROM '{here('data/parquet/*/taxon.parquet')}'
  )
  SELECT DISTINCT
    CASE WHEN taxon_key LIKE 'itis:%'  THEN 'tsn'
         WHEN taxon_key LIKE 'worms:%' THEN 'aphia' ELSE 'name' END AS qt,
    CASE WHEN taxon_key LIKE 'itis:%'  THEN CAST(itis_id  AS VARCHAR)
         WHEN taxon_key LIKE 'worms:%' THEN CAST(worms_id AS VARCHAR)
         ELSE scientific_name END AS qv
  FROM t
  WHERE COALESCE(itis_id, worms_id) IS NOT NULL OR scientific_name IS NOT NULL"))

cat(glue("warming taxon xref: {sum(ids$qt == 'tsn')} TSN + ",
         "{sum(ids$qt == 'aphia')} AphiaID + {sum(ids$qt == 'name')} name\n\n"))

x <- fetch_taxon_xref(
  itis_ids  = as.integer(ids$qv[ids$qt == "tsn"]),
  worms_ids = as.integer(ids$qv[ids$qt == "aphia"]),
  names     = ids$qv[ids$qt == "name"],
  cache_csv = cache_csv, sleep = sleep, verbose = TRUE)

cat(glue(
  "\ndone: {nrow(x)} rows; {sum(!is.na(x$worms_id))} with worms_id, ",
  "{sum(!is.na(x$itis_id))} with itis_id, ",
  "{sum(x$query_type == 'tsn' & !is.na(x$itis_id) & x$query_value != as.character(x$itis_id))}",
  " TSN(s) re-keyed onto an accepted id\n"))
cat(glue("status: {paste(names(table(x$status)), table(x$status), sep = '=', collapse = ', ')}\n"))
