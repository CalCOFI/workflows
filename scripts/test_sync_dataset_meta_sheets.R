#!/usr/bin/env Rscript
# Unit tests for the pure, network-free logic in
# scripts/sync_dataset_meta_sheets.R — mirrors scripts/test_sync_questions_sheets.R:
# pure functions only, a fake sheet as a data.frame rather than a live Google
# Sheet. Run with:
#
#   Rscript scripts/test_sync_dataset_meta_sheets.R
#
# sync_dataset_meta_sheets.R is sys.nframe()==0-guarded, so source()-ing it
# here does not run its CLI / touch the network.
suppressMessages(librarian::shelf(testthat, yaml, readr, glue, here, calcofi4db, quiet = TRUE))
suppressPackageStartupMessages(
  if (nzchar(Sys.getenv("CALCOFI4DB_DIR"))) {
    devtools::load_all(Sys.getenv("CALCOFI4DB_DIR"), quiet = TRUE)
  } else library(calcofi4db))
source(here::here("scripts/sync_dataset_meta_sheets.R"))

# dm_editable_cols / dm_measured_fields ---------------------------------------

test_that("dm_editable_cols is the three-column contract", {
  expect_equal(dm_editable_cols(), c("value", "edited_by", "edited_date"))
})

test_that("dm_measured_fields matches the brief's six read-only context fields", {
  expect_equal(dm_measured_fields(),
               c("coverage_temporal_observed", "coverage_spatial_observed",
                 "source_accessed", "n_obs", "year_min", "year_max"))
})

# dm_provider_needs_sheet — the create-vs-skip decision -------------------------

test_that("dm_provider_needs_sheet is TRUE for a provider with no entry at all", {
  expect_true(dm_provider_needs_sheet(NULL))
})

test_that("dm_provider_needs_sheet is TRUE for an entry with a NULL or blank sheet_id (sccoos's shape)", {
  expect_true(dm_provider_needs_sheet(list(sheet_id = NULL, url = NULL, created = NULL)))
  expect_true(dm_provider_needs_sheet(list(sheet_id = "")))
})

test_that("dm_provider_needs_sheet is FALSE once a sheet_id is on file", {
  expect_false(dm_provider_needs_sheet(list(sheet_id = "1AbCdEf")))
})

# dm_read_fields_csv -----------------------------------------------------------

test_that("dm_read_fields_csv sorts required -> recommended -> optional and coerces editable to logical", {
  d <- dm_read_fields_csv()
  expect_true(is.logical(d$editable))
  tiers <- factor(d$importance, levels = c("required", "recommended", "optional"), ordered = TRUE)
  expect_false(is.unsorted(tiers))
  expect_true("license" %in% d$field[d$importance == "required"])
  expect_true(all(!d$editable[d$field %in% dm_measured_fields()]))
})

# YAML scalar quoting -----------------------------------------------------------

test_that("dm_yaml_plain_safe / dm_yaml_scalar reproduce real-world unquoted and quoted forms", {
  expect_true(dm_yaml_plain_safe("CC-BY-4.0"))
  expect_true(dm_yaml_plain_safe("https://calcofi.org/data/x"))       # colon not followed by space
  expect_false(dm_yaml_plain_safe("Keeling, C.D.: a title"))          # ": " forces quoting
  expect_false(dm_yaml_plain_safe(""))
  expect_false(dm_yaml_plain_safe("true"))

  expect_equal(dm_yaml_scalar("CC-BY-4.0"), "CC-BY-4.0")
  expect_equal(dm_yaml_scalar(""), '""')
  # a value with an embedded quote round-trips through yaml.load to itself
  expect_equal(yaml::yaml.load(dm_yaml_scalar_line("k", 'He said "hi"'))$k, 'He said "hi"')

  # round-trips through yaml.load for a battery of realistic values
  for (v in c("CC-BY-4.0", "", "Todd Martz; Aaron Mau", "https://calcofi.org/x",
              'CalCOFI. (2023). CalCOFI Bottle Database.', "a: b")) {
    line <- dm_yaml_scalar_line("k", v)
    got <- yaml::yaml.load(line)$k
    expect_equal(got, v, info = v)
  }
})

