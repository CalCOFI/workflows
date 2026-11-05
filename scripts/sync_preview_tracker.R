#!/usr/bin/env Rscript
# Preview tracker — the internal Google Sheet that follows every held dataset
# (`in_release: false`) along the private-preview pathway: its ingest PR(s) and
# their state (open | merged | closed), the candidate release, the private
# preview link, and the consent question the preview's decision form answers.
# One row per held dataset, generated; nothing in it is typed by hand except
# the `notes` column, which a run keeps (Ben, 2026-11-05: "an internal document
# that tracks these preview links with datasets as part of the process ...
# should match with the PRs and note whether open / merged / closed").
#
#   Rscript scripts/sync_preview_tracker.R              # dry run: prints the table, no Sheet write
#   Rscript scripts/sync_preview_tracker.R --execute    # writes the Sheet (creates it the first
#                                                       # time, records it in metadata/preview_tracker.yml)
#
# Sources, all read live:
#   held datasets   calcofi4db::release_excluded_datasets() over the ingest notebooks
#   PRs             `gh pr list --state all --json ... files` on CalCOFI/workflows; a PR belongs to
#                   a dataset when it changed ingest_{key}.qmd, metadata/{provider}/{dataset}/ or
#                   data/parquet/{key}/ (pt_prs_for_dataset(), pure)
#   candidate       gs://calcofi-preview/ducklake-preview-{short}/releases/latest.txt
#   preview         gs://calcofi-preview/datasets/{key}-{token}/current.txt → the link
#                   https://preview.calcofi.io/{key}/{token}/ (what scripts/build_preview.sh wrote)
#   decisions       gs://calcofi-preview/consent/{key}/*.json (the form; pull_preview_consent.R
#                   folds them into the consent question)
#   consent         the related_field = consent row of metadata/{provider}/{dataset}/questions.csv
#
# The Sheet lives in the `questions` folder of the org Shared Drive beside the provider
# question sheets (metadata/questions_sheets.yml `_folder`), is written by the calcofi-admin
# service account (scripts/lib_google_auth.R) and is shared with the data team only — it
# carries the private preview links, so it is never public and never committed.
# Needs `gh` (authenticated) and the active gcloud account able to read gs://calcofi-preview
# (`source ~/.config/calcofi/env.sh`). Deps via librarian::shelf(): googlesheets4,
# googledrive, jsonlite, yaml, readr, here, calcofi4db.
suppressMessages(librarian::shelf(
  googlesheets4, googledrive, jsonlite, yaml, readr, here, calcofi4db, quiet = TRUE))

PT_REPO        <- "CalCOFI/workflows"
PT_BUCKET      <- Sys.getenv("CALCOFI_PREVIEW_BUCKET", "calcofi-preview")
PT_HOST        <- Sys.getenv("PREVIEW_HOST", "preview.calcofi.io")
PT_YML         <- here("metadata/preview_tracker.yml")
PT_SHEETS_YML  <- here("metadata/questions_sheets.yml")
PT_TITLE       <- "CalCOFI integrated database — private preview tracker"
PT_TAB         <- "previews"
# the data team: Ben, Erin, Betty, Mark (Ben, 2026-11-05: "shared only with Betty, Erin, Mark and myself")
PT_SHARE_WITH  <- c("bebest@ucsd.edu", "ben@oceanmetrics.io", "esatterthwaite@ucsd.edu",
                    "bthuang@ucsd.edu", "bhuang0022@gmail.com", "m4gold@ucsd.edu")
PT_COLS <- c("dataset_key", "provider", "dataset_name", "stage", "prs", "pr_state", "pr_url",
             "candidate_version", "preview_url", "preview_build", "decisions",
             "consent_label", "consent_status", "consent_who", "consent_answered",
             "notes", "refreshed_utc")

`%||%` <- function(a, b) if (is.null(a)) b else a

# pure / network-free -----------------------------------------------------
# unit-tested in scripts/test_preview_tracker.R

#' open | merged | closed from a `gh pr list` record (state OPEN | MERGED | CLOSED).
pt_pr_state <- function(state) {
  s <- tolower(state)
  ifelse(s %in% c("open", "merged"), s, ifelse(s == "closed", "closed", NA_character_))
}

