#!/usr/bin/env Rscript
# Unit tests for the pure, network-free logic in scripts/pull_preview_consent.R — the rule
# that folds a preview decision into a questions.csv consent row, exercised with a fake record
# (the shape preview/app/consent.py writes) rather than the bucket. Run with:
#
#   Rscript scripts/test_pull_preview_consent.R
#
# pull_preview_consent.R is sys.nframe()==0-guarded, so source()-ing it here does not run its
# CLI / touch gcloud or git.
suppressMessages(librarian::shelf(testthat, readr, calcofi4db, here, quiet = TRUE))
source(here::here("scripts/pull_preview_consent.R"))

QCOLS <- c("label", "id", "question", "context", "status", "priority",
           "proposed_answer", "answer", "asked_date", "answered_date", "who",
           "related_table", "related_field")

fixture_q <- function(consent_status = "open", consent_answer = NA_character_,
                      consent_who = NA_character_, consent_date = NA_character_) {
  data.frame(
    label = c("Q01", "Q02", "Q03"),
    id = c("test_ds_01", "test_ds_02", "test_ds_03"),
    question = c("Q one?", "May CalCOFI.io publish test_ds as shown in the private preview?", "Q three?"),
    context = c("ctx1", "Standing consent row (agreed 2026-10-22).", NA_character_),
    status = c("open", consent_status, "answered"),
    priority = c("blocker", "high", "normal"),
    proposed_answer = c(NA_character_, NA_character_, NA_character_),
    answer = c(NA_character_, consent_answer, "settled: Y"),
    asked_date = c(NA_character_, "2026-11-03", "2026-07-01"),
    answered_date = c(NA_character_, consent_date, "2026-07-15"),
    who = c(NA_character_, consent_who, "provider Z"),
    related_table = c("sample", "dataset", "sample"),
    related_field = c("depth", "consent", "date"),
    stringsAsFactors = FALSE)[, QCOLS]
}

fixture_rec <- function(decision = "yes", comment = "Looks right to us.", name = "Jane Provider",
                        email = "jane@example.org", citation_changed = FALSE) {
  list(
    dataset_key = "test_ds", decision = decision, comment = comment, email = email, name = name,
    via = "link", recorded_utc = "2026-11-04T17:25:09Z", build_id = "20261104T000000Z",
    build_sha256 = "abc", question_id = "test_ds_02",
    question = "May CalCOFI.io publish test_ds as shown in the private preview?",
    release_candidate = "v2026.11.04",
    attribution = list(
      citation_main   = list(value = if (citation_changed) "Provider J (2026). The data. doi:10/x" else "Provider J (2025). The data.",
                             changed = citation_changed),
      license_name    = list(value = "CC BY 4.0", changed = FALSE),
      license_url     = list(value = "https://creativecommons.org/licenses/by/4.0/", changed = FALSE),
      acknowledgement = list(value = "", changed = FALSE)))
}

strip_attrs <- function(df) { attr(df, "consent_action") <- NULL; attr(df, "consent_note") <- NULL; df }

# consent_apply: yes -----------------------------------------------------------

test_that("yes with a comment and one changed attribution answers the consent row", {
  q   <- fixture_q()
  res <- consent_apply(q, fixture_rec(citation_changed = TRUE))
  expect_equal(attr(res, "consent_action"), "answered")
  expect_equal(names(res), QCOLS)                      # columns and their order unchanged
  expect_equal(res$id, q$id)                           # rows and their order unchanged
  i <- 2
  expect_equal(res$status[i], "answered")
  expect_equal(res$answer[i],
               "Yes\nLooks right to us.\ncitation_main as given in the preview: Provider J (2026). The data. doi:10/x")
  expect_equal(res$who[i], "Jane Provider <jane@example.org>")
  expect_equal(res$answered_date[i], "2026-11-04")
  expect_equal(res$context[i], q$context[i])           # context untouched by a yes
  expect_equal(strip_attrs(res)[-i, ], q[-i, ])        # every other row untouched
})

test_that("yes without a comment or a changed field is a bare Yes", {
  res <- consent_apply(fixture_q(), fixture_rec(comment = ""))
  expect_equal(res$answer[2], "Yes")
  expect_equal(attr(res, "consent_action"), "answered")
})

test_that("yes on a row already answered keeps the provider's answer (a pull never moves back)", {
  q   <- fixture_q(consent_status = "answered", consent_answer = "yes, by email 2026-10-30",
                   consent_who = "The PI", consent_date = "2026-10-30")
  res <- consent_apply(q, fixture_rec(citation_changed = TRUE))
  expect_equal(attr(res, "consent_action"), "kept")
  expect_match(attr(res, "consent_note"), "already answered")
  expect_equal(strip_attrs(res), q)
})

test_that("yes on a wontfix row is kept too", {
  q   <- fixture_q(consent_status = "wontfix")
  res <- consent_apply(q, fixture_rec())
  expect_equal(attr(res, "consent_action"), "kept")
  expect_equal(strip_attrs(res), q)
})

test_that("who falls back to whichever of name and email the record holds", {
  expect_equal(pc_who(list(name = "Jane", email = "")), "Jane")
  expect_equal(pc_who(list(name = NULL, email = "j@x.org")), "j@x.org")
  expect_equal(pc_who(list(name = "Jane", email = "j@x.org")), "Jane <j@x.org>")
})