# header/body split + kv-block parse -------------------------------------------

test_that("dm_split_header separates the col-0 header comment from the indent-2 body", {
  lines <- c("# descriptive metadata for x_y", "  visibility: public", "  license: CC-BY-4.0")
  s <- dm_split_header(lines)
  expect_equal(s$header, "# descriptive metadata for x_y")
  expect_equal(s$body, c("  visibility: public", "  license: CC-BY-4.0"))
})

test_that("dm_parse_kv_block attaches a comment to the key immediately below it and captures a folded block", {
  body <- c(
    "  visibility: public",
    "  description: >",
    "    line one",
    "    line two",
    "  # source: https://x, checked 2026-09-05",
    "  license: CC-BY-4.0")
  p <- dm_parse_kv_block(body, indent = 2L)
  expect_equal(vapply(p$entries, `[[`, "", "key"), c("visibility", "description", "license"))
  lic <- Filter(function(e) e$key == "license", p$entries)[[1]]
  expect_equal(lic$lines, c("  # source: https://x, checked 2026-09-05", "  license: CC-BY-4.0"))
  desc <- Filter(function(e) e$key == "description", p$entries)[[1]]
  expect_equal(desc$lines, c("  description: >", "    line one", "    line two"))
})

# dm_replace_entry_value -------------------------------------------------------

test_that("dm_replace_entry_value keeps the comment and re-uses a scalar style", {
  entries <- dm_parse_kv_block(c("  # a note", "  license: CC-BY-4.0"), 2L)$entries
  out <- dm_replace_entry_value(entries, "license", "CC0-1.0")
  e <- out[[1]]
  expect_equal(e$lines, c("  # a note", "  license: CC0-1.0"))
})

test_that("dm_replace_entry_value keeps a folded block folded, re-flowing the new value", {
  entries <- dm_parse_kv_block(c("  description: >", "    old text", "    more old text"), 2L)$entries
  out <- dm_replace_entry_value(entries, "description", "brand new\ntwo lines")
  expect_equal(out[[1]]$lines, c("  description: >", "    brand new", "    two lines"))
})

test_that("dm_replace_entry_value appends a fresh field with no prior entry", {
  out <- dm_replace_entry_value(list(), "contact", "data@calcofi.io")
  expect_equal(out[[1]], list(key = "contact", lines = "  contact: data@calcofi.io"))
})

# dm_set_edited -----------------------------------------------------------------

test_that("dm_set_edited creates then merges the edited: map without disturbing other keys", {
  entries <- list(list(key = "license", lines = "  license: CC-BY-4.0"))
  e1 <- dm_set_edited(entries, list(license = list(by = "Jane", date = "2026-09-05")))
  txt1 <- paste(dm_dedent(Filter(function(x) x$key == "edited", e1)[[1]]$lines, 2L), collapse = "\n")
  expect_equal(yaml::yaml.load(txt1)$edited$license$by, "Jane")

  e2 <- dm_set_edited(e1, list(contact = list(by = "Bob", date = "2026-09-06")))
  txt2 <- paste(dm_dedent(Filter(function(x) x$key == "edited", e2)[[1]]$lines, 2L), collapse = "\n")
  parsed2 <- yaml::yaml.load(txt2)$edited
  expect_equal(parsed2$license$by, "Jane")   # earlier edit preserved
  expect_equal(parsed2$contact$by, "Bob")
  expect_equal(sum(vapply(e2, function(x) x$key == "license", logical(1))), 1)  # untouched, still present once
})

# dm_validate_field -------------------------------------------------------------

test_that("dm_validate_field refuses a license outside the registry", {
  v <- dm_validate_field("license", "CC-BY-9.9", licenses = c("CC-BY-4.0", "CC0-1.0"))
  expect_false(v$ok)
  expect_match(v$msg, "not an active id")
})

test_that("dm_validate_field accepts a license in the registry", {
  expect_true(dm_validate_field("license", "CC-BY-4.0", licenses = c("CC-BY-4.0", "CC0-1.0"))$ok)
})