#' The PR records (list of lists with number, state, url, title, files = list of {path}) that
#' changed a dataset's notebook, metadata folder or parquet sidecars, oldest first.
pt_prs_for_dataset <- function(prs, key, provider, dataset) {
  wanted <- c(paste0("ingest_", key, ".qmd"),
              paste0("metadata/", provider, "/", dataset, "/"),
              paste0("data/parquet/", key, "/"))
  hit <- vapply(prs, function(pr) {
    paths <- vapply(pr$files %||% list(), function(f) f$path %||% "", "")
    any(paths == wanted[1] | startsWith(paths, wanted[2]) | startsWith(paths, wanted[3]))
  }, logical(1))
  out <- prs[hit]
  out[order(vapply(out, function(pr) as.integer(pr$number), 1L))]
}

#' "#153 merged; #246 merged" and the state of the dataset's first (ingest) PR.
pt_pr_summary <- function(prs) {
  if (!length(prs)) return(list(prs = "", pr_state = "", pr_url = ""))
  st <- pt_pr_state(vapply(prs, function(pr) pr$state, ""))
  nn <- vapply(prs, function(pr) as.integer(pr$number), 1L)
  list(prs = paste0("#", nn, " ", st, collapse = "; "),
       pr_state = st[1], pr_url = prs[[1]]$url %||% "")
}

