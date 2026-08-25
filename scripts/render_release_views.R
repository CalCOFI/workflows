#!/usr/bin/env Rscript
# Print server/postgis/init/50_release_views.sql with every read_parquet() URL
# re-pointed at the given release THROUGH ITS CATALOG (content-addressed since
# v2026.09), so deploy_consumers.sh can pipe it into psql:
#   Rscript scripts/render_release_views.R v2026.09.01 | ssh calcofi 'sudo docker exec -i postgis psql …'
# The committed file stays pinned to the version it was last authored against;
# the live views always track the promoted release. A table whose URL cannot be
# resolved fails loudly — the old `sed` on the version string matched nothing
# once the path shape changed and left the views silently frozen.
suppressMessages({library(calcofi4r); library(glue)})
args    <- commandArgs(trailingOnly = TRUE)
version <- if (length(args)) args[1] else "latest"
sql_path <- if (length(args) > 1) args[2] else here::here("../server/postgis/init/50_release_views.sql")
cat_ <- cc_catalog(version); version <- cat_$version
sql <- readLines(sql_path, warn = FALSE)
pat <- "read_parquet\\('[^']*/parquet/([A-Za-z0-9_]+)\\.parquet'\\)"
hits <- regmatches(sql, gregexpr(pat, sql))
for (i in seq_along(sql)) for (h in hits[[i]]) {
  tbl <- sub(pat, "\\1", h)
  src <- cc_release_sources(cat_, tbl)
  if (length(src$urls) != 1) stop(glue("{tbl}: expected one object, got {length(src$urls)}"))
  sql[i] <- sub(h, glue("read_parquet('{src$urls}')"), sql[i], fixed = TRUE)
}
sql <- gsub("Release v[0-9.]+ ", glue("Release {version} "), sql)
n <- sum(lengths(hits))
if (n == 0) stop("no read_parquet(...) URLs found to re-point")
cat(sql, sep = "\n")
