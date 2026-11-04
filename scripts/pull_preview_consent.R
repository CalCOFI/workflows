#!/usr/bin/env Rscript
# pull_preview_consent.R — fold each decision a provider makes in a dataset's private preview
# (preview/, the calcofi-preview service) into the dataset's standing consent question, push
# that row to the provider's Google Sheet and commit the CSV, so the Sheet, git and the release
# gate all see one answer (Ben, 2026-11-04: "the preview form should update the Google Sheet
# questions it pulls from, which is then what the ingest uses").
#
#   Rscript scripts/pull_preview_consent.R [--bucket calcofi-preview] [--execute] [--push-sheets] [--commit]
#
# Without --execute it is a dry run: it lists the decisions and prints the plan, touching
# nothing. The decisions are the objects consent/{key}/{utc}_{email}.json the service writes
# (preview/app/consent.py: dataset_key, decision yes | not_yet, comment, email, name, via,
# recorded_utc, build_id, question_id, question, release_candidate, attribution.{citation_main,
# license_name, license_url, acknowledgement}.{value, changed}); one that already has a sibling
# marker {name}.applied.json was applied by an earlier run and is skipped. The rest are applied
# oldest first per dataset to the consent row of metadata/{provider}/{dataset}/questions.csv
# (related_field = consent; provider and dataset come from the key's entry in
# calcofi4db::read_ingest_yaml(), never from a split on the first underscore).
#
# The rule (consent_apply(), pure, unit-tested in scripts/test_pull_preview_consent.R):
#   yes      status answered, answer = "Yes" + the comment + one line per attribution field the
#            reviewer changed, who = "Name <email>", answered_date = the date of recorded_utc —
#            unless the row is already closed (answered | wontfix): a pull never moves a status
#            back or overwrites a provider's answer, so the row is kept and reported.
#   not_yet  status unchanged; "YYYY-MM-DD not yet (Name): comment" appended to context, once.
#
# --execute writes each changed questions.csv (readr::write_csv(na = ""), the file's own row
# order, re-read through read_questions() to validate). --push-sheets then runs
# `Rscript scripts/sync_questions_sheets.R push {provider} --execute` for each provider touched,
# so the provider's Sheet tab shows the answered row (that push refuses while the sheet holds
# unpulled edits; pull them first). --commit commits only the questions.csv files this run
# changed, on main after `git pull --ff-only`, and pushes; it refuses (before applying anything)
# when the checkout is not on main or the pull fails. The marker is written last, after every
# requested step succeeded, so a run that fails part way is simply repeated: the rule is
# idempotent.
#
# Needs: the active gcloud account able to read and write gs://{bucket}/consent/ (on the data
# team's machine, `source ~/.config/calcofi/env.sh` makes it the calcofi-admin service
# account). Deps beyond calcofi4db, all CRAN, via librarian::shelf(): readr, jsonlite, here.
# Schedule it with scripts/launchd/io.calcofi.preview-consent.plist (preview/README.md).
suppressMessages(librarian::shelf(readr, jsonlite, here, calcofi4db, quiet = TRUE))

PC_BUCKET_DEFAULT <- "calcofi-preview"
PC_PUBLIC_BUCKETS <- c("calcofi-db", "calcofi-files-public")
PC_ATTRIBUTION_FIELDS <- c("citation_main", "license_name", "license_url", "acknowledgement")

# pure / network-free -----------------------------------------------------
# unit-tested in scripts/test_pull_preview_consent.R without any network call

#' A blank, NULL or NA value as "" so the record's fields can be pasted freely.
pc_chr <- function(x) {
  if (is.null(x) || length(x) == 0 || is.na(x[[1]])) return("")
  trimws(as.character(x[[1]]))
}

#' Read a questions.csv validated by read_questions() but in the file's own row order
#' (read_questions() re-sorts by priority, which would reorder the file on every write).
pc_read_questions <- function(path) {
  calcofi4db::read_questions(path)
  readr::read_csv(path, na = "", show_col_types = FALSE,
                  col_types = readr::cols(.default = readr::col_character()))
}

