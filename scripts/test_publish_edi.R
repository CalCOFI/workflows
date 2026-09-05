#!/usr/bin/env Rscript
# Unit tests for the pure logic in libs/edi_entities.R (publish_to-edi.qmd's
# helpers) — small synthetic fixtures mirroring the real release shapes
# (datasets.json records, catalog.json table entries, EML document lists), no
# network, no real release read. Run with:
#
#   Rscript scripts/test_publish_edi.R
suppressMessages(librarian::shelf(testthat, glue, digest, tibble, quiet = TRUE))
suppressPackageStartupMessages(
  if (nzchar(Sys.getenv("CALCOFI4DB_DIR"))) {
    devtools::load_all(Sys.getenv("CALCOFI4DB_DIR"), quiet = TRUE)
  } else library(calcofi4db))
source(here::here("libs/edi_entities.R"))

# ---- edi_dataset_record() ---------------------------------------------------

test_that("edi_dataset_record finds by dataset_key, NULL when absent", {
  dj <- list(datasets = list(
    list(dataset_key = "calcofi_bottle", tables = list("sample", "obs")),
    list(dataset_key = "calcofi_mets",   tables = list("sample", "obs"))))
  expect_equal(edi_dataset_record(dj, "calcofi_mets")$dataset_key, "calcofi_mets")
  expect_null(edi_dataset_record(dj, "nope"))
})

# ---- edi_non_interference_check() ------------------------------------------

test_that("a calcofi.org-sourced program dataset is not blocked", {
  rec <- list(links = list(data_source = "https://calcofi.org/downloads/database/x.zip"),
             distributions = list(
               list(kind = "mirror", portal = "erddap-noaa", url = "https://coastwatch/x")))
  chk <- edi_non_interference_check(rec, list(link_data_source = "https://calcofi.org/downloads/database/x.zip"))
  expect_false(chk$blocked)
  expect_length(chk$reasons, 0)
})

test_that("a dataset whose source is itself an EDI/knb-lter-cce package is blocked on link_data_source", {
  sc <- list(link_data_source = "https://portal.edirepository.org/nis/mapbrowse?scope=knb-lter-cce&identifier=313")
  chk <- edi_non_interference_check(list(links = list(), distributions = list()), sc)
  expect_true(chk$blocked)
  expect_match(chk$reasons[1], "edirepository")
})

test_that("a dataset already registered as an EDI archive distribution is blocked even with a non-EDI source link", {
  rec <- list(
    links = list(data_source = "https://example.org/source.csv"),
    distributions = list(
      list(kind = "archive", portal = "edi", id = "edi.109.4", url = "https://portal.edirepository.org/nis/mapbrowse?packageid=edi.109.4")))
  chk <- edi_non_interference_check(rec, NULL)
  expect_true(chk$blocked)
  expect_match(chk$reasons[1], "edi.109.4")
})

test_that("a pasta.lternet.edu link_data_source also blocks (not just the portal UI host)", {
  chk <- edi_non_interference_check(NULL, list(link_data_source = "https://pasta.lternet.edu/package/eml/knb-lter-cce/78/5"))
  expect_true(chk$blocked)
})

# ---- edi_classify_table() ---------------------------------------------------

test_that("a dataset_key-bearing, non-supplemental table classifies as csv", {
  cls <- edi_classify_table("sample", list(name = "sample", supplemental = FALSE, partitioned = FALSE), TRUE)
  expect_equal(cls$class, "csv")
})

test_that("a table with no dataset_key column classifies as other_ref (a shared vocabulary table)", {
  cls <- edi_classify_table("measurement_type", list(name = "measurement_type", supplemental = FALSE), FALSE)
  expect_equal(cls$class, "other_ref")
  expect_match(cls$reason, "vocabulary")
})

test_that("a supplemental table is excluded even when it happens to carry dataset_key", {
  cls <- edi_classify_table("obs_ctd_full",
                            list(name = "obs_ctd_full", supplemental = TRUE, rows = 271394164, bytes = 1365041987),
                            TRUE)
  expect_equal(cls$class, "excluded_supplemental")
  expect_match(cls$reason, "271,394,164")
  expect_match(cls$reason, "GB")
})

