#!/usr/bin/env Rscript
# Warm metadata/taxon_common.csv — the vernacular (common) name registry — from
# every taxon in the current release.
#
# `common_name` only ever reached the release from a dataset's OWN vocabulary
# (the ichthyo species list, the bird/mammal list), so every taxon resolved
# through measurement_taxon.csv / taxon_override.csv arrived with none: 57% of
# the release's taxa at v2026.08.14, including worms:440388 Metacarcinus
# magister, whose missing "Dungeness crab" surfaced this.
#
# WHAT THIS SCRIPT DOES NOT DO IS CHOOSE. WoRMS returns English vernaculars as an
# unordered bag with no preferred-name flag, so a taxon with more than one is
# written with `common_name` EMPTY and every candidate in `candidates_en`, for a
# human to pick by editing the cell. One candidate is taken automatically,
# because that is not a choice. See ensure_taxon_common().
#
# Reviewable, committed registry like taxon_xref.csv / taxon_lineage.csv: a
# re-run only fetches what is missing and NEVER overwrites a hand-picked name, so
# this is a one-time cost. Safe to delete (it refetches, slowly).
#
#   Rscript scripts/warm_taxon_common.R [sleep_seconds]

librarian::shelf(dplyr, glue, here, calcofi/calcofi4db, quiet = T)

args      <- commandArgs(trailingOnly = TRUE)
sleep     <- if (length(args)) as.numeric(args[1]) else 0.15
cache_csv <- here("metadata/taxon_common.csv")

# Resolve the version from the AUTHORITATIVE GCS latest.txt — the same file
# calcofi4r, db-query and libs/publish_netcdf.R read. Never a local copy: an
# in-repo pointer drifted six months behind here once and quietly under-warmed
# the xref cache without erroring (see warm_taxon_xref.R).
rel <- trimws(readLines(
  "https://storage.googleapis.com/calcofi-db/ducklake/releases/latest.txt",
  warn = FALSE))
cat(glue("release: {rel}"), "\n")

con <- calcofi4db::get_duckdb_con(":memory:")
on.exit(calcofi4db::close_duckdb(con))
DBI::dbExecute(con, "INSTALL httpfs; LOAD httpfs;")

taxa <- DBI::dbGetQuery(con, glue(
  "SELECT taxon_key, scientific_name, worms_id, common_name
   FROM read_parquet('https://storage.googleapis.com/calcofi-db/ducklake/releases/{rel}/parquet/taxon.parquet')"))

# Only ask about taxa that need a name AND have a WoRMS id to ask with. A taxon
# that already carries its provider's own common name is left alone: that is the
# name they publish, and second-guessing it would rename their data under them.
need <- taxa |>
  filter(is.na(common_name) | common_name == "", !is.na(worms_id))
cat(glue("{nrow(taxa)} taxa in release; {sum(!is.na(taxa$common_name) & taxa$common_name != '')} ",
         "already named by their own dataset; {nrow(need)} to query"), "\n")

ensure_taxon_common(need, cache_csv = cache_csv, sleep = sleep, verbose = TRUE)

d <- read_taxon_common(cache_csv)
pending <- d |> filter(n_candidates_en > 1, is.na(common_name) | common_name == "")
cat(glue("\nregistry: {nrow(d)} rows, ",
         "{sum(!is.na(d$common_name) & d$common_name != '')} named, ",
         "{nrow(pending)} awaiting a choice"), "\n")
if (nrow(pending))
  cat("\nEdit `common_name` in metadata/taxon_common.csv for these, e.g.:\n",
      paste0("  ", head(pending$taxon_key, 5), "  ", head(pending$scientific_name, 5),
             "  [", head(pending$candidates_en, 5), "]", collapse = "\n"), "\n")
