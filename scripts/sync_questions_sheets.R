#!/usr/bin/env Rscript
# Provider question sheets — one Google Sheet per active provider
# (metadata/questions_sheets.yml), one tab per dataset, generated from and
# pulled back into metadata/{provider}/{dataset}/questions.csv.
#
# The CSV in git is the source of truth for the QUESTION (label, id, question,
# context, priority, proposed_answer, related_table, related_field, asked_date);
# the sheet is the source of truth for four editable columns — answer, status,
# answered_date, who — once a provider has typed into it. See CLAUDE.md
# "The question registry convention".
#
#   Rscript scripts/sync_questions_sheets.R push [provider]              # dry run: plan only, no network
#   Rscript scripts/sync_questions_sheets.R push [provider] --execute    # create/update the sheet(s)
#   Rscript scripts/sync_questions_sheets.R pull [provider]              # dry run: reads the sheet, prints the diff
#   Rscript scripts/sync_questions_sheets.R pull [provider] --execute    # applies the diff to questions.csv
#
# `provider` is a metadata/provider.csv slug (calcofi, swfsc, sio, cce-lter,
# cdfw, farallon, sccoos); omit it to act on every active provider that has a
# row in metadata/questions_sheets.yml.
#
# Google auth (only for `pull`, and for `push --execute`; a push dry run needs
# none). The token is chosen by environment variable, in this order:
#   QS_GOOGLE_SA_JSON=<service-account json>  — the calcofi-admin key. The
#       sheets are then OWNED by the service account (its own Drive), and its
#       GCP project must have the Sheets + Drive APIs enabled, else every
#       gs4_create() answers 403 PERMISSION_DENIED (measured 2026-09-03).
#   QS_GOOGLE_EMAIL=<address>  — a cached user token for that account with
#       BOTH the spreadsheets and drive scopes (drive_share() needs drive).
#       Cache it once, in an interactive R session (Rscript cannot open the
#       browser flow):
#         googlesheets4::gs4_auth(email = "bebest@ucsd.edu",
#           scopes = c("https://www.googleapis.com/auth/spreadsheets",
#                      "https://www.googleapis.com/auth/drive"))
#   neither  — interactive gs4_auth() (browser), interactive sessions only.
# googledrive is handed the same token, so the two packages never disagree.
# The authenticated user is dropped from SHARE_WITH (Drive refuses to share a
# file with its owner).
#
# Deps beyond calcofi4db, all CRAN, loaded via librarian::shelf() below:
# googlesheets4, googledrive, readr, yaml, glue, here.
suppressMessages(librarian::shelf(
  googlesheets4, googledrive, readr, yaml, glue, here, calcofi4db, quiet = TRUE))

SHEETS_YML  <- here("metadata/questions_sheets.yml")
PROVIDER_CSV <- here("metadata/provider.csv")
SHARE_WITH  <- c("bebest@ucsd.edu", "ben@oceanmetrics.io", "esatterthwaite@ucsd.edu", "bthuang@ucsd.edu", "bhuang0022@gmail.com")
QS_SCOPES   <- c("https://www.googleapis.com/auth/spreadsheets",
                 "https://www.googleapis.com/auth/drive")

#' Authenticate once per process — see the header for the precedence. Returns
#' the authenticated address (lower-case) so callers can skip sharing with it.
qs_auth <- function() {
  sa <- Sys.getenv("QS_GOOGLE_SA_JSON", "")
  em <- Sys.getenv("QS_GOOGLE_EMAIL", "")
  if (nzchar(sa)) {
    googlesheets4::gs4_auth(path = path.expand(sa), scopes = QS_SCOPES)
  } else if (nzchar(em)) {
    googlesheets4::gs4_auth(email = em, scopes = QS_SCOPES)
  } else {
    googlesheets4::gs4_auth(scopes = QS_SCOPES)
  }
  googledrive::drive_auth(token = googlesheets4::gs4_token())
  who <- tryCatch(googlesheets4::gs4_user(), error = function(e) NA_character_)
  if (length(who) != 1 || is.na(who)) who <- NA_character_
  qcat("authenticated as {if (is.na(who)) '<unknown>' else who}")
  tolower(who)
}
# rlang's null-coalescing operator: NULL → b; never tests NA (a list would break `||`)
`%||%` <- function(a, b) if (is.null(a)) b else a