test_that("dm_validate_field refuses a contact that is neither an email nor a URL", {
  v <- dm_validate_field("contact", "just some text")
  expect_false(v$ok)
  expect_match(v$msg, "neither an email nor a URL")
})

test_that("dm_validate_field accepts an email or a URL contact", {
  expect_true(dm_validate_field("contact", "data@calcofi.io")$ok)
  expect_true(dm_validate_field("contact", "https://calcofi.org/contact")$ok)
})

test_that("dm_validate_field enforces a bare DOI", {
  expect_true(dm_validate_field("doi", "10.25921/3w9f-jd72")$ok)
  expect_false(dm_validate_field("doi", "https://doi.org/10.25921/3w9f-jd72")$ok)
  expect_false(dm_validate_field("doi", "not-a-doi")$ok)
})

test_that("dm_validate_field parses creators lines and requires a name", {
  ok <- dm_validate_field("creators", "Todd Martz · SIO · 0000-0001-2345-6789 · tmartz@ucsd.edu")
  expect_true(ok$ok)
  bad <- dm_validate_field("creators", " · SIO · · ")
  expect_false(bad$ok)
})

test_that("dm_validate_field is a no-op on an empty value", {
  expect_true(dm_validate_field("license", "")$ok)
  expect_true(dm_validate_field("doi", "")$ok)
})

# dm_parse_people ----------------------------------------------------------------

test_that("dm_parse_people splits on the middle dot and drops blank lines", {
  p <- dm_parse_people("Todd Martz · SIO · 0000-0001-2345-6789 · tmartz@ucsd.edu\n\nAaron Mau · SIO · · ")
  expect_length(p, 2)
  expect_equal(p[[1]]$name, "Todd Martz"); expect_equal(p[[1]]$email, "tmartz@ucsd.edu")
  expect_equal(p[[2]]$name, "Aaron Mau"); expect_equal(p[[2]]$orcid, "")
})

# dm_format_people_field -----------------------------------------------------

test_that("dm_format_people_field formats a YAML list-of-mappings (a CalOOS-minted holding's shape)", {
  v <- list(list(name = "James Wilkinson", organization = "UCSD SIO", email = "jwilkinson@ucsd.edu", role = "lead"))
  expect_equal(dm_format_people_field(v), "James Wilkinson · UCSD SIO ·  · jwilkinson@ucsd.edu")
})

test_that("dm_format_people_field passes through pre-formatted lines unchanged", {
  v <- list("Todd Martz · SIO · 0000-0001-2345-6789 · tmartz@ucsd.edu")
  expect_equal(dm_format_people_field(v), "Todd Martz · SIO · 0000-0001-2345-6789 · tmartz@ucsd.edu")
})

test_that("dm_format_people_field on empty/NULL is blank", {
  expect_equal(dm_format_people_field(NULL), "")
  expect_equal(dm_format_people_field(list()), "")
})

# dm_build_metadata_rows ----------------------------------------------------------

test_that("dm_build_metadata_rows pulls editable values from the sidecar and measured ones from `measured`", {
  fields <- data.frame(field = c("license", "n_obs"), importance = c("required", "optional"),
                        eml_path = c("", ""), guidance = c("g1", "g2"), editable = c(TRUE, FALSE),
                        stringsAsFactors = FALSE)
  sc <- list(license = "CC-BY-4.0", edited = list(license = list(by = "Jane", date = "2026-09-05")))
  rows <- dm_build_metadata_rows("test_ds", sc, fields, measured = list(n_obs = "12345"))
  expect_equal(rows$value, c("CC-BY-4.0", "12345"))
  expect_equal(rows$edited_by, c("Jane", ""))
  expect_equal(rows$edited_date, c("2026-09-05", ""))
})

# dm_apply_pull_dataset — the push -> edit -> pull round trip ---------------------

REAL_SIDECAR <- here::here("metadata/calcofi/dic/dataset_meta.yml")

