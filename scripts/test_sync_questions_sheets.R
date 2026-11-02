#!/usr/bin/env Rscript
# Unit tests for the pure, network-free logic in scripts/sync_questions_sheets.R
# — the CSV-side merge/diff/protection-request math, exercised with a fake
# sheet as a data.frame rather than a live Google Sheet. Run with:
#
#   Rscript scripts/test_sync_questions_sheets.R
#
# sync_questions_sheets.R is sys.nframe()==0-guarded, so source()-ing it here
# does not run its CLI / touch the network.
suppressMessages(librarian::shelf(testthat, readr, calcofi4db, here, quiet = TRUE))
source(here::here("scripts/sync_questions_sheets.R"))

QCOLS <- c("label", "id", "question", "context", "status", "priority",
           "proposed_answer", "answer", "asked_date", "answered_date", "who",
           "related_table", "related_field")

fixture_csv_df <- function() {
  data.frame(
    label = c("Q01", "Q02", "Q03"),
    id = c("test_ds_01", "test_ds_02", "test_ds_03"),
    question = c("Q one?", "Q two?", "Q three?"),
    context = c("ctx1", "ctx2", NA_character_),
    status = c("open", "proposed", "answered"),
    priority = c("blocker", "high", "normal"),
    proposed_answer = c(NA_character_, "we think X", NA_character_),
    answer = c(NA_character_, NA_character_, "settled: Y"),
    asked_date = c(NA_character_, "2026-08-01", "2026-07-01"),
    answered_date = c(NA_character_, NA_character_, "2026-07-15"),
    who = c(NA_character_, NA_character_, "provider Z"),
    related_table = c("sample", "obs", "sample"),
    related_field = c("depth", "value", "date"),
    stringsAsFactors = FALSE)[, QCOLS]
}

write_fixture_csv <- function(df = fixture_csv_df()) {
  f <- tempfile(fileext = ".csv")
  readr::write_csv(df, f, na = "")
  f
}

# qs_editable_cols / qs_tab_name ---------------------------------------------

test_that("qs_editable_cols is the four-column contract", {
  expect_equal(qs_editable_cols(), c("answer", "status", "answered_date", "who"))
})

test_that("qs_tab_name matches the dataset_key convention", {
  expect_equal(qs_tab_name("swfsc", "ichthyo"), "swfsc_ichthyo")
})

# qs_read_csv_raw -------------------------------------------------------------

test_that("qs_read_csv_raw preserves file row order (not read_questions()'s priority sort)", {
  f <- write_fixture_csv()
  on.exit(unlink(f))
  d <- qs_read_csv_raw(f)
  expect_equal(d$id, c("test_ds_01", "test_ds_02", "test_ds_03"))  # file order, not blocker-first
  expect_equal(names(d), QCOLS)
})

test_that("qs_read_csv_raw errors (via read_questions()) on a bad status", {
  f <- write_fixture_csv()
  on.exit(unlink(f))
  txt <- readLines(f)
  txt <- sub("open", "askedd", txt, fixed = TRUE)
  writeLines(txt, f)
  expect_error(qs_read_csv_raw(f), "unknown question status")
})

# qs_stamp_asked_dates ---------------------------------------------------------

test_that("qs_stamp_asked_dates stamps only blank rows", {
  df <- fixture_csv_df()
  res <- qs_stamp_asked_dates(df, today = as.Date("2026-09-03"))
  expect_equal(res$n_stamped, 1)
  expect_equal(res$stamped_ids, "test_ds_01")
  expect_equal(res$df$asked_date[res$df$id == "test_ds_01"], "2026-09-03")
  # untouched rows keep their original date
  expect_equal(res$df$asked_date[res$df$id == "test_ds_02"], "2026-08-01")
})

test_that("qs_stamp_asked_dates is idempotent on a second call", {
  df <- fixture_csv_df()
  once  <- qs_stamp_asked_dates(df, today = as.Date("2026-09-03"))
  twice <- qs_stamp_asked_dates(once$df, today = as.Date("2026-09-04"))
  expect_equal(twice$n_stamped, 0)
  expect_equal(twice$df, once$df)
})

# qs_apply_pull -----------------------------------------------------------------