#' cat() a glue()d line with its newline intact. glue::glue() trims trailing
#' whitespace/newlines by default (.trim = TRUE), so `cat(glue::glue("...\n"))`
#' silently drops the line break — this is the one call site that does it right.
#' `.envir = parent.frame()` is required (not glue::glue()'s own default) because
#' this wrapper adds a stack frame between the template and its caller's
#' variables.
qcat <- function(..., .envir = parent.frame())
  cat(glue::glue(..., .envir = .envir), "\n", sep = "")

# pure / network-free -----------------------------------------------------
# unit-tested in scripts/test_sync_questions_sheets.R without any network call

#' The four sheet columns a provider may edit; everything else is protected.
qs_editable_cols <- function() c("answer", "status", "answered_date", "who")

#' Tab name for a (provider, dataset) pair — matches the dataset_key convention.
qs_tab_name <- function(provider, dataset) paste0(provider, "_", dataset)

#' Read a questions.csv, validated by read_questions() but returned in the
#' file's own row order (read_questions() re-sorts by priority, which would
#' otherwise reorder questions.csv on every pull and create noise diffs).
qs_read_csv_raw <- function(path) {
  calcofi4db::read_questions(path)  # validate only; throws on bad vocab/dup labels
  readr::read_csv(path, na = "", show_col_types = FALSE,
                   col_types = readr::cols(.default = readr::col_character()))
}

#' Stamp `asked_date` on rows where it is still blank — "asked_date is stamped
#' by the first push." Idempotent: a row with a date already set is untouched,
#' so a second push does nothing here.
#'
#' @return list(df=, n_stamped=, stamped_ids=)
qs_stamp_asked_dates <- function(df, today = Sys.Date()) {
  blank <- is.na(df$asked_date) | !nzchar(df$asked_date)
  df$asked_date[blank] <- format(today, "%Y-%m-%d")
  list(df = df, n_stamped = sum(blank), stamped_ids = df$id[blank])
}

