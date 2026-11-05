#!/usr/bin/env Rscript
# Unit tests for the pure rules of scripts/sync_preview_tracker.R — no network, no Sheet.
#   Rscript scripts/test_preview_tracker.R
suppressMessages(librarian::shelf(testthat, here, quiet = TRUE))
sys.source(here("scripts/sync_preview_tracker.R"), envir = environment())

pr <- function(number, state, files, url = paste0("https://github.com/CalCOFI/workflows/pull/", number))
  list(number = number, state = state, url = url, title = "", files = lapply(files, function(p) list(path = p)))

test_that("pt_pr_state maps GitHub states to open | merged | closed", {
  expect_equal(pt_pr_state(c("OPEN", "MERGED", "CLOSED", "weird")), c("open", "merged", "closed", NA))
})

test_that("a PR belongs to a dataset by the files it changed, oldest first", {
  prs <- list(
    pr(246, "MERGED", c("RELEASES.md", "ingest_cce-lter_toc.qmd", "ingest_cce-lter_poc-pon.qmd")),
    pr(153, "MERGED", c("ingest_cce-lter_toc.qmd", "metadata/cce-lter/toc/questions.csv")),
    pr(156, "MERGED", c("ingest_cce-lter_poc-pon-cce-region.qmd", "metadata/cce-lter/poc-pon-cce-region/questions.csv")),
    pr(245, "MERGED", c("RELEASES.md", "data/releases/v2026.11.04/test_results.json")),
    pr(155, "OPEN",   c("ingest_cce-lter_chl-size-fractionated.qmd")))
  toc <- pt_prs_for_dataset(prs, "cce-lter_toc", "cce-lter", "toc")
  expect_equal(vapply(toc, `[[`, 1, "number"), c(153, 246))
  # poc-pon must not pick up poc-pon-cce-region (prefix of the metadata folder is exact)
  pp <- pt_prs_for_dataset(prs, "cce-lter_poc-pon", "cce-lter", "poc-pon")
  expect_equal(vapply(pp, `[[`, 1, "number"), 246)
  expect_length(pt_prs_for_dataset(prs, "sio_cetacean-edna", "sio", "cetacean-edna"), 0)
  s <- pt_pr_summary(toc)
  expect_equal(s$prs, "#153 merged; #246 merged")
  expect_equal(s$pr_state, "merged")
  expect_match(s$pr_url, "/pull/153$")
  expect_equal(pt_pr_summary(list())$prs, "")
})

test_that("pt_stage reads the pathway from the columns", {
  expect_equal(pt_stage("open", "", "", "open", 0), "PR open — not yet merged")
  expect_equal(pt_stage("merged", "", "", "open", 0), "merged, held — candidate not yet built")
  expect_equal(pt_stage("merged", "v2026.11.05", "", "open", 0), "candidate built — preview not built")
  expect_equal(pt_stage("merged", "v2026.11.05", "https://preview.calcofi.io/k/t/", "open", 0),
               "preview live — awaiting the provider's decision")
  expect_equal(pt_stage("merged", "v2026.11.05", "https://preview.calcofi.io/k/t/", "open", 1),
               "preview live — decision recorded, not yet pulled")
  expect_equal(pt_stage("merged", "v2026.11.05", "https://preview.calcofi.io/k/t/", "answered", 0),
               "consent given — ready to un-hold")
  expect_equal(pt_stage("closed", "", "", "", 0), "PR closed without merge")
  expect_equal(pt_stage("", "", "", "", 0), "held — no PR found")
})

test_that("notes typed in the Sheet survive a refresh, by dataset_key", {
  new <- data.frame(dataset_key = c("a", "b", "c"), notes = c("", "", ""), stringsAsFactors = FALSE)
  old <- data.frame(dataset_key = c("b", "a"), notes = c("sent to Ralf", NA), stringsAsFactors = FALSE)
  expect_equal(pt_keep_notes(new, old)$notes, c("", "sent to Ralf", ""))
  expect_equal(pt_keep_notes(new, NULL)$notes, c("", "", ""))
})

test_that("the candidate root is the stamped one, else the one named after the dataset", {
  roots <- c("ducklake-preview", "ducklake-preview-ifcb", "ducklake-preview-toc", "ducklake-preview-poc-pon",
             "ducklake-preview-poc-pon-cce")
  stamped <- c("sio_cetacean-sightings" = "ducklake-preview", "sccoos_ifcb-ctd" = "ducklake-preview-ifcb",
               "cce-lter_poc-pon-cce-region" = "ducklake-preview-poc-pon-cce")
  expect_equal(pt_candidate_root("sio_cetacean-sightings", roots, stamped), "ducklake-preview")
  expect_equal(pt_candidate_root("cce-lter_poc-pon-cce-region", roots, stamped), "ducklake-preview-poc-pon-cce")
  expect_equal(pt_candidate_root("cce-lter_toc", roots, stamped), "ducklake-preview-toc")
  expect_equal(pt_candidate_root("cce-lter_poc-pon", roots, stamped), "ducklake-preview-poc-pon")
  # a root stamped with another dataset is never taken by name
  expect_true(is.na(pt_candidate_root("cce-lter_poc-pon", roots, c("x_y" = "ducklake-preview-poc-pon"))))
  expect_true(is.na(pt_candidate_root("cce-lter_chl-size-fractionated", roots, stamped)))
})

test_that("a dataset that exists only in an unmerged PR gets a row, once, by its notebook file", {
  prs <- list(
    pr(154, "OPEN",   c("ingest_swfsc_ctd-noaa.qmd", "metadata/swfsc/ctd-noaa/questions.csv")),
    pr(155, "OPEN",   c("ingest_cce-lter_chl-size-fractionated.qmd")),
    pr(160, "CLOSED", c("ingest_cce-lter_chl-size-fractionated.qmd")),
    pr(153, "MERGED", c("ingest_cce-lter_toc.qmd")),
    pr(243, "OPEN",   c("release_database.qmd")))
  d <- pt_pr_new_datasets(prs, known_keys = c("cce-lter_toc"))
  expect_equal(d$key, c("swfsc_ctd-noaa", "cce-lter_chl-size-fractionated"))
  expect_equal(d$provider, c("swfsc", "cce-lter"))
  expect_equal(d$dataset, c("ctd-noaa", "chl-size-fractionated"))
  expect_equal(d$number, c(154L, 155L))
  expect_equal(nrow(pt_pr_new_datasets(prs, known_keys = c("cce-lter_toc", "swfsc_ctd-noaa", "cce-lter_chl-size-fractionated"))), 0)
})

cat("preview tracker tests passed\n")
