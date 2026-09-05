#!/usr/bin/env Rscript
# One-off, idempotent migration (plan 2026-09-05 CalCOFI.io dataset catalog,
# WS-R2, D-9 / Decision 14): moves the DESCRIPTIVE keys out of each
# ingest_*.qmd's `calcofi.dataset_meta` YAML block into a sidecar,
# metadata/{provider}/{dataset}/dataset_meta.yml, that a Google Sheet can
# round-trip (scripts/sync_dataset_meta_sheets.R). The STRUCTURAL keys
# (dataset_name, dataset_name_short, category, color, tables, in_release —
# calcofi4db::dataset_meta_structural_keys()) stay in the notebook.
#
#   Rscript scripts/migrate_dataset_meta.R
#
# A second run is a no-op: a dataset whose sidecar already exists and whose
# notebook already carries only structural keys is reported "already migrated"
# and neither file is touched.
#
# The comment lines that sit immediately above a key (no blank line between)
# are its evidence trail (`# source: <url>, checked <date>`, license notes,
# ...) and travel WITH that key, verbatim, dedented from 4 to 2 spaces — never
# re-serialized through yaml::write_yaml(), which drops comments and re-flows
# strings. A comment block with no key below it (calcofi_ctd-cast's trailing
# note on why coverage_temporal/coverage_spatial are absent) has nothing to
# travel with, so it stays in the notebook untouched, exactly where it was.
#
# The gate: calcofi4db::ingest_yaml_to_dataset_df(calcofi4db::read_ingest_yaml(here()))
# must return something all.equal() to what it returned before the migration —
# a byte-identical round-trip of every value — and
# calcofi4db::check_dataset_meta_split(here()) must find no descriptive key
# left in any notebook. Both run at the end of this script and stop() on any
# difference.
suppressMessages(librarian::shelf(yaml, here, glue, quiet = TRUE))
suppressPackageStartupMessages(
  if (nzchar(Sys.getenv("CALCOFI4DB_DIR"))) {
    devtools::load_all(Sys.getenv("CALCOFI4DB_DIR"), quiet = TRUE)
  } else library(calcofi4db))

WD <- here::here()

#' cat() a glue()d line with its newline intact. glue::glue() trims trailing
#' whitespace/newlines by default (.trim = TRUE), so `cat(glue::glue("...\n"))`
#' silently drops the line break (see scripts/sync_questions_sheets.R's qcat()).
mcat <- function(..., .envir = parent.frame())
  cat(glue::glue(..., .envir = .envir), "\n", sep = "")

# pure / testable ------------------------------------------------------------
# unit-tested in scripts/test_migrate_dataset_meta.R without touching a real notebook

#' Locate the `  dataset_meta:` block inside an ingest .qmd's `calcofi:` front
#' matter and split its lines into the ordered list of top-level (4-space
#' indent) key "entries" — comment lines immediately above a key travel with
#' it — plus any trailing dangling comment (a note with no key of its own),
#' which is reported separately and left where it was.
#'
#' @return NULL if the file has no `dataset_meta:` block, else
#'   list(dm_line=, end_line=, entries=list(list(key=,lines=), ...), trailing_comment=)
mdm_parse_block <- function(lines) {
  dm_i <- which(grepl("^  dataset_meta:\\s*$", lines))
  if (!length(dm_i)) return(NULL)
  dm_i <- dm_i[1]
  n <- length(lines)
  end_i <- n
  for (i in seq(dm_i + 1L, n)) {
    if (grepl("^---\\s*$", lines[i]) || grepl("^  \\S", lines[i])) { end_i <- i - 1L; break }
  }
  block <- if (end_i >= dm_i + 1L) lines[seq(dm_i + 1L, end_i)] else character(0)

  entries <- list()
  pending <- character(0)
  i <- 1L; nb <- length(block)
  while (i <= nb) {
    ln <- block[i]
    if (grepl("^    [A-Za-z_][A-Za-z0-9_]*:", ln)) {
      key  <- sub("^    ([A-Za-z_][A-Za-z0-9_]*):.*$", "\\1", ln)
      full <- c(pending, ln)
      pending <- character(0)
      i <- i + 1L
      while (i <= nb && grepl("^ {5,}\\S", block[i])) { full <- c(full, block[i]); i <- i + 1L }
      entries[[length(entries) + 1L]] <- list(key = key, lines = full)
    } else if (grepl("^    #", ln)) {
      pending <- c(pending, ln); i <- i + 1L
    } else if (!nzchar(trimws(ln))) {
      i <- i + 1L  # a stray blank line between entries — none observed, dropped defensively
    } else {
      stop("mdm_parse_block: unrecognized line in dataset_meta block: '", ln, "'", call. = FALSE)
    }
  }
  list(dm_line = dm_i, end_line = end_i, entries = entries, trailing_comment = pending)
}