#' Merge a sheet's editable columns back into the local questions.csv content.
#'
#' @param csv_df  the full local table (from qs_read_csv_raw()), one row per question
#' @param sheet_df a data.frame with columns id, answer, status, answered_date, who
#'   (as returned by googlesheets4::range_read(), or a fake for testing)
#' @param path optional, only used in error messages
#'
#' @return list(df=<csv_df with matched-id editable cells replaced>,
#'   diffs=data.frame(id,label,field,old,new,note), flips=<character ids>)
qs_apply_pull <- function(csv_df, sheet_df, path = NULL) {
  need <- c("id", qs_editable_cols())
  miss <- setdiff(need, names(sheet_df))
  if (length(miss))
    stop("sheet is missing column(s): ", paste(miss, collapse = ", "), call. = FALSE)

  # Sheets returns "" for a blank cell, not NA
  blankify <- function(x) { x <- trimws(x); ifelse(!is.na(x) & nzchar(x), x, NA_character_) }
  for (cl in qs_editable_cols()) sheet_df[[cl]] <- blankify(sheet_df[[cl]])
  sheet_df$id <- trimws(sheet_df$id)

  unknown <- setdiff(sheet_df$id[!is.na(sheet_df$id) & nzchar(sheet_df$id)], csv_df$id)
  if (length(unknown))
    stop("pulled sheet has id(s) not present in ", if (!is.null(path)) path else "questions.csv",
         ": ", paste(unknown, collapse = ", "),
         " — the id column is protected and should never change from the sheet side.",
         call. = FALSE)

  sheet_df <- sheet_df[!is.na(sheet_df$id) & nzchar(sheet_df$id) & sheet_df$id %in% csv_df$id, , drop = FALSE]
  sheet_df <- sheet_df[!duplicated(sheet_df$id), , drop = FALSE]

  # validate BEFORE flipping, so an invalid value from the provider is always
  # reported rather than silently corrected
  bad <- sheet_df[!is.na(sheet_df$status) & !sheet_df$status %in% calcofi4db::question_statuses(), , drop = FALSE]
  if (nrow(bad)) {
    lbl <- csv_df$label[match(bad$id, csv_df$id)]
    stop("pulled status invalid for: ",
         paste(sprintf("%s (%s) = %s", bad$id, lbl, encodeString(bad$status, quote = "\"")), collapse = "; "),
         "\n  Allowed: ", paste(calcofi4db::question_statuses(), collapse = " | "), call. = FALSE)
  }

  # auto-flip: an answer present with status still open (or blank) means the
  # provider typed an answer but did not change the dropdown
  flip <- !is.na(sheet_df$answer) & nzchar(sheet_df$answer) &
          (is.na(sheet_df$status) | sheet_df$status == "open")
  flips <- sheet_df$id[flip]
  sheet_df$status[flip] <- "answered"

  out <- csv_df
  diffs <- data.frame(id = character(), label = character(), field = character(),
                       old = character(), new = character(), note = character(),
                       stringsAsFactors = FALSE)
  for (i in seq_len(nrow(sheet_df))) {
    rid <- sheet_df$id[i]
    ri  <- match(rid, out$id)
    for (cl in qs_editable_cols()) {
      old <- out[[cl]][ri]; new <- sheet_df[[cl]][i]
      changed <- !identical(old, new) && !(is.na(old) && is.na(new))
      if (changed) {
        note <- if (cl == "status" && rid %in% flips)
          "auto-flip: answer present, status was open" else ""
        diffs <- rbind(diffs, data.frame(
          id = rid, label = out$label[ri], field = cl,
          old = ifelse(is.na(old), "", old), new = ifelse(is.na(new), "", new),
          note = note, stringsAsFactors = FALSE))
        out[[cl]][ri] <- new
      }
    }
  }

  if (length(flips))
    warning("auto-flipped to answered (answer present, status was open): ",
            paste(unique(flips), collapse = ", "), call. = FALSE)

  list(df = out, diffs = diffs, flips = unique(flips))
}

#' Write a questions.csv the safe way (na = "") and re-read it immediately so
#' a bad write trips read_questions()'s validator right here, not at some
#' later reader — same pattern as calcofi4db::register_measurement_types().
qs_write_questions_csv <- function(df, path) {
  readr::write_csv(df, path, na = "")
  calcofi4db::read_questions(path)
}

#' Sorted 0-based column indices -> list of {start, end} (end exclusive)
#' contiguous runs, for building minimal protected-range column spans.
qs_contiguous_ranges <- function(idx0) {
  if (!length(idx0)) return(list())
  idx0 <- sort(unique(idx0))
  if (length(idx0) == 1) return(list(list(start = idx0[1], end = idx0[1] + 1L)))
  brk    <- which(diff(idx0) != 1)
  starts <- idx0[c(1, brk + 1)]
  ends   <- idx0[c(brk, length(idx0))]
  Map(function(s, e) list(start = s, end = e + 1L), starts, ends)
}

#' Sheets API addProtectedRange requests: one per contiguous run of protected
#' (non-editable) columns (whole column, every row including the header), plus
#' one per contiguous run of *editable* columns' header row only (so a
#' provider can edit the data cells but cannot rename a column the pull
#' matches by name).
qs_protection_requests <- function(sheet_id, col_names, editable_cols = qs_editable_cols()) {
  editable_idx0 <- match(editable_cols, col_names) - 1L
  if (anyNA(editable_idx0))
    stop("editable column(s) not found in tab: ",
         paste(editable_cols[is.na(editable_idx0)], collapse = ", "), call. = FALSE)
  protected_idx0 <- setdiff(seq_along(col_names) - 1L, editable_idx0)

  col_reqs <- lapply(qs_contiguous_ranges(protected_idx0), function(r) list(addProtectedRange = list(
    protectedRange = list(
      range = list(sheetId = sheet_id, startColumnIndex = r$start, endColumnIndex = r$end),
      description = "generated by scripts/sync_questions_sheets.R — edit in the GitHub CSV instead",
      warningOnly = FALSE))))

  hdr_reqs <- lapply(qs_contiguous_ranges(sort(editable_idx0)), function(r) list(addProtectedRange = list(
    protectedRange = list(
      range = list(sheetId = sheet_id, startRowIndex = 0L, endRowIndex = 1L,
                   startColumnIndex = r$start, endColumnIndex = r$end),
      description = "header — do not rename, the pull matches columns by name",
      warningOnly = FALSE))))

  c(col_reqs, hdr_reqs)
}