# ---- edi_partition_url_for() / edi_table_read_plan() -----------------------

test_that("edi_partition_url_for extracts the right partition among several", {
  urls <- c(
    "https://storage.googleapis.com/calcofi-db/ducklake/tables/obs/dataset_key=calcofi_bottle/abc/data_0.parquet",
    "https://storage.googleapis.com/calcofi-db/ducklake/tables/obs/dataset_key=calcofi_mets/def/data_0.parquet")
  expect_equal(edi_partition_url_for(urls, "calcofi_mets"), urls[2])
  expect_true(is.na(edi_partition_url_for(urls, "calcofi_dic")))
})

test_that("edi_table_read_plan prefers the ready-made partition over a filter", {
  # a minimal catalog.json fixture with one hive-partitioned table, two partitions
  cat_ <- list(version = "vTEST", tables = list(list(
    name = "obs", partitioned = TRUE,
    objects = list(
      list(path = "ducklake/tables/obs/dataset_key=calcofi_bottle/h1/data_0.parquet",
           partition_by = "dataset_key", partition_value = "calcofi_bottle", content_hash = "h1"),
      list(path = "ducklake/tables/obs/dataset_key=calcofi_mets/h2/data_0.parquet",
           partition_by = "dataset_key", partition_value = "calcofi_mets", content_hash = "h2")))))
  plan <- edi_table_read_plan(cat_, "obs", "calcofi_bottle")
  expect_equal(plan$mode, "partition")
  expect_match(plan$url, "dataset_key=calcofi_bottle")
})

test_that("edi_first_object reads the whole-table object's url/bytes/sha256", {
  cat_ <- list(version = "vTEST", tables = list(list(
    name = "measurement_type",
    objects = list(list(path = "ducklake/tables/measurement_type/h/measurement_type.parquet",
                        bytes = 12345, sha256 = "abc123")))))
  o <- edi_first_object(cat_, "measurement_type")
  expect_match(o$url, "^https://storage.googleapis.com/calcofi-db/")
  expect_equal(o$bytes, 12345)
  expect_equal(o$sha256, "abc123")
  expect_null(edi_first_object(cat_, "nope"))
})

test_that("edi_table_read_plan falls back to filter for a non-partitioned shared table", {
  cat_ <- list(version = "vTEST", tables = list(list(
    name = "sample", partitioned = FALSE,
    objects = list(list(path = "ducklake/tables/sample/h/sample.parquet", content_hash = "h")))))
  plan <- edi_table_read_plan(cat_, "sample", "calcofi_bottle")
  expect_equal(plan$mode, "filter")
  expect_match(plan$filter_sql, "calcofi_bottle")
})

# ---- edi_rewrite_datatable_physical() / edi_add_other_entity() -------------

test_that("edi_rewrite_datatable_physical swaps a matching entity's physical to the CSV, leaves others untouched", {
  doc <- list(dataset = list(dataTable = list(
    list(entityName = "sample", physical = list(objectName = "sample.parquet", dataFormat = list(externallyDefinedFormat = list(formatName = "Apache Parquet")))),
    list(entityName = "obs",    physical = list(objectName = "obs.parquet")))))
  out <- edi_rewrite_datatable_physical(doc, "sample", "sample.csv", bytes = 12345, sha256 = "deadbeef",
                                        url = "https://example.org/sample.csv")
  p <- out$dataset$dataTable[[1]]$physical
  expect_equal(p$objectName, "sample.csv")
  expect_equal(p$size$size, "12345")
  expect_equal(p$authentication$authentication, "deadbeef")
  expect_equal(p$dataFormat$textFormat$simpleDelimited$fieldDelimiter, ",")
  expect_equal(p$distribution$online$url, "https://example.org/sample.csv")
  # the other entity is untouched
  expect_equal(out$dataset$dataTable[[2]]$physical$objectName, "obs.parquet")
})

test_that("edi_rewrite_datatable_physical is a no-op when the entity name is absent", {
  doc <- list(dataset = list(dataTable = list(list(entityName = "sample", physical = list()))))
  out <- edi_rewrite_datatable_physical(doc, "nope", "x.csv", 1, "h")
  expect_identical(out, doc)
})

