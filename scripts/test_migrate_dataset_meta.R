#!/usr/bin/env Rscript
# Unit tests for the pure, file-system-light logic in
# scripts/migrate_dataset_meta.R — a synthetic notebook + expected sidecar
# fixture in a tempdir, exercising the parser/classifier/builder functions
# directly (mdm_migrate_file(write = FALSE) never touches the real repo) plus
# one write = TRUE round-trip into a scratch metadata/ directory. Run with:
#
#   Rscript scripts/test_migrate_dataset_meta.R
#
# migrate_dataset_meta.R is sys.nframe()==0-guarded, so source()-ing it here
# does not run its CLI (which would touch the real repo).
suppressMessages(librarian::shelf(testthat, yaml, glue, here, calcofi4db, quiet = TRUE))
suppressPackageStartupMessages(
  if (nzchar(Sys.getenv("CALCOFI4DB_DIR"))) {
    devtools::load_all(Sys.getenv("CALCOFI4DB_DIR"), quiet = TRUE)
  } else library(calcofi4db))
source(here::here("scripts/migrate_dataset_meta.R"))

# A synthetic ingest notebook exercising every shape seen in the real 16:
# a comment block above a structural key, a comment above a descriptive key,
# a folded `>` block, a quoted scalar, an empty string, a flow-style empty
# list (`link_others: []`), a block-style list, and a DANGLING trailing
# comment (no key below it) at the end of dataset_meta.
fixture_notebook_lines <- function() c(
  '---',
  'title: "Ingest Test Dataset"',
  'calcofi:',
  '  target_name: ingest_test_ds',
  '  workflow_type: ingest',
  '  output: data/parquet/test_ds/manifest.json',
  '  provider: test',
  '  dataset: ds',
  '  dataset_meta:',
  '    dataset_name: Test Dataset',
  '    # display trio comment',
  '    dataset_name_short: Test',
  '    category: Zooplankton',
  '    color: "#123456"',
  '    description: >',
  '      A synthetic dataset',
  '      for testing.',
  '    # source: https://example.org, checked 2026-09-05',
  '    citation_main: "Someone. (2026). Test Dataset."',
  '    link_others: []',
  '    link_more:',
  '      - https://example.org/a',
  '      - https://example.org/b',
  '    # no license stated; left empty',
  '    license: ""',
  '    # coverage_temporal / coverage_spatial deliberately absent: measured at',
  '    # release time, not asserted here.',
  '  tables_owned:',
  '    - {table: sample, shared: true}',
  '---',
  '',
  '## Overview',
  '',
  'Body text unaffected by the migration.')

write_fixture <- function(tmp) {
  qmd <- file.path(tmp, "ingest_test_ds.qmd")
  writeLines(fixture_notebook_lines(), qmd)
  qmd
}

# `link_more` is not a real dataset_meta_descriptive_keys() field, so classify
# against a small allowlist that includes it (stand-in for a hypothetical
# descriptive key with a block list value) alongside the real ones.
DESC_KEYS <- c(calcofi4db::dataset_meta_descriptive_keys(), "link_more")

# mdm_parse_block -------------------------------------------------------------

test_that("mdm_parse_block finds the block bounds and every key in order", {
  lines <- fixture_notebook_lines()
  parsed <- mdm_parse_block(lines)
  expect_false(is.null(parsed))
  expect_equal(vapply(parsed$entries, `[[`, "", "key"),
               c("dataset_name", "dataset_name_short", "category", "color",
                 "description", "citation_main", "link_others", "link_more", "license"))
})

test_that("mdm_parse_block attaches a comment only to the key immediately below it", {
  parsed <- mdm_parse_block(fixture_notebook_lines())
  e <- parsed$entries[[2]]  # dataset_name_short
  expect_equal(e$key, "dataset_name_short")
  expect_true(any(grepl("display trio comment", e$lines)))
  # dataset_name (no comment above it) carries none
  expect_equal(parsed$entries[[1]]$lines, "    dataset_name: Test Dataset")
})

test_that("mdm_parse_block captures a folded block scalar as continuation lines of its key", {
  parsed <- mdm_parse_block(fixture_notebook_lines())
  e <- Filter(function(x) x$key == "description", parsed$entries)[[1]]
  expect_equal(e$lines, c(
    "    description: >",
    "      A synthetic dataset",
    "      for testing."))
})