#' Write a questions.csv the safe way (na = "") and re-read it so a bad write trips the
#' validator here, not at a later reader.
pc_write_questions <- function(df, path) {
  readr::write_csv(df, path, na = "")
  calcofi4db::read_questions(path)
  invisible(path)
}

#' provider and dataset of a dataset_key, from its entry in the ingest YAML (a list keyed by
#' provider_dataset, as read_ingest_yaml() returns); NULL when no notebook declares the key.
pc_split_key <- function(key, ingest_yaml) {
  e <- ingest_yaml[[key]]
  if (is.null(e) || is.null(e$provider) || is.null(e$dataset)) return(NULL)
  list(provider = e$provider, dataset = e$dataset,
       questions_csv = file.path("metadata", e$provider, e$dataset, "questions.csv"))
}

#' Index of the consent row (related_field == "consent"); integer(0) when there is none.
pc_consent_row <- function(q) {
  if (!"related_field" %in% names(q)) return(integer(0))
  which(!is.na(q$related_field) & q$related_field == "consent")
}

#' "Name <email>", or whichever of the two the record holds.
pc_who <- function(rec) {
  name <- pc_chr(rec$name); email <- pc_chr(rec$email)
  if (nzchar(name) && nzchar(email)) return(sprintf("%s <%s>", name, email))
  if (nzchar(name)) name else email
}

#' The date (YYYY-MM-DD) of the record's recorded_utc.
pc_date <- function(rec) substr(pc_chr(rec$recorded_utc), 1, 10)

#' One line per attribution field the reviewer changed in the preview's form.
pc_attribution_lines <- function(rec) {
  a <- rec$attribution
  if (is.null(a)) return(character(0))
  out <- character(0)
  for (f in PC_ATTRIBUTION_FIELDS) {
    v <- a[[f]]
    if (is.null(v) || !isTRUE(v$changed)) next
    out <- c(out, sprintf("%s as given in the preview: %s", f, pc_chr(v$value)))
  }
  out
}

#' Apply one preview decision to a questions table. Data frame in, data frame out: the same
#' columns in the same order, the same rows in the same order, with only the consent row's
#' cells changed. The outcome is on the result as attr(, "consent_action"), one of
#'   answered        decision yes applied: status answered, answer, who, answered_date set
#'   kept            decision yes on a row already closed (answered | wontfix): untouched
#'   noted           decision not_yet: a "not yet" line appended to context
#'   already_noted   decision not_yet whose line context already holds: untouched
#'   no_consent_row  the table has no related_field == "consent" row: untouched
#' and attr(, "consent_note") says why in a sentence.
consent_apply <- function(q, rec) {
  decision <- pc_chr(rec$decision)
  stopifnot("decision must be yes or not_yet" = decision %in% c("yes", "not_yet"))
  out <- q
  i <- pc_consent_row(q)
  done <- function(df, action, note) {
    attr(df, "consent_action") <- action
    attr(df, "consent_note")   <- note
    df
  }
  if (length(i) != 1)
    return(done(out, "no_consent_row",
                if (length(i)) "more than one related_field = consent row" else "no related_field = consent row"))
  who <- pc_who(rec); date <- pc_date(rec); comment <- pc_chr(rec$comment)

  if (decision == "yes") {
    status <- pc_chr(q$status[i])
    if (status %in% c("answered", "wontfix"))
      return(done(out, "kept", sprintf("row %s is already %s (%s, %s); a pull never overwrites a provider's answer",
                                       pc_chr(q$label[i]), status, pc_chr(q$who[i]), pc_chr(q$answered_date[i]))))
    answer <- c("Yes", if (nzchar(comment)) comment, pc_attribution_lines(rec))
    out$status[i]        <- "answered"
    out$answer[i]        <- paste(answer, collapse = "\n")
    out$who[i]           <- who
    out$answered_date[i] <- date
    return(done(out, "answered", sprintf("row %s answered by %s on %s", pc_chr(q$label[i]), who, date)))
  }

  # not_yet: the status stays; the context records who said not yet, when, and why
  line <- sprintf("%s not yet (%s)%s", date, if (nzchar(pc_chr(rec$name))) pc_chr(rec$name) else who,
                  if (nzchar(comment)) paste0(": ", comment) else "")
  ctx <- pc_chr(q$context[i])
  if (nzchar(ctx) && line %in% strsplit(ctx, "\n", fixed = TRUE)[[1]])
    return(done(out, "already_noted", sprintf("row %s already notes '%s'", pc_chr(q$label[i]), line)))
  out$context[i] <- if (nzchar(ctx)) paste(ctx, line, sep = "\n") else line
  done(out, "noted", sprintf("row %s: appended '%s' to context", pc_chr(q$label[i]), line))
}