test_that("push -> edit -> pull round-trip on a real sidecar reproduces it byte-for-byte except the edited value+stamp", {
  skip_if_not(file.exists(REAL_SIDECAR), "migrate_dataset_meta.R has not run yet")
  orig <- readLines(REAL_SIDECAR, warn = FALSE)

  # simulate a provider editing ONE field (pi_names) in the sheet; every other
  # field's "value" column equals the sidecar's current value unchanged
  sc <- yaml::yaml.load(paste(dm_dedent(dm_split_header(orig)$body, 2L), collapse = "\n"))
  fields <- dm_read_fields_csv()
  editable <- fields$field[fields$editable]
  rows <- data.frame(
    field = editable,
    value = vapply(editable, function(f) dm_sidecar_field_value(sc, f), character(1)),
    edited_by = "", edited_date = "", stringsAsFactors = FALSE)
  rows$value[rows$field == "pi_names"] <- "Todd Martz; Aaron Mau; Jane Provider"
  rows$edited_by[rows$field == "pi_names"] <- "Jane Provider"

  res <- dm_apply_pull_dataset(orig, rows, licenses = c("CC-BY-4.0"), today = as.Date("2026-09-05"))
  expect_equal(nrow(res$diffs), 1)
  expect_equal(res$diffs$field, "pi_names")
  expect_length(res$errors, 0)

  new_sc <- yaml::yaml.load(paste(dm_dedent(dm_split_header(res$lines)$body, 2L), collapse = "\n"))
  expect_equal(new_sc$pi_names, "Todd Martz; Aaron Mau; Jane Provider")
  expect_equal(new_sc$edited$pi_names$by, "Jane Provider")
  expect_equal(new_sc$edited$pi_names$date, "2026-09-05")

  # every OTHER key's value is untouched
  for (f in setdiff(names(sc), c("pi_names", "edited"))) expect_equal(new_sc[[f]], sc[[f]], info = f)

  # every line outside the pi_names entry (and the appended edited: block) is
  # byte-identical to the original
  orig_no_pi <- orig[!grepl("^  pi_names:", orig)]
  new_no_pi_or_edited <- res$lines[!grepl("^  pi_names:", res$lines) & !grepl("^  edited:|^    pi_names:|^      by:|^      date:", res$lines)]
  expect_equal(new_no_pi_or_edited, orig_no_pi)
})

test_that("dm_apply_pull_dataset refuses an out-of-registry license and writes nothing for that field", {
  sidecar <- c("# header", "  visibility: public", "  license: CC-BY-4.0")
  rows <- data.frame(field = "license", value = "Not-A-Real-License", edited_by = "X", edited_date = "",
                      stringsAsFactors = FALSE)
  res <- dm_apply_pull_dataset(sidecar, rows, licenses = c("CC-BY-4.0", "CC0-1.0"))
  expect_equal(nrow(res$diffs), 0)
  expect_length(res$errors, 1)
  expect_match(res$errors, "license")
  expect_equal(res$lines, sidecar)  # untouched
})

test_that("dm_apply_pull_dataset refuses a non-email/URL contact", {
  sidecar <- c("# header", "  contact: \"\"")
  rows <- data.frame(field = "contact", value = "call me maybe", edited_by = "X", edited_date = "",
                      stringsAsFactors = FALSE)
  res <- dm_apply_pull_dataset(sidecar, rows)
  expect_length(res$errors, 1)
  expect_match(res$errors, "contact")
})

test_that("dm_apply_pull_dataset ignores a measured (non-editable) field even if the sheet carries a value for it", {
  sidecar <- c("# header", "  license: CC-BY-4.0")
  rows <- data.frame(field = "n_obs", value = "999999", edited_by = "", edited_date = "", stringsAsFactors = FALSE)
  res <- dm_apply_pull_dataset(sidecar, rows)
  expect_equal(nrow(res$diffs), 0)
  expect_equal(res$lines, sidecar)
})

# holdings tab --------------------------------------------------------------------

test_that("dm_holdings_row shapes one row from a holding sidecar", {
  sc <- list(dataset_name = "HPLC Pigments", provider = "cce-lter", category = "Phytoplankton",
             status = "planned", priority = "high", owner = "Erin", next_step = "confirm EDI package",
             gh_issue = "42", observed = "2026-09-01")
  row <- dm_holdings_row("cce-lter_hplc-pigments", sc)
  expect_equal(row$status, "planned"); expect_equal(row$owner, "Erin")
})