#' Split parsed entries into structural (kept in the notebook) and descriptive
#' (moved to the sidecar), preserving each bucket's original relative order.
mdm_classify <- function(entries, desc_keys = calcofi4db::dataset_meta_descriptive_keys()) {
  is_desc <- vapply(entries, function(e) e$key %in% desc_keys, logical(1))
  list(structural = entries[!is_desc], descriptive = entries[is_desc])
}

#' Dedent every line in `x` by exactly `n` leading spaces.
mdm_dedent <- function(x, n = 2L) {
  vapply(x, function(ln) {
    lead <- nchar(regmatches(ln, regexpr("^ *", ln)))
    if (lead < n) stop("cannot dedent by ", n, " spaces: '", ln, "'", call. = FALSE)
    substring(ln, n + 1L)
  }, character(1), USE.NAMES = FALSE)
}

#' The sidecar file's full text for one dataset (character vector of lines,
#' one string per line, no trailing newline needed — writeLines adds it).
mdm_build_sidecar <- function(dataset_key, descriptive_entries) {
  header <- paste0(
    "# descriptive metadata for ", dataset_key, " -- provider-editable ",
    "(Google Sheet tab `metadata`, scripts/sync_dataset_meta_sheets.R); ",
    "the structural keys stay in ingest_", dataset_key, ".qmd")
  body <- unlist(lapply(descriptive_entries, function(e) mdm_dedent(e$lines, 2L)))
  c(header, "  visibility: public", body)
}

#' The notebook's replacement `dataset_meta:` block — unchanged indentation,
#' only the descriptive entries removed.
mdm_build_notebook_block <- function(structural_entries, trailing_comment) {
  c("  dataset_meta:", unlist(lapply(structural_entries, function(e) e$lines)), trailing_comment)
}

#' provider: / dataset: values from a `calcofi:` block's own top-level lines
#' (unquoted scalars only — the only form any ingest notebook uses today).
mdm_read_provider_dataset <- function(lines) {
  pline <- grep("^  provider:\\s*\\S", lines, value = TRUE)
  dline <- grep("^  dataset:\\s*\\S",  lines, value = TRUE)
  if (!length(pline) || !length(dline))
    stop("could not find provider:/dataset: lines", call. = FALSE)
  list(provider = trimws(sub("^  provider:\\s*", "", pline[1])),
       dataset  = trimws(sub("^  dataset:\\s*",  "", dline[1])))
}