#' One setDataValidation request restricting the `status` column's data rows
#' (not the header) to the controlled vocabulary.
qs_validation_request <- function(sheet_id, col_names, nrow_data,
                                   values = calcofi4db::question_statuses()) {
  idx0 <- match("status", col_names) - 1L
  if (is.na(idx0)) stop("no 'status' column in tab", call. = FALSE)
  list(setDataValidation = list(
    range = list(sheetId = sheet_id, startRowIndex = 1L, endRowIndex = 1L + nrow_data,
                 startColumnIndex = idx0, endColumnIndex = idx0 + 1L),
    rule = list(
      condition = list(type = "ONE_OF_LIST",
                        values = lapply(values, function(v) list(userEnteredValue = v))),
      showCustomUi = TRUE,
      strict = TRUE)))
}

#' The README tab's content.
qs_readme_content <- function(provider_short) {
  data.frame(
    Field = c(
      "What is this?", "", "Columns you can edit", "answer", "status",
      "answered_date", "who", "", "Every other column", "", "status values",
      "priority values (reference only)", "", "Source of record"),
    Description = c(
      glue::glue("Open questions on the {provider_short} data as it is being integrated ",
                 "into the CalCOFI database. One tab per dataset."),
      "",
      "Only these four columns are unlocked for editing:",
      "your answer, in plain text",
      "one of: open | proposed | answered | wontfix (pick from the dropdown)",
      "the date you answered (any format is fine)",
      "your name / initials",
      "",
      "Every other column (id, label, question, context, priority, proposed_answer, related_table, related_field) is generated and locked. Editing it here will not be saved.",
      "",
      "open = no answer yet. proposed = we already have an answer and want you to confirm or correct it (see proposed_answer). answered = settled, see answer. wontfix = closed without an answer, deliberately.",
      "blocker > high > normal > low — how urgently we need an answer.",
      "",
      glue::glue("The record for these questions is the CalCOFI GitHub repository ",
                 "(github.com/CalCOFI/workflows, metadata/{{provider}}/{{dataset}}/questions.csv). ",
                 "Edits to answer / status / answered_date / who here are pulled back into that ",
                 "file by the data team; edits to any other column are not saved.")),
    stringsAsFactors = FALSE)
}

# network-touching orchestration --------------------------------------------
# Cannot be exercised without Google auth — see the header comment for exactly
# what to run. Written carefully but unverified against a live sheet; the
# checkpoint / hand-back notes flag the one known risk (protection is applied
# only at tab creation, see gs_push_provider()).

qs_provider_registry <- function(path = PROVIDER_CSV) {
  d <- utils::read.csv(path, stringsAsFactors = FALSE)
  d[d$status == "active", , drop = FALSE]
}

qs_dataset_paths <- function(provider) {
  sort(Sys.glob(here(glue::glue("metadata/{provider}/*/questions.csv"))))
}

qs_load_sheets_yml <- function(path = SHEETS_YML) yaml::read_yaml(path)

qs_save_sheets_yml <- function(x, path = SHEETS_YML) {
  # keep provider order stable (active-registry order) rather than
  # yaml::write_yaml's arbitrary list order, so re-writes produce a minimal
  # git diff — but union, not intersect: a provider not (yet, or no longer)
  # in the active registry must still be written, never silently dropped
  reg_order <- qs_provider_registry()$provider
  ord <- c(intersect(reg_order, names(x)), setdiff(names(x), reg_order))
  yaml::write_yaml(x[ord], path)
}