test_that("qs_apply_pull diffs a changed answer/status/who/answered_date", {
  csv_df <- fixture_csv_df()
  sheet_df <- data.frame(
    id = c("test_ds_01", "test_ds_02", "test_ds_03"),
    answer = c("we answered it", NA, "settled: Y"),
    status = c("answered", "proposed", "answered"),
    answered_date = c("2026-09-01", NA, "2026-07-15"),
    who = c("Jane Provider", NA, "provider Z"),
    stringsAsFactors = FALSE)

  res <- qs_apply_pull(csv_df, sheet_df)
  # only row 1 changed (row 2 unchanged from its csv values; row 3 identical)
  expect_setequal(res$diffs$id, "test_ds_01")
  expect_setequal(res$diffs$field, c("answer", "status", "answered_date", "who"))
  expect_equal(res$df$answer[res$df$id == "test_ds_01"], "we answered it")
  expect_equal(res$df$status[res$df$id == "test_ds_01"], "answered")
  expect_length(res$flips, 0)
})

test_that("qs_apply_pull auto-flips status to answered when answer is present but status is still open", {
  csv_df <- fixture_csv_df()
  sheet_df <- data.frame(
    id = csv_df$id,
    answer = c("here's the answer", NA, "settled: Y"),
    status = c("open", "proposed", "answered"),  # provider forgot to change the dropdown
    answered_date = c(NA, NA, "2026-07-15"),
    who = c("Jane", NA, "provider Z"),
    stringsAsFactors = FALSE)

  expect_warning(res <- qs_apply_pull(csv_df, sheet_df), "auto-flipped")
  expect_equal(res$flips, "test_ds_01")
  expect_equal(res$df$status[res$df$id == "test_ds_01"], "answered")
  note <- res$diffs$note[res$diffs$id == "test_ds_01" & res$diffs$field == "status"]
  expect_match(note, "auto-flip")
})

test_that("qs_apply_pull errors, naming the row, on an invalid pulled status", {
  csv_df <- fixture_csv_df()
  sheet_df <- data.frame(
    id = csv_df$id,
    answer = c(NA, NA, "settled: Y"),
    status = c("asked", "proposed", "answered"),  # "asked" is not a valid status
    answered_date = c(NA, NA, "2026-07-15"),
    who = c(NA, NA, "provider Z"),
    stringsAsFactors = FALSE)

  err <- tryCatch(qs_apply_pull(csv_df, sheet_df), error = function(e) e)
  expect_true(inherits(err, "error"))
  expect_match(conditionMessage(err), "test_ds_01")
  expect_match(conditionMessage(err), "Q01")
})

test_that("qs_apply_pull errors on a sheet id absent from the csv (id column should be protected)", {
  csv_df <- fixture_csv_df()
  sheet_df <- data.frame(
    id = c("test_ds_01", "test_ds_99"),
    answer = c(NA, "rogue row"), status = c("open", "open"),
    answered_date = c(NA, NA), who = c(NA, NA), stringsAsFactors = FALSE)
  expect_error(qs_apply_pull(csv_df, sheet_df), "test_ds_99")
})

test_that("no row lost on a second push: qs_apply_pull never drops or adds rows", {
  csv_df <- fixture_csv_df()
  sheet_df <- data.frame(
    id = "test_ds_02", answer = "answer for two", status = "answered",
    answered_date = "2026-09-03", who = "Jane", stringsAsFactors = FALSE)

  res <- qs_apply_pull(csv_df, sheet_df)
  expect_equal(nrow(res$df), 3)
  expect_setequal(res$df$id, csv_df$id)
  # rows 1 and 3 are byte-identical to the input (only row 2 changed)
  expect_equal(res$df[res$df$id == "test_ds_01", ], csv_df[csv_df$id == "test_ds_01", ])
  expect_equal(res$df[res$df$id == "test_ds_03", ], csv_df[csv_df$id == "test_ds_03", ])

  # simulate the re-push: the full merged df (all 3 rows) is what gets written
  # to the sheet next time — nothing here ever drops a row
  expect_equal(nrow(res$df), nrow(csv_df))
})

# a stale sheet never reverts git (2026-10-22) ------------------------------
# the provider sheets had fallen behind git: answers recorded in the repo since
# September still read open/proposed there, and a pull would have reverted them

test_that("a blank sheet cell never blanks a value git holds", {
  csv_df <- fixture_csv_df()
  sheet_df <- data.frame(
    id = "test_ds_03", answer = NA, status = "answered", answered_date = NA, who = NA,
    stringsAsFactors = FALSE)
  res <- qs_apply_pull(csv_df, sheet_df)
  expect_equal(res$df, csv_df)
  expect_setequal(res$diffs$field, c("answer", "answered_date", "who"))
  expect_true(all(res$diffs$action == "keep"))
  expect_match(res$diffs$note, "behind git")
})

