# erddap_splice_config(): the generated block is replaced between its markers, and the id sets it
# returns drive what is flagged for reload on the live server
root <- normalizePath(file.path(testthat::test_path(), "..", ".."))
source(file.path(root, "libs", "erddap_deploy.R"))

splice_fixture <- function(old_ids) {
  repo <- tempfile("erddap_"); dir.create(file.path(repo, "content"), recursive = TRUE)
  blk  <- function(id, body = "a") sprintf('<dataset type="EDDTableFromDatabase" datasetID="%s"><x>%s</x></dataset>', id, body)
  writeLines(c("<erddapDatasets>", blk("hand_made"), ERDDAP_BEGIN,
               vapply(old_ids, blk, ""), ERDDAP_END, "</erddapDatasets>"),
             file.path(repo, "content", "datasets.xml"))
  list(repo = repo, blk = blk)
}

test_that("an added dataset is reported as added, not compared with a block that is not there", {
  # regression 2026-11-26: `ob[[i]]` for an id only in the new config was a subscript out of bounds
  f   <- splice_fixture(c("keep", "edit", "gone"))
  gen <- tempfile(fileext = ".xml")
  writeLines(c(f$blk("keep"), f$blk("edit", "b"), f$blk("new")), gen)
  ids <- erddap_splice_config(f$repo, gen)
  expect_equal(ids$added,   "new")
  expect_equal(ids$changed, "edit")
  expect_equal(ids$retired, "gone")
  expect_equal(ids$all,     c("keep", "edit", "new"))
  expect_equal(ids$kept_outside, "hand_made")
})

test_that("splicing the same config twice changes nothing the second time", {
  f   <- splice_fixture("keep")
  gen <- tempfile(fileext = ".xml"); writeLines(c(f$blk("keep"), f$blk("new")), gen)
  erddap_splice_config(f$repo, gen)
  first <- readLines(file.path(f$repo, "content", "datasets.xml"))
  ids   <- erddap_splice_config(f$repo, gen)
  expect_equal(readLines(file.path(f$repo, "content", "datasets.xml")), first)
  expect_length(c(ids$added, ids$changed, ids$retired), 0)
})