#' Where the sheets live. A service account has NO Drive storage quota, so a
#' bare gs4_create() (which creates in the caller's own My Drive) answers 403
#' PERMISSION_DENIED (measured 2026-09-03). Files created inside a Shared Drive
#' are owned by the drive, so the script creates every sheet through the Drive
#' API inside one folder there: `QS_DRIVE_FOLDER` (a folder id), or — by default —
#' a folder named QS_FOLDER_NAME under QS_DRIVE_PARENT ("CalCOFI Data Folder",
#' itself inside the org Shared Drive), created on first use and recorded in
#' metadata/questions_sheets.yml under `_folder` so every later run reuses it.
QS_DRIVE_PARENT <- Sys.getenv("QS_DRIVE_PARENT", "1KYo8-WiWpdYcvHU8CBPvPhJdJdOym0oW")
QS_FOLDER_NAME  <- "questions"

#' Shared-Drive-aware Drive API calls (googledrive's helpers scope a query to
#' the drive, which a member of the FOLDER but not the DRIVE cannot see).
qs_drive_list <- function(parent, mime = NULL) {
  q <- sprintf("'%s' in parents and trashed = false", parent)
  if (!is.null(mime)) q <- sprintf("%s and mimeType = '%s'", q, mime)
  req <- googledrive::request_generate("drive.files.list", params = list(
    q = q, supportsAllDrives = TRUE, includeItemsFromAllDrives = TRUE,
    pageSize = 200, fields = "files(name,id,mimeType,webViewLink)"))
  gargle::response_process(googledrive::request_make(req))$files
}

qs_ensure_folder <- function(yml, sheets_yml_path = SHEETS_YML) {
  env_id <- Sys.getenv("QS_DRIVE_FOLDER", "")
  if (nzchar(env_id)) return(env_id)
  if (!is.null(yml[["_folder"]]$id) && nzchar(yml[["_folder"]]$id)) return(yml[["_folder"]]$id)
  hits <- Filter(function(f) identical(f$name, QS_FOLDER_NAME),
                 qs_drive_list(QS_DRIVE_PARENT, "application/vnd.google-apps.folder"))
  if (length(hits)) {
    id <- hits[[1]]$id; url <- hits[[1]]$webViewLink %||% NA_character_
  } else {
    f  <- googledrive::drive_mkdir(QS_FOLDER_NAME, path = googledrive::as_id(QS_DRIVE_PARENT))
    id <- as.character(f$id); url <- f$drive_resource[[1]]$webViewLink %||% NA_character_
    qcat("created Drive folder '{QS_FOLDER_NAME}' under {QS_DRIVE_PARENT}: {id}")
  }
  yml[["_folder"]] <- list(id = id, url = url, parent = QS_DRIVE_PARENT)
  qs_save_sheets_yml(yml, sheets_yml_path)
  id
}

gs_ensure_spreadsheet <- function(provider, short, entry, folder_id) {
  if (!is.null(entry$sheet_id) && nzchar(entry$sheet_id))
    return(googlesheets4::as_sheets_id(entry$sheet_id))
  name <- glue::glue("CalCOFI integrated database — questions for {short}")
  f  <- googledrive::drive_create(as.character(name), path = googledrive::as_id(folder_id),
                                  type = "spreadsheet")
  ss <- googlesheets4::as_sheets_id(as.character(f$id))
  # drive_create() gives one tab named "Sheet1"; the README tab is the front page
  googlesheets4::sheet_rename(ss, sheet = 1, new_name = "README")
  ss
}