#' The marker object beside a decision: consent/{key}/{utc}_{email}.applied.json.
pc_marker_name <- function(obj) sub("\\.json$", ".applied.json", obj)

#' Decisions newest last per dataset: the order they are applied in.
pc_order_records <- function(recs) {
  if (!length(recs)) return(recs)
  key <- vapply(recs, function(r) pc_chr(r$dataset_key), "")
  utc <- vapply(recs, function(r) pc_chr(r$recorded_utc), "")
  recs[order(key, utc)]
}

#' The commit message for the questions.csv files one run changed: one applied record gives
#' "{key}: consent {decision} from the preview ({who}, {date})" with the attribution lines
#' below; several give a summary subject and one such line each.
pc_commit_message <- function(applied) {
  line <- function(a) sprintf("%s: consent %s from the preview (%s, %s)",
                              a$key, a$decision, a$who, a$date)
  if (length(applied) == 1) {
    a <- applied[[1]]
    body <- a$attribution
  } else {
    body <- unlist(lapply(applied, function(a) c(line(a), paste0("  ", a$attribution))))
  }
  subject <- if (length(applied) == 1) line(applied[[1]]) else
    sprintf("preview consent: %d decisions from the preview", length(applied))
  paste(c(subject, if (length(body)) c("", body)), collapse = "\n")
}

# network-touching orchestration --------------------------------------------

pc_gcloud <- function(args, input = NULL) {
  out <- system2("gcloud", args, stdout = TRUE, stderr = TRUE, input = input)
  status <- attr(out, "status")
  if (!is.null(status) && status != 0)
    stop("gcloud ", paste(args, collapse = " "), " failed: ", paste(out, collapse = "\n"), call. = FALSE)
  out
}

#' Every object under consent/ in the bucket (gcloud storage ls -r); none is not an error.
pc_list_consent <- function(bucket) {
  out <- suppressWarnings(system2("gcloud", c("storage", "ls", "-r", shQuote(sprintf("gs://%s/consent/**", bucket))),
                                  stdout = TRUE, stderr = TRUE))
  out <- trimws(out)
  out[startsWith(out, "gs://")]
}

pc_read_record <- function(obj) {
  txt <- pc_gcloud(c("storage", "cat", shQuote(obj)))
  rec <- jsonlite::fromJSON(paste(txt, collapse = "\n"), simplifyVector = FALSE)
  rec$object <- obj
  rec
}

pc_write_marker <- function(obj, payload) {
  f <- tempfile(fileext = ".json")
  on.exit(unlink(f))
  jsonlite::write_json(payload, f, auto_unbox = TRUE, pretty = TRUE, null = "null")
  pc_gcloud(c("storage", "cp", shQuote(f), shQuote(pc_marker_name(obj))))
  invisible(pc_marker_name(obj))
}

pc_git <- function(root, args, stop_on_error = TRUE) {
  out <- system2("git", c("-C", shQuote(root), args), stdout = TRUE, stderr = TRUE)
  status <- attr(out, "status")
  if (stop_on_error && !is.null(status) && status != 0)
    stop("git ", paste(args, collapse = " "), " failed: ", paste(out, collapse = "\n"), call. = FALSE)
  out
}