# consent_apply: not_yet -------------------------------------------------------

test_that("not_yet appends one dated line to context, once, and leaves the status", {
  q    <- fixture_q()
  rec  <- fixture_rec(decision = "not_yet", comment = "We need the co-authors to see it first.")
  once <- consent_apply(q, rec)
  expect_equal(attr(once, "consent_action"), "noted")
  expect_equal(once$status[2], "open")
  expect_true(is.na(once$answer[2]))
  expect_equal(once$context[2],
               "Standing consent row (agreed 2026-10-22).\n2026-11-04 not yet (Jane Provider): We need the co-authors to see it first.")
  expect_equal(strip_attrs(once)[-2, ], q[-2, ])
  twice <- consent_apply(strip_attrs(once), rec)
  expect_equal(attr(twice, "consent_action"), "already_noted")
  expect_equal(strip_attrs(twice), strip_attrs(once))
})

test_that("not_yet on an empty context and without a comment is the bare dated line", {
  q <- fixture_q(); q$context[2] <- NA_character_
  res <- consent_apply(q, fixture_rec(decision = "not_yet", comment = ""))
  expect_equal(res$context[2], "2026-11-04 not yet (Jane Provider)")
})

test_that("not_yet after a yes keeps the answer and still notes the context", {
  q   <- strip_attrs(consent_apply(fixture_q(), fixture_rec()))
  res <- consent_apply(q, fixture_rec(decision = "not_yet", comment = "second thoughts", name = "Jo"))
  expect_equal(res$status[2], "answered")
  expect_equal(res$answer[2], "Yes\nLooks right to us.")
  expect_match(res$context[2], "\n2026-11-04 not yet \\(Jo\\): second thoughts$")
})

# consent_apply: no consent row -------------------------------------------------

test_that("a record for a dataset with no consent row changes nothing and says so", {
  q <- fixture_q(); q$related_field[2] <- "citation"
  res <- consent_apply(q, fixture_rec())
  expect_equal(attr(res, "consent_action"), "no_consent_row")
  expect_equal(strip_attrs(res), q)
  expect_equal(pc_consent_row(q), integer(0))
})

test_that("an unknown decision is refused", {
  expect_error(consent_apply(fixture_q(), fixture_rec(decision = "maybe")), "yes or not_yet")
})

# the CSV round trip -----------------------------------------------------------

test_that("the answered table writes with na = '' and re-reads in file order through the validator", {
  f <- tempfile(fileext = ".csv"); on.exit(unlink(f))
  res <- consent_apply(fixture_q(), fixture_rec(citation_changed = TRUE))
  pc_write_questions(strip_attrs(res), f)
  back <- pc_read_questions(f)
  expect_equal(back$id, c("test_ds_01", "test_ds_02", "test_ds_03"))
  expect_equal(back$answer[2], res$answer[2])          # the newline inside the cell survives
  expect_false(any(grepl("NA", readLines(f), fixed = TRUE)))
})

# the small helpers ----------------------------------------------------------------

test_that("pc_split_key reads provider and dataset from the ingest YAML entry, never by splitting", {
  yml <- list(`cce-lter_poc-pon` = list(provider = "cce-lter", dataset = "poc-pon"))
  expect_equal(pc_split_key("cce-lter_poc-pon", yml)$provider, "cce-lter")
  expect_equal(pc_split_key("cce-lter_poc-pon", yml)$questions_csv, "metadata/cce-lter/poc-pon/questions.csv")
  expect_null(pc_split_key("cce_lter-poc-pon", yml))
})

test_that("the marker sits beside the decision and ordering is per dataset, oldest first", {
  expect_equal(pc_marker_name("gs://b/consent/k/20261104T172509Z_j@x.org.json"),
               "gs://b/consent/k/20261104T172509Z_j@x.org.applied.json")
  recs <- list(list(dataset_key = "b", recorded_utc = "2026-11-04T10:00:00Z"),
               list(dataset_key = "a", recorded_utc = "2026-11-04T12:00:00Z"),
               list(dataset_key = "a", recorded_utc = "2026-11-03T12:00:00Z"))
  o <- pc_order_records(recs)
  expect_equal(vapply(o, function(r) paste(r$dataset_key, r$recorded_utc), ""),
               c("a 2026-11-03T12:00:00Z", "a 2026-11-04T12:00:00Z", "b 2026-11-04T10:00:00Z"))
})

test_that("the commit message names the key, decision, who and date, attribution lines below", {
  one <- list(list(key = "sccoos_ifcb-ctd", decision = "yes", who = "Jane <j@x.org>", date = "2026-11-04",
                   attribution = "citation_main as given in the preview: X"))
  expect_equal(pc_commit_message(one),
               "sccoos_ifcb-ctd: consent yes from the preview (Jane <j@x.org>, 2026-11-04)\n\ncitation_main as given in the preview: X")
  two <- c(one, list(list(key = "sio_cetacean-sightings", decision = "not_yet", who = "Jo", date = "2026-11-05",
                          attribution = character(0))))
  msg <- pc_commit_message(two)
  expect_match(msg, "^preview consent: 2 decisions from the preview\n")
  expect_match(msg, "sio_cetacean-sightings: consent not_yet from the preview \\(Jo, 2026-11-05\\)")
})