test_that("mdm_parse_block captures a block list as continuation lines of its key", {
  parsed <- mdm_parse_block(fixture_notebook_lines())
  e <- Filter(function(x) x$key == "link_more", parsed$entries)[[1]]
  expect_equal(e$lines, c(
    "    link_more:",
    "      - https://example.org/a",
    "      - https://example.org/b"))
})

test_that("mdm_parse_block reports the dangling trailing comment separately, not as an entry", {
  parsed <- mdm_parse_block(fixture_notebook_lines())
  expect_true(any(grepl("deliberately absent", parsed$trailing_comment)))
  expect_false(any(vapply(parsed$entries, function(e) any(grepl("deliberately absent", e$lines)), logical(1))))
})

test_that("mdm_parse_block returns NULL when there is no dataset_meta: block", {
  expect_null(mdm_parse_block(c("calcofi:", "  target_name: x", "---")))
})

# mdm_classify / mdm_dedent ---------------------------------------------------

test_that("mdm_classify splits structural vs descriptive and preserves order within each", {
  parsed <- mdm_parse_block(fixture_notebook_lines())
  cls <- mdm_classify(parsed$entries, desc_keys = DESC_KEYS)
  expect_equal(vapply(cls$structural, `[[`, "", "key"),
               c("dataset_name", "dataset_name_short", "category", "color"))
  expect_equal(vapply(cls$descriptive, `[[`, "", "key"),
               c("description", "citation_main", "link_others", "link_more", "license"))
})

test_that("mdm_dedent strips exactly n leading spaces and errors on too little indent", {
  expect_equal(mdm_dedent(c("    a: 1", "      - b"), 2L), c("  a: 1", "    - b"))
  expect_error(mdm_dedent(c("a: 1"), 2L), "cannot dedent")
})

# mdm_build_sidecar / mdm_build_notebook_block --------------------------------

test_that("mdm_build_sidecar carries the header, visibility, and every descriptive entry dedented, verbatim", {
  parsed <- mdm_parse_block(fixture_notebook_lines())
  cls <- mdm_classify(parsed$entries, desc_keys = DESC_KEYS)
  sc <- mdm_build_sidecar("test_ds", cls$descriptive)
  expect_match(sc[1], "^# descriptive metadata for test_ds")
  expect_equal(sc[2], "  visibility: public")
  expect_true("  description: >" %in% sc)
  expect_true("    A synthetic dataset" %in% sc)
  expect_true('  citation_main: "Someone. (2026). Test Dataset."' %in% sc)
  expect_true("  link_others: []" %in% sc)
  expect_true("    - https://example.org/a" %in% sc)
  expect_true('  license: ""' %in% sc)
  # comment travelled with its key, dedented
  expect_true("  # source: https://example.org, checked 2026-09-05" %in% sc)
  # the sidecar text is valid YAML end to end
  expect_no_error(yaml::yaml.load(paste(sc, collapse = "\n")))
  parsed_sc <- yaml::yaml.load(paste(sc, collapse = "\n"))
  expect_equal(parsed_sc$visibility, "public")
  expect_equal(trimws(parsed_sc$description), "A synthetic dataset for testing.")
  expect_equal(parsed_sc$link_others, list())
  expect_equal(unlist(parsed_sc$link_more), c("https://example.org/a", "https://example.org/b"))
})

test_that("mdm_build_notebook_block keeps only structural entries plus the dangling trailing comment", {
  parsed <- mdm_parse_block(fixture_notebook_lines())
  cls <- mdm_classify(parsed$entries, desc_keys = DESC_KEYS)
  nb <- mdm_build_notebook_block(cls$structural, parsed$trailing_comment)
  expect_equal(nb[1], "  dataset_meta:")
  expect_false(any(grepl("^    description", nb)))
  expect_false(any(grepl("^    license", nb)))
  expect_true(any(grepl("deliberately absent", nb)))
  expect_true(any(grepl("dataset_name_short: Test$", nb)))
})

# mdm_read_provider_dataset ----------------------------------------------------

test_that("mdm_read_provider_dataset reads the unquoted scalars", {
  pd <- mdm_read_provider_dataset(fixture_notebook_lines())
  expect_equal(pd, list(provider = "test", dataset = "ds"))
})

# mdm_migrate_file — end-to-end on a real tempdir, including the write=TRUE path ---