test_that("a status never moves back: answered -> open and proposed -> open are kept", {
  csv_df <- fixture_csv_df()
  sheet_df <- data.frame(
    id = c("test_ds_02", "test_ds_03"), answer = c(NA, "settled: Y"),
    status = c("open", "open"), answered_date = c(NA, "2026-07-15"),
    who = c(NA, "provider Z"), stringsAsFactors = FALSE)
  res <- qs_apply_pull(csv_df, sheet_df)
  expect_equal(res$df$status, c("open", "proposed", "answered"))
  expect_equal(res$diffs$action, c("keep", "keep"))
  expect_match(res$diffs$note[1], "proposed -> open")
  expect_length(res$flips, 0)   # git's own answer repeated is not a new answer
})

test_that("answered -> wontfix on a closed row is a conflict (a stale sheet can hold either)", {
  csv_df <- fixture_csv_df()
  sheet_df <- data.frame(
    id = "test_ds_03", answer = "settled: Y", status = "wontfix",
    answered_date = "2026-07-15", who = "provider Z", stringsAsFactors = FALSE)
  res <- qs_apply_pull(csv_df, sheet_df)
  expect_equal(res$df$status[3], "answered")
  expect_equal(res$diffs$action, "conflict")
})

test_that("a different answer on a row git already closed is a conflict, not applied", {
  csv_df <- fixture_csv_df()
  sheet_df <- data.frame(
    id = "test_ds_03", answer = "an older wording", status = "answered",
    answered_date = "2026-07-15", who = "provider Z", stringsAsFactors = FALSE)
  res <- qs_apply_pull(csv_df, sheet_df)
  expect_equal(res$df, csv_df)
  expect_equal(res$diffs$action, "conflict")
})

test_that("a closed row's blank who is still filled from the sheet", {
  csv_df <- fixture_csv_df(); csv_df$who[3] <- NA
  sheet_df <- data.frame(
    id = "test_ds_03", answer = "settled: Y", status = "answered",
    answered_date = "2026-07-15", who = "provider Z", stringsAsFactors = FALSE)
  res <- qs_apply_pull(csv_df, sheet_df)
  expect_equal(res$df$who[3], "provider Z")
  expect_equal(res$diffs$action, "apply")
})

test_that("an open row with a partial note is not auto-flipped when the sheet repeats the note", {
  csv_df <- fixture_csv_df(); csv_df$answer[1] <- "partial: depends on the CTD team"
  sheet_df <- data.frame(
    id = "test_ds_01", answer = "partial: depends on the CTD team", status = "open",
    answered_date = NA, who = NA, stringsAsFactors = FALSE)
  res <- qs_apply_pull(csv_df, sheet_df)
  expect_length(res$flips, 0)
  expect_equal(nrow(res$diffs), 0)
  expect_equal(res$df, csv_df)
})

test_that("an open row with a partial note is auto-flipped when the provider writes a new answer", {
  csv_df <- fixture_csv_df(); csv_df$answer[1] <- "partial: depends on the CTD team"
  sheet_df <- data.frame(
    id = "test_ds_01", answer = "yes, use the corrected series", status = "open",
    answered_date = NA, who = "Jane", stringsAsFactors = FALSE)
  expect_warning(res <- qs_apply_pull(csv_df, sheet_df), "auto-flipped")
  expect_equal(res$df$status[1], "answered")
  expect_equal(res$df$answer[1], "yes, use the corrected series")
})

# qs_unpulled_edits (the push guard) --------------------------------------------

test_that("qs_unpulled_edits lists provider edits and conflicts, not a stale sheet", {
  csv_df <- fixture_csv_df()
  sheet_df <- data.frame(
    id = c("test_ds_01", "test_ds_02", "test_ds_03"),
    answer = c("provider typed this", NA, "an older wording"),
    status = c("open", "open", "answered"),           # row 2 reverted: stale, not an edit
    answered_date = c(NA, NA, "2026-07-15"), who = c(NA, NA, "provider Z"),
    stringsAsFactors = FALSE)
  d <- qs_unpulled_edits(csv_df, sheet_df)
  expect_setequal(d$id, c("test_ds_01", "test_ds_03"))
  expect_setequal(d$action, c("apply", "conflict"))
})

test_that("qs_unpulled_edits is empty for a sheet in step with git, and ignores deleted ids", {
  csv_df <- fixture_csv_df()
  sheet_df <- csv_df[, c("id", qs_editable_cols())]
  sheet_df <- rbind(sheet_df, data.frame(id = "test_ds_99", answer = "gone from git",
    status = "answered", answered_date = NA, who = NA))
  expect_equal(nrow(qs_unpulled_edits(csv_df, sheet_df)), 0)
})