#' Push provider(s) questions.csv content to their Google Sheet.
#'
#' Dry run (execute=FALSE) touches no network at all: it prints what would be
#' written (tab, row count, pending asked_date stamps). --execute creates the
#' spreadsheet if needed (first time only: shares with share_with, writes
#' sheet_id/url/created into the yml), writes the README + each dataset tab,
#' and — only for a tab that did not already exist — applies column protection
#' and status-column validation (sheet_write() does not clear existing
#' protected ranges, so re-adding them on every push would pile up
#' duplicates; if the column layout ever changes, an existing tab's
#' protection/validation must be reset by hand).
gs_push_provider <- function(provider, sheets_yml_path = SHEETS_YML, execute = FALSE,
                              share_with = SHARE_WITH) {
  yml   <- qs_load_sheets_yml(sheets_yml_path)
  entry <- yml[[provider]]
  paths <- qs_dataset_paths(provider)
  if (!length(paths)) {
    qcat("{provider}: no questions.csv files — nothing to push")
    return(invisible(NULL))
  }

  plan <- lapply(paths, function(p) {
    ds  <- basename(dirname(p))
    df  <- qs_read_csv_raw(p)
    stamped <- qs_stamp_asked_dates(df)
    list(path = p, dataset = ds, tab = qs_tab_name(provider, ds),
         df = stamped$df, n_stamped = stamped$n_stamped)
  })

  qcat("push plan for {provider}: {length(plan)} dataset tab(s)")
  for (pl in plan)
    qcat("  {pl$tab}: {nrow(pl$df)} row(s)",
         if (pl$n_stamped > 0) glue::glue(", {pl$n_stamped} asked_date to stamp") else "")

  if (!isTRUE(execute)) { cat("dry run — pass --execute to write\n"); return(invisible(plan)) }

  reg   <- qs_provider_registry()
  short <- reg$provider_short[match(provider, reg$provider)]
  if (is.na(short)) short <- provider

  is_new_sheet <- is.null(entry$sheet_id) || !nzchar(entry$sheet_id)
  folder_id <- qs_ensure_folder(yml, sheets_yml_path)
  yml <- qs_load_sheets_yml(sheets_yml_path)   # qs_ensure_folder() may have written _folder
  ss <- gs_ensure_spreadsheet(provider, short, entry, folder_id)
  if (is_new_sheet) {
    meta <- googlesheets4::gs4_get(ss)
    yml[[provider]] <- list(sheet_id = as.character(ss), url = meta$spreadsheet_url,
                             created = format(Sys.Date()))
    qs_save_sheets_yml(yml, sheets_yml_path)
    # the folder's own sharing (Shared Drive membership) is what normally grants
    # access; per-file sharing is additive, silent (no notification e-mail — the
    # provider e-mail carries the link), and a refusal is reported, not fatal
    share_with <- setdiff(tolower(share_with), getOption("qs.auth_user", character()))
    shared <- character()
    for (email in share_with) {
      ok <- tryCatch({
        googledrive::drive_share(googledrive::as_id(as.character(ss)), role = "writer",
                                  type = "user", emailAddress = email,
                                  sendNotificationEmail = FALSE); TRUE },
        error = function(e) { qcat("  share with {email} refused: {substr(conditionMessage(e), 1, 80)}"); FALSE })
      if (ok) shared <- c(shared, email)
    }
    qcat("created {meta$spreadsheet_url} in folder {folder_id}; shared with {paste(shared, collapse=', ')}")
  }

  googlesheets4::sheet_write(qs_readme_content(short), ss = ss, sheet = "README")

  for (pl in plan) {
    googlesheets4::sheet_write(pl$df, ss = ss, sheet = pl$tab)
    # protection + validation are applied once per tab: skipped when the tab
    # already carries a protected range (sheet_write() keeps them, so re-adding
    # on every push would pile up duplicates; an interrupted first push is
    # therefore completed by the next one, not left unprotected)
    props <- googlesheets4::sheet_properties(ss)
    sid   <- props$id[props$name == pl$tab]
    protect <- !qs_tab_is_protected(ss, sid)
    if (protect) {
      reqs <- c(qs_protection_requests(sid, names(pl$df)),
                list(qs_validation_request(sid, names(pl$df), nrow(pl$df))))
      # gargle's endpoint registry takes the batchUpdate body fields as params
      googlesheets4::request_make(googlesheets4::request_generate(
        "sheets.spreadsheets.batchUpdate",
        params = list(spreadsheetId = as.character(ss), requests = reqs)))
    }
    if (pl$n_stamped > 0) qs_write_questions_csv(pl$df, pl$path)
    qcat("  wrote {pl$tab} ({nrow(pl$df)} rows){if (protect) ' + protection/validation' else ''}")
  }
  invisible(ss)
}