test_that("edi_add_other_entity appends without disturbing existing entities", {
  doc <- list(dataset = list(dataTable = list(list(entityName = "sample"))))
  out <- edi_add_other_entity(doc, "measurement_type", "shared vocabulary table",
                              "measurement_type.parquet", bytes = 999, sha256 = "abc123",
                              url = "https://example.org/measurement_type.parquet")
  expect_length(out$dataset$otherEntity, 1)
  expect_equal(out$dataset$otherEntity[[1]]$entityName, "measurement_type")
  expect_equal(out$dataset$otherEntity[[1]]$physical$authentication$authentication, "abc123")
  expect_length(out$dataset$dataTable, 1) # untouched
})

test_that("edi_note_excluded_table records the reason under additionalMetadata", {
  doc <- list(additionalMetadata = list(metadata = list(calcofi = list(datasetKey = "calcofi_ctd-cast"))))
  out <- edi_note_excluded_table(doc, "obs_ctd_full", "too large")
  expect_equal(out$additionalMetadata$metadata$calcofi$excludedTables$obs_ctd_full, "too large")
  expect_equal(out$additionalMetadata$metadata$calcofi$datasetKey, "calcofi_ctd-cast") # untouched
})

# ---- edi_content_hash() / edi_manifest_row() -------------------------------

test_that("edi_content_hash is order-independent and changes with the input set", {
  h1 <- edi_content_hash(c("b", "a"))
  h2 <- edi_content_hash(c("a", "b"))
  h3 <- edi_content_hash(c("a", "b", "c"))
  expect_equal(h1, h2)
  expect_false(identical(h1, h3))
  expect_true(is.na(edi_content_hash(character())))
})

test_that("edi_manifest_row builds one well-typed row", {
  r <- edi_manifest_row("calcofi_bottle", "v2026.09.05", "hash123", n_csv = 3L, n_other_ref = 1L,
                        n_excluded = 0L, bytes_total = 1e8)
  expect_s3_class(r, "tbl_df")
  expect_equal(r$dataset_key, "calcofi_bottle")
  expect_true(is.na(r$package_id))
  expect_true(is.na(r$evaluated_utc))
})

# ---- edi_has_credentials() ---------------------------------------------------

test_that("edi_has_credentials reports absence and each present form, and restores the environment", {
  old <- Sys.getenv(c("EDI_KEY", "EDI_USER", "EDI_PASS"), unset = NA)
  on.exit(for (n in names(old)) if (is.na(old[n])) Sys.unsetenv(n) else Sys.setenv(!!n := old[[n]]), add = TRUE)

  Sys.unsetenv(c("EDI_KEY", "EDI_USER", "EDI_PASS"))
  expect_false(edi_has_credentials()$available)

  Sys.setenv(EDI_KEY = "k")
  expect_equal(edi_has_credentials(), list(available = TRUE, method = "key"))
  Sys.unsetenv("EDI_KEY")

  Sys.setenv(EDI_USER = "u", EDI_PASS = "p")
  expect_equal(edi_has_credentials(), list(available = TRUE, method = "userpass"))
})

# ---- edi_read_package_registry() / edi_package_id_for() -------------------

test_that("edi_read_package_registry returns an empty typed tibble when the file does not exist", {
  reg <- edi_read_package_registry(tempfile(fileext = ".csv"))
  expect_equal(names(reg), EDI_PACKAGES_COLS)
  expect_equal(nrow(reg), 0)
  expect_true(is.na(edi_package_id_for(reg, "calcofi_bottle")))
})

test_that("edi_read_package_registry / edi_package_id_for round-trip a real file", {
  p <- tempfile(fileext = ".csv")
  on.exit(unlink(p))
  readr::write_csv(tibble::tibble(
    dataset_key = "calcofi_bottle", scope = "edi", identifier = "500", revision = "1",
    env = "production", package_id = "edi.500.1",
    created_utc = "2026-09-05T00:00:00Z", updated_utc = "2026-09-05T00:00:00Z"), p, na = "")
  reg <- edi_read_package_registry(p)
  expect_equal(edi_package_id_for(reg, "calcofi_bottle"), "edi.500.1")
  expect_true(is.na(edi_package_id_for(reg, "calcofi_mets")))
})

cat("\nAll libs/edi_entities.R tests passed.\n")