#' Migrate one ingest .qmd in place, writing its sidecar. Returns a one-row
#' summary list, or errors on an inconsistent already-migrated state.
mdm_migrate_file <- function(qmd_path, metadata_dir, write = TRUE) {
  lines  <- readLines(qmd_path, warn = FALSE)
  parsed <- mdm_parse_block(lines)
  if (is.null(parsed)) return(NULL)

  pd <- mdm_read_provider_dataset(lines)
  dataset_key <- paste0(pd$provider, "_", pd$dataset)

  sc_dir  <- file.path(metadata_dir, pd$provider, pd$dataset)
  sc_path <- file.path(sc_dir, "dataset_meta.yml")

  cls <- mdm_classify(parsed$entries)

  if (file.exists(sc_path)) {
    if (!length(cls$descriptive))
      return(list(dataset_key = dataset_key, qmd = basename(qmd_path), sidecar = sc_path,
                  keys_moved = character(0), already = TRUE))
    stop(qmd_path, ": sidecar already exists at ", sc_path,
         " but the notebook still carries descriptive key(s): ",
         paste(vapply(cls$descriptive, `[[`, "", "key"), collapse = ", "), call. = FALSE)
  }
  if (!length(cls$descriptive))
    stop(qmd_path, ": no descriptive dataset_meta key found to migrate", call. = FALSE)

  sidecar_lines <- mdm_build_sidecar(dataset_key, cls$descriptive)
  new_block     <- mdm_build_notebook_block(cls$structural, parsed$trailing_comment)
  new_lines     <- c(lines[seq_len(parsed$dm_line - 1L)], new_block,
                     lines[seq(parsed$end_line + 1L, length(lines))])

  if (isTRUE(write)) {
    dir.create(sc_dir, recursive = TRUE, showWarnings = FALSE)
    writeLines(sidecar_lines, sc_path)
    writeLines(new_lines, qmd_path)
  }

  list(dataset_key = dataset_key, qmd = basename(qmd_path), sidecar = sc_path,
       keys_moved = vapply(cls$descriptive, `[[`, "", "key"), already = FALSE,
       sidecar_lines = sidecar_lines, notebook_lines = new_lines)
}

# orchestration ---------------------------------------------------------------

.main <- function() {
  qmds <- sort(Sys.glob(file.path(WD, "ingest_*.qmd")))
  qmds <- qmds[vapply(qmds, function(f) any(grepl("^  dataset_meta:\\s*$", readLines(f, warn = FALSE))), logical(1))]
  cat(length(qmds), "ingest notebook(s) with a calcofi.dataset_meta block\n\n")

  # snapshot before ------------------------------------------------------------
  before <- calcofi4db::ingest_yaml_to_dataset_df(calcofi4db::read_ingest_yaml(WD))
  snap <- tempfile(fileext = ".rds")
  saveRDS(before, snap)
  cat("snapshotted ingest_yaml_to_dataset_df() (", nrow(before), " row(s)) -> ", snap, "\n\n", sep = "")

  n_migrated <- 0L; n_already <- 0L
  for (qmd in qmds) {
    r <- mdm_migrate_file(qmd, metadata_dir = file.path(WD, "metadata"))
    if (is.null(r)) next
    if (isTRUE(r$already)) {
      mcat("{r$dataset_key} ({r$qmd}): already migrated, no-op")
      n_already <- n_already + 1L
    } else {
      mcat("{r$dataset_key} ({r$qmd}): moved {length(r$keys_moved)} key(s) -> {sub(paste0(WD, '/'), '', r$sidecar, fixed = TRUE)}")
      cat("  ", paste(r$keys_moved, collapse = ", "), "\n", sep = "")
      n_migrated <- n_migrated + 1L
    }
  }
  mcat("\n{n_migrated} notebook(s) migrated, {n_already} already migrated.")

  # gate ------------------------------------------------------------------------
  after <- calcofi4db::ingest_yaml_to_dataset_df(calcofi4db::read_ingest_yaml(WD))
  cmp <- all.equal(before, after)
  if (!isTRUE(cmp))
    stop("GATE 1 FAILED: ingest_yaml_to_dataset_df(read_ingest_yaml(here())) differs before/after:\n",
         paste(cmp, collapse = "\n"), call. = FALSE)
  cat("GATE 1 passed: ingest_yaml_to_dataset_df(read_ingest_yaml(here())) is identical before/after (all.equal, every cell).\n")

  split_check <- calcofi4db::check_dataset_meta_split(WD)
  cat("GATE 2 passed: check_dataset_meta_split() found no descriptive key left in any notebook.\n")
  print(as.data.frame(split_check), row.names = FALSE)

  invisible(list(before = before, after = after, split_check = split_check))
}

if (sys.nframe() == 0) .main()