#' Does a tab already carry any protected range?
qs_tab_is_protected <- function(ss, sid) {
  req <- googlesheets4::request_generate("sheets.spreadsheets.get", params = list(
    spreadsheetId = as.character(ss),
    fields = "sheets(properties(sheetId),protectedRanges(protectedRangeId))"))
  js <- gargle::response_process(googlesheets4::request_make(req))
  for (sh in js$sheets)
    if (identical(as.numeric(sh$properties$sheetId), as.numeric(sid)))
      return(length(sh$protectedRanges %||% list()) > 0)
  FALSE
}

#' Pull provider(s) editable columns back from their Google Sheet into
#' questions.csv. Always reads (needs the sheet to compute a diff) and always
#' prints the diff; --execute additionally writes the CSV.
gs_pull_provider <- function(provider, sheets_yml_path = SHEETS_YML, execute = FALSE) {
  yml   <- qs_load_sheets_yml(sheets_yml_path)
  entry <- yml[[provider]]
  if (is.null(entry$sheet_id) || !nzchar(entry$sheet_id))
    stop(provider, ": no sheet_id in ", sheets_yml_path,
         " — run `push ", provider, " --execute` first", call. = FALSE)
  ss <- googlesheets4::as_sheets_id(entry$sheet_id)

  paths <- qs_dataset_paths(provider)
  any_diff <- FALSE
  for (p in paths) {
    ds  <- basename(dirname(p))
    tab <- qs_tab_name(provider, ds)
    csv_df <- qs_read_csv_raw(p)
    sheet_df <- tryCatch(
      googlesheets4::range_read(ss, sheet = tab, col_types = "c"),
      error = function(e) NULL)
    if (is.null(sheet_df)) { qcat("{tab}: no tab in sheet — skipping"); next }

    res <- qs_apply_pull(csv_df, sheet_df, path = p)
    if (nrow(res$diffs)) {
      any_diff <- TRUE
      cat("\n")
      qcat("{tab}: {nrow(res$diffs)} change(s)")
      print(as.data.frame(res$diffs), row.names = FALSE)
      if (length(res$flips))
        cat("  auto-flipped to answered: ", paste(res$flips, collapse = ", "), "\n")
      if (isTRUE(execute)) {
        qs_write_questions_csv(res$df, p)
        cat("  wrote ", p, "\n")
      }
    } else {
      qcat("{tab}: no changes")
    }
  }
  if (!isTRUE(execute)) cat("\ndry run — pass --execute to write\n")
  invisible(any_diff)
}

# CLI -----------------------------------------------------------------------

.main <- function(args = commandArgs(trailingOnly = TRUE)) {
  flags   <- args[grepl("^--", args)]
  pos     <- args[!grepl("^--", args)]
  execute <- "--execute" %in% flags
  if (!length(pos))
    stop("usage: Rscript scripts/sync_questions_sheets.R <push|pull> [provider] [--execute]", call. = FALSE)
  mode         <- pos[1]
  provider_arg <- if (length(pos) >= 2) pos[2] else NULL
  if (!mode %in% c("push", "pull"))
    stop("unknown mode '", mode, "' — expected push or pull", call. = FALSE)

  providers <- if (!is.null(provider_arg)) provider_arg else
    intersect(qs_provider_registry()$provider, names(qs_load_sheets_yml()))

  # a push dry run touches no Google API; everything else does
  if (mode == "pull" || execute) options(qs.auth_user = qs_auth())

  for (pv in providers) {
    if (mode == "push") gs_push_provider(pv, execute = execute)
    else                gs_pull_provider(pv, execute = execute)
  }
}

# run only when invoked as `Rscript scripts/sync_questions_sheets.R ...`, not
# when source()'d (e.g. by the test script)
if (sys.nframe() == 0) .main()
