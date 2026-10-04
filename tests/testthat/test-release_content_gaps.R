# release_content_gaps(): a report of what the released record will publish empty (libs/release_content_gaps.R).
# Run from the repo root: testthat::test_file("tests/testthat/test-release_content_gaps.R")

root <- normalizePath(file.path(testthat::test_path(), "..", ".."))
source(file.path(root, "libs", "release_content_gaps.R"))

# one measurement record per case; `NULL` is what jsonlite gives a registry field the key has no row in
meas <- list(measurements = list(
  list(key = "complete",    face = list(kind = "scale"), why = list(list(rank = 1)), method = list(list(a = 1))),
  list(key = "no_face_key", face = NULL,                 why = list(list(rank = 1)), method = list(list(a = 1))),
  list(key = "no_why_key",  face = list(kind = "none"),  why = NULL,                 method = list(list(a = 1))),
  list(key = "no_method",   face = list(kind = "scale"), why = list(list(rank = 1)), method = NULL)))
ds <- list(datasets = list(
  list(dataset_key = "full",   attribution = list(citation_main = "X (2026).", license = "CC-BY-4.0", doi = "10.1/x")),
  list(dataset_key = "none",   attribution = list(citation_main = NULL, license = NULL, doi = NULL)),
  list(dataset_key = "blanks", attribution = list(citation_main = "", license = " ", doi = NA_character_)),
  list(dataset_key = "doi_only_missing",
       attribution = list(citation_main = "Y (2026).", license = "custom", doi = NULL))))

test_that("a measurement key with no face, no why or no method is listed once per gap", {
  g <- release_content_gaps(measurements = meas, datasets = list(datasets = list()), quiet = TRUE)
  expect_equal(g$key[g$gap == "no_face"],   "no_face_key")
  expect_equal(g$key[g$gap == "no_why"],    "no_why_key")
  expect_equal(g$key[g$gap == "no_method"], "no_method")
  expect_false("complete" %in% g$key)
  expect_equal(nrow(g), 3L)
})

test_that("a dataset is listed for each of citation, licence and DOI it lacks (NULL, empty, blank, NA)", {
  g <- release_content_gaps(measurements = list(measurements = list()), datasets = ds, quiet = TRUE)
  expect_equal(sort(g$key[g$gap == "no_citation"]), c("blanks", "none"))
  expect_equal(sort(g$key[g$gap == "no_license"]),  c("blanks", "none"))
  expect_equal(sort(g$key[g$gap == "no_doi"]),      c("blanks", "doi_only_missing", "none"))
  expect_false("full" %in% g$key)
})

test_that("a clean release returns zero rows and does not stop", {
  clean <- list(measurements = list(meas$measurements[[1]]))
  g <- expect_no_error(release_content_gaps(measurements = clean,
                                            datasets = list(datasets = list(ds$datasets[[1]])), quiet = TRUE))
  expect_equal(nrow(g), 0L)
  expect_named(g, c("kind", "key", "gap", "detail"))
})

test_that("registry_dir lists canonical keys with no face or why, and names a page-less grain", {
  d <- withr::local_tempdir()
  writeLines(c("# comment", "measurement_type,grain,is_canonical",
               "has_both,obs,TRUE", "needs_both,obs,TRUE", "per_cast_key,sample,TRUE", "twin,obs,FALSE"),
             file.path(d, "measurement_type.csv"))
  writeLines(c("# comment", "key,face_kind", "has_both,scale"), file.path(d, "measurement_face.csv"))
  writeLines(c("key,rank", "has_both,1"), file.path(d, "measurement_why.csv"))
  g <- release_content_gaps(measurements = list(measurements = list()), datasets = list(datasets = list()),
                            registry_dir = d, quiet = TRUE)
  expect_setequal(g$key[g$kind == "registry"], c("needs_both", "per_cast_key"))
  expect_false("twin" %in% g$key)
  expect_match(g$detail[g$key == "per_cast_key"][1], "no /measurements/ page")
  expect_equal(g$detail[g$key == "needs_both"][1], "")
})