test_that("dm_apply_holdings_pull updates only status/priority/owner/next_step and validates status", {
  sidecar <- c("# header", "  status: planned", "  priority: normal", "  owner: \"\"", "  next_step: \"\"")
  row <- list(status = "external", priority = "high", owner = "Erin", next_step = "email PI")
  res <- dm_apply_holdings_pull(sidecar, row)
  expect_length(res$errors, 0)
  expect_equal(nrow(res$diffs), 4)
  parsed <- yaml::yaml.load(paste(dm_dedent(dm_split_header(res$lines)$body, 2L), collapse = "\n"))
  expect_equal(parsed$status, "external"); expect_equal(parsed$owner, "Erin")
})

test_that("dm_apply_holdings_pull refuses an unknown status", {
  sidecar <- c("# header", "  status: planned", "  priority: normal", "  owner: \"\"", "  next_step: \"\"")
  row <- list(status = "done-ish", priority = "high", owner = "Erin", next_step = "email PI")
  res <- dm_apply_holdings_pull(sidecar, row)
  expect_length(res$errors, 1)
  expect_equal(nrow(res$diffs), 0)
})

# dm_contiguous_ranges / dm_protection_requests / dm_status_validation_request ----

test_that("dm_contiguous_ranges matches the hand-verified example", {
  ranges <- dm_contiguous_ranges(c(0, 1, 3, 4, 5))
  got <- lapply(ranges, function(r) c(r$start, r$end))
  expect_equal(got, list(c(0, 2), c(3, 6)))
})

test_that("dm_protection_requests protects everything but value/edited_by/edited_date", {
  cols <- c("dataset_key", "field", "value", "guidance", "edited_by", "edited_date")
  reqs <- dm_protection_requests(1, cols, dm_editable_cols())
  ranges <- lapply(reqs, function(r) r$addProtectedRange$protectedRange$range)
  full_col_ranges <- Filter(function(r) is.null(r$startRowIndex), ranges)
  protected_idx <- unlist(lapply(full_col_ranges, function(r) seq(r$startColumnIndex, r$endColumnIndex - 1)))
  expect_setequal(protected_idx, c(0, 1, 3))  # dataset_key, field, guidance
})

test_that("dm_status_validation_request targets the status column and data rows only", {
  cols <- c("dataset_key", "status", "priority")
  req <- dm_status_validation_request(1, cols, nrow_data = 5, values = c("planned", "external", "archived"))
  rng <- req$setDataValidation$range
  expect_equal(rng$startColumnIndex, 1L); expect_equal(rng$startRowIndex, 1L); expect_equal(rng$endRowIndex, 6L)
})

# dm_read_measured — degrades gracefully -------------------------------------------

test_that("dm_read_measured returns blank context for a workflow_dir with no releases", {
  tmp <- tempfile(); dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))
  out <- dm_read_measured("x_y", workflow_dir = tmp)
  expect_equal(unname(unlist(out)), rep("", length(dm_measured_fields())))
})

# real-world smoke test -------------------------------------------------------------

test_that("every metadata/*/*/dataset_meta.yml in the repo is readable and every editable field validates blank-safe", {
  paths <- Sys.glob(here::here("metadata/*/*/dataset_meta.yml"))
  skip_if(length(paths) == 0, "no dataset_meta.yml found")
  licenses <- calcofi4db::read_license_registry(LICENSE_CSV)
  licenses <- licenses$license[licenses$status == "active"]
  fields <- dm_read_fields_csv()
  for (p in paths) {
    sc <- calcofi4db::read_dataset_sidecar(p, licenses = licenses)
    for (f in fields$field[fields$editable]) {
      v <- dm_sidecar_field_value(sc, f)
      res <- dm_validate_field(f, v, licenses = licenses)
      expect_true(res$ok, info = paste(p, f, v))
    }
  }
})

cat("\nAll scripts/sync_dataset_meta_sheets.R tests passed.\n")