#' Refuse to commit from anywhere but an up-to-date main: the questions.csv files are shared
#' with every other session, and a commit off a stale or side branch would never reach the
#' Sheet's source of truth.
pc_check_commit_ready <- function(root) {
  branch <- pc_git(root, c("rev-parse", "--abbrev-ref", "HEAD"))
  if (!identical(branch, "main"))
    stop("--commit needs the checkout on main, not '", branch, "'", call. = FALSE)
  pull <- pc_git(root, c("pull", "--ff-only", "--quiet"), stop_on_error = FALSE)
  if (!is.null(attr(pull, "status")) && attr(pull, "status") != 0)
    stop("--commit: `git pull --ff-only` failed (", paste(pull, collapse = " "), "); fix the checkout first",
         call. = FALSE)
  invisible(TRUE)
}

pc_push_sheets <- function(root, provider) {
  script <- file.path(root, "scripts/sync_questions_sheets.R")
  status <- system2("Rscript", c(shQuote(script), "push", provider, "--execute"))
  if (status != 0)
    stop("sync_questions_sheets.R push ", provider, " --execute failed (exit ", status,
         "); pull the sheet first if it holds unpulled edits, then re-run", call. = FALSE)
  invisible(TRUE)
}

pc_main <- function(args = commandArgs(trailingOnly = TRUE)) {
  execute <- "--execute" %in% args
  push    <- "--push-sheets" %in% args
  commit  <- "--commit" %in% args
  bucket  <- PC_BUCKET_DEFAULT
  if (any(grepl("^--bucket=", args))) bucket <- sub("^--bucket=", "", args[grepl("^--bucket=", args)][1])
  if ("--bucket" %in% args) bucket <- args[which(args == "--bucket") + 1]
  if (is.na(bucket) || !nzchar(bucket)) stop("--bucket needs a name", call. = FALSE)
  if (bucket %in% PC_PUBLIC_BUCKETS)
    stop("refusing the public bucket ", bucket, ": decisions live in the private preview bucket", call. = FALSE)
  root <- here::here()

  objs    <- pc_list_consent(bucket)
  markers <- objs[endsWith(objs, ".applied.json")]
  pending <- objs[endsWith(objs, ".json") & !endsWith(objs, ".applied.json")]
  pending <- pending[!pc_marker_name(pending) %in% markers]
  cat(sprintf("gs://%s/consent/: %d decision object(s), %d applied before, %d to consider\n",
              bucket, sum(endsWith(objs, ".json")) - length(markers), length(markers), length(pending)))
  if (!length(pending)) {
    if (!execute) cat("dry run: nothing to apply\n")
    return(invisible(list()))
  }

  recs <- pc_order_records(lapply(pending, pc_read_record))
  yml  <- calcofi4db::read_ingest_yaml(root)
  if (commit && execute) pc_check_commit_ready(root)

  # the plan: every pending record against the current CSV, in order, each dataset's table
  # carried from one record to the next so a yes followed by a not yet lands on one table
  tables <- list(); applied <- list(); changed <- character(); skipped <- list()
  for (rec in recs) {
    key <- pc_chr(rec$dataset_key); decision <- pc_chr(rec$decision)
    head_line <- sprintf("%s  %s  %-7s %s", rec$object, pc_date(rec), decision, pc_who(rec))
    ds <- pc_split_key(key, yml)
    if (is.null(ds)) {
      cat(head_line, "\n  skip: no ingest notebook declares dataset_key", key, "\n")
      skipped[[rec$object]] <- "no ingest notebook declares the dataset_key"; next
    }
    path <- file.path(root, ds$questions_csv)
    if (!file.exists(path)) {
      cat(head_line, "\n  skip: no", ds$questions_csv, "\n")
      skipped[[rec$object]] <- paste("no", ds$questions_csv); next
    }
    q <- if (!is.null(tables[[path]])) tables[[path]] else pc_read_questions(path)
    if (!length(pc_consent_row(q))) {
      cat(head_line, "\n  skip:", ds$questions_csv, "has no related_field = consent row\n")
      skipped[[rec$object]] <- "no consent row"; next
    }
    qid <- pc_chr(rec$question_id); rid <- pc_chr(q$id[pc_consent_row(q)])
    res <- consent_apply(q, rec)
    action <- attr(res, "consent_action"); note <- attr(res, "consent_note")
    cat(head_line, "\n  ", ds$questions_csv, ": ", action, " — ", note,
        if (nzchar(qid) && qid != rid) sprintf(" (the preview asked %s, the consent row is %s)", qid, rid) else "",
        "\n", sep = "")
    for (l in pc_attribution_lines(rec)) cat("    ", l, "\n", sep = "")
    tables[[path]] <- res
    if (action %in% c("answered", "noted")) changed <- union(changed, path)
    applied[[rec$object]] <- list(
      object = rec$object, key = key, provider = ds$provider, decision = decision, who = pc_who(rec),
      date = pc_date(rec), action = action, note = note, questions_csv = ds$questions_csv,
      attribution = pc_attribution_lines(rec), path = path)
  }

  if (!execute) {
    cat(sprintf("\ndry run: %d record(s) would be applied (%d questions.csv to write, %d skipped); pass --execute\n",
                length(applied), length(changed), length(skipped)))
    return(invisible(applied))
  }

  # execute: CSVs, then the Sheet, then git, then the markers (last, so a failure part way
  # leaves the decision pending and the next run repeats the idempotent rule)
  for (path in changed) {
    pc_write_questions(tables[[path]], path)
    cat("wrote", sub(paste0("^", root, "/"), "", path), "\n")
  }
  if (push && length(changed)) {
    for (pv in unique(vapply(applied, function(a) a$provider, ""))) {
      if (!any(vapply(applied, function(a) a$provider == pv && a$path %in% changed, NA))) next
      cat("pushing the", pv, "sheet\n")
      pc_push_sheets(root, pv)
    }
  }
  sha <- NA_character_
  if (commit && length(changed)) {
    rel <- sub(paste0("^", root, "/"), "", changed)
    pc_git(root, c("add", "--", shQuote(rel)))
    staged <- pc_git(root, c("diff", "--cached", "--name-only", "--", shQuote(rel)))
    if (length(staged)) {
      acted <- Filter(function(a) a$action %in% c("answered", "noted"), applied)
      msg <- pc_commit_message(unname(acted))
      f <- tempfile(fileext = ".txt"); on.exit(unlink(f), add = TRUE)
      writeLines(msg, f)
      pc_git(root, c("commit", "--quiet", "-F", shQuote(f), "--", shQuote(rel)))
      sha <- pc_git(root, c("rev-parse", "--short", "HEAD"))
      pc_git(root, c("push", "--quiet"))
      cat("committed", sha, "and pushed:", strsplit(msg, "\n")[[1]][1], "\n")
    } else {
      cat("nothing to commit: the files already hold the result\n")
    }
  }
  for (a in applied) {
    pc_write_marker(a$object, list(
      applied_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      dataset_key = a$key, decision = a$decision, action = a$action, note = a$note,
      questions_csv = a$questions_csv, who = a$who, date = a$date,
      attribution = I(a$attribution),
      sheet_pushed = push && a$path %in% changed,
      commit = if (commit && !is.na(sha)) sha else NULL))
  }
  cat(sprintf("applied %d record(s): %d questions.csv written, %d marker(s) set, %d skipped\n",
              length(applied), length(changed), length(applied), length(skipped)))
  invisible(applied)
}

# run only when invoked as `Rscript scripts/pull_preview_consent.R ...`, not when source()'d
# by the test script
if (sys.nframe() == 0) pc_main()