#' Datasets that exist only in a PR not yet merged (open, or closed without merge): the
#' ingest_{provider}_{dataset}.qmd files those PRs add whose key main does not know. One row
#' per key, the lowest PR number first; a provider slug never holds an underscore.
pt_pr_new_datasets <- function(prs, known_keys) {
  rows <- lapply(prs, function(pr) {
    if (toupper(pr$state) == "MERGED") return(NULL)
    paths <- vapply(pr$files %||% list(), function(f) f$path %||% "", "")
    nb <- grep("^ingest_[a-z0-9-]+_[a-z0-9-]+\\.qmd$", paths, value = TRUE)
    if (!length(nb)) return(NULL)
    key <- sub("^ingest_(.*)\\.qmd$", "\\1", nb)
    key <- key[!key %in% known_keys]
    if (!length(key)) return(NULL)
    data.frame(key = key, provider = sub("_.*$", "", key), dataset = sub("^[^_]+_", "", key),
               number = as.integer(pr$number), branch = pr$headRefName %||% "", stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  if (is.null(out)) return(data.frame(key = character(), provider = character(), dataset = character(),
                                      number = integer(), branch = character(), stringsAsFactors = FALSE))
  out <- out[order(out$number), , drop = FALSE]
  out[!duplicated(out$key), , drop = FALSE]
}

#' Where the dataset stands on the pathway, from what the other columns hold.
pt_stage <- function(pr_state, candidate_version, preview_url, consent_status, n_decisions) {
  if (identical(consent_status, "answered")) return("consent given — ready to un-hold")
  if (nzchar(preview_url %||% "") && n_decisions > 0) return("preview live — decision recorded, not yet pulled")
  if (nzchar(preview_url %||% "")) return("preview live — awaiting the provider's decision")
  if (nzchar(candidate_version %||% "")) return("candidate built — preview not built")
  if (identical(pr_state, "merged")) return("merged, held — candidate not yet built")
  if (identical(pr_state, "open")) return("PR open — not yet merged")
  if (identical(pr_state, "closed")) return("PR closed without merge")
  "held — no PR found"
}

#' Carry the `notes` a person typed in the Sheet across a regeneration (by dataset_key).
pt_keep_notes <- function(new, old) {
  if (is.null(old) || !all(c("dataset_key", "notes") %in% names(old))) return(new)
  m <- match(new$dataset_key, old$dataset_key)
  kept <- ifelse(is.na(m), "", ifelse(is.na(old$notes[m]), "", old$notes[m]))
  new$notes <- ifelse(nzchar(new$notes), new$notes, kept)
  new
}

# live reads ---------------------------------------------------------------

#' Run a command, its args shell-quoted (system2() joins them with spaces, so a header such as
#' "Accept: application/vnd.github.raw" would otherwise split in two); character() on failure.
pt_sh <- function(cmd, args) {
  out <- suppressWarnings(system2(cmd, shQuote(args), stdout = TRUE, stderr = FALSE))
  if (!is.null(attr(out, "status")) && attr(out, "status") != 0) return(character())
  out
}

pt_gh_prs <- function(repo = PT_REPO, limit = 400) {
  txt <- pt_sh("gh", c("pr", "list", "--repo", repo, "--state", "all", "--limit", limit,
                       "--json", "number,title,state,url,headRefName,mergedAt,closedAt,updatedAt,files"))
  if (!length(txt)) stop("gh pr list returned nothing — is gh authenticated?", call. = FALSE)
  jsonlite::fromJSON(paste(txt, collapse = "\n"), simplifyVector = FALSE)
}

pt_gcs_cat <- function(path) {
  out <- pt_sh("gcloud", c("storage", "cat", path))
  if (!length(out)) "" else trimws(out[1])
}

pt_gcs_ls <- function(path) sub("/$", "", basename(pt_sh("gcloud", c("storage", "ls", path))))

#' The preview slugs {key}-{token} the bucket holds, as a named vector token by key.
pt_preview_tokens <- function(bucket = PT_BUCKET) {
  slugs <- pt_gcs_ls(sprintf("gs://%s/datasets/", bucket))
  slugs <- slugs[grepl("-[a-z0-9]{8}$", slugs)]
  tok <- sub(".*-([a-z0-9]{8})$", "\\1", slugs)
  stats::setNames(tok, sub("-[a-z0-9]{8}$", "", slugs))
}

pt_consent_row <- function(path) {
  if (!file.exists(path)) return(NULL)
  q <- tryCatch(calcofi4db::read_questions(path), error = function(e) readr::read_csv(path, show_col_types = FALSE))
  q <- q[!is.na(q$related_field) & q$related_field == "consent", , drop = FALSE]
  if (!nrow(q)) NULL else q[nrow(q), , drop = FALSE]
}

#' The consent row of a dataset's questions.csv as a PR branch holds it (gh api raw contents).
pt_consent_row_ref <- function(provider, dataset, ref, repo = PT_REPO) {
  txt <- pt_sh("gh", c("api", "-H", "Accept: application/vnd.github.raw",
                       sprintf("repos/%s/contents/metadata/%s/%s/questions.csv?ref=%s", repo, provider, dataset, ref)))
  if (!length(txt)) return(NULL)
  f <- tempfile(fileext = ".csv"); writeLines(txt, f); on.exit(unlink(f))
  pt_consent_row(f)
}

#' The candidate root (ducklake-preview-{short}) holding a dataset: the root whose
#' dataset_key.txt names it (preview_candidate.sh stamps it), else — for a root built before
#' the stamp — the one named after the dataset or its first word; `stamped` is a named vector
#' root by dataset_key. Never a root stamped with another dataset.
pt_candidate_root <- function(key, roots, stamped = character()) {
  if (key %in% names(stamped)) return(stamped[[key]])
  roots <- setdiff(roots, stamped)
  dataset <- sub("^[^_]+_", "", key)
  cands <- paste0("ducklake-preview-", c(dataset, sub("-.*$", "", dataset)))
  hit <- cands[cands %in% roots]
  if (length(hit)) hit[1] else NA_character_
}

pt_build_table <- function(workflow_dir = here()) {
  yml  <- calcofi4db::read_ingest_yaml(workflow_dir)
  held <- calcofi4db::release_excluded_datasets(workflow_dir)
  prs  <- pt_gh_prs()
  toks <- pt_preview_tokens()
  roots <- grep("^ducklake-preview", pt_gcs_ls(sprintf("gs://%s/", PT_BUCKET)), value = TRUE)
  stamped <- stats::setNames(roots, vapply(roots, function(r) pt_gcs_cat(sprintf("gs://%s/%s/dataset_key.txt", PT_BUCKET, r)), ""))
  stamped <- stamped[nzchar(names(stamped))]
  now  <- format(Sys.time(), "%Y-%m-%dT%H:%MZ", tz = "UTC")
  rows <- lapply(sort(held), function(key) {
    x  <- yml[[key]]
    if (is.null(x)) stop("held dataset ", key, " has no calcofi: YAML block", call. = FALSE)
    pr <- pt_pr_summary(pt_prs_for_dataset(prs, key, x$provider, x$dataset))
    root <- pt_candidate_root(key, roots, stamped)
    cand <- if (is.na(root)) "" else pt_gcs_cat(sprintf("gs://%s/%s/releases/latest.txt", PT_BUCKET, root))
    tok  <- toks[key]
    purl <- if (is.na(tok)) "" else sprintf("https://%s/%s/%s/", PT_HOST, key, tok)
    pbld <- if (is.na(tok)) "" else pt_gcs_cat(sprintf("gs://%s/datasets/%s-%s/current.txt", PT_BUCKET, key, tok))
    ndec <- length(grep("\\.json$", pt_gcs_ls(sprintf("gs://%s/consent/%s/", PT_BUCKET, key)), value = TRUE)) -
            length(grep("\\.applied\\.json$", pt_gcs_ls(sprintf("gs://%s/consent/%s/", PT_BUCKET, key))))
    cq <- pt_consent_row(file.path(workflow_dir, x$questions_file %||% ""))
    cstatus <- if (is.null(cq)) "" else cq$status
    data.frame(
      dataset_key = key, provider = x$provider,
      dataset_name = x$dataset_meta$dataset_name_short %||% x$dataset_meta$dataset_name %||% key,
      stage = pt_stage(pr$pr_state, cand, purl, cstatus, ndec),
      prs = pr$prs, pr_state = pr$pr_state, pr_url = pr$pr_url,
      candidate_version = cand, preview_url = purl, preview_build = pbld,
      decisions = as.character(ndec),
      consent_label = if (is.null(cq)) "" else cq$label,
      consent_status = cstatus,
      consent_who = if (is.null(cq) || is.na(cq$who)) "" else cq$who,
      consent_answered = if (is.null(cq) || is.na(cq$answered_date)) "" else as.character(cq$answered_date),
      notes = "", refreshed_utc = now, stringsAsFactors = FALSE)
  })
  pending <- pt_pr_new_datasets(prs, names(yml))
  rows_pr <- lapply(seq_len(nrow(pending)), function(i) {
    p  <- pending[i, ]
    pr <- pt_pr_summary(pt_prs_for_dataset(prs, p$key, p$provider, p$dataset))
    cq <- pt_consent_row_ref(p$provider, p$dataset, p$branch)
    cstatus <- if (is.null(cq)) "" else cq$status
    title <- prs[[match(p$number, vapply(prs, function(x) as.integer(x$number), 1L))]]$title %||% p$key
    data.frame(
      dataset_key = p$key, provider = p$provider, dataset_name = title,
      stage = pt_stage(pr$pr_state, "", "", cstatus, 0),
      prs = pr$prs, pr_state = pr$pr_state, pr_url = pr$pr_url,
      candidate_version = "", preview_url = "", preview_build = "", decisions = "0",
      consent_label = if (is.null(cq)) "" else cq$label,
      consent_status = cstatus,
      consent_who = if (is.null(cq) || is.na(cq$who)) "" else cq$who,
      consent_answered = if (is.null(cq) || is.na(cq$answered_date)) "" else as.character(cq$answered_date),
      notes = "", refreshed_utc = now, stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, c(rows, rows_pr))
  out[, PT_COLS]
}

pt_readme <- function(n) data.frame(
  section = c("what", "rows", "stage", "prs", "candidate_version", "preview_url", "decisions",
              "consent_*", "notes", "refresh"),
  text = c(
    "Internal tracker of every dataset held from the public release (in_release: false) along the private-preview pathway: PR → merge → candidate release → private preview → the provider's decision → consent recorded → released. Data team only; the preview links are private.",
    sprintf("One row per held dataset (%d today). Rows are generated from the repo, GitHub and gs://calcofi-preview by scripts/sync_preview_tracker.R; every column but `notes` is overwritten on each refresh.", n),
    "Where the dataset stands, derived from the other columns (see pt_stage() in the script).",
    "Every CalCOFI/workflows PR that changed the dataset's notebook, metadata folder or parquet sidecars, oldest first, each with its state: open, merged, or closed (closed without merge). pr_state and pr_url are the first (ingest) PR's.",
    "The candidate release in gs://calcofi-preview the preview streams (scripts/preview_candidate.sh); blank until a candidate was built.",
    "The private link sent to the provider (scripts/build_preview.sh, link mode); preview_build is the build it shows now.",
    "Decisions recorded in the preview's form and not yet folded into the consent question by scripts/pull_preview_consent.R.",
    "The dataset's consent question in metadata/{provider}/{dataset}/questions.csv and the provider's Sheet: answered = consent given, the public release may carry the dataset (check_dataset_consent()).",
    "The one column a person may type in; a refresh keeps it by dataset_key.",
    "Rscript scripts/sync_preview_tracker.R --execute (dry run without the flag). Documented in the preview-release skill and calcofi.io/docs/provide.html."),
  stringsAsFactors = FALSE)

# sheet --------------------------------------------------------------------

source(here("scripts/lib_google_auth.R"))

pt_load_yml <- function(path = PT_YML) if (file.exists(path)) yaml::read_yaml(path) else list()

pt_ensure_sheet <- function(yml, folder_id, share_with = PT_SHARE_WITH, auth_user = "") {
  if (!is.null(yml$sheet_id) && nzchar(yml$sheet_id)) return(list(ss = googlesheets4::as_sheets_id(yml$sheet_id), new = FALSE))
  f  <- googledrive::drive_create(PT_TITLE, path = googledrive::as_id(folder_id), type = "spreadsheet")
  ss <- googlesheets4::as_sheets_id(as.character(f$id))
  googlesheets4::sheet_rename(ss, sheet = 1, new_name = "README")
  shared <- character()
  for (email in setdiff(tolower(share_with), auth_user)) {
    ok <- tryCatch({
      googledrive::drive_share(googledrive::as_id(as.character(ss)), role = "writer", type = "user",
                               emailAddress = email, sendNotificationEmail = FALSE); TRUE },
      error = function(e) { cat("  share with ", email, " refused: ", substr(conditionMessage(e), 1, 80), "\n", sep = ""); FALSE })
    if (ok) shared <- c(shared, email)
  }
  cat("created ", PT_TITLE, " in folder ", folder_id, "; shared with ", paste(shared, collapse = ", "), "\n", sep = "")
  list(ss = ss, new = TRUE)
}

pt_write_sheet <- function(tbl, execute = FALSE) {
  who <- cc_google_auth(CC_GOOGLE_SCOPES)
  yml <- pt_load_yml()
  folder_id <- yaml::read_yaml(PT_SHEETS_YML)[["_folder"]]$id
  stopifnot(nzchar(folder_id %||% ""))
  s  <- pt_ensure_sheet(yml, folder_id, auth_user = who)
  ss <- s$ss
  if (s$new) {
    meta <- googlesheets4::gs4_get(ss)
    yaml::write_yaml(list(sheet_id = as.character(ss), url = meta$spreadsheet_url,
                          folder = folder_id, created = format(Sys.Date())), PT_YML)
  }
  old <- if (!s$new && PT_TAB %in% googlesheets4::sheet_names(ss))
    googlesheets4::range_read(ss, sheet = PT_TAB, col_types = "c") else NULL
  tbl <- pt_keep_notes(tbl, old)
  googlesheets4::sheet_write(pt_readme(nrow(tbl)), ss = ss, sheet = "README")
  googlesheets4::sheet_write(tbl, ss = ss, sheet = PT_TAB)
  props <- googlesheets4::sheet_properties(ss)
  sid   <- props$id[props$name == PT_TAB]
  googlesheets4::request_make(googlesheets4::request_generate(
    "sheets.spreadsheets.batchUpdate",
    params = list(spreadsheetId = as.character(ss), requests = list(
      list(updateSheetProperties = list(
        properties = list(sheetId = sid, gridProperties = list(frozenRowCount = 1, frozenColumnCount = 1)),
        fields = "gridProperties.frozenRowCount,gridProperties.frozenColumnCount")),
      list(autoResizeDimensions = list(dimensions = list(
        sheetId = sid, dimension = "COLUMNS", startIndex = 0, endIndex = length(PT_COLS))))))))
  cat("wrote ", nrow(tbl), " row(s) to ", googlesheets4::gs4_get(ss)$spreadsheet_url, "\n", sep = "")
  invisible(ss)
}

# main ---------------------------------------------------------------------

if (sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)
  execute <- "--execute" %in% args
  tbl <- pt_build_table()
  show <- tbl[, c("dataset_key", "stage", "prs", "candidate_version", "preview_url", "consent_status")]
  print(show, row.names = FALSE, right = FALSE)
  if (!execute) { cat("dry run — pass --execute to write the Sheet\n") } else pt_write_sheet(tbl, execute = TRUE)
}