test_that("mdm_migrate_file(write=FALSE) never touches disk and reports the moved keys", {
  tmp <- tempfile(); dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))
  qmd <- write_fixture(tmp)
  before_qmd <- readLines(qmd)

  # override dataset_meta_descriptive_keys() for this call via classify's own
  # default arg: mdm_migrate_file always uses calcofi4db's real list, so drive
  # the test through the real descriptive keys already present in the fixture
  r <- mdm_migrate_file(qmd, metadata_dir = file.path(tmp, "metadata"), write = FALSE)

  expect_false(is.null(r))
  expect_equal(r$dataset_key, "test_ds")
  # link_others is a real dataset_meta_descriptive_keys() field; link_more is
  # a fixture-only stand-in and is NOT, so it stays structural
  expect_setequal(r$keys_moved, c("description", "citation_main", "link_others", "license"))
  expect_false(file.exists(file.path(tmp, "metadata", "test", "ds", "dataset_meta.yml")))
  expect_identical(readLines(qmd), before_qmd)  # untouched
})

test_that("mdm_migrate_file(write=TRUE) writes a valid sidecar and a notebook with no descriptive key left", {
  tmp <- tempfile(); dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))
  qmd <- write_fixture(tmp)

  r <- mdm_migrate_file(qmd, metadata_dir = file.path(tmp, "metadata"), write = TRUE)
  expect_true(file.exists(r$sidecar))

  sc <- yaml::yaml.load_file(r$sidecar)
  expect_equal(sc$visibility, "public")
  expect_equal(sc$license, "")
  expect_equal(trimws(sc$citation_main), "Someone. (2026). Test Dataset.")
  expect_equal(sc$link_others, list())

  nb_front <- yaml::yaml.load(paste(readLines(qmd), collapse = "\n"))
  dm <- nb_front$calcofi$dataset_meta
  # link_more is a fixture-only stand-in, not a real descriptive key, so it
  # stays behind in the notebook alongside the structural keys
  expect_setequal(names(dm), c("dataset_name", "dataset_name_short", "category", "color", "link_more"))
  expect_null(dm$description); expect_null(dm$license); expect_null(dm$citation_main)
  expect_null(dm$link_others)
})

test_that("mdm_migrate_file is idempotent: a second write=TRUE run is a no-op that reports already=TRUE", {
  tmp <- tempfile(); dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))
  qmd <- write_fixture(tmp)

  r1 <- mdm_migrate_file(qmd, metadata_dir = file.path(tmp, "metadata"), write = TRUE)
  qmd_after_1 <- readLines(qmd); sidecar_after_1 <- readLines(r1$sidecar)

  r2 <- mdm_migrate_file(qmd, metadata_dir = file.path(tmp, "metadata"), write = TRUE)
  expect_true(isTRUE(r2$already))
  expect_identical(readLines(qmd), qmd_after_1)
  expect_identical(readLines(r1$sidecar), sidecar_after_1)
})

test_that("mdm_migrate_file errors if a sidecar exists but the notebook still carries a descriptive key (two truths)", {
  tmp <- tempfile(); dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))
  qmd <- write_fixture(tmp)
  sc_dir <- file.path(tmp, "metadata", "test", "ds")
  dir.create(sc_dir, recursive = TRUE)
  writeLines(c("visibility: public"), file.path(sc_dir, "dataset_meta.yml"))
  expect_error(mdm_migrate_file(qmd, metadata_dir = file.path(tmp, "metadata"), write = TRUE),
               "still carries descriptive")
})

# real-world regression: every migrated notebook in the repo round-trips clean ---

test_that("every ingest_*.qmd with a dataset_meta block in the repo has a sidecar and no descriptive key left", {
  wd <- here::here()
  qmds <- Sys.glob(file.path(wd, "ingest_*.qmd"))
  qmds <- qmds[vapply(qmds, function(f) any(grepl("^  dataset_meta:\\s*$", readLines(f, warn = FALSE))), logical(1))]
  skip_if(length(qmds) == 0, "no migrated ingest notebooks found")
  for (qmd in qmds) {
    r <- mdm_migrate_file(qmd, metadata_dir = file.path(wd, "metadata"), write = FALSE)
    expect_true(isTRUE(r$already), info = qmd)
  }
  split_check <- calcofi4db::check_dataset_meta_split(wd)
  expect_true(all(split_check$has_sidecar))
  expect_true(all(!nzchar(split_check$descriptive_in_notebook)))
})

cat("\nAll scripts/migrate_dataset_meta.R tests passed.\n")
