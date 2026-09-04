#!/usr/bin/env Rscript
# Inject the calcofi.io brand chrome into already-rendered notebooks.
#
# _quarto.yml includes libs/brand/quarto_head.html (in-header) and
# libs/brand/quarto_header.html (before-body) on every render, so a notebook
# rendered after 2026-08-25 carries the theme, favicon and header natively. The
# ~58 notebooks rendered before that are ingest runs — re-rendering one is an
# hours-long pipeline step, not a stylesheet change — so the Pages workflow runs
# this instead: for each _output/*.html without the `cc-brand v2` marker, insert
# the same two snippets after <head> and after <body …>. Idempotent; a notebook
# that already carries the marker (new render, or a previous injection) is
# untouched, so it is safe to commit the result or to run it only at deploy time.
#
#   Rscript scripts/brand_inject_html.R            # inject in place
#   Rscript scripts/brand_inject_html.R --dry-run  # list what would change

args    <- commandArgs(trailingOnly = TRUE)
dry_run <- "--dry-run" %in% args
wd      <- getwd()
if (!dir.exists(file.path(wd, "_output")))
  stop("run from the workflows/ repo root (no ./_output found)")

marker   <- "cc-brand v2"
# a page rendered between 2026-08-25 and the v2 flip (2026-09-04) carries the v1 chrome;
# its head block (marker comment … </style>) and header (marker … </header>) are swapped
# for the v2 snippets in place — the plan's "swap the URL in already-rendered HTML"
marker_v1 <- "cc-brand v1"
head_snip   <- paste(readLines(file.path(wd, "libs/brand/quarto_head.html"),   warn = FALSE), collapse = "\n")
header_snip <- paste(readLines(file.path(wd, "libs/brand/quarto_header.html"), warn = FALSE), collapse = "\n")

# index.html is the Jekyll landing page (its layout already wears the brand)
htmls <- setdiff(list.files(file.path(wd, "_output"), pattern = "[.]html$", full.names = TRUE),
                 file.path(wd, "_output", "index.html"))

n_done <- 0L
for (f in htmls) {
  x <- readChar(f, file.info(f)$size, useBytes = TRUE)
  Encoding(x) <- "UTF-8"
  if (grepl(marker, x, fixed = TRUE)) next
  # only quarto/bootstrap pages: a stray non-quarto html is left alone
  if (!grepl('name="generator" content="quarto', x, fixed = TRUE)) next
  if (grepl(marker_v1, x, fixed = TRUE)) {
    x <- sub("(?s)<!-- cc-brand v1 \u2014.*?</style>", head_snip, x, perl = TRUE)
    x <- sub("(?s)<!-- cc-brand v1 header.*?</header>", header_snip, x, perl = TRUE)
    if (grepl(marker_v1, x, fixed = TRUE)) { cat("skip (v1 blocks not matched):", basename(f), "\n"); next }
    n_done <- n_done + 1L
    if (dry_run) { cat("would swap v1 -> v2:", basename(f), "\n"); next }
    writeLines(x, f, useBytes = TRUE)
    cat("swapped v1 -> v2:", basename(f), "\n"); next
  }
  if (!grepl("<head>", x, fixed = TRUE) || !grepl("<body[^>]*>", x)) {
    cat("skip (no <head>/<body>):", basename(f), "\n"); next
  }
  x <- sub("<head>", paste0("<head>\n", head_snip, "\n"), x, fixed = TRUE)
  x <- sub("(<body[^>]*>)", paste0("\\1\n", header_snip, "\n"), x)
  n_done <- n_done + 1L
  if (dry_run) { cat("would inject:", basename(f), "\n"); next }
  writeLines(x, f, useBytes = TRUE)
  cat("injected:", basename(f), "\n")
}
cat(sprintf("%s %d of %d notebooks\n", if (dry_run) "would inject" else "injected", n_done, length(htmls)))