test_that("qs_status_rank orders open < proposed < answered = wontfix", {
  expect_equal(qs_status_rank(c("open", "proposed", "answered", "wontfix")), c(0L, 1L, 2L, 2L))
})

# qs_write_questions_csv -------------------------------------------------------

test_that("qs_write_questions_csv round-trips and passes read_questions()", {
  csv_df <- fixture_csv_df()
  f <- tempfile(fileext = ".csv")
  on.exit(unlink(f))
  out <- qs_write_questions_csv(csv_df, f)
  expect_s3_class(out, "data.frame")
  # the gate: read_questions() passes on the CSV after a write (simulating "after a pull")
  expect_silent(calcofi4db::read_questions(f))
  # na = "" was used, not the readr default na = "NA" (the registry round-trip trap)
  raw <- readLines(f)
  expect_false(any(grepl(",NA,|,NA$", raw)))
})

# qs_contiguous_ranges ----------------------------------------------------------

test_that("qs_contiguous_ranges matches the hand-verified 13-column example", {
  # QUESTION_COLS has 13 columns; editable = status(4), answer(7),
  # answered_date(9), who(10) (0-based) -> protected = 0,1,2,3,5,6,8,11,12
  protected_idx0 <- c(0, 1, 2, 3, 5, 6, 8, 11, 12)
  ranges <- qs_contiguous_ranges(protected_idx0)
  got <- lapply(ranges, function(r) c(r$start, r$end))
  expect_equal(got, list(c(0, 4), c(5, 7), c(8, 9), c(11, 13)))
})

test_that("qs_contiguous_ranges handles empty and single-element input", {
  expect_equal(qs_contiguous_ranges(integer(0)), list())
  expect_equal(qs_contiguous_ranges(5L), list(list(start = 5L, end = 6L)))
})

# qs_protection_requests / qs_validation_request (pure request-shape checks) --

test_that("qs_protection_requests builds one range per contiguous protected run plus editable headers", {
  reqs <- qs_protection_requests(sheet_id = 12345, col_names = QCOLS)
  # 4 protected column runs (see qs_contiguous_ranges test) + editable-header runs
  # editable idx0 = 4 (status), 7 (answer), 9 (answered_date), 10 (who)
  # -> header runs: [4,5), [7,8), [9,11)  => 3 header ranges
  expect_equal(length(reqs), 4 + 3)
  all_ranges <- lapply(reqs, function(r) r$addProtectedRange$protectedRange$range)
  expect_true(all(vapply(all_ranges, function(r) r$sheetId == 12345, logical(1))))
  # the editable-column header ranges are exactly rows 0:1 (header only)
  hdr <- all_ranges[vapply(all_ranges, function(r) !is.null(r$startRowIndex), logical(1))]
  expect_true(all(vapply(hdr, function(r) r$startRowIndex == 0 && r$endRowIndex == 1, logical(1))))
})

test_that("qs_protection_requests errors if an editable column is missing from the tab", {
  expect_error(qs_protection_requests(1, c("id", "label")), "not found in tab")
})

test_that("qs_validation_request targets the status column and data rows only", {
  req <- qs_validation_request(sheet_id = 99, col_names = QCOLS, nrow_data = 10)
  rng <- req$setDataValidation$range
  status_idx0 <- match("status", QCOLS) - 1L
  expect_equal(rng$sheetId, 99)
  expect_equal(rng$startColumnIndex, status_idx0)
  expect_equal(rng$endColumnIndex, status_idx0 + 1L)
  expect_equal(rng$startRowIndex, 1L)   # skip header
  expect_equal(rng$endRowIndex, 11L)    # 1 (header) + 10 data rows
  vals <- vapply(req$setDataValidation$rule$condition$values, `[[`, "", "userEnteredValue")
  expect_equal(vals, calcofi4db::question_statuses())
})

# real-world smoke test: every questions.csv in the repo round-trips clean ----

test_that("every metadata/*/*/questions.csv in the repo reads via qs_read_csv_raw()", {
  paths <- Sys.glob(here::here("metadata/*/*/questions.csv"))
  skip_if(length(paths) == 0, "no questions.csv found")
  for (p in paths) {
    d <- qs_read_csv_raw(p)
    expect_equal(names(d), QCOLS, info = p)
    expect_true(all(!duplicated(d$id)), info = p)
  }
})

cat("\nAll scripts/sync_questions_sheets.R tests passed.\n")
