# cc_netcdf_plan() (libs/publish_netcdf.R): a file whose content the site already records is not
# uploaded again, and a release already published with that content writes nothing.
root <- normalizePath(file.path(testthat::test_path(), "..", ".."))
withr::with_dir(root, source(file.path(root, "libs", "publish_netcdf.R")))

h1 <- strrep("a", 32); h2 <- strrep("b", 32)
nc <- tempfile(fileext = ".nc"); writeLines("bytes", nc)
prior <- list(releases = list(
  list(version = "v2", since = "v2", content_hash = h1, sha256 = "s1",
       canonical_url = "https://e/ds/aaaa/ds.nc", generated_utc = "2026-01-02T00:00:00Z")))

test_that("content the site records is not uploaded again, and its release is published", {
  p <- cc_netcdf_plan(nc, "ds", "v2", h1, prior = prior)
  expect_false(p$upload); expect_true(p$published)
  expect_equal(p$since, "v2"); expect_equal(p$sha256, "s1")
})

test_that("a hash carrying a name still matches the recorded one", {
  # regression 2026-11-26: the notebook's hash column was named by dataset, identical() counted the
  # name, and every run uploaded every file again
  p <- cc_netcdf_plan(nc, "ds", "v2", c(ds = h1), prior = prior)
  expect_false(p$upload); expect_true(p$published)
})

test_that("the same content under a later release is carried, not uploaded", {
  p <- cc_netcdf_plan(nc, "ds", "v3", h1, prior = prior)
  expect_false(p$upload); expect_false(p$published)
  expect_equal(p$identical_to, "v2")
})

test_that("new content is uploaded under its own hash", {
  p <- cc_netcdf_plan(nc, "ds", "v3", h2, prior = prior)
  expect_true(p$upload); expect_false(p$published)
  expect_equal(p$since, "v3")
  expect_match(p$canonical_url, paste0("/ds/", strrep("b", 24), "/ds.nc$"))
})
