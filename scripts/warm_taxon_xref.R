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

# The release's taxon shard stages outside the repo, and the version is resolved
# from the AUTHORITATIVE GCS `latest.txt` — the same file calcofi4r, db-query and
# libs/publish_netcdf.R read.
#
# This previously read an in-repo `data/releases/latest.txt`. That file was last
# written in 2026-02 and had drifted six months behind the real `latest.txt`, so
# the script resolved to v2026.02 and warmed the cache from a release predating
# most of the taxa in it. It did not error — the old shard is still staged — it
# just quietly under-warmed, and every ingest then paid live WoRMS/ITIS calls for
# taxa the current release already knew. A stale pointer that still resolves is
# worse than one that breaks. The file is deleted; do not reintroduce a local copy.
RELEASES_URL <- "https://storage.googleapis.com/calcofi-db/ducklake/releases"
release <- trimws(readLines(glue("{RELEASES_URL}/latest.txt"), warn = FALSE)[1])
stopifnot("could not resolve latest release from GCS" =
            grepl("^v[0-9]{4}[.][0-9]{2}", release))
release_taxon <- calcofi4db::cc_stage_path(
  "releases", release, "parquet", "taxon.parquet")

# The promoted release is not always staged on this machine (a fresh clone, or a
# release cut elsewhere). Fall back to the newest local one rather than failing:
# this script only harvests ids, so an older shard is a smaller warm, not a wrong
# one — but say which was used, because a silent fallback is how the stale
# pointer went unnoticed for six months.
if (!file.exists(release_taxon)) {
  staged <- sort(basename(Sys.glob(calcofi4db::cc_stage_path("releases", "v*"))))
  staged <- staged[file.exists(calcofi4db::cc_stage_path(
    "releases", staged, "parquet", "taxon.parquet"))]
  if (!length(staged))
    stop("no staged release carries parquet/taxon.parquet; stage ", release,
         " or run release_database.qmd first")
  cat(glue("{release} is not staged locally; falling back to ",
           "{tail(staged, 1)}"), "\n")
  release       <- tail(staged, 1)
  release_taxon <- calcofi4db::cc_stage_path(
    "releases", release, "parquet", "taxon.parquet")
}
cat(glue("warming from release {release}"), "\n")

ids <- DBI::dbGetQuery(con, glue("
  WITH t AS (
    SELECT * FROM '{release_taxon}'
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
